// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AgentHub, IAgentHub} from '../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../src/interfaces/IAgentHub.sol';
import {RiskOracle} from '../src/contracts/dependencies/RiskOracle.sol';
import {MockAgentReentrantOne} from './mocks/MockAgentReentrantOne.sol';
import {MockAgentReentrantTwo} from './mocks/MockAgentReentrantTwo.sol';
import {MockAgent} from './mocks/MockAgent.sol';

contract AgentHub_Test is Test {
  using Strings for string;

  AgentHub public _agentHub;
  MockAgent public _agent;
  RiskOracle public riskOracle;

  address public constant HUB_OWNER = address(25);
  address public constant RISK_ORACLE_OWNER = address(25);
  address public constant AGENT_ADMIN = address(25);
  address public constant TARGET_CONTRACT = address(20);
  address public constant MARKET = address(5);
  string public UPDATE_TYPE = 'CapsUpdate';

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

  function test_updateIdExecuted() public {
    uint256 agentId = _registerAgent();
    _addUpdateToRiskOracle(MARKET);

    assertEq(_agentHub.getLastInjectedUpdate(agentId, MARKET).timestamp, 0);
    assertEq(_agentHub.getLastInjectedUpdate(agentId, MARKET).id, 0);

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, MARKET, UPDATE_TYPE, 1, abi.encode(5_00));
    assertTrue(_checkAndPerformAutomation(agentId));

    assertEq(_agentHub.getLastInjectedUpdate(agentId, MARKET).timestamp, block.timestamp);
    assertEq(_agentHub.getLastInjectedUpdate(agentId, MARKET).id, 1);
    vm.warp(block.timestamp + 1);

    // check update cannot be injected twice, because updateId already executed
    assertFalse(_checkAndPerformAutomation(agentId));
  }

  function test_updateIdExecuted_differentAgents() public {
    uint256 agentOneId = _registerAgent();
    uint256 agentTwoId = _registerAgent();

    uint256[] memory agentIds = new uint256[](2);
    agentIds[0] = agentOneId;
    agentIds[1] = agentTwoId;

    _addUpdateToRiskOracle(MARKET);

    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _check(agentIds);
    assertTrue(shouldRunKeeper);
    assertEq(actions.length, 2);

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentOneId, MARKET, UPDATE_TYPE, 1, abi.encode(5_00));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentTwoId, MARKET, UPDATE_TYPE, 1, abi.encode(5_00));

    // same updateId can be injected by two agents independently
    _execute(actions);
  }

  function test_isAgentDisabled() public {
    uint256 agentId = _registerAgent();

    _addUpdateToRiskOracle(MARKET);
    assertTrue(_agentHub.isAgentEnabled(agentId));

    (bool shouldUpdate, ) = _check(_convertToArray(agentId));
    assertTrue(shouldUpdate);

    vm.prank(AGENT_ADMIN);
    _agentHub.setAgentEnabled(agentId, false);

    (shouldUpdate, ) = _check(_convertToArray(agentId));
    assertFalse(shouldUpdate);

    address[] memory markets = new address[](1);
    markets[0] = MARKET;
    IAgentHub.ActionData[] memory actions = new IAgentHub.ActionData[](1);
    actions[0] = IAgentHub.ActionData(agentId, markets);

    vm.expectRevert(IAgentHub.NoActionCanBePerformed.selector);
    _execute(actions);
  }

  function test_updateExpired() public {
    uint256 agentId = _registerAgent();
    _addUpdateToRiskOracle(MARKET);

    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _check(
      _convertToArray(agentId)
    );
    assertTrue(shouldRunKeeper);

    assertGe(_agentHub.getExpirationPeriod(agentId), 0);
    uint256 expiryTimestamp = block.timestamp + _agentHub.getExpirationPeriod(agentId);

    // update can be injected at block.timestamp + expiryTime
    vm.warp(expiryTimestamp);
    (shouldRunKeeper, ) = _check(_convertToArray(agentId));
    assertTrue(shouldRunKeeper);

    // update cannot be injected if current ts greater than block.timestamp + expiryTime
    vm.warp(expiryTimestamp + 1);
    (shouldRunKeeper, actions) = _check(_convertToArray(agentId));
    assertFalse(shouldRunKeeper);

    vm.expectRevert(IAgentHub.NoActionCanBePerformed.selector);
    _execute(actions);
  }

  function test_minimumDelay() public {
    uint256 agentId = _registerAgent();
    uint32 minimumDelay = 6 hours;

    _addUpdateToRiskOracle(MARKET); // updateId 1
    assertTrue(_checkAndPerformAutomation(agentId));

    vm.prank(AGENT_ADMIN);
    _agentHub.setMinimumDelay(agentId, minimumDelay);

    _addUpdateToRiskOracle(MARKET); // updateId 2

    uint256 delayEnd = block.timestamp + minimumDelay;

    // update cannot be injected before delayEnd
    vm.warp(delayEnd - 1);
    assertFalse(_checkAndPerformAutomation(agentId));

    // update can be injected at or after delayEnd / after minimumDelay has passed
    vm.warp(delayEnd);
    assertTrue(_checkAndPerformAutomation(agentId));
  }

  function test_multipleUpdates_expiredUpdateFiltered() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(34);
    _addMarketToAgentHub(market2);
    _addUpdateToRiskOracle(market1); // updateId 1

    uint256 expiryTime = _agentHub.getExpirationPeriod(agentId);
    vm.warp(block.timestamp + expiryTime + 1);

    _addUpdateToRiskOracle(market2); // updateId 2

    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _check(
      _convertToArray(agentId)
    );
    assertTrue(shouldRunKeeper);

    // updateId 1 got filtered because it is expired
    assertEq(actions[0].markets, _convertToArray(market2));
  }

  function test_multipleUpdates_minDelayNotPassedUpdateFiltered() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(34);
    _addMarketToAgentHub(market2);
    _addUpdateToRiskOracle(market1); // updateId 1

    _checkAndPerformAutomation(agentId); // updateId 1 injected

    _addUpdateToRiskOracle(market1); // updateId 2
    _addUpdateToRiskOracle(market2); // updateId 3

    (, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));
    assertEq(actions[0].markets.length, 2);

    vm.prank(AGENT_ADMIN);
    _agentHub.setMinimumDelay(agentId, 1);

    // updateId 1 got filtered because minDelay did not pass
    (, actions) = _check(_convertToArray(agentId));
    assertEq(actions[0].markets.length, 1);
  }

  function test_multipleUpdates_executedUpdateFiltered() public {
    uint256 agentId = _registerAgent();
    address market1 = MARKET;
    address market2 = address(34);

    _addMarketToAgentHub(market2);
    _addUpdateToRiskOracle(market1); // updateId 1

    _checkAndPerformAutomation(agentId); // updateId 1 executed
    _addUpdateToRiskOracle(market2); // updateId 2

    (bool shouldRun, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));
    assertTrue(shouldRun);
    assertEq(actions[0].markets.length, 1); // updateId 1 got filtered
  }

  function test_multipleUpdates_incorrectMarketUpdateFiltered() public {
    uint256 agentId = _registerAgent();
    address market1 = MARKET;
    address market2 = address(34);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2

    (bool shouldRun, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));
    assertTrue(shouldRun);
    assertEq(actions[0].markets.length, 1); // updateId 2 got filtered as market2 is not allowed
  }

  // updates: [{updateId: 1, capUpdate, market1}, {updateId: 2, capUpdate, market2}, {updateId: 3, capUpdate, market1}, {updateId: 4, wrongUpdateType, market1}]
  // injection: only for updateId 3 and updateId 2
  function test_multipleUpdates_invalidUpdateTypeUpdateFiltered() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    _addMarketToAgentHub(market2);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market1); // updateId 3
    _addUpdateToRiskOracle(market1, 'WrongUpdateType'); // updateId 4

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, market1, UPDATE_TYPE, 3, abi.encode(5_00));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, market2, UPDATE_TYPE, 2, abi.encode(5_00));

    // only updateId 2 and updateId 3 is injected because updateId 4 has invalid updateType, and updateId 1 has the same
    // market as updateId 3, but updateId 3 is the latest one
    assertTrue(_checkAndPerformAutomation(agentId));
  }

  function testOnlyPermissionedSenderCanExecute() public {
    uint256 agentId = _registerAgent();
    address permissionedSender = address(155);

    _addUpdateToRiskOracle(MARKET);

    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _check(
      _convertToArray(agentId)
    );
    assertTrue(shouldRunKeeper);

    vm.startPrank(AGENT_ADMIN);
    _agentHub.addPermissionedSender(agentId, permissionedSender);
    _agentHub.setAgentAsPermissioned(agentId, true);
    vm.stopPrank();

    vm.prank(address(1)); // invalid permissioned sender
    vm.expectRevert(IAgentHub.NoActionCanBePerformed.selector);
    _execute(actions);

    vm.startPrank(permissionedSender);
    _execute(actions);
  }

  function test_marketsFromAgentEnabled() public {
    uint256 agentId = _registerAgent();
    address marketFromHub = MARKET;
    address marketFromAgent = address(105);

    vm.prank(AGENT_ADMIN);
    _agentHub.setMarketsFromAgentEnabled(agentId, true);
    _addUpdateToRiskOracle(marketFromHub); // updateId 1 (not used)
    _addUpdateToRiskOracle(marketFromAgent); // updateId 2

    vm.mockCall(
      address(_agent),
      abi.encodeWithSelector(_agent.getMarkets.selector, agentId),
      abi.encode(_convertToArray(marketFromAgent))
    );

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(
      agentId,
      marketFromAgent,
      UPDATE_TYPE,
      2,
      abi.encode(5_00)
    );
    assertTrue(_checkAndPerformAutomation(agentId));
  }

  function test_marketsFromAgentDisabled() public {
    uint256 agentId = _registerAgent();
    address marketFromHub = MARKET;
    address marketFromAgent = address(105);

    assertFalse(_agentHub.isMarketsFromAgentEnabled(agentId));

    _addUpdateToRiskOracle(marketFromHub); // updateId 1
    _addUpdateToRiskOracle(marketFromAgent); // updateId 2 (not used)

    vm.mockCall(
      address(_agent),
      abi.encodeWithSelector(_agent.getMarkets.selector, agentId),
      abi.encode(_convertToArray(marketFromAgent))
    );

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(
      agentId,
      marketFromHub,
      UPDATE_TYPE,
      1,
      abi.encode(5_00)
    );
    assertTrue(_checkAndPerformAutomation(agentId));
  }

  function test_notConfiguredMarketsNotInjected_marketsFromAgentDisabled() public {
    uint256 agentId = _registerAgent();
    address newMarket = address(105);

    assertFalse(_agentHub.isMarketsFromAgentEnabled(agentId));
    _addUpdateToRiskOracle(newMarket); // updateId 1

    // as market is not configured, update cannot be injected
    assertFalse(_checkAndPerformAutomation(agentId));

    IAgentHub.ActionData[] memory actions = new IAgentHub.ActionData[](1);
    actions[0] = IAgentHub.ActionData({agentId: agentId, markets: _convertToArray(newMarket)});

    vm.expectRevert(IAgentHub.NoActionCanBePerformed.selector);
    _agentHub.execute(actions);
  }

  function test_restrictedMarketsNotInjected_marketsFromAgentEnabled() public {
    uint256 agentId = _registerAgent();
    address newMarket = address(105);

    vm.prank(AGENT_ADMIN);
    _agentHub.setMarketsFromAgentEnabled(agentId, true);
    _addUpdateToRiskOracle(newMarket); // updateId 1

    vm.mockCall(
      address(_agent),
      abi.encodeWithSelector(_agent.getMarkets.selector, agentId),
      abi.encode(_convertToArray(newMarket))
    );

    vm.prank(AGENT_ADMIN);
    _agentHub.addRestrictedMarket(agentId, newMarket);

    // as market is restricted, update cannot be injected
    (bool shouldUpdate, ) = _check(_convertToArray(agentId));
    assertFalse(shouldUpdate);

    IAgentHub.ActionData[] memory actions = new IAgentHub.ActionData[](1);
    actions[0] = IAgentHub.ActionData({agentId: agentId, markets: _convertToArray(newMarket)});

    vm.expectRevert(IAgentHub.NoActionCanBePerformed.selector);
    _agentHub.execute(actions);
  }

  // executeData: [{agentId: 1, markets: [market1]}, {agentId: 1, markets: [market1]}]
  // injection: only for update from market1 once
  function test_duplicatedAgentIdsPassedOnExecute_sameMarket() public {
    uint256 agentId = _registerAgent();
    _addUpdateToRiskOracle(MARKET);

    uint256[] memory agentIds = new uint256[](2);
    agentIds[0] = agentId;
    agentIds[1] = agentId;

    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _check(agentIds);
    assertTrue(shouldRunKeeper);

    vm.recordLogs();
    _execute(actions);
    Vm.Log[] memory logEntries = vm.getRecordedLogs();

    // update was injected only once, as the generic validation filtered the already injected update
    // so even if passing multiple agentIds the update gets injected only once
    assertEq(logEntries.length, 1);
    assertEq(
      logEntries[0].topics[0],
      keccak256('UpdateInjected(uint256,address,string,uint256,bytes)')
    );
  }

  // executeData: [{agentId: 1, markets: [market1]}, {agentId: 1, markets: [market2]}]
  // injection: for both updates from market1 and market2
  function test_duplicatedAgentIdsPassedOnExecute_differentMarket() public {
    uint256 agentId = _registerAgent();
    address newMarket = address(78);
    _addMarketToAgentHub(newMarket);

    _addUpdateToRiskOracle(MARKET);
    _addUpdateToRiskOracle(newMarket);

    uint256[] memory agentIds = new uint256[](1);
    agentIds[0] = agentId;

    (bool shouldRunKeeper, ) = _check(agentIds);
    assertTrue(shouldRunKeeper);

    IAgentHub.ActionData[] memory actionData = new IAgentHub.ActionData[](2);
    actionData[0] = IAgentHub.ActionData({agentId: agentId, markets: _convertToArray(MARKET)});
    actionData[1] = IAgentHub.ActionData({agentId: agentId, markets: _convertToArray(newMarket)});

    // passing multiple agentIds with different markets we see that updates
    // from both the markets are being injected
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, MARKET, UPDATE_TYPE, 1, abi.encode(5_00));
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, newMarket, UPDATE_TYPE, 2, abi.encode(5_00));

    _execute(actionData);
  }

  // executeData: [{agentId: 1, markets: [market1, market2, market1, market3, market3, market2, market2]}]
  // injection: only once each for updates from market1, market2, market3
  function test_duplicatedMarketsPassedOnExecute_sameAgent() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);
    _addMarketToAgentHub(market2);
    _addMarketToAgentHub(market3);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    (bool shouldRunKeeper, ) = _check(_convertToArray(agentId));
    assertTrue(shouldRunKeeper);

    address[] memory markets = new address[](7);
    markets[0] = market1;
    markets[1] = market2;
    markets[2] = market1;
    markets[3] = market3;
    markets[4] = market3;
    markets[5] = market2;
    markets[6] = market2;

    IAgentHub.ActionData[] memory actionData = new IAgentHub.ActionData[](1);
    actionData[0] = IAgentHub.ActionData({agentId: agentId, markets: markets});

    // update injected for each market only once
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, market1, UPDATE_TYPE, 1, abi.encode(5_00));
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, market2, UPDATE_TYPE, 2, abi.encode(5_00));
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, market3, UPDATE_TYPE, 3, abi.encode(5_00));
    _execute(actionData);
  }

  function test_maxBatchSize_maxBatchSizeZero() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);
    _addMarketToAgentHub(market2);
    _addMarketToAgentHub(market3);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    (, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));

    assertEq(_agentHub.getMaxBatchSize(), 0);
    assertEq(actions.length, 1);
    assertEq(actions[0].markets.length, 3);
  }

  function test_maxBatchSize_updateCountGreaterThanMaxBatchSize() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);
    _addMarketToAgentHub(market2);
    _addMarketToAgentHub(market3);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    uint16 batchSize = 2;

    vm.prank(HUB_OWNER);
    _agentHub.setMaxBatchSize(batchSize);
    (, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));

    // check returns markets of limited to maxBatchSize i.e 2 in this case
    // we have 3 updates / markets but it gets limited to 2 markets as maxBatchSize is set as 2
    assertEq(actions.length, 1);
    assertEq(actions[0].markets.length, batchSize);
  }

  function test_maxBatchSize_updateCountLessThanMaxBatchSize() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);
    _addMarketToAgentHub(market2);
    _addMarketToAgentHub(market3);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    uint16 batchSize = 100;

    vm.prank(HUB_OWNER);
    _agentHub.setMaxBatchSize(batchSize);
    (, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));

    // check returns markets of size 3, as maxBatchSize > markets or updateCount
    assertEq(actions.length, 1);
    assertEq(actions[0].markets.length, 3);
  }

  function test_maxBatchSize_updateCountGreaterThanMaxBatchSize_multipleAgents() public {
    uint256 agentOneId = _registerAgent();
    uint256 agentTwoId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);

    vm.startPrank(AGENT_ADMIN);
    _agentHub.addAllowedMarket(agentOneId, market1);
    _agentHub.addAllowedMarket(agentOneId, market2);

    _agentHub.addAllowedMarket(agentTwoId, market1);
    _agentHub.addAllowedMarket(agentTwoId, market2);
    vm.stopPrank();

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2

    uint256[] memory agentIds = new uint256[](2);
    agentIds[0] = agentOneId;
    agentIds[1] = agentTwoId;

    // total of 4 updates can be injected for both the agents
    (, IAgentHub.ActionData[] memory actions) = _check(agentIds);
    assertEq(actions.length, 2);
    assertEq(actions[0].markets.length, 2);
    assertEq(actions[1].markets.length, 2);

    uint16 maxBatchSize = 3;
    vm.prank(HUB_OWNER);
    _agentHub.setMaxBatchSize(maxBatchSize);

    // total of only 3 updates can be injected for both the agents, limited by the maxBatchSize
    (, actions) = _check(agentIds);
    assertEq(actions.length, 2);
    assertEq(actions[0].markets.length, 2);
    assertEq(actions[1].markets.length, 1);
  }

  function test_revert_executeReentered_sameMarket() public {
    uint256 agentId = _registerAgent();
    address reentrantAgent = address(new MockAgentReentrantOne(address(_agentHub)));

    vm.prank(HUB_OWNER);
    _agentHub.setAgentAddress(agentId, reentrantAgent);

    _addUpdateToRiskOracle(MARKET);
    (, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));

    // the mock agent injection calls `execute()` on the hub again with same market and agentId, but as the state variables
    // we're updated already during the first `execute()` we revert during the second `execute()` called by the agent contract
    vm.expectRevert(IAgentHub.NoActionCanBePerformed.selector);
    _execute(actions);
  }

  function test_executeReentered_differentUpdate() public {
    uint256 agentId = _registerAgent();
    address market2 = address(83);

    vm.prank(AGENT_ADMIN);
    _agentHub.addAllowedMarket(agentId, market2);

    address reentrantAgent = address(new MockAgentReentrantTwo(address(_agentHub), market2));

    _addUpdateToRiskOracle(MARKET); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2

    vm.prank(HUB_OWNER);
    _agentHub.setAgentAddress(agentId, reentrantAgent);

    (, IAgentHub.ActionData[] memory actions) = _check(_convertToArray(agentId));

    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, MARKET, UPDATE_TYPE, 1, abi.encode(5_00));
    vm.expectEmit(true, true, true, true, address(_agentHub));
    emit IAgentConfigurator.UpdateInjected(agentId, market2, UPDATE_TYPE, 2, abi.encode(5_00));

    // the mock agent injection calls `execute()` on the hub again but this time with different market (different update),
    // this is valid case, and even though we reentered `execute()` it should not revert
    _execute(actions);
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

  function _addUpdateToRiskOracle(address market) internal {
    _addUpdateToRiskOracle(market, UPDATE_TYPE);
  }

  function _addUpdateToRiskOracle(address market, string memory updateType) internal {
    vm.startPrank(RISK_ORACLE_OWNER);
    if (!updateType.equal(UPDATE_TYPE)) {
      riskOracle.addUpdateType(updateType);
    }

    riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(5_00),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addMarketToAgentHub(address market) internal {
    vm.prank(AGENT_ADMIN);
    _agentHub.addAllowedMarket(0, market);
  }

  function _checkAndPerformAutomation(uint256 agentId) internal virtual returns (bool) {
    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _check(
      _convertToArray(agentId)
    );
    if (shouldRunKeeper) {
      _execute(actions);
    }
    return shouldRunKeeper;
  }

  function _check(
    uint256[] memory agentIds
  ) internal virtual returns (bool, IAgentHub.ActionData[] memory) {
    return _agentHub.check(agentIds);
  }

  function _execute(IAgentHub.ActionData[] memory actions) internal virtual {
    _agentHub.execute(actions);
  }

  function _convertToArray(address value) internal pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = value;
  }

  function _convertToArray(uint256 value) internal pure returns (uint256[] memory array) {
    array = new uint256[](1);
    array[0] = value;
  }
}
