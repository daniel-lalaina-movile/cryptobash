#!/usr/bin/env bash

# https://github.com/daniel-lalaina-movile/cryptobash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name="./$(basename "${BASH_SOURCE[0]}")"
tdir=$script_dir/temp

binance_uri="api.binance.com"
gateio_uri="api.gateio.ws"
ftx_uri="ftx.com"
source $script_dir/.credentials

residential_country_currency="BRL"
LC_NUMERIC="en_US.UTF-8"

usage() {
 cat << EOF
Usage: ${script_name} [-h] [-v] [-t] -p <order|balance|runaway> arg1 [arg2...]

Available options:

-h, --help      Print this help.
-v, --verbose   Run with debug
-t, --test      Use Binance test endpoint. (Works with "order" or "runaway" params)
-p, --param     Main action parameter
		-p balance
		-p order
                -p runaway

Examples:

Buy 50 USDT of ADA_USDT
$script_name -p order binance BUY ADA_USDT 50
$script_name -p order gateio BUY ADA_USDT 50
$script_name -p order ftx BUY ADA_USDT 50

Buy 50 USDT of each ADA ETH BTC
$script_name -p order binance BUY ADA_USDT,ETH_USDT,BTC_USDT 50
$script_name -p order gateio BUY ADA_USDT,ETH_USDT,BTC_USDT 50
$script_name -p order ftx BUY ADA_USDT,ETH_USDT,BTC_USDT 50

Show your balance.
$script_name -p balance all
$script_name -p balance binance
$script_name -p balance gateio
$script_name -p balance ftx

Sell every token that you have, at market price.
$script_name -p runaway binance
$script_name -p runaway gateio
$script_name -p runaway ftx
$script_name -p runaway all

EOF
exit
}

cleanup() {
 trap - SIGINT SIGTERM ERR EXIT
 #rm -rf $tdir/*
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # defaults
  test=""
  param=''
  progress_bar="true"

  while :; do
    case "${1-}" in
    --docker) script_name="docker run cryptobash";;
    -h | --help) usage;;
    -v | --verbose) set -x; progress_bar="false";;
    -t | --test) test="/test";;
    -p | --param)
      param="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1";;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # Checking exchange keys

  if echo ${@-} |grep -q "binance"; then
   echo -n "$binance_key$binance_secret" |wc -c |grep -Eq "^128$|^0$" || die "Invalid binance_key/binance_secret, if you don't have account in this exchange, please leave both fields empty"
  elif echo ${@-} |grep -q "gateio"; then
   echo -n "$gateio_key$gateio_secret" |wc -c |grep -Eq "^96$|^0$" || die "Invalid gateio_key/gateio_secret, if you don't have account in this exchange, please leave both fields empty"
  elif echo ${@-} |grep -q "ftx"; then
   echo -n "$ftx_key$ftx_secret" |wc -c |grep -Eq "^80$|^0$" || die "Invalid ftx_key/ftx_secret, if you don't have account in this exchange, please leave both fields empty"
  elif echo ${@-} |grep -q "all"; then
   echo -n "$gateio_key$gateio_secret$binance_key$binance_secret" |wc -c |grep -Eq "^0$" && die "You must configure a pair of key/secret for at least one of the exchanges."
  fi

  # Checking required params and arguments

  if [[ "${param}" != @(order|balance|runaway) ]]; then die "Missing main parameter: -p <order|balance|runaway>"; fi
  if [[ "${param}" == @(balance|runaway) ]]; then
   exchange=$(echo ${@-} |grep -oPi "(binance|gateio|ftx|all)" || die "Exchange argument is required for param runaway.\nEx\n${script_name} -p runaway binance\n${script_name} -p runaway gateio\n${script_name} -p runaway all")
  fi
  if [ ${param} == "order" ]; then
   side=$(echo ${@-} |grep -oP "\b(SELL|BUY)\b" || die "SIDE argument is required for param order.\nExamples:\n${script_name} -p order SELL ADA_USDT 30")
   symbol=$(echo ${@-} |grep -oP "\b[A-Z0-9]+(USDT|BTC)\b" || die "SYMBOL argument is required for param order. Examples\nTo SELL 30 USDT of ADA:\n${script_name} -p order SELL ADA_USDT 30\nTo buy 30 USDT of each ADA,SOL,LUNA:\n${script_name} -p order SELL ADA_USDT,SOLUSDT,LUNAUSDT 30")
   qty=$(echo ${@-} |grep -oP "\b[0-9.]+\b" || die "QUOTEQTY argument (which is the amount you want to spend, not the ammount of coins you want to buy/sell) is required for param order.\nExamples:\n/$script_name -p order SELL ADA_USDT 30")
   exchange=$(echo ${@-} |grep -oPi "(binance|gateio|ftx)" || die "Exchange argument is required for param order.\nExamples:\n${script_name} -p order binance SELL ADA_USDT 30\n${script_name} -p order gateio SELL ADA_USDT 30\n${script_name} -p order ftx SELL ADA_USDT 30")
  fi

  return 0
}

parse_params "$@"

banner() {
clear
msg "\033[0;34m
██████╗ ██╗      ██████╗  ██████╗██╗  ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗    ██████╗  ██████╗  ██████╗██╗  ██╗███████╗
██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██║  ██║██╔══██╗██║████╗  ██║    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝
██████╔╝██║     ██║   ██║██║     █████╔╝ ██║     ███████║███████║██║██╔██╗ ██║    ██████╔╝██║   ██║██║     █████╔╝ ███████╗
██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║     ██╔══██║██╔══██║██║██║╚██╗██║    ██╔══██╗██║   ██║██║     ██╔═██╗ ╚════██║
██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╗██║  ██║██║  ██║██║██║ ╚████║    ██║  ██║╚██████╔╝╚██████╗██║  ██╗███████║
╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝    ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝
\033[0m"
}
if [ ! ${param} == "balance" ]; then banner; fi

progress_bar() {
 pid=$!
 banner
 while kill -0 $pid 2> /dev/null; do
  for ((k = 0; k <= 30 ; k++)); do
   echo -n "[ "
   for ((i = 0 ; i <= k; i++)); do echo -n "\$\$\$\$"; done
   #for ((j = i ; j <= 30 ; j++)); do echo -n "   "; done
   v=$((k * 30))
   echo -n " ] "
   kill -0 $pid 2>/dev/null || break
   echo -n "$v %" $'\r'
   sleep 0.3
  done
 done
 msg "\r[ \$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$ ] 1000 %"
}

func_timestamp() {
 echo -n $(($(date +%s%N)/1000000))
}

curl_usd() {
  fiat_usd_rate="$(curl -s -H 'user-agent: Mozilla' -H 'Accept-Language: en-US,en;q=0.9,it;q=0.8' "https://www.google.com/search?q=1+usd+to+$residential_country_currency" |grep -oP "USD = [0-9]+\\.[0-9]+ $residential_country_currency" |head -n1 |grep -oP "[0-9]+\\.[0-9]+" |tr -d '\n')"
}

curl_binance() {
 curl -s -X $binance_method -H "X-MBX-APIKEY: $binance_key" "https://$binance_uri/$binance_endpoint?$binance_query_string&signature=$binance_signature"
}

curl_binance_public() {
 curl -s -X $binance_method "https://$binance_uri/$binance_endpoint?"
}

curl_gateio() {
 curl -s -X $gateio_method -H "Timestamp: $gateio_timestamp" -H "KEY: $gateio_key" -H "SIGN: $gateio_signature" "https://$gateio_uri/$gateio_endpoint?"
}

curl_gateio_public() {
 curl -s -X $gateio_method "https://$gateio_uri/$gateio_endpoint?$gateio_query_string"
}

curl_ftx() {
 curl -s -X $ftx_method -H "FTX-TS: $ftx_timestamp" -H "FTX-KEY: $ftx_key" -H "FTX-SIGN: $ftx_signature" "https://${ftx_uri}${ftx_endpoint}"
}

curl_ftx_public() {
 curl -s -X $ftx_method "https://${ftx_uri}${ftx_endpoint}?$ftx_query_string"
}

if [ ${param} == "runaway" ]; then
 if [ -z $test ]; then read -p "Are you sure? This will convert all your assets to USDT (y/n)" -n 1 -r; if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit; fi; fi
 if echo -n $binance_key$binance_secret |wc -c |grep -Eq "^128$" && [[ $exchange =~ binance|all ]]; then
  binance_method="GET"
  binance_endpoint="api/v1/exchangeInfo"
  curl_binance_public |jq '.symbols | .[] | [{symbol: .symbol, filter: .filters}] | .[] |del(.filter[] | select(.filterType != "LOT_SIZE"))' |grep -E 'symbol|stepSize' |sed 's/^.*: "//g; s/".*//g' |paste - - > $tdir/binance_exchangeInfo
  binance_endpoint="sapi/v1/capital/config/getall"
  binance_timestamp=$(func_timestamp)
  binance_query_string="timestamp=$binance_timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance |jq -r '.[] |select((.free|tonumber>0.0001) and (.coin!="USDT")) |.coin,.free' |paste - - |while read symbol qty; do
   read symbol stepSize<<<$(grep -E "^${symbol}USDT\s+" $tdir/binance_exchangeInfo || grep -E "^${symbol}BTC\s+" $tdir/binance_exchangeInfo)
   if echo "$qty < $stepSize" |bc -l |grep -q 1; then continue; fi
   stepSize=$(echo $stepSize |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   decimal=$(echo "1 / $stepSize" |bc -l |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   qty_dec=$(echo "$qty * $decimal" |bc -l |sed -E 's/\..*//g') 
   qty=$(echo "$qty_dec / $decimal" |bc -l |sed -E 's/\.0+$//g; s/^\./0./g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   binance_method="POST"
   binance_endpoint="api/v3/order$test"
   binance_timestamp=$(func_timestamp)
   binance_query_string="quantity=$qty&symbol=${symbol}&side=SELL&type=MARKET&timestamp=$binance_timestamp"
   binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
   curl_binance |grep -v "Invalid symbol" || \
    binance_method="POST" 
    binance_timestamp=$(func_timestamp)
    binance_query_string="quantity=$qty&symbol=${symbol}&side=SELL&type=MARKET&timestamp=$binance_timestamp" \
    binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}') \
    curl_binance &
  done
 fi &
 if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$" && [[ $exchange =~ gateio|all ]]; then
  if [ ! -z $test ]; then echo "Unfortunately, gate.io doesn't have a test endpoint, so here we are testing only our side"; fi
  gateio_method="GET"
  gateio_query_string=""
  gateio_endpoint="api/v4/spot/accounts"
  gateio_body=""
  gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
  gateio_timestamp=$(date +%s)
  gateio_sign_string="$gateio_method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$gateio_timestamp"
  gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
  curl_gateio |jq -r ' .[] | select((.available!="0") and (.currency!="USDT")) |.currency,.available' |paste - - > $tdir/gateio_balance
  gateio_endpoint="api/v4/spot/currency_pairs"
  curl_gateio_public |jq -r '.[] |.id,.amount_precision,.precision' |paste - - - > $tdir/gateio_supported_pairs
  cat $tdir/gateio_balance | grep -Ev "^(USDT|USDC|BUSD)" |while read symbol qty; do
   read symbol amount_scale price_scale<<<$(grep -E "^${symbol}_USDT\s+" ${tdir}/gateio_supported_pairs || grep -E "^${symbol}_BTC\s+" $tdir/gateio_supported_pairs)
   gateio_query_string="currency_pair=$symbol"
   gateio_endpoint="api/v4/spot/tickers"
   gateio_last_price=$(gateio_method="GET"; curl_gateio_public |jq -r '.[].last')
   gateio_price=$(echo "scale=${price_scale}; $gateio_last_price * 0.996" |bc -l |sed -E 's/^\./0./g')
   qty=$(echo "scale=${amount_scale}; $qty / 1" |bc -l |sed -E 's/^\./0./g')
   gateio_method="POST"
   gateio_query_string=""
   gateio_endpoint="spot/${test}order"
   gateio_body='{"currency_pair":"'$symbol'","side":"sell","amount":"'$qty'","price":"'$gateio_price'"}'
   gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
   gateio_timestamp=$(date +%s)
   gateio_sign_string="$gateio_method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$gateio_timestamp"
   gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
   curl_gateio
  done
 fi &
 if echo -n $ftx_key$ftx_secret |wc -c |grep -Eq "^80$" && [[ $exchange =~ ftx|all ]]; then
  if [ ! -z $test ]; then echo "Unfortunately, ftx doesn't have a test endpoint, so here we are testing only our side"; fi
  ftx_method="GET"
  ftx_endpoint="/api/wallet/balances"
  ftx_timestamp=$(func_timestamp)
  ftx_query_string=""
  ftx_body=""
  ftx_signature=$(echo -n "${ftx_timestamp}${ftx_method}${ftx_endpoint}${ftx_query_string}${ftx_body}" |openssl dgst -sha256 -hmac "$ftx_secret" |awk '{print $2}')
  curl_ftx |jq -r '.result | .[] |select(.total!=0) | .coin,.free' |paste - - > $tdir/ftx_balance
  ftx_endpoint="/api/markets"
  curl_ftx_public |jq -r '.result |del(.[] | select(.type != "spot")) | .[] | .name,.sizeIncrement' |paste - - > $tdir/ftx_markets
  cat $tdir/ftx_balance | grep -Ev "^(USDT?|USDC|BUSD)" |while read symbol qty; do
   read symbol sizeIncrement<<<$(grep -E "^${symbol}\/USDT?\s+" ${tdir}\/ftx_markets || grep -E "^${symbol}\/BTC\s+" $tdir/ftx_markets)
   # scientific notation to regular float
   qty=$(echo $qty |awk '{printf "%F",$1+0}')
   sizeIncrement=$(echo $sizeIncrement |awk '{printf "%F",$1+0}')
   if echo "$qty < $sizeIncrement" |bc -l |grep -q 1; then continue; fi
   stepSize=$(echo $stepSize |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   decimal=$(echo "1 / $stepSize" |bc -l |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   qty_dec=$(echo "$qty * $decimal" |bc -l |sed -E 's/\..*//g') 
   qty=$(echo "$qty_dec / $decimal" |bc -l |sed -E 's/\.0+$//g; s/^\./0./g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   ftx_method="POST"
   ftx_endpoint="/api/${test}orders"
   ftx_timestamp=$(func_timestamp)
   ftx_query_string=""
   ftx_body='{"market":"'${symbol}'","side":"sell","price": null,"type":"market","size":'${qty}'}'
   ftx_signature=$(echo -n "${ftx_timestamp}${ftx_method}${ftx_endpoint}${ftx_query_string}${ftx_body}" |openssl dgst -sha256 -hmac "$ftx_secret" |awk '{print $2}')
   curl_ftx
  done
 fi
 exit
fi

if [ ${param} == "balance" ]; then
 rm -f $tdir/*
 curl -s -m3 'https://'$gateio_uri'/api/v4/spot/tickers?currency_pair=USDT_USD' |jq -r .[].last |grep -E "[0-9]+\.[0-9]+" > $tdir/usdtusd || echo "1" > $tdir/usdtusd &
 fiat_deposits=$(awk '{dep+=$1}END{print dep}' $script_dir/.fiat_deposits 2>/dev/null &)
 $(
 if [ $residential_country_currency == "USD" ]; then fiat_usd_rate="1"; else curl_usd; fi
 if echo -n $binance_key$binance_secret |wc -c |grep -Eq "^128$" && [[ $exchange =~ binance|all ]]; then
  binance_method="GET"
  binance_endpoint="sapi/v1/capital/config/getall"
  binance_timestamp=$(func_timestamp)
  binance_query_string="timestamp=$binance_timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance |jq ' .[] | select(.free!="0" or .locked!="0") | .coin,.free,.locked' |paste - - - > $tdir/binance_balance
  binance_endpoint="api/v3/ticker/24hr"
  curl_binance_public |jq '.[] | {symbol: .symbol, price: .lastPrice, last24hr: .priceChangePercent|tonumber} | select(.price!="0.00000000" and .price!="0.00" and .price!="0") | to_entries[] | .value' |paste - - - > $tdir/binance_24hr
  sed -i 's/"//g' $tdir/binance_24hr $tdir/binance_balance
  btcusdt=$(grep -E "^BTCUSDT\b" $tdir/binance_24hr |awk '{print $2}')
  cat $tdir/binance_balance |while read symbol available locked; do
   amount=$(echo "$available + $locked" | bc -l)
   if grep -q "^${symbol}USDT" $tdir/binance_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/binance_24hr |awk '{print $2,$3}')
   elif [[ ${symbol} =~ USDT|BUSD|USDC ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/binance_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/binance_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${btcusdt}" |bc -l)
   #else
   #usdt_pair_price=$(curl_usd)
   fi
   usdt_available=$(echo "$available * $usdt_pair_price" |bc -l)
   usdt_locked=$(echo "$locked * $usdt_pair_price" |bc -l)
   usdt_total=$(echo "$usdt_available + $usdt_locked" |bc -l)
   until [ -f $tdir/usdtusd ]; do sleep 0.1; done
   usdtusd=$(head -1 $tdir/usdtusd)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$(echo "$usdt_total * $usdtusd" |bc -l)
   else
    fiat_total=$(echo "$usdt_total * $usdtusd * $fiat_usd_rate" |bc -l)
   fi
   btc_total=$(echo "$usdt_total / $btcusdt" |bc -l)
   echo $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr >> $tdir/binance_final
  done
 fi &
 if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$" && [[ $exchange =~ gateio|all ]]; then
  gateio_method="GET"
  gateio_query_string=""
  gateio_body=""
  gateio_endpoint="api/v4/spot/accounts"
  gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
  gateio_timestamp=$(date +%s)
  gateio_sign_string="$gateio_method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$gateio_timestamp"
  gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
  curl_gateio |jq ' .[] | select(.available!="0" or .locked!="0") |.currency,.available,.locked' |paste - - - > $tdir/gateio_balance
  #curl_gateio |jq ' .[] | {symbol: .currency, available: .available, locked: .locked} | select(.available!="0" or .locked!="0") | to_entries[] | .value' |paste - - - > $tdir/gateio_balance
  gateio_endpoint="api/v4/spot/tickers"
  curl_gateio_public |jq '.[] | {symbol: .currency_pair, price: .last, last24hr: .change_percentage|tonumber} | select(.price!="0.00000000" and .price!="0.00" and .price!="0") | to_entries[] | .value' |sed 's/_//g' |paste - - - > $tdir/gateio_24hr
  sed -i 's/"//g' $tdir/gateio_24hr $tdir/gateio_balance
  btcusdt=$(grep -E "^BTCUSDT\b" $tdir/gateio_24hr |awk '{print $2}')
  cat $tdir/gateio_balance |while read symbol available locked; do
   amount=$(echo "$available + $locked" | bc -l)
   if grep -q "^${symbol}USDT" $tdir/gateio_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/gateio_24hr |awk '{print $2,$3}')
   elif [[ ${symbol} =~ USDT|BUSD|USDC ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/gateio_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/gateio_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${btcusdt}" |bc -l)
  #else
   #usdt_pair_price=$(curl_usd)
   fi
   usdt_available=$(echo "$available * $usdt_pair_price" |bc -l)
   usdt_locked=$(echo "$locked * $usdt_pair_price" |bc -l)
   usdt_total=$(echo "$usdt_available + $usdt_locked" |bc -l)
   until [ -f $tdir/usdtusd ]; do sleep 0.1; done
   usdtusd=$(head -1 $tdir/usdtusd)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$(echo "$usdt_total * $usdtusd" |bc -l)
   else
    fiat_total=$(echo "$usdt_total * $usdtusd * $fiat_usd_rate" |bc -l)
   fi
   btc_total=$(echo "$usdt_total / $btcusdt" |bc -l)
   echo $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr >> $tdir/gateio_final
  done
 fi &
 if echo -n $ftx_key$ftx_secret |wc -c |grep -Eq "^80$" && [[ $exchange =~ ftx|all ]]; then
  ftx_method="GET"
  ftx_endpoint="/api/wallet/balances"
  ftx_timestamp=$(func_timestamp)
  ftx_query_string=""
  ftx_body=""
  ftx_signature=$(echo -n "${ftx_timestamp}${ftx_method}${ftx_endpoint}${ftx_query_string}${ftx_body}" |openssl dgst -sha256 -hmac "$ftx_secret" |awk '{print $2}')
  curl_ftx |jq '.result | .[] |select(.total!=0) | .coin,.free,.total,.usdValue' |paste - - - - > $tdir/ftx_balance
  ftx_endpoint="/api/markets"
  curl_ftx_public |jq '.result | .[] | .name,.price,.change24h' |paste - - - |grep "/" > $tdir/ftx_24hr
  sed -Ei 's/(\"|\/)//g' $tdir/ftx_24hr $tdir/ftx_balance
  btcusdt=$(grep -E "^BTCUSDT\b" $tdir/ftx_24hr |awk '{print $2}')
  cat $tdir/ftx_balance |while read symbol available total usd; do
   amount=$total
   if grep -q "^${symbol}USDT" $tdir/ftx_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/ftx_24hr |awk '{print $2,$3}')
   elif grep -q "^${symbol}USD" $tdir/ftx_24hr; then
    read usd_pair_price last24hr <<<$(grep "^${symbol}USD" $tdir/ftx_24hr |awk '{print $2,$3}')
    until [ -f $tdir/usdtusd ]; do sleep 0.1; done
    usdtusd=$(head -1 $tdir/usdtusd)
    usdt_pair_price=$(echo "$usd_pair_price / ${usdtusd}" |bc -l)
   elif [[ ${symbol} =~ ^(USD|USDT|BUSD|USDC)$ ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/ftx_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/ftx_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${btcusdt}" |bc -l)
   #else
   #usdt_pair_price=$(curl_usd)
   fi
   usdt_available=$(echo "$available * $usdt_pair_price" |bc -l)
   usdt_locked=$(echo "($total - $available) * $usdt_pair_price" |bc -l)
   usdt_total=$(echo "$usdt_available + $usdt_locked" |bc -l)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$usd
   else
    fiat_total=$(echo "$usdt_total * $usdtusd * $fiat_usd_rate" |bc -l)
   fi
   btc_total=$(echo "$usdt_total / $btcusdt" |bc -l)
   echo $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr >> $tdir/ftx_final
  done
 fi
 ) &

 if [ $progress_bar == "true" ]; then progress_bar; else wait; fi
 # Unifying and summing up the amounts of same assets from multiple exchanges.
 num_of_exchanges=$(ls -1 ${tdir}/*_final |wc -l) 
 awk '{a[$1]+=$2;b[$1]+=$3;c[$1]+=$4;d[$1]+=$5;e[$1]+=$6;f[$1]+=$7;g[$1]+=$8}END{for(i in a)print i, a[i], b[i], c[i], d[i], e[i], f[i], g[i]/'${num_of_exchanges}'"%"}' $tdir/*_final > $tdir/total_final1
 # Including percentage allocation column.
 awk 'FNR==NR{s+=$5;next;} {printf $0" "; printf "%.2f",100*$5/s; print "%"}' $tdir/total_final1 $tdir/total_final1 |sort -n -k5 > $tdir/total_final2
 # Including footer with total sum of each column.
 awk '{for(i=2;i<=8;i++)a[i]+=$i;print $0} END{l="Total";i=2;while(i in a){l=l" "a[i];i++};print l" X"}' $tdir/total_final2 > $tdir/total_final3
 tail -1 $tdir/total_final3 |awk '{print $1" X "$3" "$4" "$5" "$6" "$7" X "$9}' > $tdir/footer
 sed -i '$ d' $tdir/total_final3
 # Including header
 sed -i '1i\Token Amount USDT-free USDT-locked in-USDT in-BTC in-'$residential_country_currency' Last24hr Allocation' $tdir/total_final3
 # Fixing column versions compatibility due to -o, coloring, and printing
 msg "\n$(cat $tdir/total_final3 $tdir/footer |column -t $(column -h 2>/dev/null |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g; s/Token/\\033\[0;34mToken/g; s/Allocation/Allocation\\033\[0m/g; s/ (-[0-9\.]+%)/ \\033\[0;31m\1\\033\[0m/g; s/ ([0-9\.]+%)\ / \\033\[0;32m\1\ \\033\[0m/g' |tee $tdir/total_final4)\033[0m"

 if [[ $exchange == "all" ]] ; then
  echo -e "Exchange USDT BTC $residential_country_currency" > $tdir/total_per_exchange
  for exchange in `ls -1 ${tdir}/*_final |sed -E 's/(^.*\/|_final)//g'`; do
   echo -n "${exchange^}" >> $tdir/total_per_exchange
   awk '{usdt+=$5;btc+=$6;rcc+=$7} END{print " "usdt" "btc" "rcc}' ${tdir}/${exchange}_final >> $tdir/total_per_exchange
  done
  echo "Total $(tail -1 $tdir/total_final4 |awk -F'[| ]+' '{print $5" "$6" "$7}')" >> $tdir/total_per_exchange
  msg "\n$(cat $tdir/total_per_exchange |column -t $(column -h 2>/dev/null |grep -q "\-o," && printf '%s' -o ' | ') |sed 's/|/ | /g' |grep --color ".*")"
 fi
 if [ ! -z $fiat_deposits ]; then
  echo "Return Percentage $residential_country_currency" >> $tdir/total_result
  current_total=$(tail -1 $tdir/total_final4 |awk -F'[| ]+' '{print $7}')
  echo ">>>>> $(echo "scale=2;100 * $current_total / $fiat_deposits - 100" |bc -l)% $(echo "$current_total - $fiat_deposits" |bc -l)" >> $tdir/total_result
  msg "\n$(cat $tdir/total_result |column -t $(column -h 2>/dev/null |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g')"
 fi
 exit
fi

if [ ${param} == "order" ]; then

 if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$" && [ $exchange = "gateio" ]; then
   gateio_method="GET"
   gateio_query_string=""
   gateio_endpoint="api/v4/spot/currency_pairs"
   curl_gateio_public |jq -r '.[] |.id,.amount_precision,.precision' |paste - - - > $tdir/gateio_supported_pairs

 for symbol in `echo $symbol`; do

  if echo -n $binance_key$binance_secret |wc -c |grep -Eq "^128$" && [ $exchange == "binance" ]; then
   symbol=$(echo $symbol |sed 's/_//g')
   binance_method="POST"
   binance_endpoint="api/v3/order$test"
   timestamp=$(func_timestamp)
   binance_query_string="quoteOrderQty=$qty&symbol=$symbol&side=$side&type=MARKET&timestamp=$timestamp"
   binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
   curl_binance
  fi
 
  if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$" && [ $exchange = "gateio" ]; then
   if [ ! -z $test ]; then echo "Unfortunately, gate.io doesn't have a test endpoint, so here we are testing only our side"; fi
   read symbol amount_scale price_scale<<<$(grep -E "^${symbol}\s+" ${tdir}/gateio_supported_pairs || die "Currency pair not suported.")
   gateio_query_string="currency_pair=$symbol"
   gateio_endpoint="api/v4/spot/tickers"
   gateio_last_price=$(gateio_method="GET"; curl_gateio_public |jq -r '.[].last')
   if echo $side |grep -i sell; then calc="0.996"; else calc="1.004"; fi
   gateio_price=$(echo "scale=${price_scale}; $gateio_last_price * $calc" |bc -l |sed -E 's/^\./0./g')
   qty=$(echo "scale=${amount_scale}; $qty / 1" |bc -l |sed -E 's/^\./0./g')
   gateio_method="POST"
   gateio_query_string=""
   gateio_endpoint="spot/${test}order"
   gateio_body='{"currency_pair":"'$symbol'","side":"'${side}'","amount":"'$qty'","price":"'$gateio_price'"}'
   gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
   gateio_timestamp=$(date +%s)
   gateio_sign_string="$gateio_method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$gateio_timestamp"
   gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
   curl_gateio
  fi

  if echo -n $ftx_key$ftx_secret |wc -c |grep -Eq "^80$" && [ $exchange == "ftx" ]; then
   echo "implementing right now"
   exit
   if [ ! -z $test ]; then echo "Unfortunately, ftx doesn't have a test endpoint, so here we are testing only our side"; fi
    symbol=$(echo $symbol |sed 's/_/\//g')
    ftx_method="POST"
    ftx_endpoint="/api/${test}orders"
    ftx_timestamp=$(func_timestamp)
    ftx_query_string=""
    ftx_body='{"market":"'${symbol}'","side":"'${side}'","price": null,"type":"market","size":'${qty}'}'
    ftx_signature=$(echo -n "${ftx_timestamp}${ftx_method}${ftx_endpoint}${ftx_query_string}${ftx_body}" |openssl dgst -sha256 -hmac "$ftx_secret" |awk '{print $2}')
    curl_ftx
  fi
 done
 exit
fi
