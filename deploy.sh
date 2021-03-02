#!/bin/bash

readonly DEPLOY_PATH="${PWD}"

export PATH=${DEPLOY_PATH}/images/bin:$PATH
export FABRIC_CFG_PATH=${DEPLOY_PATH}/config

#set -euo pipefail

. scripts/utils.sh
. scripts/config.sh
. scripts/envVar.sh

. scripts/check.sh
. scripts/channel.sh
. scripts/network.sh
. scripts/ca.sh
. scripts/chaincode.sh

if ! check_env; then
  fatalln "Unable to start network"
fi

## Parse mode
if [[ $# -lt 1 ]]; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

while [[ $# -ge 1 ]]; do
  key="$1"
  case $key in
  -h)
    printHelp $MODE
    exit 0
    ;;

  *)
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done


if [ "${MODE}" == "up" ]; then
  CHAINCODE clean
  NETWORK clean
  NETWORK start
elif [ "${MODE}" == "cc" ]; then
  CHAINCODE clean
  CHAINCODE start
elif [ "${MODE}" == "ca" ]; then
  CA start
elif [ "${MODE}" == "downCA" ]; then
  CA clean
elif [ "${MODE}" == "clean" ]; then
  CHAINCODE clean
  NETWORK clean
else
  printHelp
  exit 1
fi
