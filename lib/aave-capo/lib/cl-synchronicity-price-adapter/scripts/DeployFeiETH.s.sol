// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {FixedRatioSynchronicityPriceAdapterBaseToPeg} from '../src/contracts/FixedRatioSynchronicityPriceAdapterBaseToPeg.sol';
import {BaseAggregatorsMainnet} from '../src/lib/BaseAggregators.sol';

contract DeployFeiETHMainnet is Script {
  function run() external {
    vm.startBroadcast();

    new FixedRatioSynchronicityPriceAdapterBaseToPeg(
      BaseAggregatorsMainnet.ETH_USD_AGGREGATOR,
      95_00,
      18,
      '0.95/USD/ETH'
    );

    vm.stopBroadcast();
  }
}
