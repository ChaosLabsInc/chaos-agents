// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {MaticSynchronicityPriceAdapter} from '../src/contracts/MaticSynchronicityPriceAdapter.sol';
import {BaseAggregatorsPolygon} from '../src/lib/BaseAggregators.sol';

contract MaticSynchronicityPriceAdapterTest is Test {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 42326830);
  }

  function testStMaticLatestAnswer() public {
    MaticSynchronicityPriceAdapter adapter = new MaticSynchronicityPriceAdapter(
      BaseAggregatorsPolygon.MATIC_USD_AGGREGATOR,
      BaseAggregatorsPolygon.STMATIC_RATE_PROVIDER,
      'stMATIC / MATIC / USD'
    );

    int256 price = adapter.latestAnswer();

    assertApproxEqAbs(
      uint256(price),
      105747000, // value calculated manually for selected block
      10000
    );
  }

  function testMaticXLatestAnswer() public {
    MaticSynchronicityPriceAdapter adapter = new MaticSynchronicityPriceAdapter(
      BaseAggregatorsPolygon.MATIC_USD_AGGREGATOR,
      BaseAggregatorsPolygon.MATICX_RATE_PROVIDER,
      'MATICX / MATIC / USD'
    );

    int256 price = adapter.latestAnswer();

    assertApproxEqAbs(
      uint256(price),
      105010000, // value calculated manually for selected block
      10000
    );
  }
}
