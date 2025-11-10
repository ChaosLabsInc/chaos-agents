// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {Test} from 'forge-std/Test.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {RiskOracle} from '../../src/contracts/dependencies/RiskOracle.sol';
import {MockAaveAgent} from '../mocks/MockAaveAgent.sol';
import {AgentHub, IAgentHub, IRiskOracle} from '../../src/contracts/AgentHub.sol';
import {IBaseAgent} from '../../src/interfaces/IBaseAgent.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';

abstract contract BaseAgentTest is Test {
  AgentHub internal _agentHub;
  IRiskOracle internal _riskOracle;

  address internal _riskOracleOwner = address(20);
  address internal _agentConfigurator = address(25);
  uint256 internal _agentId;
  IBaseAgent internal _agent;
  string internal _updateType;
  bytes internal _agentContext;
  MockAaveAgent mockBaseAgentHarness;

  constructor(string memory updateType) {
    _updateType = updateType;
  }

  function _deployAgent() internal virtual returns (address);
  function _postSetup() internal virtual {}

  function _customiseAgentConfig(
    IAgentConfigurator.AgentRegistrationInput memory config
  ) internal view virtual returns (IAgentConfigurator.AgentRegistrationInput memory) {
    return config;
  }

  function setUp() public virtual {
    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](1);
    initialSenders[0] = _riskOracleOwner;
    string[] memory initialUpdateTypes = new string[](1);
    initialUpdateTypes[0] = _updateType;

    _riskOracle = IRiskOracle(
      address(new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes))
    );
    vm.stopPrank();

    _agentHub = AgentHub(
      address(
        new TransparentUpgradeableProxy(
          address(new AgentHub()),
          address(this),
          abi.encodeWithSelector(AgentHub.initialize.selector, address(this))
        )
      )
    );

    _agent = IBaseAgent(_deployAgent());

    _agentId = _agentHub.registerAgent(
      _customiseAgentConfig(
        IAgentConfigurator.AgentRegistrationInput({
          agentAddress: address(_agent),
          riskOracle: address(_riskOracle),
          admin: address(this),
          agentContext: abi.encode(''),
          isAgentEnabled: true,
          isAgentPermissioned: false,
          isMarketsFromAgentEnabled: true,
          expirationPeriod: 1 days,
          minimumDelay: 1 days,
          updateType: _updateType,
          allowedMarkets: new address[](0),
          restrictedMarkets: new address[](0),
          permissionedSenders: new address[](0)
        })
      )
    );
    _agentContext = _agentHub.getAgentContext(_agentId);

    mockBaseAgentHarness = new MockAaveAgent(address(_agentHub));
    _postSetup();

    vm.warp(5 days);
  }

  function test_revert_onlyAgentHub_can_inject(
    address caller,
    IRiskOracle.RiskParameterUpdate memory update
  ) public {
    vm.assume(caller != address(_agentHub));

    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSelector(IBaseAgent.OnlyAgentHub.selector, caller));
    _agent.inject(_agentId, _agentContext, update);
  }

  function test_decodeToUint(uint256 value) public view {
    bytes memory encodedValue = abi.encode(value);
    assertEq(mockBaseAgentHarness.decodeToUint(encodedValue), value);
  }

  function _addressToArray(address input) internal pure returns (address[] memory) {
    address[] memory output = new address[](1);
    output[0] = input;
    return output;
  }

  function _checkAndPerformAutomation(uint256 agentId) internal returns (bool) {
    uint256[] memory agentIds = new uint256[](1);
    agentIds[0] = agentId;

    (bool shouldRunKeeper, IAgentHub.ActionData[] memory actions) = _agentHub.check(agentIds);
    if (shouldRunKeeper) {
      _agentHub.execute(actions);
    }
    return shouldRunKeeper;
  }
}
