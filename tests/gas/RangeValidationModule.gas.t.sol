// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AgentHub} from '../../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentConfigurator.sol';
import {RangeValidationModule, IRangeValidationModule} from '../../src/contracts/modules/RangeValidationModule.sol';

contract RangeValidationModule_gas_Test is Test {
  AgentHub _agentHub;
  uint256 _agentId;
  RangeValidationModule _rangeValidationModule;
  address public constant AGENT_ADMIN = address(25);
  uint256 public constant BPS_MAX = 100_00;
  address public constant MARKET = address(14);

  string _updateType = 'SlopeOneUpdate';

  function setUp() public {
    _agentHub = AgentHub(
      address(
        new TransparentUpgradeableProxy(
          address(new AgentHub()),
          address(this),
          abi.encodeWithSelector(AgentHub.initialize.selector, address(this))
        )
      )
    );
    _rangeValidationModule = new RangeValidationModule();
    _agentId = _agentHub.registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        agentAddress: address(0),
        riskOracle: address(0),
        admin: AGENT_ADMIN,
        agentContext: abi.encode(),
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        expirationPeriod: 1 days,
        minimumDelay: 0,
        updateType: _updateType,
        allowedMarkets: new address[](1),
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );
  }

  function test_validate_absoluteChange() public {
    IRangeValidationModule.RangeConfig memory config = IRangeValidationModule.RangeConfig({
      maxIncrease: 500,
      maxDecrease: 0,
      isIncreaseRelative: false,
      isDecreaseRelative: false
    });

    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, _updateType, config);
    IRangeValidationModule.RangeValidationInput memory rangeValidationInput;
    rangeValidationInput.from = 100;
    rangeValidationInput.to = 600;
    rangeValidationInput.updateType = _updateType;

    _rangeValidationModule.validate(address(_agentHub), _agentId, MARKET, rangeValidationInput);
    vm.snapshotGasLastCall(
      'RangeValidationModule',
      'validate: absolute change (default fallback config)'
    );

    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      MARKET,
      _updateType,
      config
    );
    _rangeValidationModule.validate(address(_agentHub), _agentId, MARKET, rangeValidationInput);
    vm.snapshotGasLastCall('RangeValidationModule', 'validate: absolute change (market config)');
  }

  function test_validate_relativeChange() public {
    IRangeValidationModule.RangeConfig memory config = IRangeValidationModule.RangeConfig({
      maxIncrease: 100_00,
      maxDecrease: 0,
      isIncreaseRelative: true,
      isDecreaseRelative: true
    });

    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, _updateType, config);
    IRangeValidationModule.RangeValidationInput memory rangeValidationInput;
    rangeValidationInput.from = 100;
    rangeValidationInput.to = 200;
    rangeValidationInput.updateType = _updateType;

    _rangeValidationModule.validate(address(_agentHub), _agentId, MARKET, rangeValidationInput);
    vm.snapshotGasLastCall(
      'RangeValidationModule',
      'validate: relative change (default fallback config)'
    );

    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      MARKET,
      _updateType,
      config
    );

    _rangeValidationModule.validate(address(_agentHub), _agentId, MARKET, rangeValidationInput);
    vm.snapshotGasLastCall('RangeValidationModule', 'validate: relative change (market config)');
  }

  function test_validate_noChange() public {
    IRangeValidationModule.RangeConfig memory config = IRangeValidationModule.RangeConfig({
      maxIncrease: 1_00,
      maxDecrease: 1_00,
      isIncreaseRelative: true,
      isDecreaseRelative: true
    });

    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, _updateType, config);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput;
    rangeValidationInput.from = 100;
    rangeValidationInput.to = 100;
    rangeValidationInput.updateType = _updateType;

    assertTrue(
      _rangeValidationModule.validate(address(_agentHub), _agentId, MARKET, rangeValidationInput)
    );
    vm.snapshotGasLastCall('RangeValidationModule', 'validate: no change (same from and to value)');
  }

  function test_setRangeConfig() public {
    vm.startPrank(AGENT_ADMIN);
    IRangeValidationModule.RangeConfig memory config = IRangeValidationModule.RangeConfig({
      maxIncrease: 100_00,
      maxDecrease: 100_00,
      isIncreaseRelative: true,
      isDecreaseRelative: true
    });

    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, _updateType, config);
    vm.snapshotGasLastCall('RangeValidationModule', 'setDefaultRangeConfig');

    _rangeValidationModule.getDefaultRangeConfig(address(_agentHub), _agentId, _updateType);
    vm.snapshotGasLastCall('RangeValidationModule', 'getDefaultRangeConfig');

    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      MARKET,
      _updateType,
      config
    );
    vm.snapshotGasLastCall('RangeValidationModule', 'setRangeConfigByMarket');

    _rangeValidationModule.getRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      MARKET,
      _updateType
    );
    vm.snapshotGasLastCall('RangeValidationModule', 'getRangeConfigByMarket');
  }
}
