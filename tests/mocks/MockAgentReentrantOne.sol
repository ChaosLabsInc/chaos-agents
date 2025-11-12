// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRiskOracle} from '../../src/contracts/dependencies/IRiskOracle.sol';
import {IAgentHub} from '../../src/interfaces/IAgentHub.sol';
import {BaseAgent} from '../../src/contracts/agent/BaseAgent.sol';

contract MockAgentReentrantOne is BaseAgent {
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
  ) internal virtual override {
    address[] memory markets = new address[](1);
    markets[0] = update.market;

    IAgentHub.ActionData[] memory actions = new IAgentHub.ActionData[](1);
    actions[0] = IAgentHub.ActionData({agentId: agentId, markets: markets});
    IAgentHub(AGENT_HUB).execute(actions);
  }
}
