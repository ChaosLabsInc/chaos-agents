// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveDiscountRateAgent} from '../../src/contracts/agent/aave/AaveDiscountRateAgent.sol';
import {IRangeValidationModule} from '../../src/interfaces/IRangeValidationModule.sol';
import {IAgentHub, IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';

library SetupDiscountRateAgent {
  function _deployAndSetupDiscountRateAgent(
    address agentHub,
    address rangeValidationModule,
    address owner,
    address riskOracle,
    address aaveOracle,
    address configEngine,
    address pool,
    address[] memory markets
  ) internal {
    address discountRateAgent = address(
      new AaveDiscountRateAgent(agentHub, rangeValidationModule, pool, aaveOracle)
    );

    // register agent on the hub
    uint256 discountRateAgentId = IAgentHub(agentHub).registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        admin: msg.sender,
        riskOracle: riskOracle,
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        agentAddress: discountRateAgent,
        expirationPeriod: 12 hours,
        minimumDelay: 1 days,
        updateType: 'PendleDiscountRateUpdate_Core',
        agentContext: abi.encode(configEngine),
        allowedMarkets: markets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );

    // configure range for the agent
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      discountRateAgentId,
      'PendleDiscountRateUpdate_Core',
      _getDefaultRangeValidationModuleConfig()
    );

    IAgentHub(agentHub).setAgentAdmin(discountRateAgentId, owner);
  }

  function _getDefaultRangeValidationModuleConfig()
    internal
    pure
    returns (IRangeValidationModule.RangeConfig memory config)
  {
    return
      IRangeValidationModule.RangeConfig({
        maxIncrease: 0.01e18, // 1% increase
        maxDecrease: 0.01e18, // 1% decrease
        isIncreaseRelative: false,
        isDecreaseRelative: false
      });
  }
}
