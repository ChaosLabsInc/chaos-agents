// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IChainlinkAggregator} from '../interfaces/IChainlinkAggregator.sol';
import {ICLSynchronicityPriceAdapter} from '../interfaces/ICLSynchronicityPriceAdapter.sol';
import {IERC4626} from 'forge-std/interfaces/IERC4626.sol';

/**
 * @title sDAIGnosisChainSynchronicityPriceAdapter
 * @author BGD Labs
 * @notice Price adapter to calculate price of (sDAI / USD) pair by using
 * @notice Chainlink Data Feed for (DAI / USD) and exchange rate of
 * @notice (sDAI / DAI) using the sDAI ERC4626 convertToAssets()
 */
contract sDAIGnosisChainSynchronicityPriceAdapter is ICLSynchronicityPriceAdapter {
  /**
   * @notice Price feed for (DAI / Base) pair
   */
  IChainlinkAggregator public immutable DAI_TO_BASE;

  /**
   * @notice sDAI token contract to get the exchange rate
   */
  IERC4626 public immutable sDAI;

  /**
   * @notice Number of decimals for sDAI / DAI ratio
   */
  uint8 public immutable RATIO_DECIMALS;

  /**
   * @notice Number of decimals in the output of this price adapter
   */
  uint8 public immutable DECIMALS;

  string private _description;

  /**
   * @param daiToBaseAggregatorAddress the address of DAI / BASE chainlink feed
   * @param sDaiAddress the address of the sDAI token contract
   * @param pairName name identifier
   */
  constructor(
    address daiToBaseAggregatorAddress,
    address sDaiAddress,
    string memory pairName
  ) {
    DAI_TO_BASE = IChainlinkAggregator(daiToBaseAggregatorAddress);
    sDAI = IERC4626(sDaiAddress);

    DECIMALS = DAI_TO_BASE.decimals();
    RATIO_DECIMALS = sDAI.decimals();

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
  function latestAnswer() public view override returns (int256) {
    int256 daiToBasePrice = DAI_TO_BASE.latestAnswer();
    int256 ratio = int256(sDAI.convertToAssets(10 ** RATIO_DECIMALS));

    if (daiToBasePrice <= 0) {
      return 0;
    }

    return (daiToBasePrice * ratio) / int256(10 ** RATIO_DECIMALS);
  }
}
