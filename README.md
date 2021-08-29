# cryptobash

## This project makes requests to Binance and Gate.io crypto exchanges.

## Installation:

git clone git@github.com:daniel-lalaina-movile/cryptobash.git  (or git clone https://github.com/daniel-lalaina-movile/cryptobash.git)

cd bashcrypto

cp .credentials-example .credentials

Include your API keys and secrets in .credentials (If you use only one of both exchanges, just keep the other one empty.)

## Current capabilities

- Show your balance (Binance ✔️ / Gate.io ✔️)
- Sell every token asap at market price (Binance ✔️ / Gate.io ❌)
- Make basic orders on specific tokens at market price (Binance ✔️ / Gate.io ❌)

TODO:
Orders on gate.io (Their API doesn't support orders at market price, so I need to retrieve last price before each order)
More sophisticated orders.
Auto rebalance based on pre-configured percentages.

## Instructions:

./crypto.bash -h   (run help)

## Example:
./crypto.bash -p balance

![screenshot](https://user-images.githubusercontent.com/1348148/131236986-61bb4f9c-fd60-4f31-be14-7145a7d4a53a.gif)
