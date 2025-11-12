// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IGelatoAutomationHub, IAgentHub} from '../../interfaces/IGelatoAutomationHub.sol';

/**
 * @title GelatoAgentHub
 * @author BGD Labs
 * @notice Gelato automation compatible version of the agent hub
 */
contract GelatoAgentHub is IGelatoAutomationHub {
  /// @inheritdoc IGelatoAutomationHub
  IAgentHub public immutable AGENT_HUB;

  /**
   * @param agentHub the address of the agentHub on which to perform automation
   */
  constructor(address agentHub) {
    AGENT_HUB = IAgentHub(agentHub);
  }

  /// @inheritdoc IGelatoAutomationHub
  function check(uint256[] memory agentIds) public view returns (bool, bytes memory) {
    (bool automationNeeded, IAgentHub.ActionData[] memory actions) = AGENT_HUB.check(agentIds);
    return (automationNeeded, abi.encodeCall(this.execute, actions));
  }

  /// @inheritdoc IGelatoAutomationHub
  function execute(IAgentHub.ActionData[] memory actions) external {
    AGENT_HUB.execute(actions);
  }
}
