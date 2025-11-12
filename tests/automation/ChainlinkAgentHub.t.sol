// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AgentHub} from '../../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';
import {RiskOracle} from '../../src/contracts/dependencies/RiskOracle.sol';
import {MockAgent} from '../mocks/MockAgent.sol';
import {ChainlinkAgentHub} from '../../src/contracts/automation/ChainlinkAgentHub.sol';

contract ChainlinkAgentHub_Test is Test {
  AgentHub public _agentHub;
  ChainlinkAgentHub public _chainlinkAgentHub;
  MockAgent public _agent;
  RiskOracle public riskOracle;

  address public constant HUB_OWNER = address(25);
  address public constant RISK_ORACLE_OWNER = address(25);
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

    _chainlinkAgentHub = new ChainlinkAgentHub(address(_agentHub));

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

  function test_automation() public {
    uint256 agentId = _registerAgent();
    _addUpdateToRiskOracle(MARKET);

    assertTrue(_checkAndPerformAutomation(agentId));
  }

  function _checkAndPerformAutomation(uint256 agentId) internal virtual returns (bool) {
    uint256[] memory agentIds = new uint256[](1);
    agentIds[0] = agentId;

    (bool shouldRunKeeper, bytes memory performData) = _chainlinkAgentHub.checkUpkeep(
      abi.encode(agentIds)
    );
    if (shouldRunKeeper) {
      _chainlinkAgentHub.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }

  function _registerAgent() internal returns (uint256 agentId) {
    address[] memory markets = new address[](1);
    markets[0] = MARKET;

    vm.startPrank(HUB_OWNER);
    agentId = _agentHub.registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        agentAddress: address(_agent),
        riskOracle: address(riskOracle),
        admin: address(44),
        agentContext: abi.encode(address(20)),
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
    vm.startPrank(RISK_ORACLE_OWNER);
    riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(5_00),
      UPDATE_TYPE,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }
}
