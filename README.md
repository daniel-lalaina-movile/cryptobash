# cryptobash

## This project makes requests to Binance and Gate.io crypto exchanges.

## Example:
- ./crypto.bash -p balance

![2021-09-04 00-08-03](https://user-images.githubusercontent.com/1348148/132080576-8dfaa45c-2406-45ae-bdee-c059e6bcf607.gif)

## Regular installation:

- `git clone git@github.com:daniel-lalaina-movile/cryptobash.git`  
(or git clone https://github.com/daniel-lalaina-movile/cryptobash.git)

- `cd bashcrypto`

- `cp .credentials-example .credentials`

- Include your API credentials in .credentials file  
(If you use only one of both exchanges, just keep the other one empty.)

### Optional

- `cp .fiat_deposits-example .fiat_deposits`

- Include the deposits or sum of deposits in .fiat_deposits 

## Docker installation

- Same as regular instalation, plus:

- [Install Docker](https://docs.docker.com/get-docker/ "Docker")

- `cd bashcrypto`

- `docker build -t cryptobash .`

## Current capabilities

- Show your results, and the balance detais represented in USDT BTC FIAT. (Binance ✔️ / Gate.io ✔️)
- Sell every token asap at market price (Binance ✔️ / Gate.io ❌)
- Make basic orders on specific or multiple tokens at market price (Binance ✔️ / Gate.io ❌)

## TODO:

- Orders on gate.io (Their API doesn't support orders at market price, so I need to retrieve last price before each order)
- More sophisticated orders.
- Auto rebalance based on pre-configured percentages.

## Test regular installation:

- Regular (run help) `./crypto.bash -h`  

- Doker (run help) `docker run cryptobash -h`  
