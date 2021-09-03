# cryptobash

## This project makes requests to Binance and Gate.io crypto exchanges.

## Example:
- ./crypto.bash -p balance

![cryptobash](https://user-images.githubusercontent.com/1348148/131860897-5dbb68fb-c29b-4dab-b33a-a9eea9cb8d26.gif)

## Installation:

- git clone git@github.com:daniel-lalaina-movile/cryptobash.git  
(or git clone https://github.com/daniel-lalaina-movile/cryptobash.git)

- cd bashcrypto

- cp .credentials-example .credentials

- Include your API credentials in .credentials file  
(If you use only one of both exchanges, just keep the other one empty.)

## Current capabilities

- Show your detailed balance in USD and your fiat currency (Binance ✔️ / Gate.io ✔️)
- Sell every token asap at market price (Binance ✔️ / Gate.io ❌)
- Make basic orders on specific or multiple tokens at market price (Binance ✔️ / Gate.io ❌)

## TODO:

- Orders on gate.io (Their API doesn't support orders at market price, so I need to retrieve last price before each order)
- More sophisticated orders.
- Auto rebalance based on pre-configured percentages.

## Instructions:

- ./crypto.bash -h  
(run help)
