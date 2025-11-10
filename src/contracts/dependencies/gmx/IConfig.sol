// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConfig {
  function setUint(bytes32 baseKey, bytes memory data, uint256 value) external;
}
