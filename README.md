# cryptobash

## This project makes requests to Binance and Gate.io crypto exchanges.

## Example:
- ./crypto.bash -p balance

![2021-09-04 00-08-03](https://user-images.githubusercontent.com/1348148/132080576-8dfaa45c-2406-45ae-bdee-c059e6bcf607.gif)

## Installation:

- git clone git@github.com:daniel-lalaina-movile/cryptobash.git  
(or git clone https://github.com/daniel-lalaina-movile/cryptobash.git)

- cd bashcrypto

- cp .credentials-example .credentials

- Include your API credentials in .credentials file  
(If you use only one of both exchanges, just keep the other one empty.)

## Current capabilities

- Show your detailed balance in USDT and your fiat currency (Binance ✔️ / Gate.io ✔️)
- Sell every token asap at market price (Binance ✔️ / Gate.io ❌)
- Make basic orders on specific or multiple tokens at market price (Binance ✔️ / Gate.io ❌)

## TODO:

- Orders on gate.io (Their API doesn't support orders at market price, so I need to retrieve last price before each order)
- More sophisticated orders.
- Auto rebalance based on pre-configured percentages.

## Instructions:

- ./crypto.bash -h  
(run help)
