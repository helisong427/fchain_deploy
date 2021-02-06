#!/bin/bash

export PATH=${PWD}/images/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config

CHANNEL_NAME="mychannel"
FABRIC_VERSION=amd64-2.2.1-bf63e7cb0

# ip配置
. scripts/utils.sh
. scripts/check.sh
. scripts/lib.sh
#set -euo pipefail

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
  -CCg)
    PROFILE_GENESIS="$2"
    shift
    ;;
  -CCc)
    PROFILE_CHANNEL="$2"
    shift
    ;;
  -CCcn)
    CHANNEL_NAME="$2"
    shift
    ;;

  -COAc)
    PROFILE_CHANNEL="$2"
    shift
    ;;
  -COAomn)
    ORG_MSP_NAME="$2"
    shift
    ;;
  -COAcn)
    CHANNEL_NAME="$2"
    shift
    ;;

  -SOh)
    ORDERER_HOSTNAME="$2"
    shift
    ;;
  -SOd)
    ORDERER_DOMAIN="$2"
    shift
    ;;
  -SOp)
    ROOT_PASSWORD="$2"
    shift
    ;;

  -SPpn)
    PEER_HOSTNAME="$2"
    shift
    ;;
  -SPon)
    ORG_HOSTNAME="$2"
    shift
    ;;
  -SPd)
    PEER_DOMAIN="$2"
    shift
    ;;
  -SPp)
    ROOT_PASSWORD="$2"
    shift
    ;;

  *)
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

if [ "${MODE}" == "createConfig" ]; then
  createConfig
elif [ "${MODE}" == "createOrgAnchor" ]; then
  createOrgAnchor
elif [ "${MODE}" == "startupOrder" ]; then
  startupOrder
elif [ "${MODE}" == "startupPeer" ]; then
  startupPeer
elif [ "${MODE}" == "createChannel" ]; then
  createChannel
elif [ "${MODE}" == "clean" ]; then
  clean
else
  printHelp
  exit 1
fi
