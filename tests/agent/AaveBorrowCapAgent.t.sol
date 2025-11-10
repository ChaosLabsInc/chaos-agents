// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';

import {AaveCapsAgent} from '../../src/contracts/agent/aave/AaveCapsAgent.sol';
import {RangeValidationModule, IRangeValidationModule} from '../../src/contracts/modules/RangeValidationModule.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';
import {BaseAgentTest} from './BaseAgentTest.sol';

contract AaveBorrowCap_Test is BaseAgentTest('BorrowCapUpdate'), TestnetProcedures {
  RangeValidationModule internal _rangeValidationModule;

  function setUp() public override {
    initTestEnvironment();
    super.setUp();
  }

  function _customiseAgentConfig(
    IAgentConfigurator.AgentRegistrationInput memory config
  ) internal view override returns (IAgentConfigurator.AgentRegistrationInput memory) {
    config.agentContext = abi.encode(report.configEngine);
    return config;
  }

  function _deployAgent() internal override returns (address) {
    _rangeValidationModule = new RangeValidationModule();
    return
      address(
        new AaveCapsAgent(
          address(_agentHub),
          address(_rangeValidationModule),
          address(contracts.poolProxy)
        )
      );
  }

  function _postSetup() internal override {
    IRangeValidationModule.RangeConfig memory rangeConfig = IRangeValidationModule.RangeConfig({
      maxIncrease: 100_00,
      maxDecrease: 100_00,
      isIncreaseRelative: true,
      isDecreaseRelative: true
    });
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'BorrowCapUpdate',
      rangeConfig
    );

    vm.startPrank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_agent));

    // as initial caps are at 0, which the agent cannot update from
    contracts.poolConfiguratorProxy.setBorrowCap(address(weth), 100);
    vm.stopPrank();
  }

  function test_validate_borrowCapNotInRange() public {
    (uint256 currentBorrowCap, ) = contracts.protocolDataProvider.getReserveCaps(address(weth));
    uint256 newBorrowCap = (currentBorrowCap * 2) + 1; // more than 100% relative increase

    _addUpdateToRiskOracle(newBorrowCap); // updateId 1
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));
  }

  function test_validate_borrowCapInRange() public {
    (uint256 currentBorrowCap, ) = contracts.protocolDataProvider.getReserveCaps(address(weth));
    uint256 newBorrowCap = (currentBorrowCap * 2); // 100% relative increase

    _addUpdateToRiskOracle(newBorrowCap); // updateId 1
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));
  }

  function test_validate_invalidBorrowCapToAndFromZero() public {
    _addUpdateToRiskOracle(0); // updateId 1
    // cannot set new borrow cap to 0
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    IRangeValidationModule.RangeConfig memory rangeConfig = IRangeValidationModule.RangeConfig({
      maxIncrease: 1000,
      maxDecrease: 1000,
      isIncreaseRelative: false,
      isDecreaseRelative: false
    });
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'BorrowCapUpdate',
      rangeConfig
    );

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setBorrowCap(address(weth), 0);

    _addUpdateToRiskOracle(1); // updateId 2
    // cannot set new borrow cap when current borrow cap is 0, even if rangeValidationModule permits
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_injectionFromHub() public {
    (uint256 currentBorrowCap, ) = contracts.protocolDataProvider.getReserveCaps(address(weth));
    uint256 newBorrowCap = currentBorrowCap * 2;

    _addUpdateToRiskOracle(currentBorrowCap * 2); // 100% relative increase
    assertTrue(_checkAndPerformAutomation(_agentId));
    (currentBorrowCap, ) = contracts.protocolDataProvider.getReserveCaps(address(weth));
    assertEq(currentBorrowCap, newBorrowCap);
  }

  function _addUpdateToRiskOracle(uint256 cap) internal {
    vm.startPrank(_riskOracleOwner);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encodePacked(cap),
      _updateType,
      address(weth),
      'additionalData'
    );
    vm.stopPrank();
  }
}
