// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EthereumScript, ArbitrumScript, OptimismScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {RangeValidationModule} from '../src/contracts/modules/RangeValidationModule.sol';

library DeployRangeValidationModule {
  bytes32 public constant SALT = 'v1';

  function _deployRangeValidationModule() internal returns (address) {
    return Create2Utils.create2Deploy(SALT, type(RangeValidationModule).creationCode);
  }
}

// make deploy-ledger contract=scripts/RangeValidationModule.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  function run() external broadcast {
    DeployRangeValidationModule._deployRangeValidationModule();
  }
}

// make deploy-ledger contract=scripts/RangeValidationModule.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  function run() external broadcast {
    DeployRangeValidationModule._deployRangeValidationModule();
  }
}

// make deploy-ledger contract=scripts/RangeValidationModule.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  function run() external broadcast {
    DeployRangeValidationModule._deployRangeValidationModule();
  }
}
