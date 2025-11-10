// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRiskOracle} from '../dependencies/IRiskOracle.sol';
import {IBaseAgent} from '../../interfaces/IBaseAgent.sol';

/**
 * @title BaseAgent
 * @author BGD Labs
 * @notice Abstract base contract to be inherited by the agents to do agent specific validation and injection
 */
abstract contract BaseAgent is IBaseAgent {
  /// @inheritdoc IBaseAgent
  address public immutable AGENT_HUB;

  /**
   * @param agentHub the address of the agentHub which will use the agent contract
   */
  constructor(address agentHub) {
    AGENT_HUB = agentHub;
  }

  modifier onlyAgentHub() {
    require(msg.sender == AGENT_HUB, OnlyAgentHub(msg.sender));
    _;
  }

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
  ) external virtual onlyAgentHub {
    _processUpdate(agentId, agentContext, update);
  }

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
  ) external view virtual returns (bool);

  /**
   * @notice method to get all the market addresses to be used by the agent hub.
   *         this is a virtual method that must be implemented by the child contract
   *         to define custom dynamic market addresses to be used for a specific agent.
   * @dev this method is used by the agent hub only when `isMarketsFromAgentEnabled` flag is set to true on hub.
   *      if flag is false, the markets from this agent contract will be ignored and markets from the hub will
   *      be used instead. please note, if the hub has configured restricted markets, those markets will be
   *      filtered out from the list of markets returned by this method.
   * @param agentId the id of the agent
   * @return the list of custom markets to be used by the hub for the agent
   */
  function getMarkets(uint256 agentId) external view virtual returns (address[] memory);

  /**
   * @notice processes injection of the risk parameter update for a specific agent
   *         this is an internal virtual method to be implemented and overridden by the child contract
   *         to process injection of the update to the target protocol
   * @param agentContext contains custom config bytes data for the agent
   * @param agentId the id of the agent for which to process injection
   * @param update risk parameter update to be injected
   */
  function _processUpdate(
    uint256 agentId,
    bytes calldata agentContext,
    IRiskOracle.RiskParameterUpdate calldata update
  ) internal virtual;
}
