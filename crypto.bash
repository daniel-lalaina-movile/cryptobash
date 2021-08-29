#!/usr/bin/env bash
# v2.2.2
# https://gist.github.com/daniel-lalaina-movile/5641c4299a87ac2f510bf4900522e2e3

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name=$(basename "${BASH_SOURCE[0]}")
temp_dir=$script_dir/temp

binance_uri="api.binance.com"
gateio_uri="api.gateio.ws"
source $script_dir/.credentials

usage() {
  cat << EOF
Usage: $script_name [-h] [-v] [-t] -p <order|balance|runaway> arg1 [arg2...]

Available options:

-h, --help      Print this help.
-v, --verbose   Run with debug
-t, --test      Use Binance test endpoint. (Works with "order" or "runaway" params)
-p, --param     [balance|order|runaway]
-w, --web	Turn off progress bar. (To use with shell2http and display on web) (TODO: Explain how to use shell2http)

Examples:

Buy 50 USDT of ADAUSDT (Currently you can buy only XXX/USDT or XXX/BTC).
$script_name -p order <exchange> <SIDE> <SYMBOL> <QUOTEQTY> (Ex: -p binace order BUY ADAUSDT 50)

Show your balance.
$script_name -p balance

Sell every coin you have, at market price.
$script_name -p runaway

EOF
exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m'
  else
    NOFORMAT='' RED='' GREEN='' BLUE='' RED=''
  fi
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
  test=""
  method="GET"
  param=''
  web="false"

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -t | --test) test="/test";;
    -w | --web) web="true";;
    -p | --param)
      param="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  if [[ "${param}" != @(order|balance|runaway) ]]; then die "Missing required parameter: -p <order|balance|runaway>"; fi
  if [ ${param} == "order" ]; then
   side=$(echo ${@-} |grep -oP "(SELL|BUY)" || die "SIDE argument is required for param order. Ex -p order SELL ADAUSDT 30")
   symbol=$(echo ${@-} |grep -oP "[A-Z]+(USDT|BTC)" || die "SYMBOL argument is required for param order. Ex -p order SELL ADAUSDT 30")
   qty=$(echo ${@-} |grep -oP "[0-9.]+" || die "QUOTEQTY argument is required for param order. Ex -p order SELL ADAUSDT 30")
   exchange=$(echo ${@-} |grep -oPi "(binance|gateio)" || die "Exchange argument is required for param order. Ex\n-p order binance SELL ADAUSDT 30\n-p order gateio SELL ADAUSDT 30\n -p order binance-gateio SELL ADAUSDT 30")
  fi
  #[[ ${#args[@]} -ne 3 ]] && [ ${param} == "order" ] && die "Missing required arguments for param order, which are <quoteOrderQty> <symbol> <side>"

  return 0
}

parse_params "$@"
setup_colors

banner() {
tput clear
msg "
██████╗ ██╗      ██████╗  ██████╗██╗  ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██║  ██║██╔══██╗██║████╗  ██║
██████╔╝██║     ██║   ██║██║     █████╔╝ ██║     ███████║███████║██║██╔██╗ ██║
██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║     ██╔══██║██╔══██║██║██║╚██╗██║
██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
                                                                              
            ██████╗  ██████╗  ██████╗██╗  ██╗███████╗                         
            ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝                         
            ██████╔╝██║   ██║██║     █████╔╝ ███████╗                         
            ██╔══██╗██║   ██║██║     ██╔═██╗ ╚════██║                         
            ██║  ██║╚██████╔╝╚██████╗██║  ██╗███████║                         
            ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝                         
"
}
banner

# Checking exchange keys
echo -n "$binance_key$binance_secret" |wc -c |grep -Eq "^128$|^0$" || die "Invalid binance_key/binance_secret, if you don't have account in this exchange, please leave both fields empty"
echo -n "$gateio_key$gateio_secret" |wc -c |grep -Eq "^96$|^0$" || die "Invalid gateio_key/gateio_secret, if you don't have account in this exchange, please leave both fields empty"
echo -n "$gateio_key$gateio_secret$binance_key$binance_secret" |wc -c |grep -Eq "^0$" && die "You must configure a pair of key/secret for at least one of the exchanges."

progress_bar() {
 pid=$!
 while kill -0 $pid 2> /dev/null; do
  i=0; c=-1
  while kill -0 $pid 2> /dev/null; do
   i=$(($i+1))
   j=$i
   c=$(($(tput cols)-3))
   tput sc
   printf "[$(for((k=0;k<j;k++));do printf "\$\$";done;)>";tput cuf $((c-j));printf "]"
   tput rc
   sleep 0.3
   if [ $i == $c ]; then break; fi
  done
 printf "[";printf '%0.s$' $(seq 1 $(($(tput cols)-3)));printf "]"
 echo
 done
}

func_timestamp() {
 echo -n $(($(date +%s%N)/1000000))
}

curl_binance() {
 curl -s -X $method -H "X-MBX-APIKEY: $binance_key" "https://$binance_uri/$binance_endpoint?$binance_query_string&signature=$binance_signature"
}

curl_binance_price() {
 curl -s -X $method 'https://'$binance_uri'/api/v3/ticker/price?symbol='$symbol'USDT' |grep -oP "[0-9]+\.[0-9]+" || \
 echo `curl -s $method 'https://'$binance_uri'/api/v3/ticker/price?symbol='$symbol'BTC' |grep -oP "[0-9]+\.[0-9]+"` \* `curl -s $method 'https://'$binance_uri'/api/v3/ticker/price?symbol=BTCUSDT' |grep -oP "[0-9]+\.[0-9]+"` |bc -l
}

curl_gateio() {
 curl -s -X $method -H "Timestamp: $timestamp" -H "KEY: $gateio_key" -H "SIGN: $gateio_signature" "https://$gateio_uri/$gateio_endpoint?"
}

curl_gateio_price() {
 curl -s -X $method 'https://'$gateio_uri'/api/v4/spot/tickers?currency_pair='$symbol'_USDT' |jq '.[].last' |grep -oP "[0-9]+\.[0-9]+" || \
 echo `curl -s -X $method 'https://'$gateio_uri'/api/v4/spot/tickers?currency_pair='$symbol'_BTC' |jq '.[].last' |grep -oP "[0-9]+\.[0-9]+"` \* `curl -s -X $method 'https://'$gateio_uri'/api/v4/spot/tickers?currency_pair=BTC_USDT' |jq '.[].last' |grep -oP "[0-9]+\.[0-9]+"` |bc -l
}

if [ ${param} == "runaway" ]; then
 read -p "Are you sure? This will convert all your assets to USDT (y/n)" -n 1 -r
 if [[ $REPLY =~ ^[Yy]$ ]]; then
  binance_endpoint="sapi/v1/capital/config/getall"
  timestamp=$(func_timestamp)
  binance_query_string="timestamp=$timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance |jq '.[] |{coin: .coin, free: .free} | select(.free|tonumber>0.0001)' |grep -oP "[A-Z0-9.]+" |sed '/USDT/,+1d' |paste - - |while read symbol qty; do
   binance_endpoint="api/v3/order$test"
   timestamp=$(func_timestamp)
   binance_query_string="quantity=$qty&symbol=$symbol&side=SELL&type=MARKET&timestamp=$timestamp"
   binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}') 
   curl_binance
  done
 fi
 exit
fi

if [ ${param} == "balance" ]; then
 rm -f $temp_dir/total_balance_*
 $(
 if echo -n $binance_key$binance_secret |wc -c |grep -Eq "^128$"; then
  binance_endpoint="sapi/v1/capital/config/getall"
  timestamp=$(func_timestamp)
  binance_query_string="timestamp=$timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance |jq '.[] |{coin: .coin, free: .free, locked: .locked} | select((.free|tonumber>0.0001) or (.locked|tonumber>0.001))' |grep -oP "[A-Z0-9.]+" |paste - - - |awk '{print $1"\t"$2+$3}' |while read symbol qty; do
   if [ $symbol == "USDT" ]; then echo -e "USDT\\t$qty" >> $temp_dir/total_balance_binance; continue; fi
   in_usdt=$(echo "scale=2; ($(curl_binance_price) * $qty)/1" |bc -l)
   echo -e "$symbol\\t$in_usdt" >> $temp_dir/total_balance_binance
  done
 fi

 if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$"; then
  gateio_query_string=""
  gateio_body=""
  gateio_endpoint="api/v4/spot/accounts"
  gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
  timestamp=$(date +%s)
  gateio_sign_string="$method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$timestamp"
  gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
  curl_gateio |jq '.[] |{currency: .currency, available: .available, locked: .locked}' |grep -oP "[A-Z0-9.]+" |paste - - - |awk '{print $1"\t"$2+$3}' |while read symbol qty; do
   if [ $symbol == "USDT" ]; then echo -e "USDT\\t$qty" >> $temp_dir/total_balance_gateio; continue; fi
   in_usdt=$(echo "scale=2; ($(curl_gateio_price) * $qty)/1" |bc -l)
   echo -e "$symbol\\t$in_usdt" >> $temp_dir/total_balance_gateio
  done
 fi
 ) &
 if [ $web == "false" ]; then progress_bar; else wait; fi

 # Unifying and summing up the amounts of same assets from multiple exchanges. And sorting.
 awk -F'\t' '{x[$1]+=$2} END{for(i in x) printf("%s\t%d\n", i, x[i])}' $temp_dir/total_balance_* |sort -n -k2 > $temp_dir/total_balance
 # Including footer Total with the sum of column 2
 echo -e "Total\\t`awk -F'\t' '{sum+=$2;} END{print sum;}' $temp_dir/total_balance`" >> $temp_dir/total_balance
 # Including header and percentage column. And printing.
 msg "\\n${BLUE}`awk -F'\t' 'BEGIN{printf "Crypto\tUSDT\tAllocation\n"}{a[++i]=$1;b[i]=$2};/Total/{for(j=1;j<=i;++j)printf "%s\t%.2f\t%.2f%%\n",a[j],b[j],(b[j]*100/$2)}' $temp_dir/total_balance |column -ts $'\t'`\\n${NOFORMAT}"

 exit
fi

if [ ${param} == "order" ]; then

 if echo $exchange |grep "binance"; then
  method="POST"
  binance_endpoint="api/v3/order$test"
  timestamp=$(func_timestamp)
  binance_query_string="quoteOrderQty=$qty&symbol=$symbol&side=$side&type=MARKET&timestamp=$timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance
 fi

 if echo $exchange |grep "gateio"; then
  # TODO
  echo "gateio order is not supported yet. I'm still thinking about it, cause they don't support orders at MARKET price :-("
 fi

 exit
fi
