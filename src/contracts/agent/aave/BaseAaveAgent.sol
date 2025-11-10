// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPool} from 'aave-address-book/AaveV3.sol';

import {IRangeValidationModule} from '../../../interfaces/IRangeValidationModule.sol';
import {BaseAgent} from '../BaseAgent.sol';

abstract contract BaseAaveAgent is BaseAgent {
  IPool public immutable POOL;
  IRangeValidationModule public immutable RANGE_VALIDATION_MODULE;

  /**
   * @notice The new bytes value from the update is invalid
   */
  error InvalidBytesValue();

  /**
   * @param agentHub the address of the agentHub which will use this agent contract
   * @param rangeValidationModule the address of range validation module used to store range config and to validate ranges
   * @param pool the address of aave pool
   */
  constructor(address agentHub, address rangeValidationModule, address pool) BaseAgent(agentHub) {
    RANGE_VALIDATION_MODULE = IRangeValidationModule(rangeValidationModule);
    POOL = IPool(pool);
  }

  /**
   * @inheritdoc BaseAgent
   * @dev returns all the reserves listed on the aave pool.
   */
  function getMarkets(uint256) external view virtual override returns (address[] memory) {
    return POOL.getReservesList();
  }

  /**
   * @notice method to decode the bytes data from risk oracle to uint256
   * @param valueInBytes the bytes data received from risk oracle
   * @return the decoded bytes value from risk oracle in uint256
   */
  function _decodeToUint(bytes calldata valueInBytes) internal pure returns (uint256) {
    require(valueInBytes.length <= 32, InvalidBytesValue());
    return
      abi.decode(abi.encodePacked(new bytes(32 - valueInBytes.length), valueInBytes), (uint256));
  }
}
