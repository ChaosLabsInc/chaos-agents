// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {DataTypes} from 'aave-v3-origin/src/contracts/protocol/libraries/types/DataTypes.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';

import {IRangeValidationModule} from '../../../interfaces/IRangeValidationModule.sol';
import {IRiskOracle} from '../../dependencies/IRiskOracle.sol';
import {BaseAgent} from '../BaseAgent.sol';
import {BaseAaveAgent} from './BaseAaveAgent.sol';

/**
 * @title AaveEModeAgent
 * @author BGD Labs
 * @notice Agent contract to be used by the agentHub to do postValidation and
 *         injection for e-mode category update by risk oracle on the Aave protocol
 */
contract AaveEModeAgent is BaseAaveAgent {
  using SafeCast for uint160;
  using Address for address;

  /// @notice Struct containing the eMode category update
  struct EModeCategoryUpdate {
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
  }

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
    // eMode category id is encoded in the market address
    uint8 eModeId = uint160(update.market).toUint8();

    DataTypes.CollateralConfig memory currentEModeData = POOL.getEModeCategoryCollateralConfig(
      eModeId
    );
    // as the definition is 100% + x%, and we take into account x% for simplicity.
    currentEModeData.liquidationBonus = currentEModeData.liquidationBonus - 100_00;

    EModeCategoryUpdate memory newEModeData = _interpret(update.newValue);

    if (
      currentEModeData.ltv == newEModeData.ltv &&
      currentEModeData.liquidationThreshold == newEModeData.liquidationThreshold &&
      currentEModeData.liquidationBonus == newEModeData.liquidationBonus
    ) return false;

    IRangeValidationModule.RangeValidationInput[]
      memory input = new IRangeValidationModule.RangeValidationInput[](3);

    input[0] = IRangeValidationModule.RangeValidationInput({
      from: currentEModeData.ltv,
      to: newEModeData.ltv,
      updateType: 'EModeLTV'
    });
    input[1] = IRangeValidationModule.RangeValidationInput({
      from: currentEModeData.liquidationThreshold,
      to: newEModeData.liquidationThreshold,
      updateType: 'EModeLiquidationThreshold'
    });
    input[2] = IRangeValidationModule.RangeValidationInput({
      from: currentEModeData.liquidationBonus,
      to: newEModeData.liquidationBonus,
      updateType: 'EModeLiquidationBonus'
    });

    return RANGE_VALIDATION_MODULE.validate(AGENT_HUB, agentId, update.market, input);
  }

  /// @inheritdoc BaseAgent
  function _processUpdate(
    uint256,
    bytes calldata agentContext,
    IRiskOracle.RiskParameterUpdate calldata update
  ) internal override {
    // eMode category id is encoded in the market address
    uint8 eModeId = uint160(update.market).toUint8();
    EModeCategoryUpdate memory eModeUpdate = _interpret(update.newValue);

    IEngine.EModeCategoryUpdate[] memory newEModeData = new IEngine.EModeCategoryUpdate[](1);
    newEModeData[0] = IEngine.EModeCategoryUpdate({
      eModeCategory: eModeId,
      ltv: eModeUpdate.ltv,
      liqThreshold: eModeUpdate.liquidationThreshold,
      liqBonus: eModeUpdate.liquidationBonus,
      label: EngineFlags.KEEP_CURRENT_STRING
    });

    // target is the aave config engine, which is a helper contract to update protocol risk params
    address target = abi.decode(agentContext, (address));
    target.functionDelegateCall(
      abi.encodeWithSelector(IEngine.updateEModeCategories.selector, newEModeData)
    );
  }

  /// @inheritdoc BaseAgent
  /// @dev overridden as we do not want to use the reserve list as markets as in
  ///      in this agent market address denotes e-mode id.
  function getMarkets(uint256) external pure override returns (address[] memory) {
    return new address[](0);
  }

  /**
   * @notice method to interpret the e-mode category update from risk oracle
   * @param valueInBytes bytes encoded e-mode category update struct value passed from the risk oracle
   * @return value the decoded e-mode category update struct from the risk oracle
   */
  function _interpret(
    bytes calldata valueInBytes
  ) internal pure returns (EModeCategoryUpdate memory) {
    return abi.decode(valueInBytes, (EModeCategoryUpdate));
  }
}
