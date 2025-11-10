# Synchronicity Price Adapters

The repository contains the Price Adapter contracts for the assets, which prices are correlated with different token rather than the pool's base one. The primary focus of these adapters is to provide accurate and reliable pricing information for assets in relation to a reference token whether it is on ETH-based or USD-based pools.

These price adapters could be used for a simple 2-step price conversion using two underlying oracles. One of the use-cases is to provide `WBTC / USD` price feed using Chainlink's `WBTC / BTC` and `BTC / USD` oracles. The same approach could be used for ETH-correlated assets, for example, `stETH / ETH` and `ETH / USD` feeds could be used to calculate the `stETH / USD` price.

Another application of the adapter is to provide the reliable stablecoins prices on the ETH-based pools. For example, the Aave v2 pool on Ethereum uses ETH-based oracles to calculate the collateral value, debt value and health factor of a user. This, coupled with the delay at which different price feeds update, introduces unnecessary volatility in positions that involve stablecoins used both as collateral and as debt.
Replacement of the current ETH-based oracles for stablecoins by using USD pairs instead will normalize the USD price using the ETH oracle and will reduce the volatility between stablecoins as all the stablecoin price feeds will update atomically when the ETH price changes.

This repository also contains the proposal smart contracts for using price adapters for stablecoins on the **Aave v2 Ethereum** and **Aave Arc** pool and deployment scripts for `WBTC / USD` and `wstETH / USD` adapters.

### Stablecoins

The proposed change is to deploy `CLSynchronicityPriceAdapterBaseToPeg` for all stablecoin assets and utilize these adapters in the `AaveOracle` smart contract, in order to accurately calculate the price of the asset in relation to `ETH`.
This will be achieved by querying [Chainlink Data Feeds](https://docs.chain.link/docs/ethereum-addresses/) for the pairs of `Asset/USD` and `ETH/USD`, then using the formula
$$Price(Asset / ETH) = {DataFeed(Asset / USD) \over DataFeed(ETH / USD)}$$
This will provide a more accurate representation of the value of the stablecoin assets.

### WBTC

To provide the `WBTC / USD` price feed `CLSynchronicityPriceAdapterPegToBase` contract utilizing `WBTC / BTC` and `BTC / USD` oracles is deployed.

General formula for this adapter is
$$Price(Asset / BASE) = {DataFeed(Asset / PEG) * DataFeed(Peg / BASE)}$$
and it can be re-used for any simple 2-step conversion.

Price adapter for Mainnet is deployed on the address [0x230e0321cf38f09e247e50afc7801ea2351fe56f](https://etherscan.io/address/0x230e0321cf38f09e247e50afc7801ea2351fe56f).

### cbETH

To provide the `cbETH / USD` price feed `CLSynchronicityPriceAdapterPegToBase` contract utilizing `cbETH / ETH` and `ETH / USD` oracles is deployed.

Price adapter for Mainnet is deployed on the address [0x5f4d15d761528c57a5C30c43c1DAb26Fc5452731](https://etherscan.io/address/0x5f4d15d761528c57a5c30c43c1dab26fc5452731).

### stETH to ETH Adapter

The price adapter for `stETH / ETH` returns a constant value of 1 ether, in practice, pegging stETH (a rebasing token) to ETH

### wstETH Adapter

A special price adapter for `wstETH / USD` is added, as additionally to using the `ETH / USD` price feed, an extra step is required to get the ratio between `wstETH` and `stETH`.

### rETH Adapter

Price adapter for `rETH / USD` uses `ETH / USD` price feed along with the `getExchangeRate()` method, which returns `rETH / ETH` ratio, of the [rETH](https://etherscan.io/token/0xae78736cd615f374d3085123a210448e74fc6393) contract itself.

Mainnet Price adapter for rETH is deployed on the address [0x05225Cd708bCa9253789C1374e4337a019e99D56](https://etherscan.io/address/0x05225cd708bca9253789c1374e4337a019e99d56).

Arbitrum Price adapter for rETH is deployed on the address [0x04c28d6fe897859153ea753f986cc249bf064f71](https://arbiscan.io/address/0x04c28d6fe897859153ea753f986cc249bf064f71).

Optimism Price adapter for rETH is deployed on the address [0x52d5F9f884CA21C27E2100735d793C6771eAB793](https://optimistic.etherscan.io/address/0x52d5F9f884CA21C27E2100735d793C6771eAB793).

### LDO Adapter

To provide the `LDO / USD` price feed `CLSynchronicityPriceAdapterPegToBase` contract utilizing `LDO / ETH` and `ETH / USD` oracles is deployed.

Price adapter for Mainnet is deployed on the address [0xb01e6c9af83879b8e06a092f0dd94309c0d497e4](https://etherscan.io/address/0xb01e6c9af83879b8e06a092f0dd94309c0d497e4).

### wstETH Adapter Polygon

To provide the `wstETH / USD` price feed `CLSynchronicityPriceAdapterPegToBase` contract utilizing `wstETH / ETH` and `ETH / USD` oracles is deployed.

Price adapter for Polygon is deployed on the address [0xa2508729b1282cc70dd33ed311d4a9a37383035b](https://polygonscan.com/address/0xa2508729b1282cc70dd33ed311d4a9a37383035b).

## Implementation

### Price Adapter

[CLSynchronicityPriceAdapterBaseToPeg](/src/contracts/CLSynchronicityPriceAdapter.sol)

- Price adapter smart contract where `ChainlinkAggregator` addresses for `Asset / USD` and `ETH / USD` are set.
- Feeds must have the same decimals value.
- Using this two feeds, it calculates the price for pair `Asset / ETH`.
- Returning price is calculated with up to 18 decimals.

[CLSynchronicityPriceAdapterPegToBase](/src/contracts/CLSynchronicityPriceAdapterPegToBase.sol)

- Price adapter smart contract where `ChainlinkAggregator` addresses for `Asset / ETH` and `ETH / USD` are set.
- Using this two feeds, it calculates the price for pair `Asset / USD`.
- Returning price is calculated with up to 18 decimals.

[CLwstETHSynchronicityPriceAdapter](/src/contracts/CLwstETHSynchronicityPriceAdapter.sol)

- Price adapter smart contract which calculates `wstETH / USD` price based on `stETH / ETH` and `ETH / USD` feeds.
- Returning price is calculated with 8 decimals.

[CLrETHSynchronicityPriceAdapter](/src/contracts/CLrETHSynchronicityPriceAdapter.sol)

- Price adapter smart contract which calculates `rETH / USD` price based on `rETH / ETH` and `ETH / USD` feeds.
- Returning price is calculated with 8 decimals.

### Governance Payloads

[ProposalPayloadStablecoinsPriceAdapter](/src/contracts/ProposalPayloadStablecoinsPriceAdapter.sol)

- Proposal payload for the Aave v2 Ethereum pool.
- For all Aave v2 Ethereum stablecoin assets deploys `CLSynchronicityPriceAdapter` and sets it as an asset source by calling `setAssetSources` function on the `AaveOracle` contract.

[ArcProposalPayloadStablecoinsPriceAdapter](/src/contracts/ArcProposalPayloadStablecoinsPriceAdapter.sol)

- Proposal payload for the Aave Arc pool.
- For all Aave Arc stablecoin assets deploys `CLSynchronicityPriceAdapter` and sets it as an asset source by calling `setAssetSources` function on the `AaveOracle` contract.

### Deployment scripts

[DeployWBTCAdapter](/scripts/DeployWBTCAdapter.s.sol) is used to deploy the price adapter for `WBTC / USD`.

[DeployWstETH](/scripts/DeployWstETH.s.sol) is used to deploy adapter for `wstETH / USD`.

## Aave v2 Ethereum stablecoin assets and USD price feeds

List of affected Aave v2 Ethereum stablecoin assets and used Chainlink Data Feeds for `Asset / USD` pair.
| Asset | Asset address | Chainlink Data Feed address |
| --- | --- | --- |
| USDT | [0xdAC17F958D2ee523a2206206994597C13D831ec7](https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7) | [0x3E7d1eAB13ad0104d2750B8863b489D65364e32D](https://etherscan.io/address/0x3e7d1eab13ad0104d2750b8863b489d65364e32d) |
| BUSD | [0x4Fabb145d64652a948d72533023f6E7A623C7C53](https://etherscan.io/address/0x4fabb145d64652a948d72533023f6e7a623c7c53) | [0x833D8Eb16D306ed1FbB5D7A2E019e106B960965A](https://etherscan.io/address/0x833d8eb16d306ed1fbb5d7a2e019e106b960965a) |
| DAI | [0x6B175474E89094C44Da98b954EedeAC495271d0F](https://etherscan.io/address/0x6b175474e89094c44da98b954eedeac495271d0f) | [0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9](https://etherscan.io/address/0xaed0c38402a5d19df6e4c03f4e2dced6e29c1ee9) |
| SUSD | [0x57Ab1ec28D129707052df4dF418D58a2D46d5f51](https://etherscan.io/address/0x57ab1ec28d129707052df4df418d58a2d46d5f51) | [0xad35Bd71b9aFE6e4bDc266B345c198eaDEf9Ad94](https://etherscan.io/address/0xad35bd71b9afe6e4bdc266b345c198eadef9ad94) |
| tUSD | [0x0000000000085d4780B73119b644AE5ecd22b376](https://etherscan.io/address/0x0000000000085d4780b73119b644ae5ecd22b376) | [0xec746eCF986E2927Abd291a2A1716c940100f8Ba](https://etherscan.io/address/0xec746ecf986e2927abd291a2a1716c940100f8ba) |
| USDC | [0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48](https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48) | [0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6](https://etherscan.io/address/0x8fffffd4afb6115b954bd326cbe7b4ba576818f6) |
| GUSD | [0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd](https://etherscan.io/address/0x056fd409e1d7a124bd7017459dfea2f387b6d5cd) | [0xa89f5d2365ce98B3cD68012b6f503ab1416245Fc](https://etherscan.io/address/0xa89f5d2365ce98b3cd68012b6f503ab1416245fc) |
| USDP | [0x8E870D67F660D95d5be530380D0eC0bd388289E1](https://etherscan.io/address/0x8e870d67f660d95d5be530380d0ec0bd388289e1) | [0x09023c0DA49Aaf8fc3fA3ADF34C6A7016D38D5e3](https://etherscan.io/address/0x09023c0da49aaf8fc3fa3adf34c6a7016d38d5e3) |
| FRAX | [0x853d955aCEf822Db058eb8505911ED77F175b99e](https://etherscan.io/address/0x853d955acef822db058eb8505911ed77f175b99e) | [0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD](https://etherscan.io/address/0xb9e1e3a9feff48998e45fa90847ed4d467e8bcfd) |
| LUSD | [0x5f98805A4E8be255a32880FDeC7F6728C6568bA0](https://etherscan.io/address/0x5f98805a4e8be255a32880fdec7f6728c6568ba0) | [0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0](https://etherscan.io/address/0x3d7ae7e594f2f2091ad8798313450130d0aba3a0) |

## Aave v2 ARC stablecoin assets and USD price feeds

List of affected Aave v2 Arc stablecoin assets and used Chainlink Data Feeds for `Asset / USD` pair.

| Asset | Asset address                                                                                                         | Chainlink Data Feed address                                                                                           |
| ----- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| USDC  | [0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48](https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48) | [0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6](https://etherscan.io/address/0x8fffffd4afb6115b954bd326cbe7b4ba576818f6) |

## Aave v3 assets

### Mainnet:

| Asset  | Asset address | Chainlink Data Feed addresses |
| ------ | ------------- | ----------------------------- |
| WBTC   | [0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599](https://etherscan.io/address/0x2260fac5e5542a773aa44fbcfedf7c193bc2c599) | WBTC/BTC: [0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23](https://etherscan.io/address/0xfdfd9c85ad200c506cf9e21f1fd8dd01932fbb23), BTC/USD: [0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c](https://etherscan.io/address/0xf4030086522a5beea4988f8ca5b36dbc97bee88c)  |
| wstETH | [0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0](https://etherscan.io/address/0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0) | stETH/ETH: [0x86392dC19c0b719886221c78AB11eb8Cf5c52812](https://etherscan.io/address/0x86392dc19c0b719886221c78ab11eb8cf5c52812), ETH/USD: [0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419](https://etherscan.io/address/0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419) |
| LDO    | [0xb01e6c9af83879b8e06a092f0dd94309c0d497e4](https://etherscan.io/address/0xb01e6c9af83879b8e06a092f0dd94309c0d497e4) | LDO/ETH: [0x4e844125952D32AcdF339BE976c98E22F6F318dB](https://etherscan.io/address/0x4e844125952D32AcdF339BE976c98E22F6F318dB) , ETH/USD: [0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419](https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419)  |

### Polygon:

| Asset | Asset address | Chainlink Data Feed addresses |
|------|----------------|--------------------------------|
| wstETH | [0xa2508729b1282cc70dd33ed311d4a9a37383035b](https://polygonscan.com/address/0xa2508729b1282cc70dd33ed311d4a9a37383035b) | wstETH/ETH: [0x10f964234cae09cB6a9854B56FF7D4F38Cda5E6a](https://polygonscan.com/address/0x10f964234cae09cB6a9854B56FF7D4F38Cda5E6a), ETH/USD: [0xF9680D99D6C9589e2a93a78A04A279e509205945](https://polygonscan.com/address/0xF9680D99D6C9589e2a93a78A04A279e509205945) |

### Arbitrum:

| Asset | Asset address | Chainlink Data Feed addresses |
|------|----------------|--------------------------------|
| rETH | [0x04c28d6fe897859153ea753f986cc249bf064f71](https://arbiscan.io/address/0x04c28d6fe897859153ea753f986cc249bf064f71) | rETH/ETH: [0xf3272cafe65b190e76caaf483db13424a3e23dd2](https://arbiscan.io/address/0xf3272cafe65b190e76caaf483db13424a3e23dd2), ETH/USD: [0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612](https://arbiscan.io/address/0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612) |

### Optimism:

| Asset | Asset address | Chainlink Data Feed addresses |
|------|----------------|--------------------------------|
| rETH | [0x52d5F9f884CA21C27E2100735d793C6771eAB793](https://optimistic.etherscan.io/address/0x52d5F9f884CA21C27E2100735d793C6771eAB793) | rETH/ETH: [0x22F3727be377781d1579B7C9222382b21c9d1a8f](https://optimistic.etherscan.io/address/0x22F3727be377781d1579B7C9222382b21c9d1a8f), ETH/USD: [0x13e3Ee699D1909E989722E753853AE30b17e08c5](https://optimistic.etherscan.io/address/0x13e3Ee699D1909E989722E753853AE30b17e08c5) |

## Security

### Foundry Tests

[CLSynchronicityPriceAdapterFormulaTest](./src/test/CLSynchronicityPriceAdapterFormulaTest.t.sol)

- Validates that formula used in price adapter is correct.
- For `TESTS_NUM` number of tests, makes mock aggregator with price of asset in `i-th` test set to $Price(ETH / USD) \over i$. Validates that price returned from the `CLSynchronicityPriceAdapter` is $1 ETHER /over i$.

[PriceChangeTest](./src/test/PriceChangeTest.t.sol)

- Validates that price difference between price feed for pair `Asset / ETH` and price from the adapter is less than `2%`.

[CLSynchronicityPriceAdapterPegToBaseTest](./src/test/CLSynchronicityPriceAdapterPegToBaseTest.t.sol)

- Validates that formula used in price adapter is correct.

[CLwstETHSynchronicityPriceAdapterTest](./src/test/CLwstETHSynchronicityPriceAdapterTest.t.sol)

- Validates that formula used in price adapter is correct.

[ProposalPayloadStablecoinsPriceAdapterTest](./src/test/ProposalPayloadStablecoinsPriceAdapterTest.t.sol)

- Validates that after proposal in Aave v2 Ethereum pool is accepted, all asset sources for stablecoin assets are changed.

[ArcProposalPayloadStablecoinsPriceAdapterTest](./src/test/ArcProposalPayloadStablecoinsPriceAdapterTest.t.sol)

- Validates that after proposal in Aave v2 Ethereum pool is accepted, all asset sources for stablecoin assets are changed.

### Audits

[SigmaP](./security/sigmap/audit-report.md)

[Certora](./security/Certora/Certora%20Review.pdf)

## Setup

### Install

To install and execute the project locally, you need:

- `npm install` : To install prettier for linting.
- `forge install` : This project is made using [Foundry](https://book.getfoundry.sh/) so to run it you will need to install it, and then install its dependencies.

### Setup environment

```sh
cp .env.example .env
```

### Build

```sh
forge build
```

### Test

```sh
forge test
```

### Copyright

2023 BGD Labs
