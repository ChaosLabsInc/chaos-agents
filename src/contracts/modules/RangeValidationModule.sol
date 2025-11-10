// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IOwnable} from 'aave-address-book/common/IOwnable.sol';

import {IRangeValidationModule} from '../../interfaces/IRangeValidationModule.sol';
import {IAgentHub} from '../../interfaces/IAgentHub.sol';

/**
 * @title RangeValidationModule
 * @author BGD Labs
 * @notice Contract shared across agents to validate range and also configure range per agent with access control
 */
contract RangeValidationModule is IRangeValidationModule {
  uint256 internal constant BPS_MAX = 100_00;

  struct AgentConfig {
    /// @notice the default range config for the agent
    RangeConfig defaultConfig;
    /// @notice the market specific range config for the agent
    mapping(address => RangeConfig) marketConfig;
  }

  mapping(bytes32 configId => AgentConfig) internal _rangeConfigs;

  modifier onlyHubOwnerOrAgentAdmin(address agentHub, uint256 agentId) {
    require(
      msg.sender == IAgentHub(agentHub).getAgentAdmin(agentId) ||
        msg.sender == IOwnable(agentHub).owner(),
      OnlyHubOwnerOrAgentAdmin(msg.sender)
    );
    _;
  }

  /// @inheritdoc IRangeValidationModule
  function validate(
    address agentHub,
    uint256 agentId,
    address market,
    RangeValidationInput calldata input
  ) public view returns (bool) {
    bytes32 configId = _getRangeConfigId(agentHub, agentId, input.updateType);
    AgentConfig storage agentConfig = _rangeConfigs[configId];
    RangeConfig memory config = agentConfig.marketConfig[market];

    // if config is not set for a specific market, fallback to the default configuration
    if (config.maxIncrease == 0 && config.maxDecrease == 0) {
      config = agentConfig.defaultConfig;
    }

    return _validateRange(input.from, input.to, config);
  }

  /// @inheritdoc IRangeValidationModule
  function validate(
    address agentHub,
    uint256 agentId,
    address market,
    RangeValidationInput[] calldata input
  ) external view returns (bool) {
    for (uint256 i = 0; i < input.length; i++) {
      if (!validate(agentHub, agentId, market, input[i])) return false;
    }
    return true;
  }

  /// @inheritdoc IRangeValidationModule
  function setDefaultRangeConfig(
    address agentHub,
    uint256 agentId,
    string calldata updateType,
    RangeConfig calldata config
  ) external onlyHubOwnerOrAgentAdmin(agentHub, agentId) {
    require(
      !config.isDecreaseRelative || config.maxDecrease <= 100_00,
      InvalidMaxRelativeDecrease(config.maxDecrease)
    );
    bytes32 configId = _getRangeConfigId(agentHub, agentId, updateType);
    _rangeConfigs[configId].defaultConfig = config;

    emit DefaultRangeConfigSet(agentHub, agentId, updateType, config);
  }

  /// @inheritdoc IRangeValidationModule
  function setRangeConfigByMarket(
    address agentHub,
    uint256 agentId,
    address market,
    string calldata updateType,
    RangeConfig calldata config
  ) external onlyHubOwnerOrAgentAdmin(agentHub, agentId) {
    require(
      !config.isDecreaseRelative || config.maxDecrease <= 100_00,
      InvalidMaxRelativeDecrease(config.maxDecrease)
    );
    bytes32 configId = _getRangeConfigId(agentHub, agentId, updateType);
    _rangeConfigs[configId].marketConfig[market] = config;

    emit MarketRangeConfigSet(agentHub, agentId, market, updateType, config);
  }

  /// @inheritdoc IRangeValidationModule
  function getDefaultRangeConfig(
    address agentHub,
    uint256 agentId,
    string calldata updateType
  ) external view returns (RangeConfig memory) {
    bytes32 configId = _getRangeConfigId(agentHub, agentId, updateType);
    return _rangeConfigs[configId].defaultConfig;
  }

  /// @inheritdoc IRangeValidationModule
  function getRangeConfigByMarket(
    address agentHub,
    uint256 agentId,
    address market,
    string calldata updateType
  ) external view returns (RangeConfig memory) {
    bytes32 configId = _getRangeConfigId(agentHub, agentId, updateType);
    return _rangeConfigs[configId].marketConfig[market];
  }

  /**
   * @notice method to get the range configuration id, unique to each configuration
   * @param agentHub address of the agentHub contract of the agent
   * @param agentId id of the agent configured on the agentHub
   * @param updateType updateType for which to get configuration id
   * @return id unique to each configuration, which is used to set and get range configuration
   */
  function _getRangeConfigId(
    address agentHub,
    uint256 agentId,
    string calldata updateType
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(agentHub, agentId, updateType));
  }

  /**
   * @notice Ensures the risk param update is within the allowed range
   * @param from current risk param value
   * @param to new updated risk param value
   * @param config struct storing the RangeConfig used to validate
   * @return true if the risk param value is in the configured range
   */
  function _validateRange(
    uint256 from,
    uint256 to,
    RangeConfig memory config
  ) internal pure returns (bool) {
    uint256 diff;
    uint256 maxChange;
    bool isRelativeChange;

    if (from < to) {
      diff = to - from;
      maxChange = config.maxIncrease;
      isRelativeChange = config.isIncreaseRelative;
    } else {
      diff = from - to;
      maxChange = config.maxDecrease;
      isRelativeChange = config.isDecreaseRelative;
    }

    // maxDiff denotes the max permitted difference, if the maxChange is relative in value, we
    // calculate the max permitted difference using the maxChange and the from value, otherwise
    // if the maxChange is absolute in value the max permitted difference is the maxChange itself
    uint256 maxDiff = isRelativeChange ? (maxChange * from) / BPS_MAX : maxChange;

    // in case of relative change, `maxDiff` is rounded down due to the nature of the division operator
    // in solidity, so in case of precision loss maxDiff is always smaller so we always return in favour that
    // the update is not in valid range
    return diff <= maxDiff;
  }
}
