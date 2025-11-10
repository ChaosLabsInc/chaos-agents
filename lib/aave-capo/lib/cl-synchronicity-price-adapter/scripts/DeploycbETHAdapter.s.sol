// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {CbEthSynchronicityPriceAdapter} from '../src/contracts/CbEthSynchronicityPriceAdapter.sol';
import {CLSynchronicityPriceAdapterPegToBase} from '../src/contracts/CLSynchronicityPriceAdapterPegToBase.sol';
import {BaseAggregatorsMainnet, BaseAggregatorsBase} from '../src/lib/BaseAggregators.sol';

contract DeploycbETHMainnet is Script {
  function run() external {
    vm.startBroadcast();

    new CbEthSynchronicityPriceAdapter(
      BaseAggregatorsMainnet.ETH_USD_AGGREGATOR,
      BaseAggregatorsMainnet.CBETH,
      'cbETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeploycbETHBase is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsBase.ETH_USD_AGGREGATOR,
      BaseAggregatorsBase.CBETH_ETH_AGGREGATOR,
      8,
      'cbETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}
