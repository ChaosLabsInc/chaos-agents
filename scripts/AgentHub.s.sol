// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EthereumScript, ArbitrumScript, OptimismScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {ITransparentProxyFactory as IProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {MiscOptimism} from 'aave-address-book/MiscOptimism.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';

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

// make deploy-ledger contract=scripts/AgentHub.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  function run() external broadcast {
    address agentHubProxy = DeployAgentHub._deployAgentHub(
      MiscEthereum.TRANSPARENT_PROXY_FACTORY,
      GovernanceV3Ethereum.EXECUTOR_LVL_1, // proxy-owner
      GovernanceV3Ethereum.EXECUTOR_LVL_1 // agentHub super admin
    );

    DeployAutomationWrapper._deployChainlinkHub(agentHubProxy);
  }
}

// make deploy-ledger contract=scripts/AgentHub.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  function run() external broadcast {
    address agentHubProxy = DeployAgentHub._deployAgentHub(
      MiscArbitrum.TRANSPARENT_PROXY_FACTORY,
      GovernanceV3Arbitrum.EXECUTOR_LVL_1, // proxy-owner
      GovernanceV3Arbitrum.EXECUTOR_LVL_1 // agentHub super admin
    );

    DeployAutomationWrapper._deployChainlinkHub(agentHubProxy);
  }
}

// make deploy-ledger contract=scripts/AgentHub.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  function run() external broadcast {
    address agentHubProxy = DeployAgentHub._deployAgentHub(
      MiscOptimism.TRANSPARENT_PROXY_FACTORY,
      GovernanceV3Optimism.EXECUTOR_LVL_1, // proxy-owner
      GovernanceV3Optimism.EXECUTOR_LVL_1 // agentHub super admin
    );

    DeployAutomationWrapper._deployChainlinkHub(agentHubProxy);
  }
}

// make deploy-ledger contract=scripts/AgentHub.s.sol:TransferPermissionEthereum chain=mainnet
contract TransferPermissionEthereum is EthereumScript {
  function run() external broadcast {
    address agentHub = address(0); // TODO: add when revoking
    OwnableUpgradeable(agentHub).transferOwnership(GovernanceV3Ethereum.EXECUTOR_LVL_1);
  }
}

// make deploy-ledger contract=scripts/AgentHub.s.sol:TransferPermissionArbitrum chain=arbitrum
contract TransferPermissionArbitrum is ArbitrumScript {
  function run() external broadcast {
    address agentHub = address(0); // TODO: add when revoking
    OwnableUpgradeable(agentHub).transferOwnership(GovernanceV3Arbitrum.EXECUTOR_LVL_1);
  }
}

// make deploy-ledger contract=scripts/AgentHub.s.sol:TransferPermissionOptimism chain=optimism
contract TransferPermissionOptimism is OptimismScript {
  function run() external broadcast {
    address agentHub = address(0); // TODO: add when revoking
    OwnableUpgradeable(agentHub).transferOwnership(GovernanceV3Optimism.EXECUTOR_LVL_1);
  }
}
