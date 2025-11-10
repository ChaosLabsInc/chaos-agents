// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {CLSynchronicityPriceAdapterPegToBase} from '../src/contracts/CLSynchronicityPriceAdapterPegToBase.sol';
import {BaseAggregatorsArbitrum} from '../src/lib/BaseAggregators.sol';

contract DeployrETHArbitrum is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsArbitrum.ETH_USD_AGGREGATOR,
      BaseAggregatorsArbitrum.RETH_ETH_AGGREGATOR,
      8,
      'rETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}
