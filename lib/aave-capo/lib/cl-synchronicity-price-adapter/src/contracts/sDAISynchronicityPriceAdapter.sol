// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IChainlinkAggregator} from '../interfaces/IChainlinkAggregator.sol';
import {ICLSynchronicityPriceAdapter} from '../interfaces/ICLSynchronicityPriceAdapter.sol';
import {IPot} from '../interfaces/IPot.sol';

/**
 * @title sDAISynchronicityPriceAdapter
 * @author BGD Labs
 * @notice Price adapter to calculate price of (sDAI / USD) pair by using
 * @notice Chainlink Data Feed for (DAI / USD) and rate provider for (sDAI / DAI).
 */
contract sDAISynchronicityPriceAdapter is ICLSynchronicityPriceAdapter {
  /**
   * @notice Price feed for (DAI / USD) pair
   */
  IChainlinkAggregator public immutable DAI_TO_USD;

  /**
   * @notice rate provider for (sDAI / DAI)
   */
  IPot public immutable RATE_PROVIDER;

  /**
   * @notice Number of decimals for sDAI / DAI ratio
   */
  uint8 public constant RATIO_DECIMALS = 27;

  /**
   * @notice Number of decimals in the output of this price adapter
   */
  uint8 public immutable DECIMALS;

  string private _description;

  /**
   * @param daiToUSDAggregatorAddress the address of DAI / USD feed
   * @param rateProviderAddress the address of the rate provider
   * @param pairName name identifier
   */
  constructor(
    address daiToUSDAggregatorAddress,
    address rateProviderAddress,
    string memory pairName
  ) {
    DAI_TO_USD = IChainlinkAggregator(daiToUSDAggregatorAddress);
    RATE_PROVIDER = IPot(rateProviderAddress);

    DECIMALS = DAI_TO_USD.decimals();

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
    int256 daiToUSDPrice = DAI_TO_USD.latestAnswer();
    int256 ratio = int256(RATE_PROVIDER.chi());

    if (daiToUSDPrice <= 0 || ratio <= 0) {
      return 0;
    }

    return (daiToUSDPrice * ratio) / int256(10 ** RATIO_DECIMALS);
  }
}
