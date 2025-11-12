// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {RangeValidationModule} from '../src/contracts/modules/RangeValidationModule.sol';

library DeployRangeValidationModule {
  bytes32 public constant SALT = 'v1';

  function _deployRangeValidationModule() internal returns (address) {
    return Create2Utils.create2Deploy(SALT, type(RangeValidationModule).creationCode);
  }
}
