// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {CLrETHSynchronicityPriceAdapter} from '../src/contracts/CLrETHSynchronicityPriceAdapter.sol';
import {BaseAggregatorsMainnet} from '../src/lib/BaseAggregators.sol';

contract CLrETHSynchronicityPriceAdapterTest is Test {
  address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16569607);
  }

  function testLatestAnswer() public {
    CLrETHSynchronicityPriceAdapter adapter = new CLrETHSynchronicityPriceAdapter(
      BaseAggregatorsMainnet.ETH_USD_AGGREGATOR,
      RETH,
      'rETH/ETH/USD'
    );

    int256 price = adapter.latestAnswer();

    assertApproxEqAbs(
      uint256(price),
      172790720000, // value calculated manually for selected block, there is a diff with DEXes at the moment
      10000
    );
  }
}
