// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {CLSynchronicityPriceAdapterPegToBase} from '../src/contracts/CLSynchronicityPriceAdapterPegToBase.sol';
import {BaseAggregatorsOptimism} from '../src/lib/BaseAggregators.sol';

contract DeployrETHOptimism is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsOptimism.ETH_USD_AGGREGATOR,
      BaseAggregatorsOptimism.RETH_ETH_AGGREGATOR,
      8,
      'rETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}
