// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AgentHub} from '../../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';
import {RiskOracle} from '../../src/contracts/dependencies/RiskOracle.sol';
import {MockAgent} from '../mocks/MockAgent.sol';

contract AgentHubSetters_gas_Test is Test {
  AgentHub _agentHub;
  MockAgent _agent;
  RiskOracle riskOracle;
  uint256 _agentId;

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
    _agentId = _registerAgent();

    vm.startPrank(AGENT_ADMIN);
  }

  function test_registerAgent() public {
    vm.stopPrank();
    _registerAgent();
    vm.snapshotGasLastCall('AgentHub.Setters', 'registerAgent');
  }

  function test_setAgentContract() public {
    _agentHub.setAgentAddress(_agentId, address(88));
    vm.snapshotGasLastCall('AgentHub.Setters', 'setAgentAddress');
  }

  function test_setAgentAdmin() public {
    _agentHub.setAgentAdmin(_agentId, address(88));
    vm.snapshotGasLastCall('AgentHub.Setters', 'setAgentAdmin');
  }

  function test_setAgentAsPermissioned() public {
    _agentHub.setAgentAsPermissioned(_agentId, true);
    vm.snapshotGasLastCall('AgentHub.Setters', 'setAgentAsPermissioned');
  }

  function test_setPermissionedSender() public {
    _agentHub.addPermissionedSender(_agentId, address(88));
    vm.snapshotGasLastCall('AgentHub.Setters', 'addPermissionedSender');

    _agentHub.removePermissionedSender(_agentId, address(88));
    vm.snapshotGasLastCall('AgentHub.Setters', 'removePermissionedSender');
  }

  function test_setAllowedMarket() public {
    _agentHub.addAllowedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'addAllowedMarket');

    _agentHub.addAllowedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'addAllowedMarket (already added before)');

    _agentHub.removeAllowedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'removeAllowedMarket');

    _agentHub.removeAllowedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'removeAllowedMarket (already removed before)');
  }

  function test_setRestrictedMarket() public {
    _agentHub.addRestrictedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'addRestrictedMarket');

    _agentHub.addRestrictedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'addRestrictedMarket (already added before)');

    _agentHub.removeRestrictedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'removeRestrictedMarket');

    _agentHub.removeRestrictedMarket(_agentId, address(66));
    vm.snapshotGasLastCall('AgentHub.Setters', 'removeRestrictedMarket (already removed before)');
  }

  function test_setDisabled() public {
    _agentHub.setAgentEnabled(_agentId, true);
    vm.snapshotGasLastCall('AgentHub.Setters', 'setAgentEnabled');
  }

  function test_setExpirationPeriod() public {
    _agentHub.setExpirationPeriod(_agentId, 100 days);
    vm.snapshotGasLastCall('AgentHub.Setters', 'setExpirationPeriod');
  }

  function test_setMaxBatchSize() public {
    vm.stopPrank();
    vm.prank(HUB_OWNER);
    _agentHub.setMaxBatchSize(100);
    vm.snapshotGasLastCall('AgentHub.Setters', 'setMaxBatchSize');
  }

  function test_setTargetConfig() public {
    _agentHub.setAgentContext(_agentId, '0xRandomConfig');
    vm.snapshotGasLastCall('AgentHub.Setters', 'setAgentContext');
  }

  function test_setAllMarketsAllowed() public {
    _agentHub.setMarketsFromAgentEnabled(_agentId, true);
    vm.snapshotGasLastCall('AgentHub.Setters', 'setMarketsFromAgentEnabled');
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
}
