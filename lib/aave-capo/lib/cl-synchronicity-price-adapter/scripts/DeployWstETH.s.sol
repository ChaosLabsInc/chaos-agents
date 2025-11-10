// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {WstETHSynchronicityPriceAdapter} from '../src/contracts/WstETHSynchronicityPriceAdapter.sol';
import {StETHtoETHSynchronicityPriceAdapter} from '../src/contracts/StETHtoETHSynchronicityPriceAdapter.sol';
import {CLSynchronicityPriceAdapterPegToBase} from '../src/contracts/CLSynchronicityPriceAdapterPegToBase.sol';
import {BaseAggregatorsMainnet, BaseAggregatorsArbitrum, BaseAggregatorsOptimism, BaseAggregatorsPolygon, BaseAggregatorsBase, BaseAggregatorsScroll} from '../src/lib/BaseAggregators.sol';

contract DeployStETHMainnetV2 is Script {
  function run() external {
    vm.startBroadcast();

    new StETHtoETHSynchronicityPriceAdapter('stETH/ETH');

    vm.stopBroadcast();
  }
}

contract DeployWstETHMainnetV3 is Script {
  address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

  function run() external {
    vm.startBroadcast();

    new WstETHSynchronicityPriceAdapter(
      BaseAggregatorsMainnet.ETH_USD_AGGREGATOR,
      STETH,
      'wstETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeployWstETHArbitrum is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsArbitrum.ETH_USD_AGGREGATOR,
      BaseAggregatorsArbitrum.WSTETH_STETH_AGGREGATOR,
      8,
      'wstETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeployWstETHOptimism is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsOptimism.ETH_USD_AGGREGATOR,
      BaseAggregatorsOptimism.WSTETH_STETH_AGGREGATOR,
      8,
      'wstETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeployWstETHPolygon is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsPolygon.ETH_USD_AGGREGATOR,
      BaseAggregatorsPolygon.WSTETH_STETH_AGGREGATOR,
      8,
      'wstETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeployWstETHBase is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsBase.ETH_USD_AGGREGATOR,
      BaseAggregatorsBase.WSTETH_STETH_AGGREGATOR,
      8,
      'wstETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}

contract DeployWstETHScroll is Script {
  function run() external {
    vm.startBroadcast();

    new CLSynchronicityPriceAdapterPegToBase(
      BaseAggregatorsScroll.ETH_USD_AGGREGATOR,
      BaseAggregatorsScroll.WSTETH_STETH_AGGREGATOR,
      8,
      'wstETH/ETH/USD'
    );

    vm.stopBroadcast();
  }
}
