// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoleStore {
  function grantRole(address account, bytes32 roleKey) external;
}
