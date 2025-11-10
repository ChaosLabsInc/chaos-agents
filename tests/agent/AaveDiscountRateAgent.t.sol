// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {PendlePriceCapAdapter, IPendlePriceCapAdapter} from 'aave-capo/contracts/PendlePriceCapAdapter.sol';

import {AaveDiscountRateAgent} from '../../src/contracts/agent/aave/AaveDiscountRateAgent.sol';
import {RangeValidationModule, IRangeValidationModule} from '../../src/contracts/modules/RangeValidationModule.sol';
import {IAgentConfigurator, BaseAgentTest} from './BaseAgentTest.sol';

contract AaveDiscountRateAgent_Test is
  BaseAgentTest('PendleDiscountRateUpdate'),
  TestnetProcedures
{
  RangeValidationModule public _rangeValidationModule;

  address internal _pendlePTAsset;
  PendlePriceCapAdapter internal _pendleAdapter;

  function setUp() public override {
    initTestEnvironment();

    // assume the already listed usdx asset as PT Tokens, we will mock the custom PT token behavior on them
    _pendlePTAsset = address(usdx);

    super.setUp();
  }

  function _customiseAgentConfig(
    IAgentConfigurator.AgentRegistrationInput memory config
  ) internal view override returns (IAgentConfigurator.AgentRegistrationInput memory) {
    address[] memory markets = new address[](1);
    markets[0] = _pendlePTAsset;

    config.allowedMarkets = markets;
    config.isMarketsFromAgentEnabled = false;
    return config;
  }

  function _deployAgent() internal override returns (address) {
    _rangeValidationModule = new RangeValidationModule();

    return
      address(
        new AaveDiscountRateAgent(
          address(_agentHub),
          address(_rangeValidationModule),
          address(contracts.poolProxy),
          address(contracts.aaveOracle)
        )
      );
  }

  function _postSetup() internal override {
    IRangeValidationModule.RangeConfig memory rangeConfig = IRangeValidationModule.RangeConfig({
      maxIncrease: 0.01e18, // 1% increase
      maxDecrease: 0.01e18, // 1% decrease
      isIncreaseRelative: false,
      isDecreaseRelative: false
    });
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'PendleDiscountRateUpdate',
      rangeConfig
    );

    // mocks so that the currently listed assets behave as Pendle PT assets
    vm.mockCall(
      _pendlePTAsset,
      abi.encodeWithSignature('expiry()'),
      abi.encode(block.timestamp + 120 days)
    );

    _pendleAdapter = new PendlePriceCapAdapter(
      IPendlePriceCapAdapter.PendlePriceCapAdapterParams({
        assetToUsdAggregator: contracts.aaveOracle.getSourceOfAsset(_pendlePTAsset),
        pendlePrincipalToken: _pendlePTAsset,
        maxDiscountRatePerYear: 1e18, // 100%
        discountRatePerYear: 0.2e18, // 20%
        aclManager: report.aclManager,
        description: 'PT_1 Adapter'
      })
    );

    address[] memory pendlePTOracles = new address[](1);
    pendlePTOracles[0] = address(_pendleAdapter);
    address[] memory pendlePTAssets = new address[](1);
    pendlePTAssets[0] = _pendlePTAsset;

    vm.startPrank(poolAdmin);
    // updates the listed assets oracle to pendle PT so they behave as pendle assets
    contracts.aaveOracle.setAssetSources(pendlePTAssets, pendlePTOracles);
    contracts.aclManager.addRiskAdmin(address(_agent));
    vm.stopPrank();
  }

  function test_validate_discountRateNotInRange(uint56 discountRateChange) public {
    vm.assume(discountRateChange > 0.01e18);
    uint256 currentDiscountRate = _pendleAdapter.discountRatePerYear();

    // more than 1% absolute increase
    _addUpdateToRiskOracle(currentDiscountRate + discountRateChange);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    vm.assume(discountRateChange <= currentDiscountRate);

    // more than 1% absolute decrease
    _addUpdateToRiskOracle(currentDiscountRate - discountRateChange);
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_discountRateInRange(uint56 discountRateChange) public {
    vm.assume(discountRateChange != 0 && discountRateChange <= 0.01e18);
    uint256 currentDiscountRate = _pendleAdapter.discountRatePerYear();

    // less than 1% absolute increase
    _addUpdateToRiskOracle(currentDiscountRate + discountRateChange);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));

    // less than 1% absolute decrease
    _addUpdateToRiskOracle(currentDiscountRate - discountRateChange);
    assertTrue(_agent.validate(_agentId, '', _riskOracle.getUpdateById(2)));
  }

  function test_validate_invalidDiscountRateToZero() public {
    _addUpdateToRiskOracle(0); // updateId 1

    IRangeValidationModule.RangeConfig memory rangeConfig = IRangeValidationModule.RangeConfig({
      maxIncrease: 1e18,
      maxDecrease: 1e18,
      isIncreaseRelative: false,
      isDecreaseRelative: false
    });
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      'PendleDiscountRateUpdate',
      rangeConfig
    );

    // cannot set new discount rate to 0
    assertFalse(_agent.validate(_agentId, '', _riskOracle.getUpdateById(1)));
  }

  function test_injectionFromHub() public {
    uint256 currentDiscount = _pendleAdapter.discountRatePerYear();
    uint256 newDiscountRate = currentDiscount + 0.01e18; // 1% relative increase

    _addUpdateToRiskOracle(newDiscountRate);
    assertTrue(_checkAndPerformAutomation(_agentId));

    currentDiscount = _pendleAdapter.discountRatePerYear();
    assertEq(currentDiscount, newDiscountRate);
  }

  function _addUpdateToRiskOracle(uint256 discountRate) internal {
    vm.startPrank(_riskOracleOwner);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encodePacked(discountRate),
      _updateType,
      _pendlePTAsset,
      'additionalData'
    );
    vm.stopPrank();
  }
}
