// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {CLSynchronicityPriceAdapterPegToBase} from '../src/contracts/CLSynchronicityPriceAdapterPegToBase.sol';
import {BaseAggregatorsMainnet} from '../src/lib/BaseAggregators.sol';

contract DeploywBTCMainnet is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsMainnet.BTC_USD_AGGREGATOR,
      BaseAggregatorsMainnet.WBTC_BTC_AGGREGATOR,
      8,
      'wBTC/BTC/USD'
    );

    vm.stopBroadcast();
  }
}
