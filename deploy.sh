#!/bin/bash

readonly DEPLOY_PATH="${PWD}"

export PATH=${DEPLOY_PATH}/images/bin:$PATH
export FABRIC_CFG_PATH=${DEPLOY_PATH}/config

#set -euo pipefail

. scripts/utils.sh
. scripts/config.sh
. scripts/envVar.sh

. scripts/check.sh
. scripts/network.sh
. scripts/channel.sh
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

function parseConfig() {

  if [ "X${CRYPTO}" != "XCA" ] && [ "X${CRYPTO}" != "XCRYPTOGEN" ]; then
      fatalln "config CRYPTO 只能为'CA'或者'CRYPTOGEN'。"
  fi

  if [ "X${CHANNEL_NAME}" == "X" ]; then
    fatalln "config CHANNEL_NAME 不能为空。"
  fi
  infoln "CHANNEL_NAME=${CHANNEL_NAME}"
  if [ "X${PROFILE_GENESIS}" == "X" ]; then
    fatalln "config PROFILE_GENESIS 不能为空。"
  fi
  infoln "PROFILE_GENESIS=${PROFILE_GENESIS}"

  if [ "X${IMAGE_TAG}" == "X" ]; then
    fatalln "config IMAGE_TAG 不能为空。"
  fi
  infoln "IMAGE_TAG=${IMAGE_TAG}"
  if [ "X${BASE_DOMAIN}" == "X" ]; then
    fatalln "config BASE_DOMAIN 不能为空。"
  fi
  infoln "BASE_DOMAIN=${BASE_DOMAIN}"

  orderer_parseConfig
  peer_parseConfig
  CC_parseConfig

}

# 检查参数配置
parseConfig


if [ "${MODE}" == "up" ]; then
  NETWORK start
elif [ "${MODE}" == "createChannel" ]; then
  CHANNEL start
elif [ "${MODE}" == "deployCC" ]; then
  CHAINCODE start
elif [ "${MODE}" == "clean" ]; then
  CHAINCODE clean
  CHANNEL clean
  NETWORK clean
else
  printHelp
  exit 1
fi
