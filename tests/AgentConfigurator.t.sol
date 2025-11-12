// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AgentHub} from '../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../src/interfaces/IAgentHub.sol';
import {RiskOracle} from '../src/contracts/dependencies/RiskOracle.sol';
import {MockAgent} from './mocks/MockAgent.sol';

contract AgentConfigurator_Test is Test {
  AgentHub public _agentHub;
  MockAgent public _agent;
  RiskOracle public riskOracle;

  address public constant HUB_OWNER = address(25);
  address public constant RISK_ORACLE_OWNER = address(25);
  address public constant AGENT_ADMIN = address(26);
  address public constant TARGET_CONTRACT = address(20);
  address public constant MARKET = address(5);
  address public HUB_PROXY_ADMIN;
  string public UPDATE_TYPE = 'CapsUpdate';

  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function setUp() public virtual {
    _agentHub = AgentHub(
      address(
        new TransparentUpgradeableProxy(
          address(new AgentHub()),
          address(this),
          abi.encodeWithSelector(AgentHub.initialize.selector, HUB_OWNER)
        )
      )
    );
    HUB_PROXY_ADMIN = address(uint160(uint256(vm.load(address(_agentHub), ADMIN_SLOT))));

    // setup risk oracle
    vm.startPrank(RISK_ORACLE_OWNER);
    address[] memory initialSenders = new address[](1);
    initialSenders[0] = RISK_ORACLE_OWNER;
    string[] memory initialUpdateTypes = new string[](1);
    initialUpdateTypes[0] = UPDATE_TYPE;

    riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    _agent = new MockAgent(address(_agentHub));

    vm.warp(5 days);
  }

  function test_registerAgent() public {
    IAgentConfigurator.AgentRegistrationInput memory registrationInput = IAgentConfigurator
      .AgentRegistrationInput({
        agentAddress: address(_agent),
        riskOracle: address(riskOracle),
        admin: AGENT_ADMIN,
        agentContext: abi.encode(TARGET_CONTRACT),
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        expirationPeriod: 1 days,
        minimumDelay: 0,
        updateType: UPDATE_TYPE,
        allowedMarkets: _convertToArray(MARKET),
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      });

    vm.prank(HUB_OWNER);
    uint256 agentId = _agentHub.registerAgent(registrationInput);

    assertEq(_agentHub.getAgentCount(), 1);
    assertEq(_agentHub.getAgentAddress(agentId), registrationInput.agentAddress);
    assertEq(_agentHub.getRiskOracle(agentId), registrationInput.riskOracle);
    assertEq(_agentHub.getAgentAdmin(agentId), registrationInput.admin);
    assertEq(_agentHub.getAgentContext(agentId), registrationInput.agentContext);
    assertEq(_agentHub.isAgentEnabled(agentId), registrationInput.isAgentEnabled);
    assertEq(_agentHub.isAgentPermissioned(agentId), registrationInput.isAgentPermissioned);
    assertEq(
      _agentHub.isMarketsFromAgentEnabled(agentId),
      registrationInput.isMarketsFromAgentEnabled
    );
    assertEq(_agentHub.getMinimumDelay(agentId), registrationInput.minimumDelay);
    assertEq(_agentHub.getExpirationPeriod(agentId), registrationInput.expirationPeriod);
    assertEq(_agentHub.getUpdateType(agentId), registrationInput.updateType);
    assertEq(_agentHub.getAllowedMarkets(agentId), registrationInput.allowedMarkets);
    assertEq(_agentHub.getRestrictedMarkets(agentId), registrationInput.restrictedMarkets);
    assertEq(_agentHub.getPermissionedSenders(agentId), registrationInput.permissionedSenders);
  }

  function test_revert_onlyHubOwner_can_registerAgents(
    address caller
  ) public callerNotProxyAdmin(caller) {
    vm.assume(HUB_OWNER != caller);

    IAgentConfigurator.AgentRegistrationInput memory registrationInput;
    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    _agentHub.registerAgent(registrationInput);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setAgentContract(
    address caller,
    address agentAddress
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    _agentHub.setAgentAddress(agentId, agentAddress);
  }

  function test_setAgentContract(address agentAddress) public {
    uint256 agentId = _registerAgent();

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.AgentAddressSet(agentId, agentAddress);

    vm.prank(HUB_OWNER);
    _agentHub.setAgentAddress(agentId, agentAddress);
    assertEq(_agentHub.getAgentAddress(agentId), agentAddress);
  }

  function test_revert_onlyOwner_can_setAgentAdmin(
    address caller,
    address agentAdmin
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    _agentHub.setAgentAdmin(agentId, agentAdmin);
  }

  function test_revert_agentAdminCannotBeHubOrAgentContract() public {
    uint256 agentId = _registerAgent();

    vm.startPrank(HUB_OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.InvalidAgentAdmin.selector, address(_agentHub))
    );
    _agentHub.setAgentAdmin(agentId, address(_agentHub));

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.InvalidAgentAdmin.selector, address(_agent))
    );
    _agentHub.setAgentAdmin(agentId, address(_agent));
  }

  function test_setAgentAdmin(address agentAdmin) public {
    vm.assume(agentAdmin != address(_agentHub) && agentAdmin != address(_agent));
    uint256 agentId = _registerAgent();

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.AgentAdminSet(agentId, agentAdmin);

    vm.prank(HUB_OWNER);
    _agentHub.setAgentAdmin(agentId, agentAdmin);
    assertEq(_agentHub.getAgentAdmin(agentId), agentAdmin);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setAgentAsPermissioned(
    address caller,
    bool isAgentPermissioned
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.setAgentAsPermissioned(agentId, isAgentPermissioned);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setPermissionedSender(
    address caller,
    address permissionedSender
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.startPrank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.addPermissionedSender(agentId, permissionedSender);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.removePermissionedSender(agentId, permissionedSender);

    vm.stopPrank();
  }

  function test_setPermissionedSender(address permissionedSender) public {
    uint256 agentId = _registerAgent();

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.PermissionedSenderAdded(agentId, permissionedSender);

    vm.prank(AGENT_ADMIN);
    _agentHub.addPermissionedSender(agentId, permissionedSender);
    assertTrue(_agentHub.isPermissionedSender(agentId, permissionedSender));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.PermissionedSenderRemoved(agentId, permissionedSender);

    vm.prank(AGENT_ADMIN);
    _agentHub.removePermissionedSender(agentId, permissionedSender);
    assertFalse(_agentHub.isPermissionedSender(agentId, permissionedSender));
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setAllowedMarket(
    address caller,
    address market
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.startPrank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.addAllowedMarket(agentId, market);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.removeAllowedMarket(agentId, market);

    vm.stopPrank();
  }

  function test_setAllowedMarket(address market) public {
    vm.assume(market != MARKET);
    uint256 agentId = _registerAgent();
    vm.startPrank(AGENT_ADMIN);

    address[] memory currentMarkets = _convertToArray(MARKET);
    assertEq(_agentHub.getAllowedMarkets(agentId), currentMarkets);

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.AllowedMarketAdded(agentId, market);
    _agentHub.addAllowedMarket(agentId, market);

    // no event emitted as market already added
    vm.recordLogs();
    _agentHub.addAllowedMarket(agentId, market);
    assertEq(vm.getRecordedLogs().length, 0);

    currentMarkets = new address[](2);
    currentMarkets[0] = MARKET;
    currentMarkets[1] = market;
    assertEq(_agentHub.getAllowedMarkets(agentId), currentMarkets);

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.AllowedMarketRemoved(agentId, market);
    _agentHub.removeAllowedMarket(agentId, market);

    // no event emitted as market already removed
    vm.recordLogs();
    _agentHub.removeAllowedMarket(agentId, market);
    assertEq(vm.getRecordedLogs().length, 0);

    currentMarkets = _convertToArray(MARKET);
    assertEq(_agentHub.getAllowedMarkets(agentId), currentMarkets);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setRestrictedMarket(
    address caller,
    address market
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.startPrank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.addRestrictedMarket(agentId, market);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.removeRestrictedMarket(agentId, market);

    vm.stopPrank();
  }

  function test_setRestrictedMarket(address market) public {
    uint256 agentId = _registerAgent();
    vm.startPrank(AGENT_ADMIN);

    assertEq(_agentHub.getRestrictedMarkets(agentId), new address[](0));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.RestrictedMarketAdded(agentId, market);
    _agentHub.addRestrictedMarket(agentId, market);

    // no event emitted as market already added
    vm.recordLogs();
    _agentHub.addRestrictedMarket(agentId, market);
    assertEq(vm.getRecordedLogs().length, 0);

    assertEq(_agentHub.getRestrictedMarkets(agentId), _convertToArray(market));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.RestrictedMarketRemoved(agentId, market);
    _agentHub.removeRestrictedMarket(agentId, market);

    // no event emitted as market already removed
    vm.recordLogs();
    _agentHub.removeRestrictedMarket(agentId, market);
    assertEq(vm.getRecordedLogs().length, 0);

    assertEq(_agentHub.getRestrictedMarkets(agentId), new address[](0));
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setAgentEnabled(
    address caller,
    bool enable
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.setAgentEnabled(agentId, enable);
  }

  function test_setAgentEnabled(bool enable) public {
    uint256 agentId = _registerAgent();
    assertTrue(_agentHub.isAgentEnabled(agentId));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.AgentEnabledSet(agentId, enable);

    vm.prank(AGENT_ADMIN);
    _agentHub.setAgentEnabled(agentId, enable);
    assertEq(_agentHub.isAgentEnabled(agentId), enable);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setExpirationPeriod(
    address caller,
    uint32 expirationPeriod
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.setExpirationPeriod(agentId, expirationPeriod);
  }

  function test_setExpirationPeriod(uint32 expirationPeriod) public {
    uint256 agentId = _registerAgent();

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.ExpirationPeriodSet(agentId, expirationPeriod);

    vm.prank(AGENT_ADMIN);
    _agentHub.setExpirationPeriod(agentId, expirationPeriod);
    assertEq(_agentHub.getExpirationPeriod(agentId), expirationPeriod);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setMinimumDelay(
    address caller,
    uint32 minDelay
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.startPrank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.setMinimumDelay(agentId, minDelay);

    vm.stopPrank();
  }

  function test_setMinimumDelay(uint32 minDelay) public {
    uint256 agentId = _registerAgent();

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.MinimumDelaySet(agentId, minDelay);

    vm.prank(AGENT_ADMIN);
    _agentHub.setMinimumDelay(agentId, minDelay);
    assertEq(_agentHub.getMinimumDelay(agentId), minDelay);
  }

  function test_revert_onlyOwner_can_setMaxBatchSize(
    address caller,
    uint16 maxBatchSize
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != HUB_OWNER);
    vm.prank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    _agentHub.setMaxBatchSize(maxBatchSize);
  }

  function test_setMaxBatchSize(uint16 maxBatchSize) public {
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.MaxBatchSizeSet(maxBatchSize);

    vm.prank(HUB_OWNER);
    _agentHub.setMaxBatchSize(maxBatchSize);
    assertEq(_agentHub.getMaxBatchSize(), maxBatchSize);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setAgentContext(
    address caller,
    bytes memory config
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.setAgentContext(agentId, config);
  }

  function test_setAgentContext(bytes memory config) public {
    uint256 agentId = _registerAgent();

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.AgentContextSet(agentId, config);

    vm.prank(AGENT_ADMIN);
    _agentHub.setAgentContext(agentId, config);
    assertEq(_agentHub.getAgentContext(agentId), config);
  }

  function test_revert_onlyOwnerOrAgentAdmin_can_setAllMarketsAllowed(
    address caller,
    bool allowed
  ) public callerNotProxyAdmin(caller) {
    vm.assume(caller != AGENT_ADMIN && caller != HUB_OWNER);
    uint256 agentId = _registerAgent();

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAgentConfigurator.OnlyOwnerOrAgentAdmin.selector, caller)
    );
    _agentHub.setMarketsFromAgentEnabled(agentId, allowed);
  }

  function test_setAllMarketsAllowed() public {
    uint256 agentId = _registerAgent();
    assertFalse(_agentHub.isMarketsFromAgentEnabled(agentId));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.MarketsFromAgentEnabled(agentId, true);

    vm.prank(AGENT_ADMIN);
    _agentHub.setMarketsFromAgentEnabled(agentId, true);
    assertTrue(_agentHub.isMarketsFromAgentEnabled(agentId));
  }

  /* ----------------------------------------- Helper methods ----------------------------------------- */

  function _registerAgent() internal returns (uint256 agentId) {
    address[] memory markets = new address[](1);
    markets[0] = MARKET;

    vm.startPrank(HUB_OWNER);
    agentId = _agentHub.registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        agentAddress: address(_agent),
        riskOracle: address(riskOracle),
        admin: AGENT_ADMIN,
        agentContext: abi.encode(TARGET_CONTRACT),
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        expirationPeriod: 1 days,
        minimumDelay: 0,
        updateType: UPDATE_TYPE,
        allowedMarkets: markets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );
    vm.stopPrank();
  }

  function _convertToArray(address value) internal pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = value;
  }

  modifier callerNotProxyAdmin(address caller) {
    vm.assume(caller != HUB_PROXY_ADMIN);
    _;
  }
}
