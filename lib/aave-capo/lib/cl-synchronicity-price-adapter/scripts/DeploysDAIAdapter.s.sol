// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {sDAISynchronicityPriceAdapter} from '../src/contracts/sDAISynchronicityPriceAdapter.sol';
import {sDAIGnosisChainSynchronicityPriceAdapter} from '../src/contracts/sDAIGnosisChainSynchronicityPriceAdapter.sol';
import {BaseAggregatorsMainnet, BaseAggregatorsGnosis} from '../src/lib/BaseAggregators.sol';

contract DeploysDAIMainnet is Script {
  function run() external {
    vm.startBroadcast();

    new sDAISynchronicityPriceAdapter(
      BaseAggregatorsMainnet.DAI_USD_AGGREGATOR,
      BaseAggregatorsMainnet.SDAI_POT,
      'sDAI/DAI/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeploysDAIGnosis is Script {
  function run() external {
    vm.startBroadcast();

    new sDAIGnosisChainSynchronicityPriceAdapter(
      BaseAggregatorsGnosis.DAI_USD_AGGREGATOR,
      BaseAggregatorsGnosis.SDAI,
      'sDAI/DAI/USD'
    );

    vm.stopBroadcast();
  }
}
