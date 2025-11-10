// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

import {IDefaultInterestRateStrategyV2, IEngine} from '../../dependencies/IDefaultInterestRateStrategyV2.sol';
import {IRangeValidationModule} from '../../../interfaces/IRangeValidationModule.sol';
import {IRiskOracle} from '../../dependencies/IRiskOracle.sol';
import {BaseAgent} from '../BaseAgent.sol';
import {BaseAaveAgent} from './BaseAaveAgent.sol';

/**
 * @title AaveRatesAgent
 * @author BGD Labs
 * @notice Agent contract to be used by the agentHub to do postValidation and
 *         injection for interest rate updates by risk oracle on the Aave protocol
 */
contract AaveRatesAgent is BaseAaveAgent {
  using Address for address;

  /**
   * @param agentHub the address of the agentHub which will use this agent contract
   * @param rangeValidationModule the address of range validation module used to store range config and to validate ranges
   * @param pool the address of aave pool
   */
  constructor(
    address agentHub,
    address rangeValidationModule,
    address pool
  ) BaseAaveAgent(agentHub, rangeValidationModule, pool) {}

  /// @inheritdoc BaseAgent
  function validate(
    uint256 agentId,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata update
  ) external view override returns (bool) {
    IEngine.InterestRateInputData memory currentRatesData = IDefaultInterestRateStrategyV2(
      POOL.getReserveData(update.market).interestRateStrategyAddress
    ).getInterestRateDataBps(update.market);

    IEngine.InterestRateInputData memory newRatesData = _interpret(update.newValue);

    if (
      currentRatesData.optimalUsageRatio == newRatesData.optimalUsageRatio &&
      currentRatesData.baseVariableBorrowRate == newRatesData.baseVariableBorrowRate &&
      currentRatesData.variableRateSlope1 == newRatesData.variableRateSlope1 &&
      currentRatesData.variableRateSlope2 == newRatesData.variableRateSlope2
    ) return false;

    IRangeValidationModule.RangeValidationInput[]
      memory input = new IRangeValidationModule.RangeValidationInput[](4);

    input[0] = IRangeValidationModule.RangeValidationInput({
      from: currentRatesData.optimalUsageRatio,
      to: newRatesData.optimalUsageRatio,
      updateType: 'OptimalUsageRatio'
    });
    input[1] = IRangeValidationModule.RangeValidationInput({
      from: currentRatesData.baseVariableBorrowRate,
      to: newRatesData.baseVariableBorrowRate,
      updateType: 'BaseVariableBorrowRate'
    });
    input[2] = IRangeValidationModule.RangeValidationInput({
      from: currentRatesData.variableRateSlope1,
      to: newRatesData.variableRateSlope1,
      updateType: 'VariableRateSlope1'
    });
    input[3] = IRangeValidationModule.RangeValidationInput({
      from: currentRatesData.variableRateSlope2,
      to: newRatesData.variableRateSlope2,
      updateType: 'VariableRateSlope2'
    });

    return RANGE_VALIDATION_MODULE.validate(AGENT_HUB, agentId, update.market, input);
  }

  /// @inheritdoc BaseAgent
  function _processUpdate(
    uint256,
    bytes calldata agentContext,
    IRiskOracle.RiskParameterUpdate calldata update
  ) internal override {
    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0].asset = update.market;
    rateUpdates[0].params = _interpret(update.newValue);

    // target is the aave config engine, which is a helper contract to update protocol risk params
    address target = abi.decode(agentContext, (address));
    target.functionDelegateCall(
      abi.encodeWithSelector(IEngine.updateRateStrategies.selector, rateUpdates)
    );
  }

  /**
   * @notice method to interpret the interest rate value from risk oracle
   * @param valueInBytes bytes encoded interest rate struct value passed from the risk oracle
   * @return value the decoded interest rate struct from the risk oracle
   */
  function _interpret(
    bytes calldata valueInBytes
  ) internal pure returns (IEngine.InterestRateInputData memory) {
    return abi.decode(valueInBytes, (IEngine.InterestRateInputData));
  }
}
