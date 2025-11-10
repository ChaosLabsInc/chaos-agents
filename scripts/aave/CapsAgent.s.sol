// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveCapsAgent} from '../../src/contracts/agent/aave/AaveCapsAgent.sol';
import {IRangeValidationModule} from '../../src/interfaces/IRangeValidationModule.sol';
import {IAgentHub, IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';

library SetupCapsAgent {
  function _deployAndSetupCapsAgent(
    address agentHub,
    address rangeValidationModule,
    address owner,
    address riskOracle,
    address configEngine,
    address pool,
    address[] memory markets
  ) internal {
    address capAgent = address(new AaveCapsAgent(agentHub, rangeValidationModule, pool));

    // register agent on the hub
    uint256 supplyCapAgentId = IAgentHub(agentHub).registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        admin: msg.sender,
        riskOracle: riskOracle,
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        agentAddress: capAgent,
        expirationPeriod: 12 hours,
        minimumDelay: 1 days,
        updateType: 'SupplyCapUpdate',
        agentContext: abi.encode(configEngine),
        allowedMarkets: markets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );
    uint256 borrowCapAgentId = IAgentHub(agentHub).registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        admin: msg.sender,
        riskOracle: riskOracle,
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        agentAddress: capAgent,
        expirationPeriod: 12 hours,
        minimumDelay: 1 days,
        updateType: 'BorrowCapUpdate',
        agentContext: abi.encode(configEngine),
        allowedMarkets: markets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );

    // configure range for the agent
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      supplyCapAgentId,
      'SupplyCapUpdate',
      _getDefaultRangeValidationModuleConfig()
    );
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      borrowCapAgentId,
      'BorrowCapUpdate',
      _getDefaultRangeValidationModuleConfig()
    );

    IAgentHub(agentHub).setAgentAdmin(supplyCapAgentId, owner);
    IAgentHub(agentHub).setAgentAdmin(borrowCapAgentId, owner);
  }

  function _getDefaultRangeValidationModuleConfig()
    internal
    pure
    returns (IRangeValidationModule.RangeConfig memory config)
  {
    return
      IRangeValidationModule.RangeConfig({
        maxIncrease: 30_00,
        maxDecrease: 30_00,
        isIncreaseRelative: true,
        isDecreaseRelative: true
      });
  }
}
