// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IChainlinkAggregator} from '../interfaces/IChainlinkAggregator.sol';
import {ICLSynchronicityPriceAdapter} from '../interfaces/ICLSynchronicityPriceAdapter.sol';
import {IMaticRateProvider} from '../interfaces/IMaticRateProvider.sol';

/**
 * @title MaticSynchronicityPriceAdapter
 * @author BGD Labs
 * @notice Price adapter to calculate price of (Asset / Base) pair by using
 * @notice Chainlink Data Feed for (MATIC / Base) and rate provider for (Asset / MATIC).
 * @notice For example it can be used to calculate stMATIC / USD
 * @notice based on MATIC / USD and stMATIC / MATIC rate provider contract.
 */
contract MaticSynchronicityPriceAdapter is ICLSynchronicityPriceAdapter {
  /**
   * @notice Price feed for (MATIC / Base) pair
   */
  IChainlinkAggregator public immutable MATIC_TO_BASE;

  /**
   * @notice Price feed for (MATIC / Base) pair
   */
  IMaticRateProvider public immutable RATE_PROVIDER;

  /**
   * @notice Number of decimals for asset / MATIC ratio
   */
  uint8 public constant RATIO_DECIMALS = 18;

  /**
   * @notice Number of decimals in the output of this price adapter
   */
  uint8 public immutable DECIMALS;

  string private _description;

  /**
   * @param maticToBaseAggregatorAddress the address of MATIC / BASE feed
   * @param rateProviderAddress the address of the rate provider
   * @param pairName name identifier
   */
  constructor(
    address maticToBaseAggregatorAddress,
    address rateProviderAddress,
    string memory pairName
  ) {
    MATIC_TO_BASE = IChainlinkAggregator(maticToBaseAggregatorAddress);
    RATE_PROVIDER = IMaticRateProvider(rateProviderAddress);

    DECIMALS = MATIC_TO_BASE.decimals();

    _description = pairName;
  }

  /// @inheritdoc ICLSynchronicityPriceAdapter
  function description() external view returns (string memory) {
    return _description;
  }

  /// @inheritdoc ICLSynchronicityPriceAdapter
  function decimals() external view returns (uint8) {
    return DECIMALS;
  }

  /// @inheritdoc ICLSynchronicityPriceAdapter
  function latestAnswer() public view virtual override returns (int256) {
    int256 maticToBasePrice = MATIC_TO_BASE.latestAnswer();
    int256 ratio = int256(RATE_PROVIDER.getRate());

    if (maticToBasePrice <= 0 || ratio <= 0) {
      return 0;
    }

    return (maticToBasePrice * ratio) / int256(10 ** RATIO_DECIMALS);
  }
}
