// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {DataTypes} from 'aave-v3-origin/src/contracts/protocol/libraries/types/DataTypes.sol';

import {AaveEModeAgent} from '../../src/contracts/agent/aave/AaveEModeAgent.sol';
import {RangeValidationModule, IRangeValidationModule} from '../../src/contracts/modules/RangeValidationModule.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentConfigurator.sol';
import {BaseAgentTest} from './BaseAgentTest.sol';

contract AaveEModeAgent_Test is BaseAgentTest('EModeCategoryUpdate'), TestnetProcedures {
  RangeValidationModule internal _rangeValidationModule;
  address public constant EMODE_MARKET = address(uint160(1));

  function setUp() public override {
    initTestEnvironment();
    super.setUp();
  }

  function _customiseAgentConfig(
    IAgentConfigurator.AgentRegistrationInput memory config
  ) internal view override returns (IAgentConfigurator.AgentRegistrationInput memory) {
    config.isMarketsFromAgentEnabled = false;
    config.allowedMarkets = _addressToArray(EMODE_MARKET);

    config.agentContext = abi.encode(report.configEngine);
    return config;
  }

  function _deployAgent() internal override returns (address) {
    _rangeValidationModule = new RangeValidationModule();

    return
      address(
        new AaveEModeAgent(
          address(_agentHub),
          address(_rangeValidationModule),
          address(contracts.poolProxy)
        )
      );
  }

  function _postSetup() internal override {
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'EModeLTV',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 50,
        maxDecrease: 50,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'EModeLiquidationThreshold',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 50,
        maxDecrease: 50,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'EModeLiquidationBonus',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 50,
        maxDecrease: 50,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );

    vm.startPrank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_agent));
    contracts.poolConfiguratorProxy.setEModeCategory(
      uint8(uint160(EMODE_MARKET)),
      80_00,
      85_00,
      105_00,
      'Test EMode Category'
    );
    vm.stopPrank();
  }

  function test_validate_eModeLTVNotInRange(uint8 change) public {
    vm.assume(change > 50);
    uint256 currentLTV = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)))
      .ltv;

    // more than 0.5% absolute increase
    uint256 newLTV = currentLTV + change;
    _addUpdateToRiskOracle(newLTV, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentLTV);

    // more than 0.5% absolute decrease
    newLTV = currentLTV - change;
    _addUpdateToRiskOracle(newLTV, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_eModeLTVInRange(uint8 change) public {
    vm.assume(change != 0 && change < 50);
    uint256 currentLTV = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)))
      .ltv;

    // less than 0.5% absolute increase
    uint256 newLTV = currentLTV + change;
    _addUpdateToRiskOracle(newLTV, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentLTV);

    // less than 0.5% absolute decrease
    newLTV = currentLTV - change;
    _addUpdateToRiskOracle(newLTV, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_eModeLiqThresholdNotInRange(uint8 change) public {
    vm.assume(change > 50);
    uint256 currentLT = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)))
      .liquidationThreshold;

    // more than 0.5% absolute increase
    uint256 newLT = currentLT + change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, newLT, EngineFlags.KEEP_CURRENT);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentLT);

    // more than 0.5% absolute decrease
    newLT = currentLT - change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, newLT, EngineFlags.KEEP_CURRENT);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_eModeLiqThresholdInRange(uint8 change) public {
    vm.assume(change != 0 && change < 50);
    uint256 currentLT = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)))
      .liquidationThreshold;

    // less than 0.5% absolute increase
    uint256 newLT = currentLT + change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, newLT, EngineFlags.KEEP_CURRENT);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentLT);

    // less than 0.5% absolute decrease
    newLT = currentLT - change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, newLT, EngineFlags.KEEP_CURRENT);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_eModeLiqBonusNotInRange(uint8 change) public {
    vm.assume(change > 50);
    uint256 currentLB = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)))
      .liquidationBonus;

    // more than 0.5% absolute increase
    uint256 newLB = currentLB + change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, newLB);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentLB);

    // more than 0.5% absolute decrease
    newLB = currentLB - change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, newLB);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_eModeLiqBonusInRange(uint8 change) public {
    vm.assume(change != 0 && change < 50);
    uint256 currentLB = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)))
      .liquidationBonus - 100_00;

    // less than 0.5% absolute increase
    uint256 newLB = currentLB + change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, newLB);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentLB);

    // less than 0.5% absolute decrease
    newLB = currentLB - change;
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, newLB);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_sameRateParams() public {
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));
  }

  function test_injectionFromHub() public {
    DataTypes.CollateralConfig memory currentEModeConfig = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)));

    uint256 newLTV = currentEModeConfig.ltv + 50;
    uint256 newLT = currentEModeConfig.liquidationThreshold + 50;
    uint256 newLB = (currentEModeConfig.liquidationBonus - 100_00) + 50;
    _addUpdateToRiskOracle(newLTV, newLT, newLB);

    assertTrue(_checkAndPerformAutomation(_agentId));

    currentEModeConfig = contracts.poolProxy.getEModeCategoryCollateralConfig(
      uint8(uint160(EMODE_MARKET))
    );
    assertEq(currentEModeConfig.ltv, newLTV);
    assertEq(currentEModeConfig.liquidationThreshold, newLT);
    assertEq(currentEModeConfig.liquidationBonus - 100_00, newLB);
  }

  function _addUpdateToRiskOracle(uint256 ltv, uint256 lt, uint256 lb) internal {
    vm.startPrank(_riskOracleOwner);
    DataTypes.CollateralConfig memory eModeConfig = contracts
      .poolProxy
      .getEModeCategoryCollateralConfig(uint8(uint160(EMODE_MARKET)));
    // as the definition is 100% + x%, and we take into account x% for simplicity
    eModeConfig.liquidationBonus = eModeConfig.liquidationBonus - 100_00;

    if (ltv != EngineFlags.KEEP_CURRENT) eModeConfig.ltv = uint16(ltv);
    if (lt != EngineFlags.KEEP_CURRENT) eModeConfig.liquidationThreshold = uint16(lt);
    if (lb != EngineFlags.KEEP_CURRENT) eModeConfig.liquidationBonus = uint16(lb);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(
        AaveEModeAgent.EModeCategoryUpdate({
          ltv: eModeConfig.ltv,
          liquidationThreshold: eModeConfig.liquidationThreshold,
          liquidationBonus: eModeConfig.liquidationBonus
        })
      ),
      _updateType,
      address(EMODE_MARKET),
      'additionalData'
    );
    vm.stopPrank();
  }
}
