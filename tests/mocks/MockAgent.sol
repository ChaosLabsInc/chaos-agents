// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRiskOracle} from '../../src/contracts/dependencies/IRiskOracle.sol';
import {BaseAgent} from '../../src/contracts/agent/BaseAgent.sol';

contract MockAgent is BaseAgent {
  constructor(address agentHub) BaseAgent(agentHub) {}

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
}
