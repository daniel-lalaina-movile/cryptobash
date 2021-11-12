#!/usr/bin/env bash

# https://github.com/daniel-lalaina-movile/cryptobash
export TERM=xterm

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name="./crypto.bash"
tdir=$script_dir/temp/$1
cp $script_dir/.rebalance $tdir/.rebalance
rebalance_file=$tdir/.rebalance

binance_uri="api.binance.com"
gateio_uri="api.gateio.ws"
ftx_uri="ftx.com"
source $script_dir/.credentials

residential_country_currency="BRL"
LC_NUMERIC="en_US.UTF-8"

usage() {
 cat << EOF
Usage: ${script_name} [-h] [-v] [-t] -p <order|overview|rebalance|runaway> arg1 [arg2...]

Available options:

-h, --help      Print this help.
-v, --verbose   Run with debug
-t, --test      Print the order payload instead of actually requesting the exchanges. (Works with "rebalance", "order" and "runaway" params)
-p, --param     Main action parameter
		-p overview  (show your balance)
		-p order  (buy/sell)
                -p runaway  (sell everything asap)
		-p rebalance  (rebalance your portfolio based on .rebalance file)

Examples:

Buy 50 USDT of ADA_USDT
$script_name -p order binance buy ADA_USDT 50
$script_name -p order gateio buy ADA_USDT 50
$script_name -p order ftx buy ADA_USDT 50

Show your balance.
$script_name -p overview

Show your balance details and close
$script_name -p overview

Show your balance details and reload it every 10 min.
$script_name -p overview 10

Send your balance totals to Telegram every 15 min.
$script_name -p overview telegram 10

Sell every token that you have, at market price.
$script_name -p runaway binance
$script_name -p runaway gateio
$script_name -p runaway ftx
$script_name -p runaway all

Rebalance all portifolio based on file .rebalance (You need to copy .rebalance-example to .rebalance and edit it.)
$script_name -p rebalance

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
  binance_query_string=""
  gateio_query_string=""
  gateio_body=""
  ftx_query_string=""
  ftx_body=""
  telegram="false"
  reload_time="0"
  binance_btcusdt=""

  while :; do
    case "${2-}" in
    -h | --help) usage;;
    -v | --verbose) set -x; progress_bar="false";;
    -t | --test) test="/test";;
    -p | --param)
      param="${3-}"
      shift
      ;;
    -?*) die "Unknown option: $2";;
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

  if [ "${param}" == "runaway" ]; then
   exchange=$(echo ${@-} |grep -oP "(binance|gateio|ftx|all)" || die "Exchange argument is required for param ${param}.\nEx\n${script_name} -p ${param} binance\n${script_name} -p ${param} gateio\n${script_name} -p ${param} ftx\n${script_name} -p ${param} all")

  elif [ "${param}" == "overview" ]; then
   if echo ${@-} |grep -q telegram; then telegram="true"; progress_bar="false"; fi
   if echo ${@-} |grep -Eq "\b[0-9]+\b"; then reload_time=$(echo "$(echo ${@-} |grep -oP "\b[0-9]+\b") * 60" |bc -l); fi

  elif [ "${param}" == "rebalance" ]; then
   [ -f $rebalance_file ] || die "Missing $rebalance_file"
   sed -E 's/\v\s+/ /g' $rebalance_file
   missing_tokens_action=$(echo ${@-} |grep -oP "(force|keep)" || echo "warn")

  elif [ ${param} == "order" ]; then
   side=$(echo ${@-} |grep -oP "\b(sell|buy)\b" || die "Side argument is required for param order.\nExamples:\n${script_name} -p order sell ADA_USDT 30")
   symbol=$(echo ${@-} |grep -oP "\b[A-Z0-9]+_(USDT|BTC)\b" || die "SYMBOL argument is required for param order. Examples\nTo sell 30 USDT of ADA:\n${script_name} -p order sell ADA_USDT 30\nTo buy 30 USDT of each ADA,SOL,LUNA:\n${script_name} -p order sell ADA_USDT,SOLUSDT,LUNAUSDT 30")
   qty=$(echo ${@-} |grep -oP "\b[0-9.]+\b" || die "QUOTEQTY argument (which is the amount you want to spend, not the ammount of coins you want to buy/sell) is required for param order.\nExamples:\n/$script_name -p order sell ADA_USDT 30")
   exchange=$(echo ${@-} |grep -oPi "(binance|gateio|ftx)" || die "Exchange argument is required for param order.\nExamples:\n${script_name} -p order binance sell ADA_USDT 30\n${script_name} -p order gateio sell ADA_USDT 30\n${script_name} -p order ftx sell ADA_USDT 30")

  else
   die "Missing main parameter: -p <order|overview|rebalance|runaway>"
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

progress_bar() {
 pid=$!
 banner
 sleep 0.1
 while kill -0 $pid 2> /dev/null; do
  for ((k = 0; k <= 30 ; k++)); do
   echo -n "[ "
   for ((i = 0 ; i <= k; i++)); do echo -n "\$\$\$\$"; done
   #for ((j = i ; j <= 30 ; j++)); do echo -n "   "; done
   v=$((k * 30))
   echo -n " ] "
   kill -0 $pid 2>/dev/null || break
   echo -n "$v %" $'\r'
   sleep 0.5
  done
 done
 cols=$(echo "$(tput cols) - 12" | bc -l)
 msg "\r[ $(for ((i=1; i<=${cols}; i++)); do echo -n "\$"; done) ] 10000 %"
}

func_timestamp() {
 echo -n $(($(date +%s%N)/1000000))
}

curl_fiat_usd_rate() {
 curl -s -H 'user-agent: Mozilla' -H 'Accept-Language: en-US,en;q=0.9,it;q=0.8' "https://www.google.com/search?q=1+usd+to+$residential_country_currency" |grep -oP "USD = [0-9]+\\.[0-9]+ $residential_country_currency" |head -n1 |grep -oP "[0-9]+\\.[0-9]+" |tr -d '\n'
 return
}

curl_telegram() {
 curl -s -H 'content-type: application/json' -d '{ "chat_id": '${telegram_chat_id}', "text": "```\n'"$(cat $tdir/total_per_exchange |column -t -o ' | ' |sed ':a;N;$!ba;s/\n/\\n/g')"'\n\n'"$(cat $tdir/total_result |column -t -o ' | ' |sed ':a;N;$!ba;s/\n/\\n/g')"'```", "parse_mode":"MarkdownV2" }' 'https://api.telegram.org/bot'${telegram_key}'/sendMessage' >/dev/null
 return
}

curl_binance() {
 curl -s -X $binance_method -H "X-MBX-APIKEY: $binance_key" "https://$binance_uri/$binance_endpoint?$binance_query_string&signature=$binance_signature"
 return
}

curl_binance_public() {
 curl -s "https://$binance_uri/$binance_endpoint?$binance_query_string"
 return
}

curl_gateio() {
 if [ -z $gateio_body ]; then
  curl -s -X $gateio_method -H "Timestamp: $gateio_timestamp" -H "KEY: $gateio_key" -H "SIGN: $gateio_signature" "https://$gateio_uri/$gateio_endpoint" |jq .
 else
  curl -s -X $gateio_method -H "Timestamp: $gateio_timestamp" -H "KEY: $gateio_key" -H "SIGN: $gateio_signature" -H 'Content-type: application/json' -d "${gateio_body}" "https://$gateio_uri/$gateio_endpoint" |jq .
 fi
 return
}

curl_gateio_public() {
 curl -s "https://$gateio_uri/$gateio_endpoint?$gateio_query_string"
 return
}

curl_ftx() {
 if [ -z $ftx_body ]; then
  curl -s -X $ftx_method -H "FTX-TS: $ftx_timestamp" -H "FTX-KEY: $ftx_key" -H "FTX-SIGN: $ftx_signature" "https://${ftx_uri}${ftx_endpoint}"
 else
  curl -s -X $ftx_method -H "FTX-TS: $ftx_timestamp" -H "FTX-KEY: $ftx_key" -H "FTX-SIGN: $ftx_signature" -H 'Content-type: application/json' -d "${ftx_body}" "https://${ftx_uri}${ftx_endpoint}"
 fi
 return
}

curl_ftx_public() {
 curl -s "https://${ftx_uri}${ftx_endpoint}$ftx_query_string"
 return
}

get_24hr() {
 if [[ $1 == "binance" ]]; then
  binance_endpoint="api/v3/ticker/24hr"
  curl_binance_public |jq -r '.[] | {symbol: .symbol, price: .lastPrice, last24hr: .priceChangePercent|tonumber} | select(.price!="0.00000000" and .price!="0.00" and .price!="0") | to_entries[] | .value' |paste - - - > $tdir/binance_24hr

 elif [[ $1 == "gateio" ]]; then
  gateio_endpoint="api/v4/spot/tickers"
  curl_gateio_public |jq -r '.[] | {symbol: .currency_pair, price: .last, last24hr: .change_percentage|tonumber} | select(.price!="0.00000000" and .price!="0.00" and .price!="0") | to_entries[] | .value' |sed 's/_//g' |paste - - - > $tdir/gateio_24hr

 elif [[ $1 == "ftx" ]]; then
  ftx_endpoint="/api/markets"
  curl_ftx_public |jq -r '.result | .[] | .name,.price,.change24h' |paste - - - |grep "/" |sed 's/\///g' > $tdir/ftx_24hr

 else
  die "$1 exchange doesn't exist"
 fi
 return
}

get_supported_pairs() {
 if [[ $1 == "binance" ]]; then
  binance_endpoint="api/v1/exchangeInfo"
  [ -f $tdir/binance_supported_pairs ] || \
    curl_binance_public |jq '.symbols | .[] | [{symbol: .symbol, filter: .filters}] | .[] |del(.filter[] | select(.filterType != "LOT_SIZE"))' |grep -E 'symbol|stepSize' |sed 's/^.*: "//g; s/".*//g' |paste - - > $tdir/binance_supported_pairs

 elif [[ $1 == "gateio" ]]; then
  gateio_endpoint="api/v4/spot/currency_pairs"
  [ -f $tdir/gateio_supported_pairs ] || \
  curl_gateio_public |jq -r '.[] |.id,.amount_precision,.precision' |paste - - - > $tdir/gateio_supported_pairs

 elif [[ $1 == "ftx" ]]; then
  ftx_endpoint="/api/markets"
  [ -f $tdir/ftx_supported_pairs ] || \
  curl_ftx_public |jq -r '.result |del(.[] | select(.type != "spot")) | .[] | .name,.sizeIncrement' |paste - - > $tdir/ftx_supported_pairs

 else
  die "$1 exchange doesn't exist"
 fi
 return
}

get_overview() {
 if [[ $1 == "binance" ]]; then
  binance_method="GET"
  binance_endpoint="sapi/v1/capital/config/getall"
  binance_timestamp=$(func_timestamp)
  binance_query_string="timestamp=$binance_timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance

 elif [[ $1 == "gateio" ]]; then
  gateio_method="GET"
  gateio_query_string=""
  gateio_endpoint="api/v4/spot/accounts"
  gateio_body=""
  gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
  gateio_timestamp=$(date +%s)
  gateio_sign_string="$gateio_method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$gateio_timestamp"
  gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
  curl_gateio

 elif [[ $1 == "ftx" ]]; then
  ftx_method="GET"
  ftx_endpoint="/api/wallet/balances"
  ftx_timestamp=$(func_timestamp)
  ftx_query_string=""
  ftx_body=""
  ftx_signature=$(echo -n "${ftx_timestamp}${ftx_method}${ftx_endpoint}${ftx_query_string}${ftx_body}" |openssl dgst -sha256 -hmac "$ftx_secret" |awk '{print $2}')
  curl_ftx

 else
  die "$1 exchange doesn't exist"
 fi
 return
}

new_order() {
if [[ $1 == "binance" ]]; then
  if [[ $4 == "quoteQty" ]]; then qtyType="quoteOrderQty"; qty=$5; elif [[ $4 == "baseQty" ]]; then qtyType="quantity"; else die "Unknown $1 qtyType"; fi
  get_supported_pairs binance
  read token_pair stepSize<<<$(grep -E "^${3}\s+" $tdir/binance_supported_pairs || grep -E "^${3}USDT\s+" $tdir/binance_supported_pairs || grep -E "^${3}BTC\s+" $tdir/binance_supported_pairs)
  if [ $qtyType == "quantity" ]; then
   stepSize=$(echo $stepSize |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   decimal=$(echo "1 / $stepSize" |bc -l |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
   qty_dec=$(echo "$qty * $decimal" |bc -l |sed -E 's/\..*//g')
   qty=$(echo "$qty_dec / $decimal" |bc -l |sed -E 's/\.0+$//g; s/^\./0./g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
  elif [ $qtyType == "quoteOrderQty" ]; then
   if echo $token_pair |grep -q "BTC$"; then
    binance_endpoint="api/v3/ticker/price"
    binance_query_string="symbol=BTCUSDT"
    if [ -z $binance_btcusdt ]; then binance_btcusdt=$(curl_binance_public |jq -r .price); fi
    qty=$(echo "$qty / $binance_btcusdt" |bc -l |sed -E 's/^\./0./g; s/\.([0-9]{4}).*/.\1/g') 
   elif echo $token_pair |grep -q "USDT$"; then
    qty=$(echo "$qty" |sed 's/\..*//g')
   else
    die "unsupported quote pair"
   fi
  else
   die "unsupported quote pair"
  fi
  #if echo "$qty < $stepSize" |bc -l |grep -q "^1$"; then return 0; fi
  binance_method="POST"
  binance_endpoint="api/v3/order$test"
  binance_timestamp=$(func_timestamp)
  binance_query_string="$qtyType=$qty&symbol=${token_pair}&side=$2&type=MARKET&timestamp=$binance_timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  if [ ! -z $test ]; then echo $binance_query_string; else curl_binance |jq .; fi

elif [[ $1 == "gateio" ]]; then
  get_supported_pairs gateio
  read token_pair amount_scale price_scale<<<$(grep -E "^${3}\s+" $tdir/gateio_supported_pairs || grep -E "^${3}_USDT\s+" ${tdir}/gateio_supported_pairs || grep -E "^${3}_BTC\s+" $tdir/gateio_supported_pairs)
  if echo $token_pair |grep -q "BTC$"; then
   binance_endpoint="api/v3/ticker/price"
   binance_query_string="symbol=BTCUSDT"
   if [ -z $gateio_btcusdt ]; then gateio_btcusdt=$(curl_binance_public |jq -r .price); fi
   qty=$(echo "$qty / $gateio_btcusdt" |bc -l) 
  fi
  gateio_query_string="currency_pair=$token_pair"
  gateio_endpoint="api/v4/spot/tickers"
  gateio_last_price=$(curl_gateio_public |jq -r '.[].last')
  if [[ $4 == "baseQty" ]]; then qty="$5"; elif [[ $4 == "quoteQty" ]]; then qty=$(echo "$5 / $gateio_last_price" | bc -l); else die "Unknown $1 qtyType" ; fi
  if [ $2 == "buy" ]; then calc_price=1.01; else calc_price=0.99; fi
  gateio_price=$(echo "scale=${price_scale}; $gateio_last_price * $calc_price" |bc -l |sed -E 's/^\./0./g')
  qty=$(echo "scale=${amount_scale}; $qty / 1" |bc -l |sed -E 's/^\./0./g')
  gateio_method="POST"
  gateio_query_string=""
  gateio_endpoint="api/v4/spot/${test}orders"
  gateio_body='{"currency_pair":"'$token_pair'","side":"'$2'","amount":"'$qty'","price":"'$gateio_price'"}'
  gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
  gateio_timestamp=$(date +%s)
  gateio_sign_string="$gateio_method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$gateio_timestamp"
  gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
  if [ ! -z $test ]; then echo $gateio_body; else curl_gateio |jq .; fi

elif [[ $1 == "ftx" ]]; then
  get_supported_pairs ftx
  read token_pair sizeIncrement<<<$(grep -E "^${3}\s+" $tdir/ftx_supported_pairs || grep -E "^${3}\/USDT?\s+" $tdir/ftx_supported_pairs || grep -E "^${3}\/BTC\s+" $tdir/ftx_supported_pairs)
  if echo $token_pair |grep -q "BTC$"; then
   binance_endpoint="api/v3/ticker/price"
   binance_query_string="symbol=BTCUSDT"
   if [ -z $ftx_btcusdt ]; then ftx_btcusd=$(curl_binance_public |jq -r .price); fi
   qty=$(echo "$qty / $ftx_btcusd" |bc -l) 
  fi
  ftx_endpoint="/api/markets"
  ftx_query_string="/$token_pair"
  ftx_last_price=$(curl_ftx_public |jq .result.last)
  if [[ $4 == "baseQty" ]]; then qty="$5"; elif [[ $4 == "quoteQty" ]]; then qty=$(echo "$5 / $ftx_last_price" | bc -l); else die "Unknown $1 qtyType" ; fi
  # scientific notation to regular float
  qty=$(echo $qty |awk '{printf "%F",$1+0}')
  sizeIncrement=$(echo $sizeIncrement |awk '{printf "%F",$1+0}')
  if echo "$qty < $sizeIncrement" |bc -l |grep -q 1; then return 0; fi
  stepSize=$(echo $sizeIncrement |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
  decimal=$(echo "1 / $sizeIncrement" |bc -l |sed -E 's/\.0+$//g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
  qty_dec=$(echo "$qty * $decimal" |bc -l |sed -E 's/\..*//g') 
  qty=$(echo "$qty_dec / $decimal" |bc -l |sed -E 's/\.0+$//g; s/^\./0./g; s/(\.[0-9]+?[1-9]+)[0]+$/\1/g')
  ftx_method="POST"
  ftx_endpoint="/api/${test}orders"
  ftx_timestamp=$(func_timestamp)
  ftx_query_string=""
  ftx_body='{"market":"'${token_pair}'","side":"'$2'","price": null,"type":"market","size":'${qty}'}'
  ftx_signature=$(echo -n "${ftx_timestamp}${ftx_method}${ftx_endpoint}${ftx_query_string}${ftx_body}" |openssl dgst -sha256 -hmac "$ftx_secret" |awk '{print $2}')
  if [ ! -z $test ]; then echo $ftx_body; else curl_ftx |jq .; fi

else
  die "$1 exchange doesn't exist"
fi
return
}
if [ ${param} == "order" ]; then
 if [[ $exchange == "binance" ]]; then symbol=$(echo $symbol |sed 's/_//g'); fi
 if [[ $exchange == "ftx" ]]; then symbol=$(echo $symbol |sed 's/_/\//g; s/\/USDT/\/USDT?/g'); fi
 new_order $exchange $side $symbol quoteQty $qty
 exit
fi

overview() {
 #rm -f $tdir/*
 read usdtusd<<<$(curl -s -m3 'https://'$gateio_uri'/api/v4/spot/tickers?currency_pair=USDT_USD' |jq -r .[].last || echo 1)
 fiat_deposits=$(awk '{dep+=$1}END{print dep}' $script_dir/.fiat_deposits 2>/dev/null &)
 $(

 if [ $residential_country_currency == "USD" ]; then
  fiat_usd_rate=1
 else
  curl_fiat_usd_rate > $tdir/fiat_usd_rate
  fiat_usd_rate=$(cat $tdir/fiat_usd_rate)
 fi

 if echo -n $binance_key$binance_secret |wc -c |grep -Eq "^128$"; then
  get_overview binance |jq -r ' .[] | select(.free!="0" or .locked!="0") | .coin,.free,.locked' |paste - - - > $tdir/binance_overview
  get_24hr binance
  binance_btcusdt=$(grep -E "^BTCUSDT\b" $tdir/binance_24hr |awk '{print $2}')
  cat $tdir/binance_overview |while read symbol available locked; do
   amount=$(echo "$available + $locked" | bc -l)
   if grep -q "^${symbol}USDT" $tdir/binance_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/binance_24hr |awk '{print $2,$3}')
   elif [[ ${symbol} =~ USDT|BUSD|USDC ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/binance_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/binance_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${binance_btcusdt}" |bc -l)
   else
    [ $residential_country_currency == $symbol ] || die "Didn't find any pair for $symbol on binance"
   fi
   usdt_available=$(echo "scale=2; ($available * $usdt_pair_price) / 1" |bc -l)
   usdt_locked=$(echo "scale=2; ($locked * $usdt_pair_price) / 1" |bc -l)
   usdt_total=$(echo "scale=2; ($usdt_available + $usdt_locked) / 1" |bc -l)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$(echo "scale=2; ($usdt_total * $usdtusd) / 1" |bc -l)
   elif [ $residential_country_currency == $symbol ]; then
    fiat_total=$(echo "scale=2; ($available + $locked) / 1" |bc -l)
    usdt_available=$(echo "scale=2; ($available / $fiat_usd_rate) / 1" |bc -l)
    usdt_locked=$(echo "scale=2; ($locked / $fiat_usd_rate) / 1" |bc -l)
    usdt_total=$(echo "scale=2; ($usdt_available + $usdt_locked) / 1" |bc -l)
   else
    fiat_total=$(echo "scale=2; ($usdt_total * $usdtusd * $fiat_usd_rate) / 1" |bc -l)
   fi
   btc_total=$(echo "scale=8; $usdt_total / $binance_btcusdt" |bc -l)
   last24hr=$(echo "scale=2; $last24hr / 1" | bc -l)
   echo "Binance $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr%" >> $tdir/binance_final
  done
 fi &

 if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$"; then
  get_overview gateio |jq -r ' .[] | select(.available!="0" or .locked!="0") |.currency,.available,.locked' |paste - - - > $tdir/gateio_overview
  get_24hr gateio
  gateio_btcusdt=$(grep -E "^BTCUSDT\b" $tdir/gateio_24hr |awk '{print $2}')
  cat $tdir/gateio_overview |while read symbol available locked; do
   amount=$(echo "$available + $locked" | bc -l)
   if grep -q "^${symbol}USDT" $tdir/gateio_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/gateio_24hr |awk '{print $2,$3}')
   elif [[ ${symbol} =~ USDT|BUSD|USDC ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/gateio_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/gateio_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${gateio_btcusdt}" |bc -l)
   else
    [ $residential_country_currency == $symbol ] || die "Didn't find any pair for $symbol on binance"
   fi
   usdt_available=$(echo "scale=2; ($available * $usdt_pair_price) / 1" |bc -l)
   usdt_locked=$(echo "scale=2; ($locked * $usdt_pair_price) / 1" |bc -l)
   usdt_total=$(echo "scale=2; ($usdt_available + $usdt_locked) / 1" |bc -l)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$(echo "scale=2; ($usdt_total * $usdtusd) / 1" |bc -l)
   elif [ $residential_country_currency == $symbol ]; then
    fiat_total=$(echo "scale=2; ($available + $locked) / 1" |bc -l)
    usdt_available=$(echo "scale=2; ($available / $fiat_usd_rate) / 1" |bc -l)
    usdt_locked=$(echo "scale=2; ($locked / $fiat_usd_rate) / 1" |bc -l)
    usdt_total=$(echo "scale=2; ($usdt_available + $usdt_locked) / 1" |bc -l)
   else
    fiat_total=$(echo "scale=2; ($usdt_total * $usdtusd * $fiat_usd_rate) / 1" |bc -l)
   fi
   btc_total=$(echo "scale=8; $usdt_total / $gateio_btcusdt" |bc -l)
   last24hr=$(echo "scale=2; $last24hr / 1" | bc -l)
   echo "Gateio $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr%" >> $tdir/gateio_final
  done
 fi &

 if echo -n $ftx_key$ftx_secret |wc -c |grep -Eq "^80$"; then
  get_overview ftx |jq -r '.result | .[] |select(.total!=0) | .coin,.free,.total,.usdValue' |paste - - - - > $tdir/ftx_overview
  get_24hr ftx
  ftx_btcusdt=$(grep -E "^BTCUSDT\b" $tdir/ftx_24hr |awk '{print $2}')
  cat $tdir/ftx_overview |while read symbol available total usd; do
   amount=$total
   if grep -q "^${symbol}USDT" $tdir/ftx_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/ftx_24hr |awk '{print $2,$3}')
   elif grep -q "^${symbol}USD" $tdir/ftx_24hr; then
    read usd_pair_price last24hr <<<$(grep "^${symbol}USD" $tdir/ftx_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$usd_pair_price / ${usdtusd}" |bc -l)
   elif [[ ${symbol} =~ ^(USD|USDT|BUSD|USDC)$ ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/ftx_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/ftx_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${ftx_btcusdt}" |bc -l)
   else
    [ $residential_country_currency == $symbol ] || die "Didn't find any pair for $symbol on binance"
   fi
   usdt_available=$(echo "scale=2; ($available * $usdt_pair_price) / 1" |bc -l)
   usdt_locked=$(echo "scale=2; (($total - $available) * $usdt_pair_price) / 1" |bc -l)
   usdt_total=$(echo "scale=2; ($usdt_available + $usdt_locked) / 1" |bc -l)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$usd
   elif [ $residential_country_currency == $symbol ]; then
    fiat_total=$(echo "scale=2; ($available + $locked) / 1" |bc -l)
    usdt_available=$(echo "scale=2; ($available / $fiat_usd_rate) / 1" |bc -l)
    usdt_locked=$(echo "scale=2; ($locked / $fiat_usd_rate) / 1" |bc -l)
    usdt_total=$(echo "scale=2; ($usdt_available + $usdt_locked) / 1" |bc -l)
   else
    fiat_total=$(echo "scale=2; ($usdt_total * $usdtusd * $fiat_usd_rate) / 1" |bc -l)
   fi
   btc_total=$(echo "scale=8; $usdt_total / $ftx_btcusdt" |bc -l)
   last24hr=$(echo "scale=2; $last24hr / 1" | bc -l)
   echo "Ftx $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr%" >> $tdir/ftx_final
  done
 fi
 ) &

 if [ $progress_bar == "true" ]; then progress_bar; else wait; fi

 # Including percentage allocation column.
 awk '{b[$0]=$6;sum=sum+$6} END{for (i in b) print i, (b[i]/sum)*100"%"}' $tdir/*_final |sort -n -k6 > $tdir/total_final_all
 # Scaling percentages and removing insignificant amounts
 sed -Ei 's/ (-)?\./ \10./g; s/\.0+ / /g; s/(\.[0-9]+?[1-9]+)[0]+ /\1 /g; s/(\.[0-9]{2})[0-9]+?%/\1%/g; /([e-]|0\.0| 0)[0-9]+?%$/d' $tdir/total_final_all
 # Including header
 sed -i '1i\Exchange Token Amount USDT-free USDT-locked in-USDT in-BTC in-'$residential_country_currency' Last24hr Allocation' $tdir/total_final_all

 # Fixing column versions compatibility due to -o, coloring, and printing
 msg "\n$(cat $tdir/total_final_all |column -t $(column -h 2>/dev/null |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g; s/Exchange/\\033\[0;34mExchange/g; s/Allocation/Allocation\\033\[0m/g; s/ (-[0-9\.]+%)/ \\033\[0;31m\1\\033\[0m/g; s/ ([0-9\.]+%) / \\033\[0;32m\1 \\033\[0m/g')\033[0m"

 echo -e "Exchange USDT BTC $residential_country_currency" > $tdir/total_per_exchange
 for exchange in `ls -1 ${tdir}/*_final |sed -E 's/(^.*\/|_final)//g'`; do
  awk '{exchange=$1;usdt+=$6;btc+=$7;rcc+=$8} END{print exchange" "usdt" "btc" "rcc}' ${tdir}/${exchange}_final >> $tdir/total_per_exchange
 done
 echo "Total $(awk '{usdt+=$6;btc+=$7;rcc+=$8} END{print " "usdt" "btc" "rcc}' ${tdir}/*_final)" >> $tdir/total_per_exchange
 msg "\n$(cat $tdir/total_per_exchange |column -t $(column -h 2>/dev/null |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g; s/Exchange/\\033\[0;34mExchange/g; s/'${residential_country_currency}'/'${residential_country_currency}'\\033\[0m/g')"

 if [ ! -z $fiat_deposits ]; then
  echo "Return Percentage $residential_country_currency" >> $tdir/total_result
  current_total=$(tail -1 $tdir/total_per_exchange |awk -F'[| ]+' '{print $4}')
  echo ">>>>> $(echo "scale=2;100 * $current_total / $fiat_deposits - 100" |bc -l)% $(echo "$current_total - $fiat_deposits" |bc -l)" >> $tdir/total_result
  msg "\n$(cat $tdir/total_result |column -t $(column -h 2>/dev/null |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g; s/Return/\\033\[0;34mReturn/g; s/'${residential_country_currency}'/'${residential_country_currency}'\\033\[0m/g')"
 fi

 echo -en "\n$(date)\n"
  if [ $residential_country_currency != "USD" ]; then echo -e "USD rate: $(cat $tdir/fiat_usd_rate)\n"; fi

 if [ $telegram == "true" ]; then curl_telegram; fi
 return
}
if [ ${param} == "overview" ]; then
 if [ $reload_time == "0" ]; then
  overview
  exit
 else
  while true; do
   overview
   sleep $reload_time
  done
 fi
fi

rebalance() {
 # Run overview first to see what we have today.
 overview >/dev/null 2>&1
 echo ""
 # We never touch PAXG
 sed -Ei '/PAXG/d' $tdir/total_final_all && echo "We never touch PAXG"
 # Getting current assets and its exchange/USDT values from $tdir/total_final_all generated by overview
 cut -d' ' -f1,2,6 $tdir/total_final_all |sed -E '/e-/d; s/^./\L&\E/; s/\.[0-9]+$//g' |grep -v "^exchange" |sort > $tdir/current_assets
 # Getting wanted exchange/tokens and current exchange/tokens.
 cut -d' ' -f1,2 $rebalance_file |sort > $tdir/goal_tokens
 cut -d' ' -f1,2 $tdir/current_assets > $tdir/current_tokens
 # Are all current tokens in the goal?
 if grep -vf $tdir/goal_tokens $tdir/current_tokens > $tdir/tokens_not_in_file; then
  if [ $missing_tokens_action == "warn" ]; then 
  cat $tdir/tokens_not_in_file
  die "The assets above are not in your rebalance file\nPlease:\n- If you want to keep them, run again with keep argument. ( ${param} keep )\n- If you want to keep some of them, take a look at your balance detais, include them in the rebalance file with the same USDT amount, and run again with force argument. ( ${param} force )- If you want to sell all of them, run again with keep argument. ( ${param} force )"
  elif [ $missing_tokens_action == "force" ]; then
   # Let's put them in rebalance file with 0 USDT goal.
   cat $tdir/tokens_not_in_file |sed -E 's/$/ 0/g' >> $rebalance_file
  elif [ $missing_tokens_action == "keep" ]; then
   # Delete from current assets because we are not going to move them, and we are not going to use its $USDTs
   cat $tdir/tokens_not_in_file |while read exchange token; do sed -Ei '/'"${exchange} ${token}"'\b/d' $tdir/current_assets; done
  fi
 fi
 for exchange in `ls -1 ${tdir}/*_final |sed -E 's/(^.*\/|_final)//g'`; do
  grep -Eq "^${exchange}" $rebalance_file || continue
  exchange_total_rebalance=$(grep -E "^${exchange}" $rebalance_file |awk '{sum+=$3}END{print sum}' |sed 's/\..*//g')
  exchange_total_current=$(grep -E "^${exchange}" $tdir/current_assets |awk '{sum+=$3}END{print sum}' |sed 's/\..*//g')

  if [ $exchange_total_rebalance -gt $exchange_total_current ]; then
   echo -e "\nNot enought funds to achieve your $exchange goal.\nCurrent: ${exchange_total_current}\nRebalance: ${exchange_total_rebalance}.\n"
   continue
  else
   grep -E "^${exchange}" $rebalance_file |while read xxx token usdt_wanted; do
    usdt_current=$(grep -E "^${exchange} ${token}\b" $tdir/current_assets |grep -oP '[0-9\.]+$' || echo 0)
    diff=$(echo "scale=0; ($usdt_current - $usdt_wanted) / 1" | bc -l)
    echo $exchange $token $diff >> $tdir/${exchange}_rebalance
   done
  fi

  sort -n -k3 $tdir/${exchange}_rebalance |tac |while read exchange token diff; do
   if [ "$token" == "${residential_country_currency}" ]; then
    echo "Skipping FIAT funds. $residential_country_currency"
   elif [[ ${token} =~ ^(USD|USDT|BUSD|USDC)$ ]]; then
    echo "Skipping stable coin $token."
   else
    side=$(echo $diff |sed -E 's/^[0-9\.].*/sell/g; s/^-.*/buy/g')
    qty=$(echo $diff |sed -E 's/^-//g')
    if [ $qty -lt 20 ]; then
     echo "Skipping $exchange $token because the diference is less then 20 bucks"
     continue
    fi
    new_order $exchange $side $token quoteQty $qty
    sleep 1
   fi
  done 

 done
}
if [ ${param} == "rebalance" ]; then
 rebalance
 exit
elif [ ${param} == "runaway" ]; then
 missing_tokens_action="force"
 touch $tdir/fake_rebalance_file
 rebalance_file="$tdir/fake_rebalance_file"
 rebalance
 exit
fi
