// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {IDefaultInterestRateStrategyV2 as IRatesStrategy} from 'aave-v3-origin/src/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';

import {AaveRatesAgent, IDefaultInterestRateStrategyV2, IEngine} from '../../src/contracts/agent/aave/AaveRatesAgent.sol';
import {RangeValidationModule, IRangeValidationModule} from '../../src/contracts/modules/RangeValidationModule.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';
import {BaseAgentTest} from './BaseAgentTest.sol';

contract AaveRatesAgent_Test is BaseAgentTest('RateStrategyUpdate'), TestnetProcedures {
  RangeValidationModule internal _rangeValidationModule;

  function setUp() public override {
    initTestEnvironment();
    super.setUp();
  }

  function _customiseAgentConfig(
    IAgentConfigurator.AgentRegistrationInput memory config
  ) internal view override returns (IAgentConfigurator.AgentRegistrationInput memory) {
    config.isMarketsFromAgentEnabled = false;
    config.allowedMarkets = _addressToArray(address(weth));

    config.agentContext = abi.encode(report.configEngine);
    return config;
  }

  function _deployAgent() internal override returns (address) {
    _rangeValidationModule = new RangeValidationModule();

    return
      address(
        new AaveRatesAgent(
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
      'OptimalUsageRatio',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 3_00,
        maxDecrease: 3_00,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'BaseVariableBorrowRate',
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
      'VariableRateSlope1',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 1_00,
        maxDecrease: 1_00,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'VariableRateSlope2',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 5_00,
        maxDecrease: 5_00,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );

    vm.prank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_agent));

    vm.prank(report.poolConfiguratorProxy);
    contracts.defaultInterestRateStrategy.setInterestRateParams(
      address(weth),
      IRatesStrategy.InterestRateData({
        optimalUsageRatio: 45_00,
        baseVariableBorrowRate: 5_00,
        variableRateSlope1: 4_00,
        variableRateSlope2: 60_00
      })
    );
  }

  function test_validate_uOptimalNotInRange(uint16 change) public {
    vm.assume(change > 3_00);
    uint256 currentUOptimal = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).optimalUsageRatio;

    // more than 3% absolute increase
    uint256 newUOptimal = currentUOptimal + change;
    _addUpdateToRiskOracle(
      newUOptimal,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentUOptimal);

    // more than 3% absolute decrease
    newUOptimal = currentUOptimal - change;
    _addUpdateToRiskOracle(
      newUOptimal,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_uOptimalInRange(uint16 change) public {
    vm.assume(change != 0 && change <= 3_00);
    uint256 currentUOptimal = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).optimalUsageRatio;

    // less then 3% absolute increase
    uint256 newUOptimal = currentUOptimal + change;
    _addUpdateToRiskOracle(
      newUOptimal,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentUOptimal);

    // less then 3% absolute decrease
    newUOptimal = currentUOptimal - change;
    _addUpdateToRiskOracle(
      newUOptimal,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_baseRateNotInRange(uint8 change) public {
    vm.assume(change != 0 && change > 50);
    uint256 currentBaseRate = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).baseVariableBorrowRate;

    // more than 0.5% absolute increase
    uint256 newBaseRate = currentBaseRate + change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      newBaseRate,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentBaseRate);

    // more than 0.5% absolute decrease
    newBaseRate = currentBaseRate - change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      newBaseRate,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_baseRateInRange(uint8 change) public {
    vm.assume(change != 0 && change <= 50);
    uint256 currentBaseRate = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).baseVariableBorrowRate;

    // more than 0.5% absolute increase
    uint256 newBaseRate = currentBaseRate + change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      newBaseRate,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentBaseRate);

    // more than 0.5% absolute decrease
    newBaseRate = currentBaseRate - change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      newBaseRate,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_slopeOneNotInRange(uint8 change) public {
    vm.assume(change > 1_00);
    uint256 currentSlopeOne = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).variableRateSlope1;

    // more than 1% absolute increase
    uint256 newSlopeOne = currentSlopeOne + change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentSlopeOne);

    // more than 1% absolute decrease
    newSlopeOne = currentSlopeOne - change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_slopeOneInRange(uint16 change) public {
    vm.assume(change != 0 && change <= 1_00);

    uint256 currentSlopeOne = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).variableRateSlope1;

    // less then 1% absolute increase
    uint256 newSlopeOne = (currentSlopeOne + change);
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentSlopeOne);

    // less then 1% absolute decrease
    newSlopeOne = currentSlopeOne - change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_slopeTwoNotInRange(uint16 change) public {
    vm.assume(change > 5_00);
    uint256 currentSlopeTwo = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).variableRateSlope2;

    // more than 5% absolute increase
    uint256 newSlopeTwo = currentSlopeTwo + change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeTwo
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentSlopeTwo);

    // more than 5% absolute decrease
    newSlopeTwo = currentSlopeTwo - change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeTwo
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_slopeTwoInRange(uint16 change) public {
    vm.assume(change > 0 && change <= 1_00);

    uint256 currentSlopeOne = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).variableRateSlope1;

    // less then 1% absolute increase
    uint256 newSlopeOne = (currentSlopeOne + change);
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(change <= currentSlopeOne);

    // less then 1% absolute decrease
    newSlopeOne = currentSlopeOne - change;
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_sameRateParams() public {
    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));
  }

  function test_injectionFromHub() public {
    uint256 currentSlopeOne = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).variableRateSlope1;

    uint256 newSlopeOne = currentSlopeOne + 1_00;

    _addUpdateToRiskOracle(
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT,
      newSlopeOne,
      EngineFlags.KEEP_CURRENT
    );
    assertTrue(_checkAndPerformAutomation(_agentId));

    currentSlopeOne = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth)).variableRateSlope1;
    assertEq(currentSlopeOne, newSlopeOne);
  }

  function _addUpdateToRiskOracle(
    uint256 uOptimal,
    uint256 baseRate,
    uint256 slope1,
    uint256 slope2
  ) internal {
    vm.startPrank(_riskOracleOwner);

    IEngine.InterestRateInputData memory rateData = IDefaultInterestRateStrategyV2(
      contracts.protocolDataProvider.getInterestRateStrategyAddress(address(weth))
    ).getInterestRateDataBps(address(weth));

    if (uOptimal != EngineFlags.KEEP_CURRENT) rateData.optimalUsageRatio = uOptimal;
    if (baseRate != EngineFlags.KEEP_CURRENT) rateData.baseVariableBorrowRate = baseRate;
    if (slope1 != EngineFlags.KEEP_CURRENT) rateData.variableRateSlope1 = slope1;
    if (slope2 != EngineFlags.KEEP_CURRENT) rateData.variableRateSlope2 = slope2;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(rateData),
      _updateType,
      address(weth),
      'additionalData'
    );
    vm.stopPrank();
  }
}
