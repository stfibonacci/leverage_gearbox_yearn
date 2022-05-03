# Gearbox Yearn Leverage

## Overview

This repo is only for learning purposes and not ready for production.

You can find the medium article here:

- [medium article]()

## Dependencies

- [nodejs and npm](https://nodejs.org/en/download/)
- [python](https://www.python.org/downloads/)
- [Brownie](https://eth-brownie.readthedocs.io/en/stable/install.html)
- [ganache-cli](https://www.npmjs.com/package/ganache-cli)
- [Brownie Token Tester](https://pypi.org/project/brownie-token-tester/)

## Installation

Clone this repo

```
git clone https://github.com/stfibonacci/leverage_gearbox_yearn.git
cd leverage_gearbox_yearn
```

## Environment Variables

get free infura account:

- [Infura](https://infura.io/)

You need install metamask and get your private key. Dont put real fund in this wallet.

- [metamask](https://metamask.io/)

Add environment variables to the env file and dont send these to github.

```bash
export WEB3_INFURA_PROJECT_ID=<PROJECT_ID>
export PRIVATE_KEY=<PRIVATE_KEY>

```

## Run on Brownie Mainnet Fork

```bash
brownie run scripts/invest_yearn.py --network mainnet-fork
```
