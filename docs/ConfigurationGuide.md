## Agent Configuration and Deployment Guide

### Setup Agent Contract

The agent contract contains the logic for protocol specific validation and injection. To create your agent contract, please inherit from the `BaseAgent` contract. Based on your needs you would need to implement the following methods on your agent contract:

- `validate()`: This method will be called by the AgentHub to do custom validation / checks for your agent, the `validate()` method passes the following params from the hub which will be used for validation: `agentId`, `agentContext` and `update` struct from risk oracle. The `validate()` method will be called per update only after passes generic validation of the AgentHub. As a protocol you would need to return true, if the update from risk oracle passes your agent specific validation and false otherwise.

- `getMarkets()`: If your agent wants to use markets that are dynamic in nature, which is not easy to configure directly on the AgentHub, then this method should return the dynamic or custom markets addresses the agent wishes to use. This method will be consumed by the AgentHub contract only if `MarketsFromAgentEnabled` flag is true for the agent on the hub, if the flag is false this method will be unused. If you wish to not use custom dynamic markets but rather markets from the hub directly, you can return an empty array as this method would be unused.

- `_processUpdate()`: This method will be used to do custom injection of the update on your protocol. The method is internally called by the `inject()` method under the hood by the agent. The `_processUpdate()` method passes the following params from the hub which will be used for validation: `agentId`, `agentContext`, `update` struct from risk oracle. `agentContext` is misc bytes data which is stored on the hub, and can be used to get specific config data for injection for ex. the target address and so on. This method will be called individually by each risk oracle update to inject, so logic to push data into your protocol from the risk oracle update should be implemented here.

Once you have the agent contract setup, we recommend adding e2e tests along with the configuration you wish to use.

Based on your protocol, the agent contract would need to be given specific roles and permission to inject updates on your protocol.
For ex. on Aave, we give 'RISK_ADMIN' role from the `ACL_MANAGER` contract to the 'SupplyCapAgent' agent contract so it has permission to update supply caps on Aave. If you have an access control role based system, you would need to give the role to your agent contract and no roles should be given to the AgentHub contract.

If you don't have an role based system with only a single entity (ex. owner) having all the control, it is recommended to migrate to a system with access control like [AccessManager](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v5.3/contracts/access/manager/AccessManager.sol) of open-zeppelin and then give the specific roles to the agent contract.

### Agent Configuration Guide

When registering / configuring an agent on the AgentHub, these are the configuration params you need to be aware of:

- **AgentContract**: The agent contract has logic specific for your protocol for doing extra validation and how the updates will be injected on your protocol. The agent contract for an agent can be updated using the `setAgentAddress()` setter

- **RiskOracle**: The RiskOracle or ChaosRiskOracle from chaos-labs is used to fetch risk updates. Each agent on the AgentHub can have a different chaos risk oracle.

- **UpdateType**: Each agent on the AgentHub corresponds to only a single updateType, the updateType should be exactly the same as on the ChaosRiskOracle as it is used to query updates. To have multiple updateTypes you simply have to register multiple agents on the AgentHub.

- **Permissioned**: Should be configured as true if only permissioned / allowed senders can call the `execute()` for your agent to inject updates from the risk oracle. If Permissioned is set as false, anyone can call `execute()` for your agent to permissionlessly inject updates.
The flag to change the permissioned status for an agent can be set using the `setPermissioned()` method.

- **PermissionedSenders**: Only valid if Permissioned is set to true. Corresponds to the allowed addresses that can call `execute()` for your agent. To add more permissioned senders for the agent `addPermissionedSender()` can be used on the AgentHub and `removePermissionedSender()` be used to remove a permissioned sender.

- **AgentEnabled**: Boolean to enable / disable an agent on the `AgentHub`. If an agent is disabled no update can be injected, so it should be set to true. `setAgentEnabled()` setter can be used on the AgentHub to change the enable flag on the agent. When doing configurations, a good practice is to disable the agent, change the configurations and then enable the agent.

- **MarketsFromAgentEnabled**: If set to true for an agent, the AgentHub will fetch custom dynamic markets from the agent contract to validate and inject. When set to false, markets from the AgentHub via `allowedMarkets` will be used.
If you wish to not have dynamic markets for your agent then this flag can be set to false, and markets can be added on the hub directly via `allowedMarkets`. Please note, the markets from the agent contract will override the `allowedMarkets`, if this value is set to true and also if `restrictedMarkets` is configured on the AgentHub, those markets will be filtered out. MarketsFromAgentEnabled flag can be changed by the agent admin using the `setMarketsFromAgentEnabled()` setter on the AgentHub.

- **AllowedMarkets**: Corresponds to the allowed markets to query from the RiskOracle for validation and injection. If `MarketsFromAgentEnabled` is set to true, the `AllowedMarkets` from hub will be overridden and unused.
To add more markets to allowedMarkets, `addAllowedMarket()` setter should be used on the AgentHub.
To remove markets from allowedMarkets, `removeAllowedMarket()` setter should be used on the AgentHub.

- **RestrictedMarkets**: Corresponds to the restricted markets to filter out markets fetched from the agent contract. If `MarketsFromAgentEnabled` is set to false, the `RestrictedMarkets` will not be applied and will be unused.
To add a restrictedMarket, `addRestrictedMarket()` setter should be used on the AgentHub.
To remove a restrictedMarket, `removeRestrictedMarket()` setter should be used on the AgentHub.

- **MaxBatchSize**: Corresponds to the maximum number of updates that can be injected for all the agents in a single `execute()` transaction. The default is 0, which means the number of updates to be injected won’t be restricted at all.
MaxBatchSize is important to set for agents consuming high gas, so we don’t exceed the gasLimit of the automation infra or the block gas limit. Please note, this value is set globally for all the agents on the AgentHub and is only enforced as a soft measure on the `check()` method. `setMaxBatchSize()` setter can be called by the hub owner, to change the maxBatchSize for all the agents.

- **ExpirationPeriod**: It is the time in seconds since the update was added on the RiskOracle within which the update can be injected. For ex. you can configure the expirationPeriod to `2 days` which means from the timestamp the update was added on the RiskOracle it should be injected before 2 days, if not the update will be deemed as expired and cannot be injected.
The expiration period can be set using the `setExpirationPeriod()` setter on the AgentHub.

- **MinimumDelay**: It is the time in seconds which should pass after an update for a agent and market pair was injected. For ex. if an minimumDelay is configured to `1 day`, for an agent and market pair of an update, at least `1 day` should pass before the update for the market and agent can be injected again.
The minimumDelay for an agent can be set using the `setMinimumDelay()` setter on the AgentHub.

- **AgentContext**: Misc custom bytes encoded config set by the agentAdmin, it is to be used by the agent contract during validation and injection to get some extra config, for ex. the target contract where to inject the update and so on.
The AgentContext can be set for an agent using the `setAgentContext()` method on the AgentHub.

#### Configuration Examples

<details>
  <summary>Common agent configurations examples</summary>
  <br>

- **Multiple markets from AgentHub**: In the example below, there will be updates checked and injected for the following markets which are configured on the AgentHub: [weth, link, usdc, usdt]. As `isMarketsFromAgentEnabled` is set to false, markets configured as `allowedMarkets` will only be used and `restrictedMarkets` won't be applicable. If in future, a market needs to be added or removed, it can be done by `addAllowedMarket()` `removeAllowedMarket()` methods.
  ```
  AGENT_HUB.registerAgent(
    IAgentConfigurator.AgentRegistrationInput({
      admin: admin,
      riskOracle: riskOracle,
      isAgentEnabled: true,
      isAgentPermissioned: false,
      isMarketsFromAgentEnabled: false,
      agentAddress: agentAddress,
      expirationPeriod: 1 days,
      minimumDelay: 0,
      updateType: 'BorrowCapUpdate',
      agentContext: abi.encode(configEngine),
      allowedMarkets: [weth, link, usdc, usdt],
      restrictedMarkets: new address[](0),
      permissionedSenders: new address[](0)
    })
  )
  ```

- **Multiple dynamic markets from AgentContract with blacklist**: In the example below, there will be updates checked and injected for the markets returned by `getMarkets()` of the AgentContract. In the case of AaveBorrowCapAgent `getMarkets()` will return all the listed assets on the protocol. As `isMarketsFromAgentEnabled` is set to true, `allowedMarkets` will not be used and will be overridden if it is configured.
Also as susde is set as `restrictedMarkets` on the AgentHub, if `getMarkets()` from the AaveBorrowCapAgent contains susde it will be filtered out on the AgentHub, and there will be updates checked and injected for all assets listed on aave except susde as it is restricted.

  ```
  AGENT_HUB.registerAgent(
    IAgentConfigurator.AgentRegistrationInput({
      admin: admin,
      riskOracle: riskOracle,
      isAgentEnabled: true,
      isAgentPermissioned: false,
      isMarketsFromAgentEnabled: true,
      agentAddress: agentAddress,
      expirationPeriod: 1 days,
      minimumDelay: 0,
      updateType: 'BorrowCapUpdate',
      agentContext: abi.encode(configEngine),
      allowedMarkets: new address[](0),
      restrictedMarkets: [susde],
      permissionedSenders: new address[](0)
    })
  )
  ```

- **Multiple updateTypes**: If multiple updateTypes are to be used, one has to register multiple agents. Please note: if you wish, you can re-use the deployed agent contract across multiple agents.

- **Permissioned agent**: If the agent should be configured as permissioned, `isAgentPermissioned` is set to true and `permissionedSenders` contains allowed sender, so injection i.e `execute()` can only be called by the allowed configured sender address.

- **Agent with minimumDelay and expirationPeriod**: In the example below, we set `expirationPeriod` to 12 hours, which means the update after being added on the ChaosRiskOracle can only be injected in 12 hours from the time it was added on ChaosRiskOracle and post 12 hours the update is deemed as expired.
We also set the `minimumDelay` to 1 day, which means that for a market and updateType pair minimum 1 day needs to pass to inject another update for the market. The minimum delay could be changed later using the `setMinimumDelay()` setter.

  ```
  AGENT_HUB.registerAgent(
    IAgentConfigurator.AgentRegistrationInput({
      admin: admin,
      riskOracle: riskOracle,
      isAgentEnabled: true,
      isAgentPermissioned: false,
      isMarketsFromAgentEnabled: false,
      agentAddress: agentAddress,
      expirationPeriod: 12 hours,
      minimumDelay: 1 days,
      updateType: 'BorrowCapUpdate',
      agentContext: abi.encode(configEngine),
      allowedMarkets: [weth, link, usdc, usdt],
      restrictedMarkets: new address[](0),
      permissionedSenders: new address[](0),
    })
  )
  ```

- **Configure new ChaosRiskOracle on already registered agent**: For an agent which is already registered, changing the ChaosRiskOracle is not permitted on the AgentHub. If you wish to use a new ChaosRiskOracle contract for the AgentHub, it is recommended to register a new agent for it.

</details>

### Deployment Guide:

- **Deploy AgentHub**: AgentHub will be unique to each protocol. The first step is to deploy the AgentHub impl and it's proxy.
  The AgentHub impl can be re-used across protocols so proxy needs to be deployed. The AgentHub proxy can be deployed with
  [`TransparentUpgradeableProxy`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v5.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) of open-zeppelin.
  For convenience, it is recommended to use `TransparentProxyFactory` to deploy the AgentHub proxy. You can find a list of deployed `TransparentProxyFactory` [here](https://search.onaave.com/?q=TRANSPARENT_PROXY_FACTORY). If the `TransparentProxyFactory` is not already deployed or you want to use a fresh instance of `TransparentProxyFactory`, you can deploy it manually from [here](https://github.com/bgd-labs/solidity-utils/blob/main/src/contracts/transparent-proxy/TransparentProxyFactory.sol).
  Please note, only the AgentHub owner has the permissions to add new agents and the owner of the AgentHub is set during initialize.
  As a deployer if you wish to register agents before giving ownership to the protocol address, please initialize the owner with the your address and then after registering the agent transfer the ownership to the protocol.

- **Deploy Common Modules**: If you use common modules like `RangeValidationModule` it should be deployed if previously not for a network, it is recommended be re-used across protocols. Script for deploying the range validation module could be found on [RangeValidationModule.s.sol](scripts/RangeValidationModule.s.sol).

- **Prepare Agent Contract**: The next step is to prepare your agent contract using the [Agent Setup Guide](#Setup-Agent-Contract) and deploy the agent contract.

- **Prepare Agent Configuration**: The next step is to prepare which configuration works best for you, using the [Configuration Guide](#Agent-Configuration-Guide) above. For reference, you can find the examples of configurations on [Configuration Examples](#Configuration-Examples)

- **Register Agent**: On the AgentHub proxy you deployed for your protocol, call `registerAgent()` using your agentAddress and other configurations. A single agent corresponds to single `updateType` and multiple markets, if you wish to have multiple `updateType` you would need to configure multiple agents.

- **Configure Automation** The final step is to configure Automation Infra on the AgentHub proxy you deployed. Determine the automation infra you wish to use (for ex. Chainlink or Gelato) and deploy the automation specific wrapper which calls the AgentHub. Based on the Automation Infra, agentIds in the specific format should be passed on the checker method and the execution should be called on-chain with the data returned from the checker method. AgentHub should be compatible with checker based automation infra on Chainlink Automation and Gelato by default. If you wish to use event based triggers, for ex. on Chainlink Automation you can add a thin layer on top of the AgentHub for infra specific changes. You can find all the automation specific wrappers of AgentHub on this [directory](../src/contracts/automation/). Script for deploying the automation specific AgentHub wrappers could be found on [Automation.s.sol](../scripts/Automation.s.sol)

Example for the e2e deployment and setup of aave caps and rates agent could be found on [CapsAgent.s.sol](../scripts/aave/CapsAgent.s.sol) and [RatesAgent.s.sol](../scripts/aave/RatesAgent.s.sol) for reference.
