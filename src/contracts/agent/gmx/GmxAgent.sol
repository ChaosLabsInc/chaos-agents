// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRiskOracle} from '../../dependencies/IRiskOracle.sol';
import {IConfig} from '../../dependencies/gmx/IConfig.sol';
import {Cast} from '../../dependencies/gmx/utils/Cast.sol';
import {Keys} from '../../dependencies/gmx/utils/Keys.sol';
import {IEventEmitter, EventUtils} from '../../dependencies/gmx/IEventEmitter.sol';
import {BaseAgent} from '../BaseAgent.sol';

/**
 * @title GmxAgent
 * @author BGD Labs
 * @notice Agent contract to be used by the agentHub to do postValidation and
 *         injection for market parameter updates by risk oracle on the GMX protocol
 */
contract GmxAgent is BaseAgent {
  using EventUtils for EventUtils.UintItems;
  using EventUtils for EventUtils.BoolItems;

  /**
   * @param agentHub the address of the agentHub which will use this agent contract
   */
  constructor(address agentHub) BaseAgent(agentHub) {}

  /// @inheritdoc BaseAgent
  function validate(
    uint256,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata update
  ) public pure override returns (bool) {
    (bytes32 baseKey, bytes memory data) = _decodeAdditionalData(update.additionalData);
    return _validateMarketInData(baseKey, update.market, data);
  }

  /**
   * @inheritdoc BaseAgent
   * @dev unused, as markets are configured directly on the hub.
   */
  function getMarkets(uint256) external pure override returns (address[] memory) {
    return new address[](0);
  }

  /// @inheritdoc BaseAgent
  function _processUpdate(
    uint256,
    bytes calldata agentContext,
    IRiskOracle.RiskParameterUpdate calldata update
  ) internal override {
    (address config, address eventEmitter) = abi.decode(agentContext, (address, address));
    uint256 previousValue = Cast.bytesToUint256(update.previousValue);
    uint256 updatedValue = Cast.bytesToUint256(update.newValue);

    (bytes32 baseKey, bytes memory data) = _decodeAdditionalData(update.additionalData);
    IConfig(config).setUint(baseKey, data, updatedValue);

    EventUtils.EventLogData memory eventData;

    eventData.uintItems.initItems(3);
    eventData.uintItems.setItem(0, 'updateId', update.updateId);
    eventData.uintItems.setItem(1, 'prevValue', previousValue);
    eventData.uintItems.setItem(2, 'nextValue', updatedValue);

    eventData.boolItems.initItems(1);
    eventData.boolItems.setItem(0, 'updateApplied', true);

    IEventEmitter(eventEmitter).emitEventLog('SyncConfig', eventData);
  }

  /**
   * @notice validates that the market within encoded additionalData param
   *         is equal to market param from the risk param update
   * @param baseKey the base key to validate
   * @param market the market address
   * @param data the data used to compute fullKey
   * @return true if the market within data is equal to market, false otherwise
   */
  function _validateMarketInData(
    bytes32 baseKey,
    address market,
    bytes memory data
  ) internal pure returns (bool) {
    address marketFromData;
    if (baseKey == Keys.MAX_PNL_FACTOR) {
      (, /* bytes32 extKey */ marketFromData /* bool isLong */, ) = abi.decode(
        data,
        (bytes32, address, bool)
      );
    } else {
      marketFromData = abi.decode(data, (address));
    }

    return market == marketFromData;
  }

  /**
   * @notice method to decode the additional data
   * @param data bytes encoded additional data
   * @return baseKey of the update
   * @return data of the update
   */
  function _decodeAdditionalData(bytes memory data) internal pure returns (bytes32, bytes memory) {
    return abi.decode(data, (bytes32, bytes));
  }
}
