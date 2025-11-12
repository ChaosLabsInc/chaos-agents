// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRiskOracle} from '../contracts/dependencies/IRiskOracle.sol';

/**
 * @title IBaseAgent
 * @author BGD labs
 */
interface IBaseAgent {
  /**
   * @notice The caller account is not the AgentHub contract
   */
  error OnlyAgentHub(address account);

  /**
   * @notice method to get the address of the agent hub contract.
   * @return agent hub contract address.
   */
  function AGENT_HUB() external view returns (address);

  /**
   * @notice method to get all the market addresses to be used by the agent hub.
   *         this is a virtual method that must be implemented by the child contract
   *         to define custom dynamic market addresses to be used for a specific agent.
   * @dev this method is used by the agent hub only when `isMarketsFromAgentEnabled` flag is set to true on hub.
   *      if flag is false, the markets from this agent contract will be ignored and markets from the hub will
   *      be used instead. please note, if the hub has configured restricted markets, those markets will be
   *      filtered out from the list of markets returned by this method.
   * @param agentId the id of the agent
   * @return the list of custom markets to be used by the agent hub for the agent
   */
  function getMarkets(uint256 agentId) external view returns (address[] memory);

  /**
   * @notice method to perform agent-specific validation for a risk parameter update.
   *         this is a virtual method that must be implemented by the child contract
   *         to define custom validation logic for a specific agent
   * @param agentId the id of the agent being validated
   * @param agentContext contains custom config bytes data for the agent
   * @param update risk parameter update to be validated
   * @return indicates whether the proposed update is valid for the specified agent
   *         - true if the update meets the agent-specific validation criteria
   *         - false if the update does not pass validation
   */
  function validate(
    uint256 agentId,
    bytes calldata agentContext,
    IRiskOracle.RiskParameterUpdate calldata update
  ) external view returns (bool);

  /**
   * @notice method called by the agentHub to inject updates from risk oracle into the protocol
   * @param agentId the id of the agent for which to do injection
   * @param agentContext contains custom config bytes data for the agent
   * @param update risk parameter update to be injected
   */
  function inject(
    uint256 agentId,
    bytes calldata agentContext,
    IRiskOracle.RiskParameterUpdate calldata update
  ) external;
}
