#!/bin/bash

export PATH=${PWD}/images/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config

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
  *)
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

if [ "${MODE}" == "crypto" ]; then
  createCryptogen
elif [ "${MODE}" == "createChannel" ]; then
  createChannel
elif [ "${MODE}" == "createOrgAnchor" ]; then
  createOrgAnchor
elif [ "${MODE}" == "clean" ]; then
  clean
else
  printHelp
  exit 1
fi
