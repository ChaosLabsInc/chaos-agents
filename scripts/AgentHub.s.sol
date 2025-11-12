// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITransparentProxyFactory as IProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {ChainlinkAgentHub} from '../src/contracts/automation/ChainlinkAgentHub.sol';
import {GelatoAgentHub} from '../src/contracts/automation/GelatoAgentHub.sol';
import {AgentHub} from '../src/contracts/AgentHub.sol';

library DeployAgentHub {
  bytes32 public constant SALT = 'v1';

  function _deployAgentHub(
    address proxyFactory,
    address proxyOwner,
    address hubOwner
  ) internal returns (address) {
    address agentHubImpl = Create2Utils.create2Deploy(SALT, type(AgentHub).creationCode);
    return _deployProxy(proxyFactory, proxyOwner, hubOwner, agentHubImpl);
  }

  function _deployProxy(
    address proxyFactory,
    address proxyOwner,
    address hubOwner,
    address agentHubImpl
  ) private returns (address) {
    return
      IProxyFactory(proxyFactory).createDeterministic(
        agentHubImpl,
        proxyOwner,
        abi.encodeWithSelector(AgentHub.initialize.selector, hubOwner),
        SALT
      );
  }
}

library DeployAutomationWrapper {
  bytes32 public constant SALT = 'v1';

  function _deployChainlinkHub(address agentHubProxy) internal returns (address) {
    return
      Create2Utils.create2Deploy(
        SALT,
        type(ChainlinkAgentHub).creationCode,
        abi.encode(agentHubProxy)
      );
  }

  function _deployGelatoHub(address agentHubProxy) internal returns (address) {
    return
      Create2Utils.create2Deploy(
        SALT,
        type(GelatoAgentHub).creationCode,
        abi.encode(agentHubProxy)
      );
  }
}
