## Current capabilities

- Rebalance all your wallet portifolio based on configuration file (Binance ✔️ / Gate.io ✔️ / FTX ✔️ )
- Show your results and the balance details represented in USDT BTC FIAT. (Binance ✔️ / Gate.io ✔️ / FTX ✔️ )
- Sell every token asap at market price (Binance ✔️ / Gate.io ✔️ / FTX ✔️ )
- Make basic orders at market price (Binance ✔️ / Gate.io ✔️ / FTX ✔️ )
- Send Telegram messages about your wallet and results. ✔️

## Example:
- `./crypto.bash -p overview

![2021-09-10 00-32-42](https://user-images.githubusercontent.com/1348148/132795835-55606189-a9ed-42c8-8127-8cade75cae4a.gif)

## Installation step 1:

- `git clone git@github.com:daniel-lalaina-movile/cryptobash.git`  
(or git clone https://github.com/daniel-lalaina-movile/cryptobash.git)

- `cd cryptobash`

- `cp .credentials-example .credentials`

- Include your API credentials in .credentials file  
(If you use only one some exchanges, just keep the other ones empty.)

### If you want to receive messages about results and balance:

- Open @BotFather ( https://telegram.me/BotFather ) in Telegram and click the `/start` command

- Send the command `/newbot`

- Give a name to the bot

- Create a username for the bot

- The godfather will write you a message with the bot url, and your token, so:  
First, copy your token, it should be something like 8394726483:AAGSnTm4FOdmXZkjdoeys8476hcplnZVzkM  
Second, click in the bot url, then click `/start` and send a "hello" msg to the bot. (It shouln't answer anything, that's right) 
Third, click on the link below, and copy the `chat_id` that appears in the the page. (REPLACE XXXXXXXXXXXXXXXXXXXXXX your token) https://api.telegram.org/botXXXXXXXXXXXXXXXXXXXXXXXXXXXX/getUpdates

- Include your telegram token and chat_id, in the file .credentials

### If you want to see your results:

- `cp .fiat_deposits-example .fiat_deposits`

- Include the deposits or sum of deposits in .fiat_deposits 

### If you want to rebalance your wallet portifolio:

- You need to have USDT funds in your wallet, it's the most listed and liquid stable currency, so it's easier to operate.

- `cp .rebalance-example .rebalance`

- Cryptobash will make all the necessary orders to get what you put in this file.<br>First column is the token without pair<br>Second column is the USDT amount.<br>It will always try to buy the <token>USDT. If it's not listed by in the exchange, it will see if <token>BTC is, and if so, it will buy BTCUSDT first, and then <token>BTC.

## Installation step 2

- [Install Docker](https://docs.docker.com/get-docker/ "Docker")

- `cd bashcrypto`

- `docker build -t cryptobash:latest .`

## Running:

- `./crypto.bash -h`  

## Donate

| Cryptocurrencies                                              | Network                   | Address                                                  |
| ------------------------------------------------------------- | ------------------------- | -------------------------------------------------------- |
| ![pngfind com-cnbc-logo-png-1429336](https://user-images.githubusercontent.com/1348148/132743912-04ae31f1-2c74-492c-b7fb-f415581cea28.png)<br>  (or any ERC20) | Ethereum (ERC20) | `0x930379d0feDB4e3AE6c39144fCD5f29f08Ee8235` |
| ![Binance-Logo wine](https://user-images.githubusercontent.com/1348148/132743946-4292efb3-5d20-41d9-955d-e26071810124.png) | Binance Smart Chain (BSC) | `0xa9A739734a2F740C8f998DDFe408bC9e39E3B415` |

## TODO:

- Logs
