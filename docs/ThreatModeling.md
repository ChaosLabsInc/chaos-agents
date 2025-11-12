# Threat Modeling

### Trust Boundaries:

**AgentHub ↔ Agent Contracts**

- The hub trusts agent contracts to properly validate and inject updates.
- Agent contracts trust the hub to perform generic validation before calling them.

**Agent Contracts ↔ Target Protocol**

- Agent contracts need appropriate permissions on the target protocol.
- Target protocol trusts agent contracts to only inject valid updates.

**ChaosRiskOracle ↔ AgentHub**

- AgentHub trusts ChaosRiskOracle as the source of risk parameters.
Even with high trust assumptions given to the ChaosRiskOracle, the AgentHub does extra validation on top to reduce the trust assumptions and control the consumption from ChaosRiskOracle in a reasonable way.

<br/>

### Potential Attack Vectors, Edge Cases:

**AgentAdmin using another agent's agentContract:**

- **Threat:** On the AgentHub, we do not allow the agentAdmin to change its agentContract. The reason is because if we have two agents, let's say, one having critical protocol permissions with high-trust admin and the other agent less critical with less less-trusted admin, the low-trust admin could potentially use the agent contract of high-trust admin.
To avoid such issues, we only allow the owner to change the agent contract address.
- **Impact:** None

**Front-Running `execute()`**

- **Threat**: If the agent is permissionless, the injection from the risk oracle to the protocol by the intended automation infrastructure can be front-runned.
E.g., if the injection is regarding cap increases, one can call `execute()`  for that update and use the whole cap increase just for itself in one transaction.
If the injection is regarding LiquidationThreshold decrease for a protocol, one can call `execute()`  for that update, and liquidate users in one transaction and keep all the profit for itself.
- **Impact**: No impact, this is akin to allowance frontrunning on ERC20.
- **Mitigation**: Permissioned agents.

**Hash collision in RangeValidationModule**

- **Threat:** Multiple agents and hubs use the same RangeValidationModule to validate ranges. The configs on the module are stored via configId, an id which is computed by doing the following hash: `keccak256(abi.encode(agentHub, agentId, updateType))`.
If for different agentHub, agentId, updateType we get the same hash, (configId) - the existing configurations could be overridden.
- **Impact**: Theoretical risk and no real issue.

**Compromised Hub Owner**

- **Threat**: Hub owner registers a malicious agent or modifies critical configurations.
- **Impact**: Complete system compromise.

**Compromised ProxyAdmin Owner**

- **Threat**: ProxyAdmin owner upgrades the AgentHub proxy to a malicious implementation.
- **Impact**: Complete system compromise.

**Compromised Agent Admin**

- **Threat**: Agent admin manipulates configurations, but only specific to that agent. The Agent admin does not have permission to set a new agentAdmin for the agent, so if compromised, the hub owner should fix it.
- **Impact**: With the agent configurations being manipulated, it can pause or allow invalid updates from RiskOracle to still be injected into the protocol.

**Malicious Agent Contract**

- **Threat**: Agent contract bypasses agent validation or injects malicious parameters.
- **Impact**: Potential exploitation of the target protocol.
- **Mitigation**: This is not expected to happen, as first, the code will be developed/reviewed by the target protocol developers, certainly before giving permissions to an agent.

**ChaosRiskOracle Compromise**

- **Threat**: ChaosRiskOracle provides harmful parameter updates.
- **Impact**: Potential damage to protocol if validation fails.
- **Mitigation**: Range validation, minimum delays, expiration checks, and circuit breakers to disable the agent.
