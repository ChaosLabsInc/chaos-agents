// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {IAaveOracle} from 'aave-v3-origin/src/contracts/interfaces/IAaveOracle.sol';
import {IPendlePriceCapAdapter} from 'aave-capo/interfaces/IPendlePriceCapAdapter.sol';

import {IRangeValidationModule} from '../../../interfaces/IRangeValidationModule.sol';
import {IRiskOracle} from '../../dependencies/IRiskOracle.sol';
import {BaseAgent} from '../BaseAgent.sol';
import {BaseAaveAgent} from './BaseAaveAgent.sol';

/**
 * @title AaveDiscountRateAgent
 * @author BGD Labs
 * @notice Agent contract to be used by the agentHub to do postValidation and
 *         injection for pendle pt discount-rate updates by risk oracle on the Aave protocol
 */
contract AaveDiscountRateAgent is BaseAaveAgent {
  using SafeCast for uint256;
  using Address for address;

  IAaveOracle public immutable AAVE_ORACLE;

  /**
   * @param agentHub the address of the agentHub which will use this agent contract
   * @param rangeValidationModule the address of range validation module used to store range config and to validate ranges
   * @param pool the address of aave pool
   * @param aaveOracle the address of aave oracle of the instance
   */
  constructor(
    address agentHub,
    address rangeValidationModule,
    address pool,
    address aaveOracle
  ) BaseAaveAgent(agentHub, rangeValidationModule, pool) {
    AAVE_ORACLE = IAaveOracle(aaveOracle);
  }

  /// @inheritdoc BaseAgent
  function validate(
    uint256 agentId,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata update
  ) external view override returns (bool) {
    uint256 currentDiscountRate = IPendlePriceCapAdapter(
      AAVE_ORACLE.getSourceOfAsset(update.market)
    ).discountRatePerYear();

    uint256 newDiscountRate = _interpret(update.newValue);
    if (currentDiscountRate == newDiscountRate || newDiscountRate == 0) return false;

    return
      RANGE_VALIDATION_MODULE.validate(
        AGENT_HUB,
        agentId,
        update.market,
        IRangeValidationModule.RangeValidationInput({
          from: currentDiscountRate,
          to: newDiscountRate,
          updateType: update.updateType
        })
      );
  }

  /// @inheritdoc BaseAgent
  function _processUpdate(
    uint256,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata update
  ) internal override {
    address target = AAVE_ORACLE.getSourceOfAsset(update.market);

    target.functionCall(
      abi.encodeCall(IPendlePriceCapAdapter.setDiscountRatePerYear, _interpret(update.newValue))
    );
  }

  /**
   * @notice method to interpret the cap value from risk oracle
   * @param valueInBytes bytes encoded discount rate passed from the risk oracle
   * @return value the decoded value from the risk oracle, denotes the discount rate value
   */
  function _interpret(bytes calldata valueInBytes) internal pure returns (uint64) {
    return _decodeToUint(valueInBytes).toUint64();
  }
}
