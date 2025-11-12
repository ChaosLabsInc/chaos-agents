// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

import {AgentHub} from '../../src/contracts/AgentHub.sol';
import {IAgentConfigurator} from '../../src/interfaces/IAgentConfigurator.sol';
import {RangeValidationModule, IRangeValidationModule} from '../../src/contracts/modules/RangeValidationModule.sol';

contract RangeValidationModule_Test is Test {
  using SafeCast for uint256;

  AgentHub _agentHub;
  uint256 _agentId;
  RangeValidationModule _rangeValidationModule;
  address public constant AGENT_ADMIN = address(25);
  address public constant HUB_OWNER = address(77);
  uint256 public constant BPS_MAX = 100_00;

  string _updateType = 'SlopeOneUpdate';

  function setUp() public {
    _agentHub = AgentHub(
      address(
        new TransparentUpgradeableProxy(
          address(new AgentHub()),
          address(this),
          abi.encodeWithSelector(AgentHub.initialize.selector, HUB_OWNER)
        )
      )
    );

    _rangeValidationModule = new RangeValidationModule();

    vm.prank(HUB_OWNER);
    _agentId = _agentHub.registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        agentAddress: address(0),
        riskOracle: address(0),
        admin: AGENT_ADMIN,
        agentContext: abi.encode(),
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        expirationPeriod: 1 days,
        minimumDelay: 0,
        updateType: _updateType,
        allowedMarkets: new address[](1),
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );
  }

  function test_validate_withoutMarket() public {
    uint256 maxIncrease = 500;
    uint256 from = 100;
    uint256 to = 600;

    _setDefaultRangeConfig(_updateType, maxIncrease, 0, false, false);
    IRangeValidationModule.RangeValidationInput memory rangeValidationInput;
    rangeValidationInput.from = from;
    rangeValidationInput.to = to;
    rangeValidationInput.updateType = _updateType;
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      address(0),
      rangeValidationInput
    );
    assertEq(output, true);
  }

  function test_validate_withMarket() public {
    address market = address(4);
    uint256 maxIncrease = 500;
    uint256 from = 100;
    uint256 to = 600;

    _setRangeConfigByMarket(market, _updateType, maxIncrease, 0, false, false);
    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: _updateType});

    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertEq(output, true);
  }

  function test_validate_absoluteIncrease_inRange(
    address market,
    string memory updateType,
    uint120 maxIncrease,
    uint256 from,
    uint256 to
  ) public {
    vm.assume(from <= to);
    uint256 diff = to - from;

    vm.assume(diff <= maxIncrease);
    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, maxIncrease, 0, false, false);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});

    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertEq(output, true);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, maxIncrease, 0, false, false);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertEq(output, true);
  }

  function test_validate_absoluteDecrease_inRange(
    address market,
    string memory updateType,
    uint120 maxDecrease,
    uint256 from,
    uint256 to
  ) public {
    vm.assume(from >= to);
    uint256 diff = from - to;

    vm.assume(diff <= maxDecrease);
    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, 0, maxDecrease, false, false);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});

    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertEq(output, true);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, 0, maxDecrease, false, false);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertEq(output, true);
  }

  function test_validate_absoluteIncrease_notInRange(
    address market,
    string memory updateType,
    uint120 maxIncrease,
    uint256 from,
    uint256 to
  ) public {
    vm.assume(from <= to);
    uint256 diff = to - from;

    vm.assume(diff > maxIncrease);
    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, maxIncrease, 0, false, false);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});

    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, maxIncrease, 0, false, false);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);
  }

  function test_validate_absoluteDecrease_notInRange(
    address market,
    string memory updateType,
    uint120 maxDecrease,
    uint256 from,
    uint256 to
  ) public {
    vm.assume(from >= to);
    uint256 diff = from - to;

    vm.assume(diff > maxDecrease);
    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, 0, maxDecrease, false, false);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});

    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, 0, maxDecrease, false, false);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);
  }

  function test_validate_relativeIncrease_inRange(
    address market,
    string memory updateType,
    uint248 maxIncreasePercent,
    uint128 from,
    uint128 to
  ) public {
    vm.assume(from <= to);
    uint256 diff = to - from;

    maxIncreasePercent = bound(uint256(maxIncreasePercent), 0, 100_00).toUint248();
    uint256 maxDiff = (maxIncreasePercent * from) / BPS_MAX;

    vm.assume(diff <= maxDiff);
    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, maxIncreasePercent, 0, true, true);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});
    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertTrue(output);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, maxIncreasePercent, 0, true, true);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertTrue(output);
  }

  function test_validate_relativeDecrease_inRange(
    address market,
    string memory updateType,
    uint248 maxDecreasePercent,
    uint128 from,
    uint128 to
  ) public {
    vm.assume(from >= to);
    uint256 diff = from - to;

    maxDecreasePercent = bound(uint256(maxDecreasePercent), 0, 100_00).toUint248();
    uint256 maxDiff = (maxDecreasePercent * from) / BPS_MAX;

    vm.assume(diff <= maxDiff);
    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, 0, maxDecreasePercent, true, true);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});
    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertTrue(output);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, 0, maxDecreasePercent, true, true);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertTrue(output);
  }

  function test_validate_relativeIncrease_notInRange(
    address market,
    string memory updateType,
    uint248 maxIncreasePercent,
    uint128 from,
    uint128 to
  ) public {
    vm.assume(from <= to);
    uint256 diff = to - from;
    maxIncreasePercent = bound(uint256(maxIncreasePercent), 0, 100_00).toUint248();
    uint256 maxDiff = (maxIncreasePercent * from) / BPS_MAX;

    vm.assume(diff > maxDiff);

    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, maxIncreasePercent, 0, true, true);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});
    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, maxIncreasePercent, 0, true, true);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);
  }

  function test_validate_relativeDecrease_notInRange(
    address market,
    string memory updateType,
    uint248 maxDecreasePercent,
    uint128 from,
    uint128 to
  ) public {
    vm.assume(from >= to);
    uint256 diff = from - to;
    maxDecreasePercent = bound(uint256(maxDecreasePercent), 0, 100_00).toUint248();
    uint256 maxDiff = (maxDecreasePercent * from) / BPS_MAX;

    vm.assume(diff > maxDiff);

    uint256 snapshotId = vm.snapshotState();
    _setDefaultRangeConfig(updateType, 0, maxDecreasePercent, true, true);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});
    rangeValidationInput.from = from;
    rangeValidationInput.to = to;

    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);

    vm.revertToState(snapshotId);
    _setRangeConfigByMarket(market, updateType, 0, maxDecreasePercent, true, true);
    // validate from market specific config set
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);
  }

  function test_validate_configDoesNotExists_sameFromAndToValue(
    address market,
    string memory updateType,
    uint256 value
  ) public view {
    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: value, to: value, updateType: updateType});
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertTrue(output);
  }

  function test_validate_configDoesNotExists_differentFromAndToValue(
    address market,
    string memory updateType,
    uint256 from,
    uint256 to
  ) public view {
    vm.assume(from != to);
    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: from, to: to, updateType: updateType});
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);
  }

  function test_validate_afterUnsettingMarketConfig(
    address market,
    string memory updateType
  ) public {
    uint256 maxIncrease = 1000;
    _setRangeConfigByMarket(market, updateType, maxIncrease, 0, false, false);

    IRangeValidationModule.RangeValidationInput memory rangeValidationInput = IRangeValidationModule
      .RangeValidationInput({from: 500, to: 1000, updateType: updateType});

    // validate from default fallback config set
    bool output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertTrue(output);

    _setRangeConfigByMarket(market, updateType, 0, 0, true, true); // reset market config
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);

    _setRangeConfigByMarket(market, updateType, 0, 0, false, false); // reset market config
    output = _rangeValidationModule.validate(
      address(_agentHub),
      _agentId,
      market,
      rangeValidationInput
    );
    assertFalse(output);
  }

  function test_revert_onlyHubOwnerOrAgentAdmin_can_setRangeConfig(
    address invalidCaller,
    address market,
    string memory updateType,
    IRangeValidationModule.RangeConfig memory config
  ) public {
    vm.assume(invalidCaller != AGENT_ADMIN && invalidCaller != HUB_OWNER);
    vm.startPrank(invalidCaller);

    vm.expectRevert(
      abi.encodeWithSelector(
        IRangeValidationModule.OnlyHubOwnerOrAgentAdmin.selector,
        invalidCaller
      )
    );
    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, updateType, config);
    vm.expectRevert(
      abi.encodeWithSelector(
        IRangeValidationModule.OnlyHubOwnerOrAgentAdmin.selector,
        invalidCaller
      )
    );
    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      market,
      updateType,
      config
    );
    vm.stopPrank();
  }

  function test_revert_invalidRelativeMaxDecrease_setRangeConfig(
    address market,
    string memory updateType,
    IRangeValidationModule.RangeConfig memory config
  ) public {
    vm.assume(config.isDecreaseRelative == true);
    vm.assume(config.maxDecrease > 100_00);
    vm.startPrank(AGENT_ADMIN);

    vm.expectRevert(
      abi.encodeWithSelector(
        IRangeValidationModule.InvalidMaxRelativeDecrease.selector,
        config.maxDecrease
      )
    );
    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, updateType, config);
    vm.expectRevert(
      abi.encodeWithSelector(
        IRangeValidationModule.InvalidMaxRelativeDecrease.selector,
        config.maxDecrease
      )
    );
    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      market,
      updateType,
      config
    );
    vm.stopPrank();
  }

  function test_setRangeConfig(address market, string memory updateType) public {
    IRangeValidationModule.RangeConfig memory config = IRangeValidationModule.RangeConfig({
      maxIncrease: 10_00,
      maxDecrease: 5_00,
      isIncreaseRelative: true,
      isDecreaseRelative: true
    });

    vm.startPrank(AGENT_ADMIN);
    vm.expectEmit(true, true, true, true, address(_rangeValidationModule));
    emit IRangeValidationModule.DefaultRangeConfigSet(
      address(_agentHub),
      _agentId,
      updateType,
      config
    );
    _rangeValidationModule.setDefaultRangeConfig(address(_agentHub), _agentId, updateType, config);

    vm.expectEmit(true, true, true, true, address(_rangeValidationModule));
    emit IRangeValidationModule.MarketRangeConfigSet(
      address(_agentHub),
      _agentId,
      market,
      updateType,
      config
    );
    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      market,
      updateType,
      config
    );
    vm.stopPrank();

    RangeValidationModule.RangeConfig memory defaultConfig = _rangeValidationModule
      .getDefaultRangeConfig(address(_agentHub), _agentId, updateType);
    assertEq(config.maxIncrease, defaultConfig.maxIncrease);
    assertEq(config.maxDecrease, defaultConfig.maxDecrease);
    assertEq(config.isIncreaseRelative, defaultConfig.isIncreaseRelative);
    assertEq(config.isDecreaseRelative, defaultConfig.isDecreaseRelative);

    RangeValidationModule.RangeConfig memory marketConfig = _rangeValidationModule
      .getRangeConfigByMarket(address(_agentHub), _agentId, market, updateType);
    assertEq(config.maxIncrease, marketConfig.maxIncrease);
    assertEq(config.maxDecrease, marketConfig.maxDecrease);
    assertEq(config.isIncreaseRelative, marketConfig.isIncreaseRelative);
    assertEq(config.isDecreaseRelative, marketConfig.isDecreaseRelative);
  }

  function _setDefaultRangeConfig(
    string memory updateType,
    uint256 maxIncrease,
    uint256 maxDecrease,
    bool isIncreaseRelative,
    bool isDecreaseRelative
  ) internal {
    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setDefaultRangeConfig(
      address(_agentHub),
      _agentId,
      updateType,
      IRangeValidationModule.RangeConfig({
        maxIncrease: maxIncrease.toUint120(),
        maxDecrease: maxDecrease.toUint120(),
        isIncreaseRelative: isIncreaseRelative,
        isDecreaseRelative: isDecreaseRelative
      })
    );
  }

  function _setRangeConfigByMarket(
    address market,
    string memory updateType,
    uint256 maxIncrease,
    uint256 maxDecrease,
    bool isIncreaseRelative,
    bool isDecreaseRelative
  ) internal {
    vm.prank(AGENT_ADMIN);
    _rangeValidationModule.setRangeConfigByMarket(
      address(_agentHub),
      _agentId,
      market,
      updateType,
      IRangeValidationModule.RangeConfig({
        maxIncrease: maxIncrease.toUint120(),
        maxDecrease: maxDecrease.toUint120(),
        isIncreaseRelative: isIncreaseRelative,
        isDecreaseRelative: isDecreaseRelative
      })
    );
  }
}
