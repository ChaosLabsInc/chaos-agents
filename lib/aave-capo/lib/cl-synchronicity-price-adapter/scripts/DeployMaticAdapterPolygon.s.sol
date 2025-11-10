// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {MaticSynchronicityPriceAdapter} from '../src/contracts/MaticSynchronicityPriceAdapter.sol';
import {BaseAggregatorsPolygon} from '../src/lib/BaseAggregatorsPolygon.sol';

contract DeployMaticXAdapterPolygon is Script {
  function run() external {
    vm.startBroadcast();

    new MaticSynchronicityPriceAdapter(
      BaseAggregatorsPolygon.MATIC_USD_AGGREGATOR,
      BaseAggregatorsPolygon.MATICX_RATE_PROVIDER,
      'MATICX/MATIC/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeployStMaticAdapterPolygon is Script {
  function run() external {
    vm.startBroadcast();

    new MaticSynchronicityPriceAdapter(
      BaseAggregatorsPolygon.MATIC_USD_AGGREGATOR,
      BaseAggregatorsPolygon.STMATIC_RATE_PROVIDER,
      'stMATIC/MATIC/USD'
    );

    vm.stopBroadcast();
  }
}
