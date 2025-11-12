// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AgentHub, IAgentHub} from '../../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';
import {RiskOracle} from '../../src/contracts/dependencies/RiskOracle.sol';
import {MockAgent} from '../mocks/MockAgent.sol';

contract AgentHubOperations_gas_Test is Test {
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

  function setUp() public {
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

  function test_marketsFromAgentEnabled() public {
    uint256 agentId = _registerAgent();

    vm.prank(AGENT_ADMIN);
    _agentHub.setMarketsFromAgentEnabled(agentId, true);

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    address[] memory markets = new address[](3);
    markets[0] = market1;
    markets[1] = market2;
    markets[2] = market3;

    vm.mockCall(
      address(_agent),
      abi.encodeWithSelector(_agent.getMarkets.selector, agentId),
      abi.encode(markets)
    );

    (, IAgentHub.ActionData[] memory actions) = _agentHub.check(_convertToArray(agentId));
    vm.snapshotGasLastCall('AgentHub.Operations', 'check: marketsFromAgentEnabled -> 3 updates');

    _agentHub.execute(actions);
    vm.snapshotGasLastCall('AgentHub.Operations', 'execute: marketsFromAgentEnabled -> 3 updates');
  }

  function test_marketsFromAgentEnabled_withRestrictedMarket() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);

    vm.startPrank(AGENT_ADMIN);
    _agentHub.setMarketsFromAgentEnabled(agentId, true);
    _agentHub.addRestrictedMarket(agentId, market3);
    vm.stopPrank();

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    address[] memory markets = new address[](3);
    markets[0] = market1;
    markets[1] = market2;
    markets[2] = market3;

    vm.mockCall(
      address(_agent),
      abi.encodeWithSelector(_agent.getMarkets.selector, agentId),
      abi.encode(markets)
    );

    _agentHub.check(_convertToArray(agentId));
    vm.snapshotGasLastCall(
      'AgentHub.Operations',
      'check: marketsFromAgentEnabled -> 3 updates, 1 restricted'
    );
  }

  function test_marketsFromAgentEnabled_updatesWithSameMarket() public {
    uint256 agentId = _registerAgent();

    vm.prank(AGENT_ADMIN);
    _agentHub.setMarketsFromAgentEnabled(agentId, true);

    address market1 = MARKET;
    address market2 = address(83);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market1); // updateId 3

    address[] memory markets = new address[](2);
    markets[0] = market1;
    markets[1] = market2;

    vm.mockCall(
      address(_agent),
      abi.encodeWithSelector(_agent.getMarkets.selector, agentId),
      abi.encode(markets)
    );

    _agentHub.check(_convertToArray(agentId));
    vm.snapshotGasLastCall(
      'AgentHub.Operations',
      'check: marketsFromAgentEnabled updatesWithSameMarket -> 3 updates, 2 with same market'
    );
  }

  function test_marketsFromAgentDisabled() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    address market3 = address(84);

    _addMarketToAgentHub(market2);
    _addMarketToAgentHub(market3);
    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market3); // updateId 3

    (, IAgentHub.ActionData[] memory actions) = _agentHub.check(_convertToArray(agentId));
    vm.snapshotGasLastCall('AgentHub.Operations', 'check: marketsFromAgentDisabled -> 3 updates');

    _agentHub.execute(actions);
    vm.snapshotGasLastCall('AgentHub.Operations', 'execute: marketsFromAgentDisabled -> 3 updates');
  }

  function test_marketsFromAgentDisabled_updatesWithSameMarket() public {
    uint256 agentId = _registerAgent();

    address market1 = MARKET;
    address market2 = address(83);
    _addMarketToAgentHub(market2);

    _addUpdateToRiskOracle(market1); // updateId 1
    _addUpdateToRiskOracle(market2); // updateId 2
    _addUpdateToRiskOracle(market1); // updateId 3

    _agentHub.check(_convertToArray(agentId));
    vm.snapshotGasLastCall(
      'AgentHub.Operations',
      'check: marketsFromAgentDisabled updatesWithSameMarket -> 3 updates, 2 with same market'
    );
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

  function _convertToArray(address value) internal pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = value;
  }

  function _convertToArray(uint256 value) internal pure returns (uint256[] memory array) {
    array = new uint256[](1);
    array[0] = value;
  }
}
