// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {EnumerableSet} from 'openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol';

import {IAgentConfigurator} from '../interfaces/IAgentConfigurator.sol';

/**
 * @title AgentConfigurator
 * @author BGD Labs
 * @notice Contract to manage configurations for the AgentHub.
 */
abstract contract AgentConfigurator is OwnableUpgradeable, IAgentConfigurator {
  using SafeCast for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  /**
   * @custom:storage-location erc7201:agent.storage.hub
   */
  struct AgentHubStorage {
    /// @notice the total number of agents registered for this hub
    uint240 agentCount;
    /// @notice the max batch size for the hub, used as soft measure to prevent exceeding the gas limit
    uint16 maxBatchSize;
    /// @notice map of agent specific configuration
    mapping(uint256 agentId => AgentConfig) config;
  }

  /**
   * @notice Struct storing the agent configurations
   */
  struct AgentConfig {
    /// @notice map of last injected update including updateId and timestamp for the market
    mapping(address market => LastInjectedUpdate) lastInjectedUpdate;
    /// @notice enumerable set of allowed markets, used only when isMarketsFromAgentEnabled is false
    EnumerableSet.AddressSet allowedMarkets;
    /// @notice enumerable set of restricted markets, used only when isMarketsFromAgentEnabled is true
    EnumerableSet.AddressSet restrictedMarkets;
    /// @notice enumerable set of permissioned senders allowed to call `execute()` for the agent
    EnumerableSet.AddressSet permissionedSenders;
    /// @notice address of the admin of the agent, which can update configurations
    address admin;
    /// @notice the update type string for the agent
    string updateType;
    /// @notice struct storing basic config for the agent, packed tightly to reduce sloads
    BasicConfig basicConfig;
  }

  /**
   * @notice Struct storing the basic agent configurations
   */
  struct BasicConfig {
    /// @notice address of the chaos risk-oracle used by the agent
    address riskOracle;
    /// @notice bool storing if the agent is enabled or not
    bool isAgentEnabled;
    /// @notice bool storing if the agent is permissioned or not
    bool isAgentPermissioned;
    /// @notice bool storing if to fetch configured markets from agent
    bool isMarketsFromAgentEnabled;
    /// @notice address of the agent contract which is used to do agent specific validation and injection
    address agentAddress;
    /// @notice expiration period for the update of the agent in seconds
    uint32 expirationPeriod;
    /// @notice minimum delay configured for the agent in seconds
    uint32 minimumDelay;
    /// @notice stores misc config for the agent, typically used during agent validation and injection
    bytes agentContext;
  }

  // keccak256(abi.encode(uint256(keccak256('agent.storage.hub')) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant AGENT_HUB_STORAGE_LOCATION =
    0xa6a8e78397042a5280bd150d020dc296a49efd5c4cfc37400f38cd94c9ec6400;

  /**
   * @notice method to get the storage pointer for the AgentHub as per EIP 7201
   * @return $ storage pointer of the AgentHub contract
   */
  function _getStorage() internal pure returns (AgentHubStorage storage $) {
    assembly {
      $.slot := AGENT_HUB_STORAGE_LOCATION
    }
  }

  function __AgentConfigurator_init(address agentHubOwner) internal onlyInitializing {
    __Ownable_init(agentHubOwner);
  }

  modifier onlyOwnerOrAgentAdmin(uint256 agentId) {
    require(
      owner() == _msgSender() || getAgentAdmin(agentId) == _msgSender(),
      OnlyOwnerOrAgentAdmin(_msgSender())
    );
    _;
  }

  /// @inheritdoc IAgentConfigurator
  function registerAgent(
    AgentRegistrationInput calldata input
  ) external onlyOwner returns (uint256) {
    AgentHubStorage storage $ = _getStorage();
    uint256 agentId = $.agentCount++;
    AgentConfig storage config = $.config[agentId];

    // basic agent registration
    config.updateType = input.updateType;
    config.basicConfig.riskOracle = input.riskOracle;
    emit AgentRegistered(agentId, input.riskOracle, config.updateType);

    // agent configuration
    setAgentAddress(agentId, input.agentAddress);
    setAgentAdmin(agentId, input.admin);
    setAgentEnabled(agentId, input.isAgentEnabled);
    setAgentAsPermissioned(agentId, input.isAgentPermissioned);
    setMarketsFromAgentEnabled(agentId, input.isMarketsFromAgentEnabled);
    setExpirationPeriod(agentId, input.expirationPeriod);
    setMinimumDelay(agentId, input.minimumDelay);
    setAgentContext(agentId, input.agentContext);

    // configure markets on agent
    for (uint256 i = 0; i < input.allowedMarkets.length; i++) {
      addAllowedMarket(agentId, input.allowedMarkets[i]);
    }
    for (uint256 i = 0; i < input.restrictedMarkets.length; i++) {
      addRestrictedMarket(agentId, input.restrictedMarkets[i]);
    }
    for (uint256 i = 0; i < input.permissionedSenders.length; i++) {
      addPermissionedSender(agentId, input.permissionedSenders[i]);
    }

    return agentId;
  }

  /// @inheritdoc IAgentConfigurator
  function setAgentAdmin(uint256 agentId, address admin) public onlyOwner {
    require(admin != address(this) && admin != getAgentAddress(agentId), InvalidAgentAdmin(admin));

    _getStorage().config[agentId].admin = admin;
    emit AgentAdminSet(agentId, admin);
  }

  /// @inheritdoc IAgentConfigurator
  function setMaxBatchSize(uint256 maxBatchSize) external onlyOwner {
    _getStorage().maxBatchSize = maxBatchSize.toUint16();
    emit MaxBatchSizeSet(maxBatchSize);
  }

  /// @inheritdoc IAgentConfigurator
  function setAgentAddress(uint256 agentId, address agentAddress) public onlyOwner {
    _getStorage().config[agentId].basicConfig.agentAddress = agentAddress;
    emit AgentAddressSet(agentId, agentAddress);
  }

  /// @inheritdoc IAgentConfigurator
  function setAgentAsPermissioned(
    uint256 agentId,
    bool permissioned
  ) public onlyOwnerOrAgentAdmin(agentId) {
    _getStorage().config[agentId].basicConfig.isAgentPermissioned = permissioned;
    emit AgentPermissionedStatusSet(agentId, permissioned);
  }

  /// @inheritdoc IAgentConfigurator
  function addPermissionedSender(
    uint256 agentId,
    address sender
  ) public onlyOwnerOrAgentAdmin(agentId) {
    bool success = _getStorage().config[agentId].permissionedSenders.add(sender);
    if (success) emit PermissionedSenderAdded(agentId, sender);
  }

  /// @inheritdoc IAgentConfigurator
  function removePermissionedSender(
    uint256 agentId,
    address sender
  ) external onlyOwnerOrAgentAdmin(agentId) {
    bool success = _getStorage().config[agentId].permissionedSenders.remove(sender);
    if (success) emit PermissionedSenderRemoved(agentId, sender);
  }

  /// @inheritdoc IAgentConfigurator
  function addAllowedMarket(uint256 agentId, address market) public onlyOwnerOrAgentAdmin(agentId) {
    bool success = _getStorage().config[agentId].allowedMarkets.add(market);
    if (success) emit AllowedMarketAdded(agentId, market);
  }

  /// @inheritdoc IAgentConfigurator
  function removeAllowedMarket(
    uint256 agentId,
    address market
  ) public onlyOwnerOrAgentAdmin(agentId) {
    bool success = _getStorage().config[agentId].allowedMarkets.remove(market);
    if (success) emit AllowedMarketRemoved(agentId, market);
  }

  /// @inheritdoc IAgentConfigurator
  function addRestrictedMarket(
    uint256 agentId,
    address market
  ) public onlyOwnerOrAgentAdmin(agentId) {
    bool success = _getStorage().config[agentId].restrictedMarkets.add(market);
    if (success) emit RestrictedMarketAdded(agentId, market);
  }

  /// @inheritdoc IAgentConfigurator
  function removeRestrictedMarket(
    uint256 agentId,
    address market
  ) external onlyOwnerOrAgentAdmin(agentId) {
    bool success = _getStorage().config[agentId].restrictedMarkets.remove(market);
    if (success) emit RestrictedMarketRemoved(agentId, market);
  }

  /// @inheritdoc IAgentConfigurator
  function setExpirationPeriod(
    uint256 agentId,
    uint256 expirationPeriod
  ) public onlyOwnerOrAgentAdmin(agentId) {
    _getStorage().config[agentId].basicConfig.expirationPeriod = expirationPeriod.toUint32();
    emit ExpirationPeriodSet(agentId, expirationPeriod);
  }

  /// @inheritdoc IAgentConfigurator
  function setAgentEnabled(uint256 agentId, bool enable) public onlyOwnerOrAgentAdmin(agentId) {
    _getStorage().config[agentId].basicConfig.isAgentEnabled = enable;
    emit AgentEnabledSet(agentId, enable);
  }

  /// @inheritdoc IAgentConfigurator
  function setMinimumDelay(
    uint256 agentId,
    uint256 minimumDelay
  ) public onlyOwnerOrAgentAdmin(agentId) {
    _getStorage().config[agentId].basicConfig.minimumDelay = minimumDelay.toUint32();
    emit MinimumDelaySet(agentId, minimumDelay);
  }

  /// @inheritdoc IAgentConfigurator
  function setAgentContext(
    uint256 agentId,
    bytes calldata context
  ) public onlyOwnerOrAgentAdmin(agentId) {
    _getStorage().config[agentId].basicConfig.agentContext = context;
    emit AgentContextSet(agentId, context);
  }

  /// @inheritdoc IAgentConfigurator
  function setMarketsFromAgentEnabled(
    uint256 agentId,
    bool enabled
  ) public onlyOwnerOrAgentAdmin(agentId) {
    _getStorage().config[agentId].basicConfig.isMarketsFromAgentEnabled = enabled;
    emit MarketsFromAgentEnabled(agentId, enabled);
  }

  /// @inheritdoc IAgentConfigurator
  function getAgentAdmin(uint256 agentId) public view returns (address) {
    return _getStorage().config[agentId].admin;
  }

  /// @inheritdoc IAgentConfigurator
  function getMaxBatchSize() external view returns (uint256) {
    return _getStorage().maxBatchSize;
  }

  /// @inheritdoc IAgentConfigurator
  function getAgentAddress(uint256 agentId) public view returns (address) {
    return _getStorage().config[agentId].basicConfig.agentAddress;
  }

  /// @inheritdoc IAgentConfigurator
  function isAgentPermissioned(uint256 agentId) external view returns (bool) {
    return _getStorage().config[agentId].basicConfig.isAgentPermissioned;
  }

  /// @inheritdoc IAgentConfigurator
  function getPermissionedSenders(uint256 agentId) external view returns (address[] memory) {
    return _getStorage().config[agentId].permissionedSenders.values();
  }

  /// @inheritdoc IAgentConfigurator
  function isPermissionedSender(uint256 agentId, address sender) external view returns (bool) {
    return _getStorage().config[agentId].permissionedSenders.contains(sender);
  }

  /// @inheritdoc IAgentConfigurator
  function getAllowedMarkets(uint256 agentId) external view returns (address[] memory) {
    return _getStorage().config[agentId].allowedMarkets.values();
  }

  /// @inheritdoc IAgentConfigurator
  function getRestrictedMarkets(uint256 agentId) external view returns (address[] memory) {
    return _getStorage().config[agentId].restrictedMarkets.values();
  }

  /// @inheritdoc IAgentConfigurator
  function getExpirationPeriod(uint256 agentId) external view returns (uint256) {
    return _getStorage().config[agentId].basicConfig.expirationPeriod;
  }

  /// @inheritdoc IAgentConfigurator
  function isAgentEnabled(uint256 agentId) external view returns (bool) {
    return _getStorage().config[agentId].basicConfig.isAgentEnabled;
  }

  /// @inheritdoc IAgentConfigurator
  function getMinimumDelay(uint256 agentId) external view returns (uint256) {
    return _getStorage().config[agentId].basicConfig.minimumDelay;
  }

  /// @inheritdoc IAgentConfigurator
  function getAgentContext(uint256 agentId) external view returns (bytes memory) {
    return _getStorage().config[agentId].basicConfig.agentContext;
  }

  /// @inheritdoc IAgentConfigurator
  function isMarketsFromAgentEnabled(uint256 agentId) external view returns (bool) {
    return _getStorage().config[agentId].basicConfig.isMarketsFromAgentEnabled;
  }

  /// @inheritdoc IAgentConfigurator
  function getUpdateType(uint256 agentId) external view returns (string memory) {
    return _getStorage().config[agentId].updateType;
  }

  /// @inheritdoc IAgentConfigurator
  function getRiskOracle(uint256 agentId) external view returns (address) {
    return _getStorage().config[agentId].basicConfig.riskOracle;
  }

  /// @inheritdoc IAgentConfigurator
  function getAgentCount() external view returns (uint256) {
    return _getStorage().agentCount;
  }

  /// @inheritdoc IAgentConfigurator
  function getLastInjectedUpdate(
    uint256 agentId,
    address market
  ) external view returns (LastInjectedUpdate memory) {
    return _getStorage().config[agentId].lastInjectedUpdate[market];
  }

  /**
   * @notice method to mark an update for a market as injected
   * @param config the config of the agent
   * @param market the address of the market to update parameters
   * @param updateType the update type to execute
   * @param updateId the updateId corresponding to the update
   * @param newValue the new value of parameters
   */
  function _setUpdateInjected(
    AgentConfig storage config,
    uint256 agentId,
    address market,
    string memory updateType,
    uint256 updateId,
    bytes memory newValue
  ) internal {
    config.lastInjectedUpdate[market] = LastInjectedUpdate({
      timestamp: block.timestamp.toUint48(),
      id: updateId.toUint208()
    });

    emit UpdateInjected(agentId, market, updateType, updateId, newValue);
  }
}
