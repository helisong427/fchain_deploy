#!/bin/bash

export PATH=${PWD}/images/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config

# ip配置
. scripts/networkUp.sh
. scripts/utils.sh
. scripts/check.sh
#set -euo pipefail

CHANNEL_NAME="mychannel"
#通道配置文件configtx.yaml中 Profiles 域中关于创世块的配置域的域名
PROFILE_GENESIS="TwoOrgsOrdererGenesis"
IMAGE_TAG="amd64-2.2.1-bf63e7cb0"
base_domain="lianxiang.com"

########### orderer 多节点配置
orderer_number="3"
orderer_1_domain="orderer0"
orderer_1_rootpw="lighting8000"

orderer_2_domain="orderer1"
orderer_2_rootpw="lighting"

orderer_3_domain="orderer2"
orderer_3_rootpw="heyufeng"

########### org和peer 多节点配置
org_number="2"
org_1_name="org1"
org_1_anchor="peer0.org1.lianxiang.com"
org_1_peer_number="2"
org_1_peer_1_domain="peer0"
org_1_peer_1_rootpw="lighting8000"
org_1_peer_2_domain="peer1"
org_1_peer_2_rootpw="lighting"

org_2_name="org2"
org_2_anchor="peer0.org2.lianxiang.com"
org_2_peer_number="2"
org_2_peer_1_domain="peer0"
org_2_peer_1_rootpw="heyufeng"
org_2_peer_2_domain="peer1"
org_2_peer_2_rootpw="heyufeng"

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
  if [ "X$base_domain" == "X" ]; then
    fatalln "config base_domain 不能为空。"
  fi
  infoln "base_domain=$base_domain"

  if [ $orderer_number -lt 1 ]; then
    fatalln "config orderer_number 需要大于0"
  fi
  infoln "orderer_number=$orderer_number"
  for ((i = 1; i <= orderer_number; i++)); do
    orderer_domain=$(eval echo '$'orderer_"${i}"_domain)
    if [ "X${orderer_domain}" == "X" ]; then
      fatalln "config orderer_${i}_domain 不能为空。"
    fi
    infoln "orderer_${i}_domain=${orderer_domain}.${base_domain}"

    orderer_rootpw=$(eval echo -e '$'orderer_"${i}"_rootpw)
    if [ "X${orderer_rootpw}" == "X" ]; then
      fatalln "config orderer_${i}_rootpw 不能为空。"
    fi
    infoln "orderer_${i}_rootpw=${orderer_rootpw}"
  done

  if [ $org_number -lt 1 ]; then
    fatalln "config org_number 需要大于0"
  fi
  infoln "org_number=$org_number"

  for ((i = 1; i <= org_number; i++)); do

    org_name=$(eval echo '$'org_"${i}_name")
    if [ "X${org_name}" == "X" ]; then
      fatalln "config org_${i}_name 不能为空。"
    fi
    infoln "org_${i}_name=${org_name}"

    org_anchor=$(eval echo '$'org_"${i}_anchor")
    if [ "X${org_anchor}" == "X" ]; then
      fatalln "config org_${i}_anchor 不能为空。"
    fi
    infoln "org_${i}_anchor=${org_anchor}"

    org_peer_number=$(eval echo '$'org_"${i}_peer_number")
    if [ "X${org_peer_number}" == "X" ]; then
      fatalln "config org_${i}_peer_number 不能为空。"
    fi
    infoln "org_${i}_peer_number=${org_peer_number}"

    for ((ii = 1; ii <= org_peer_number; ii++)); do

      org_peer_domain=$(eval echo '$'org_"${i}"_peer_"${ii}"_domain)
      if [ "X${org_peer_domain}" == "X" ]; then
        fatalln "config org_${i}_peer_${ii}_domain 不能为空。"
      fi
      infoln "org_${i}_peer_${ii}_domain=${org_peer_domain}.${org_name}.${base_domain}"

      org_peer_rootpw=$(eval echo '$'org_"${i}"_peer_"${ii}"_rootpw)
      if [ "X${org_peer_rootpw}" == "X" ]; then
        fatalln "config org_${i}_peer_${ii}_rootpw 不能为空。"
      fi
      infoln "org_${i}_peer_${ii}_rootpw=${org_peer_rootpw}"
    done

  done

}

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

function networkUp() {
  generateConfig
  createConsortium

  for ((i = 1; i <= orderer_number; i++)); do
    orderer_domain=$(eval echo '$'orderer_"${i}"_domain)
    if [ "X${orderer_domain}" == "X" ]; then
      fatalln "config orderer_${i}_domain 不能为空。"
    fi

    orderer_rootpw=$(eval echo -e '$'orderer_"${i}"_rootpw)
    if [ "X${orderer_rootpw}" == "X" ]; then
      fatalln "config orderer_${i}_rootpw 不能为空。"
    fi

    startupOrder "${orderer_domain}" "${orderer_domain}.${base_domain}" "${orderer_rootpw}"

  done

  infoln "======>   所有orderer启动完成。"

  for ((i = 1; i <= org_number; i++)); do

    org_name=$(eval echo '$'org_"${i}_name")
    if [ "X${org_name}" == "X" ]; then
      fatalln "config org_${i}_name 不能为空。"
    fi

    org_anchor=$(eval echo '$'org_"${i}_anchor")
    if [ "X${org_anchor}" == "X" ]; then
      fatalln "config org_${i}_anchor 不能为空。"
    fi

    org_peer_number=$(eval echo '$'org_"${i}_peer_number")
    if [ "X${org_peer_number}" == "X" ]; then
      fatalln "config org_${i}_peer_number 不能为空。"
    fi

    for ((ii = 1; ii <= org_peer_number; ii++)); do

      org_peer_domain=$(eval echo '$'org_"${i}"_peer_"${ii}"_domain)
      if [ "X${org_peer_domain}" == "X" ]; then
        fatalln "config org_${i}_peer_${ii}_domain 不能为空。"
      fi

      org_peer_rootpw=$(eval echo '$'org_"${i}"_peer_"${ii}"_rootpw)
      if [ "X${org_peer_rootpw}" == "X" ]; then
        fatalln "config org_${i}_peer_${ii}_rootpw 不能为空。"
      fi

      startupPeer "${org_peer_domain}" "${org_name}" "${org_peer_domain}.${org_name}.${base_domain}" "${org_peer_rootpw}"

    done

  done
  infoln "======>   所有peer启动完成。"

}

# 检查参数配置
parseConfig

if [ "${MODE}" == "up" ]; then
  networkUp
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
