// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {RepFixedPriceAdapter} from '../src/contracts/RepFixedPriceAdapter.sol';

contract DeployRepMainnet is Script {
  function run() external {
    vm.startBroadcast();

    new RepFixedPriceAdapter();

    vm.stopBroadcast();
  }
}
