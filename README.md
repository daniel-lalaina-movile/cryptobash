## Current capabilities

- Show your results, and the balance details represented in USDT BTC FIAT. (Binance ✔️ / Gate.io ✔️ / FTX ✔️ )
- Sell every token asap at market price (Binance ✔️ / Gate.io ✔️ / FTX ✔️ )
- Make basic orders on specific or multiple tokens at market price (Binance ✔️ / Gate.io ❌ / FTX ❌ )

## Example:
- `./crypto.bash -p balance all`

![2021-09-10 00-32-42](https://user-images.githubusercontent.com/1348148/132795835-55606189-a9ed-42c8-8127-8cade75cae4a.gif)

## Regular installation:

- `git clone git@github.com:daniel-lalaina-movile/cryptobash.git`  
(or git clone https://github.com/daniel-lalaina-movile/cryptobash.git)

- `cd cryptobash`

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

- `docker build -t cryptobash:latest .`

## TODO:

- Orders on gate.io (Their API doesn't support orders at market price, so I need to retrieve last price before each order)
- More sophisticated orders.
- Auto rebalance based on pre-configured percentages.
- Create logs

## Test regular installation:

- Regular (run help) `./crypto.bash -h`  

- Docker (run help) `docker run cryptobash -h`  

## Donate

| Cryptocurrencies                                              | Network                   | Address                                                  |
| ------------------------------------------------------------- | ------------------------- | -------------------------------------------------------- |
| ![pngfind com-cnbc-logo-png-1429336](https://user-images.githubusercontent.com/1348148/132743912-04ae31f1-2c74-492c-b7fb-f415581cea28.png)<br>  (or any ERC20) | Ethereum (ERC20) | `0x930379d0feDB4e3AE6c39144fCD5f29f08Ee8235` |
| ![Binance-Logo wine](https://user-images.githubusercontent.com/1348148/132743946-4292efb3-5d20-41d9-955d-e26071810124.png) | Binance Smart Chain (BSC) | `0xa9A739734a2F740C8f998DDFe408bC9e39E3B415` |
