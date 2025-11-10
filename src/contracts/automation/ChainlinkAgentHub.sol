// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IChainlinkAutomationHub, IAgentHub} from '../../interfaces/IChainlinkAutomationHub.sol';

/**
 * @title ChainlinkAgentHub
 * @author BGD Labs
 * @notice Chainlink automation compatible version of the agent hub
 */
contract ChainlinkAgentHub is IChainlinkAutomationHub {
  /// @inheritdoc IChainlinkAutomationHub
  IAgentHub public immutable AGENT_HUB;

  /**
   * @param agentHub the address of the agentHub on which to perform automation
   */
  constructor(address agentHub) {
    AGENT_HUB = IAgentHub(agentHub);
  }

  /// @inheritdoc IChainlinkAutomationHub
  function checkUpkeep(bytes memory checkData) external view returns (bool, bytes memory) {
    (bool upkeepNeeded, IAgentHub.ActionData[] memory actions) = AGENT_HUB.check(
      abi.decode(checkData, (uint256[]))
    );
    return (upkeepNeeded, abi.encode(actions));
  }

  /// @inheritdoc IChainlinkAutomationHub
  function performUpkeep(bytes memory performData) external {
    IAgentHub.ActionData[] memory actions = abi.decode(performData, (IAgentHub.ActionData[]));
    AGENT_HUB.execute(actions);
  }
}
