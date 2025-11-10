// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {EnumerableSet} from 'openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol';

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IAgentHub} from '../interfaces/IAgentHub.sol';
import {IBaseAgent} from '../interfaces/IBaseAgent.sol';
import {AgentConfigurator} from './AgentConfigurator.sol';

/**
 * @title AgentHub
 * @author BGD Labs
 * @notice Contract acting as an orchestrator of agents, defining the high-level logic of simulation,
 *         validation (both hub's and agents') and final injection of updates via agents
 */
contract AgentHub is AgentConfigurator, IAgentHub {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor() {
    _disableInitializers();
  }

  function initialize(address agentHubOwner) external initializer {
    __AgentConfigurator_init(agentHubOwner);
  }

  /// @inheritdoc IAgentHub
  function check(
    uint256[] memory agentIds
  ) public view virtual returns (bool, ActionData[] memory) {
    ActionData[] memory actionData = new ActionData[](agentIds.length);
    uint256 actionCount;

    AgentHubStorage storage $ = _getStorage();
    uint256 maxBatchSize = $.maxBatchSize;
    uint256 batchSize; // total number of updates across all agents

    for (uint256 i = 0; i < agentIds.length; i++) {
      uint256 agentId = agentIds[i];

      AgentConfig storage config = $.config[agentId];
      BasicConfig memory basicConfig = config.basicConfig;

      if (!basicConfig.isAgentEnabled) continue;

      address[] memory markets = _getAgentMarkets(
        config,
        basicConfig.isMarketsFromAgentEnabled,
        basicConfig.agentAddress,
        agentId
      );
      if (markets.length == 0) continue;

      IRiskOracle riskOracle = IRiskOracle(basicConfig.riskOracle);
      string memory updateType = config.updateType;

      address[] memory marketsToUpdate = new address[](markets.length);
      uint256 marketsToUpdateCount;
      for (uint256 j = 0; j < markets.length; j++) {
        // The Risk Oracle is expected to revert if we query a non-existing update.
        // In that case, we simply skip the market
        try riskOracle.getLatestUpdateByParameterAndMarket(updateType, markets[j]) returns (
          IRiskOracle.RiskParameterUpdate memory updateRiskParams
        ) {
          if (_validateBasics(config, basicConfig, agentId, updateRiskParams)) {
            marketsToUpdate[marketsToUpdateCount++] = updateRiskParams.market;
            batchSize++;
          }
        } catch {}

        // stop collecting data if we reached max batch size, to protect against gas overflow on execution
        if (maxBatchSize != 0 && batchSize == maxBatchSize) break;
      }

      if (marketsToUpdateCount != 0) {
        assembly {
          mstore(marketsToUpdate, marketsToUpdateCount)
        }
        actionData[actionCount].agentId = agentId;
        actionData[actionCount].markets = marketsToUpdate;
        actionCount++;
      }

      // stop collecting data if we reached max batch size, to protect against gas overflow on execution
      if (maxBatchSize != 0 && batchSize == maxBatchSize) break;
    }

    assembly {
      mstore(actionData, actionCount)
    }

    return (actionCount != 0, actionData);
  }

  /// @inheritdoc IAgentHub
  function execute(ActionData[] memory actionData) public virtual {
    AgentHubStorage storage $ = _getStorage();
    bool hasValidActions;

    for (uint256 i = 0; i < actionData.length; i++) {
      uint256 agentId = actionData[i].agentId;
      address[] memory markets = actionData[i].markets;

      AgentConfig storage config = $.config[agentId];
      BasicConfig memory basicConfig = config.basicConfig;

      // skip if agent is disabled or user is not authorized
      if (
        !basicConfig.isAgentEnabled ||
        (basicConfig.isAgentPermissioned && !config.permissionedSenders.contains(_msgSender()))
      ) continue;

      string memory updateType = config.updateType;

      address[] memory configuredMarkets = _getAgentMarkets(
        config,
        basicConfig.isMarketsFromAgentEnabled,
        basicConfig.agentAddress,
        agentId
      );

      for (uint256 j = 0; j < markets.length; j++) {
        // The Risk Oracle is expected to revert if we query a non-existing update.
        // In that case, we simply skip the market
        try
          IRiskOracle(basicConfig.riskOracle).getLatestUpdateByParameterAndMarket(
            updateType,
            markets[j]
          )
        returns (IRiskOracle.RiskParameterUpdate memory update) {
          if (
            _validateBasics(config, basicConfig, agentId, update) &&
            // checks that the market from update corresponds to the configured markets on the agent
            _isMarketConfigured(configuredMarkets, update.market)
          ) {
            _setUpdateInjected(
              config,
              agentId,
              update.market,
              updateType,
              update.updateId,
              update.newValue
            );
            IBaseAgent(basicConfig.agentAddress).inject(agentId, basicConfig.agentContext, update);
            hasValidActions = true;
          }
        } catch {}
      }
    }
    require(hasValidActions, NoActionCanBePerformed());
  }

  /**
   * @notice method to fetch markets for the corresponding agent
   * @param config the config of the agent
   * @param isMarketsFromAgentEnabled true if markets should be fetched from the agent,
   *                                  false if allowedMarkets should be taken from the Hub configuration
   * @param agentAddress the agent address
   * @param agentId the agentId
   * @return list of markets corresponding to the agentId
   */
  function _getAgentMarkets(
    AgentConfig storage config,
    bool isMarketsFromAgentEnabled,
    address agentAddress,
    uint256 agentId
  ) internal view returns (address[] memory) {
    // Case we fetch only allowed markets configured on the Hub for this Agent
    if (!isMarketsFromAgentEnabled) {
      return config.allowedMarkets.values();
    }

    // Otherwise we fetch all markets from the Agent and apply the configured restricted markets
    address[] memory markets = IBaseAgent(agentAddress).getMarkets(agentId);
    if (config.restrictedMarkets.length() == 0) return markets;

    uint256 validMarketCount;
    address[] memory validMarkets = new address[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      if (!config.restrictedMarkets.contains(markets[i])) {
        validMarkets[validMarketCount++] = markets[i];
      }
    }
    assembly {
      mstore(validMarkets, validMarketCount)
    }

    return validMarkets;
  }

  /**
   * @notice method to do generic and agent specific validation for an update
   * @param config the config of the agent
   * @param basicConfig the basic config of the agent
   * @param agentId the agentId for the agent for which to validate the update
   * @param update the risk oracle update to validate
   * @return true if the generic and agent specific validation passes for an update
   */
  function _validateBasics(
    AgentConfig storage config,
    BasicConfig memory basicConfig,
    uint256 agentId,
    IRiskOracle.RiskParameterUpdate memory update
  ) internal view returns (bool) {
    // validates if the update is not expired
    if (update.timestamp + basicConfig.expirationPeriod < block.timestamp) return false;

    LastInjectedUpdate memory lastInjectedUpdate = config.lastInjectedUpdate[update.market];
    // validates if the updateId is not executed before
    if (lastInjectedUpdate.id >= update.updateId) return false;
    // validates if minimum delay has passed since the last update for an agent and market
    if (block.timestamp - lastInjectedUpdate.timestamp < basicConfig.minimumDelay) return false;

    // agent specific validation
    return IBaseAgent(basicConfig.agentAddress).validate(agentId, basicConfig.agentContext, update);
  }

  /**
   * @notice method to check that address included into the array
   * @param configuredMarkets the list of configured markets for the agent
   * @param market the address to check
   * @return true if market was configured, false otherwise
   */
  function _isMarketConfigured(
    address[] memory configuredMarkets,
    address market
  ) internal pure returns (bool) {
    for (uint256 i = 0; i < configuredMarkets.length; i++) {
      if (configuredMarkets[i] == market) {
        return true;
      }
    }
    return false;
  }
}
