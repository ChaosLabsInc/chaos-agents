// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ProposalPayloadStablecoinsPriceAdapter} from '../src/contracts/ProposalPayloadStablecoinsPriceAdapter.sol';
import {CLSynchronicityPriceAdapterBaseToPeg} from '../src/contracts/CLSynchronicityPriceAdapterBaseToPeg.sol';
import {AaveV2Ethereum} from 'aave-address-book/AaveAddressBook.sol';

contract PriceChangeTest is Test, ProposalPayloadStablecoinsPriceAdapter {
  uint8 public constant MAX_DIFF_PERCENTAGE = 2;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 15588955);
  }

  function testStablecoinPriceAdapter() public {
    (
      address[] memory assets,
      address[] memory aggregators,
      string[] memory names
    ) = _initAssetAggregators();
    address[] memory adapters = new address[](assets.length);

    for (uint8 i = 0; i < assets.length; i++) {
      CLSynchronicityPriceAdapterBaseToPeg adapter = new CLSynchronicityPriceAdapterBaseToPeg(
        ETH_USD_AGGREGATOR,
        aggregators[i],
        18,
        names[i]
      );

      adapters[i] = address(adapter);
    }

    for (uint8 i = 0; i < assets.length; i++) {
      uint256 currentPrice = AaveV2Ethereum.ORACLE.getAssetPrice(assets[i]);
      uint256 newPrice = uint256(CLSynchronicityPriceAdapterBaseToPeg(adapters[i]).latestAnswer());

      uint256 maximumDifference = (currentPrice * MAX_DIFF_PERCENTAGE) / 100;
      uint256 lowerLimit = currentPrice - maximumDifference;
      uint256 upperLimit = currentPrice + maximumDifference;

      assertTrue(newPrice >= lowerLimit);
      assertTrue(newPrice <= upperLimit);
    }
  }
}
