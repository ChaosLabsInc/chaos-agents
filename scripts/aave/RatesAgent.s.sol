// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveRatesAgent} from '../../src/contracts/agent/aave/AaveRatesAgent.sol';
import {IRangeValidationModule} from '../../src/interfaces/IRangeValidationModule.sol';
import {IAgentHub, IAgentConfigurator} from '../../src/interfaces/IAgentHub.sol';

library SetupRatesAgent {
  function _deployAndSetupRatesAgent(
    address agentHub,
    address rangeValidationModule,
    address owner,
    address riskOracle,
    address configEngine,
    address pool,
    address[] memory markets
  ) internal {
    address agent = address(new AaveRatesAgent(agentHub, rangeValidationModule, pool));

    // register agent on the hub
    uint256 agentId = IAgentHub(agentHub).registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        admin: msg.sender,
        riskOracle: riskOracle,
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        agentAddress: agent,
        expirationPeriod: 12 hours,
        minimumDelay: 1 days,
        updateType: 'RateStrategyUpdate',
        agentContext: abi.encode(configEngine),
        allowedMarkets: markets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );

    // configure range for the agent
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      agentId,
      'OptimalUsageRatio',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 3_00,
        maxDecrease: 3_00,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      agentId,
      'BaseVariableBorrowRate',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 50,
        maxDecrease: 50,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      agentId,
      'VariableRateSlope1',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 1_00,
        maxDecrease: 1_00,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
    IRangeValidationModule(rangeValidationModule).setDefaultRangeConfig(
      agentHub,
      agentId,
      'VariableRateSlope2',
      IRangeValidationModule.RangeConfig({
        maxIncrease: 5_00,
        maxDecrease: 5_00,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );

    IAgentHub(agentHub).setAgentAdmin(agentId, owner);
  }
}
