// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRiskOracle} from '../../src/contracts/dependencies/IRiskOracle.sol';
import {IAgentHub} from '../../src/interfaces/IAgentHub.sol';

import {MockAgentReentrantOne} from './MockAgentReentrantOne.sol';

contract MockAgentReentrantTwo is MockAgentReentrantOne {
  address public immutable MARKET;
  uint256 count;

  constructor(address agentHub, address market) MockAgentReentrantOne(agentHub) {
    MARKET = market;
  }

  function _processUpdate(
    uint256 agentId,
    bytes calldata,
    IRiskOracle.RiskParameterUpdate calldata
  ) internal virtual override {
    address[] memory markets = new address[](1);
    markets[0] = MARKET;

    IAgentHub.ActionData[] memory actions = new IAgentHub.ActionData[](1);
    actions[0] = IAgentHub.ActionData({agentId: agentId, markets: markets});

    count++;
    if (count < 1) IAgentHub(AGENT_HUB).execute(actions);
  }
}
