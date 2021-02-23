#!/bin/bash

export PATH=${PWD}/images/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config

DEPLOY_PATH="${PWD}"

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
  if [ "X$CHANNEL_NAME" == "X" ]; then
    fatalln "config CHANNEL_NAME 不能为空。"
  fi
  infoln "CHANNEL_NAME=$CHANNEL_NAME"
  if [ "X$PROFILE_GENESIS" == "X" ]; then
    fatalln "config PROFILE_GENESIS 不能为空。"
  fi
  infoln "PROFILE_GENESIS=$PROFILE_GENESIS"

  if [ "X$IMAGE_TAG" == "X" ]; then
    fatalln "config IMAGE_TAG 不能为空。"
  fi
  infoln "IMAGE_TAG=$IMAGE_TAG"
  if [ "X$BASE_DOMAIN" == "X" ]; then
    fatalln "config BASE_DOMAIN 不能为空。"
  fi
  infoln "BASE_DOMAIN=$BASE_DOMAIN"

  orderer_parseConfig
  peer_parseConfig
  CC_parseConfig

}



function network() {

  mode="$1"
  if [ "X${mode}" == "Xstart" ]; then
    NETWORK_up
  elif [ "X${mode}" == "Xclean" ]; then
    NETWORK_down
  else
    fatalln "networkUp 函数的参数错误。"
  fi

}

function channel() {

  mode="$1"
  if [ "X${mode}" == "Xstart" ]; then
    CHANNEL_create
  elif [ "X${mode}" == "Xclean" ]; then
    CHANNEL_clean
  else
    fatalln "createChannel 函数的参数错误。"
  fi
}

function chaincode() {

  mode="$1"
  for ((i = 1; i <= CC_NUMBER; i++)); do
    CC_exportEnv "${i}"
    if [ "X${mode}" == "Xstart" ]; then
      CC_deploy
    elif [ "X${mode}" == "Xclean" ]; then
      CC_clean
    else
      fatalln " deployCC 函数的参数错误。"
    fi
  done
}

# 检查参数配置
parseConfig

if [ "${MODE}" == "up" ]; then
  network start
elif [ "${MODE}" == "createChannel" ]; then
  channel start
elif [ "${MODE}" == "deployCC" ]; then
  chaincode start
elif [ "${MODE}" == "clean" ]; then
  chaincode clean
  channel clean
  network clean
else
  printHelp
  exit 1
fi
