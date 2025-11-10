// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAgentHub} from '../contracts/AgentHub.sol';

/**
 * @title IChainlinkAutomationHub
 * @author BGD Labs
 */
interface IChainlinkAutomationHub {
  /**
   * @notice method that is simulated off-chain by the chainlink keepers to see if
   * `performUpkeep()` needs to be called on-chain.
   * @param checkData specified in the chainlink upkeep registration and contains the abi
   *        encoded list of agentIds for which update needs to be checked.
   * @return upkeepNeeded boolean to indicate whether the keeper should call `performUpkeep()` or not.
   * @return performData bytes that the keeper should call performUpkeep with, contains the abi encoded
   *         actions to be executed when upkeepNeeded returns true
   */
  function checkUpkeep(
    bytes calldata checkData
  ) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed on-chain by chainlink keepers.
   * The data returned by the checkUpkeep will be passed into this method to actually be executed.
   * @param performData is the abi encoded actions data which was passed back from the checkData
   * simulation.
   */
  function performUpkeep(bytes calldata performData) external;

  /**
   * @notice method to get the agent hub contract on which automation would run
   * @return agent hub contract address
   */
  function AGENT_HUB() external view returns (IAgentHub);
}
