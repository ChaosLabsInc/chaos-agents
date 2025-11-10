// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EventUtils} from './utils/EventUtils.sol';

interface IEventEmitter {
  // @dev emit a general event log
  // @param eventName the name of the event
  // @param eventData the event data
  function emitEventLog(string memory eventName, EventUtils.EventLogData memory eventData) external;
}
