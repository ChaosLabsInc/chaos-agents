// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRiskOracle} from '../../src/contracts/dependencies/IRiskOracle.sol';
import {BaseAaveAgent} from '../../src/contracts/agent/aave/BaseAaveAgent.sol';

contract MockAaveAgent is BaseAaveAgent {
  constructor(address agentHub) BaseAaveAgent(agentHub, address(0), address(0)) {}

  function validate(
    uint256,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata
  ) public pure override returns (bool) {
    return true;
  }

  function getMarkets(uint256) external pure override returns (address[] memory) {
    return new address[](0);
  }

  function _processUpdate(
    uint256 agentId,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata update
  ) internal pure override {}

  function decodeToUint(bytes calldata valueInBytes) public pure returns (uint256) {
    return _decodeToUint(valueInBytes);
  }
}
