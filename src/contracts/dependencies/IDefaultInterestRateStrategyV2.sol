// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';

interface IDefaultInterestRateStrategyV2 {
  /**
   * @notice Returns the full InterestRateDataRay object for the given reserve, in bps
   * @param reserve The reserve to get the data of
   * @return The InterestRateData object for the given reserve
   */
  function getInterestRateDataBps(
    address reserve
  ) external view returns (IEngine.InterestRateInputData memory);

  function getVariableRateSlope1(address reserve) external view returns (uint256);
}
