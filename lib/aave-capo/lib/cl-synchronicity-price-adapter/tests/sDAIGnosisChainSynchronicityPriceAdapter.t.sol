// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {sDAIGnosisChainSynchronicityPriceAdapter} from '../src/contracts/sDAIGnosisChainSynchronicityPriceAdapter.sol';
import {BaseAggregatorsGnosis} from '../src/lib/BaseAggregators.sol';

contract sDAIGnosisChainSynchronicityPriceAdapterTest is Test {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('gnosis'), 30519542);
  }

  function testLatestAnswer() public {
    sDAIGnosisChainSynchronicityPriceAdapter adapter = new sDAIGnosisChainSynchronicityPriceAdapter(
      BaseAggregatorsGnosis.DAI_USD_AGGREGATOR,
      BaseAggregatorsGnosis.SDAI,
      'sDAI / DAI / USD'
    );

    int256 price = adapter.latestAnswer();

    assertApproxEqAbs(
      uint256(price),
      1_01806632, // value calculated manually for selected block
      100
    );
  }
}
