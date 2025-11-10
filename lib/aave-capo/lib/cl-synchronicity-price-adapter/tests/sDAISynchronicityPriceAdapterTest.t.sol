// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {sDAISynchronicityPriceAdapter} from '../src/contracts/sDAISynchronicityPriceAdapter.sol';
import {BaseAggregatorsMainnet} from '../src/lib/BaseAggregators.sol';

contract sDAISynchronicityPriceAdapterTest is Test {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 17971138);
  }

  function testLatestAnswer() public {
    sDAISynchronicityPriceAdapter adapter = new sDAISynchronicityPriceAdapter(
      BaseAggregatorsMainnet.DAI_USD_AGGREGATOR,
      BaseAggregatorsMainnet.SDAI_POT,
      'sDAI / DAI / USD'
    );

    int256 price = adapter.latestAnswer();

    assertApproxEqAbs(
      uint256(price),
      103090540, // value calculated manually for selected block
      1000
    );
  }
}
