// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';
import {GmxAgent, IConfig} from '../../src/contracts/agent/gmx/GmxAgent.sol';
import {RiskOracle} from '../../src/contracts/dependencies/RiskOracle.sol';
import {IEventEmitter} from '../../src/contracts/dependencies/gmx/IEventEmitter.sol';
import {IRoleStore} from '../../src/contracts/dependencies/gmx/IRoleStore.sol';
import {BaseAgentTest} from './BaseAgentTest.sol';

contract GmxAgent_Test is BaseAgentTest('priceImpact/positionImpactExponentFactor/v2') {
  address public constant MARKET = 0xBeB1f4EBC9af627Ca1E5a75981CE1AE97eFeDA22;
  RiskOracle public constant RISK_ORACLE = RiskOracle(0x0efb5a96Ed1B33308a73355C56Aa1Bc1aa7E4A8E);
  IConfig public constant CONFIG = IConfig(0xD1781719eDbED8940534511ac671027989e724b9);
  IRoleStore public constant ROLE_STORE = IRoleStore(0x3c3d99FD298f679DBC2CEcd132b4eC4d0F5e6e72);
  IEventEmitter public constant EVENT_EMITTER =
    IEventEmitter(0xC8ee91A54287DB53897056e12D9819156D3822Fb);

  address public constant ROLE_ADMIN = 0x7A967D114B8676874FA2cFC1C14F3095C88418Eb;
  address public constant ALLOWED_KEEPER = address(20);

  bytes32 public constant CONTROLLER_ROLE = keccak256(abi.encode('CONTROLLER'));
  bytes32 public constant CONFIG_KEEPER_ROLE = keccak256(abi.encode('CONFIG_KEEPER'));

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 310705672);
    super.setUp();
  }

  function _customiseAgentConfig(
    IAgentConfigurator.AgentRegistrationInput memory config
  ) internal pure override returns (IAgentConfigurator.AgentRegistrationInput memory) {
    config.riskOracle = address(RISK_ORACLE);

    config.isMarketsFromAgentEnabled = false;
    config.allowedMarkets = _addressToArray(MARKET);

    config.permissionedSenders = _addressToArray(ALLOWED_KEEPER);

    config.agentContext = abi.encode(address(CONFIG), address(EVENT_EMITTER));
    return config;
  }

  function _deployAgent() internal override returns (address) {
    return address(new GmxAgent(address(_agentHub)));
  }
  function _postSetup() internal override {
    vm.startPrank(ROLE_ADMIN);
    ROLE_STORE.grantRole(address(_agent), CONTROLLER_ROLE); // used for emitting event on eventEmitter
    ROLE_STORE.grantRole(address(_agent), CONFIG_KEEPER_ROLE); // used to inject on the config
    vm.stopPrank();
  }

  function test_updateInjection() public {
    assertTrue(_checkAndPerformAutomation(_agentId));
  }
}
