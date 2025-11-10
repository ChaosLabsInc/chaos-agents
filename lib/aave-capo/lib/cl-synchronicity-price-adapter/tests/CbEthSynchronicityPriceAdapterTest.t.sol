// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {CbEthSynchronicityPriceAdapter} from '../src/contracts/CbEthSynchronicityPriceAdapter.sol';
import {BaseAggregatorsMainnet} from '../src/lib/BaseAggregators.sol';

contract CbEthSynchronicityPriceAdapterTest is Test {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 17334720);
  }

  function testLatestAnswer() public {
    CbEthSynchronicityPriceAdapter adapter = new CbEthSynchronicityPriceAdapter(
      BaseAggregatorsMainnet.ETH_USD_AGGREGATOR,
      BaseAggregatorsMainnet.CBETH,
      'cbETH / ETH / USD'
    );

    int256 price = adapter.latestAnswer();

    assertApproxEqAbs(
      uint256(price),
      185289330000, // value calculated manually for selected block
      10000
    );
  }
}
