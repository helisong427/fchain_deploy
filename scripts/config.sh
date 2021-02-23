#!/bin/bash

. utils.sh
########### 基本配置
CHANNEL_NAME="mychannel222"
#通道配置文件configtx.yaml中 Profiles 域中关于创世块的配置域的域名
PROFILE_GENESIS="TwoOrgsOrdererGenesis"
IMAGE_TAG="amd64-2.2.1-bf63e7cb0"
BASE_DOMAIN="lianxiang.com"

########### orderer 多节点配置
ORDERER_NUMBER="3"
ORDERER_1_NAME="orderer0"
ORDERER_1_ROOTPW="lighting8000"
ORDERER_1_PORT="7050"

ORDERER_2_NAME="orderer1"
ORDERER_2_ROOTPW="lighting"
ORDERER_2_PORT="8050"

ORDERER_3_NAME="orderer2"
ORDERER_3_ROOTPW="heyufeng"
ORDERER_3_PORT="9050"

########### org和peer 多节点配置
ORG_NUMBER="2"
ORG_1_NAME="org1"
ORG_1_MSP_NAME="Org1MSP"
ORG_1_ANCHOR="1"
ORG_1_PEER_NUMBER="2"
ORG_1_PEER_1_NAME="peer0"
ORG_1_PEER_1_ROOTPW="lighting8000"
ORG_1_PEER_1_PORT="7051"
ORG_1_PEER_2_NAME="peer1"
ORG_1_PEER_2_ROOTPW="lighting"
ORG_1_PEER_2_PORT="8051"

ORG_2_NAME="org2"
ORG_2_MSP_NAME="Org2MSP"
ORG_2_ANCHOR="1"
ORG_2_PEER_NUMBER="2"
ORG_2_PEER_1_NAME="peer0"
ORG_2_PEER_1_ROOTPW="heyufeng"
ORG_2_PEER_1_PORT="11051"
ORG_2_PEER_2_NAME="peer1"
ORG_2_PEER_2_ROOTPW="heyufeng"
ORG_2_PEER_2_PORT="10051"

########### 链码配置
CC_NUMBER="1"
CC_1_NAME="abstore"
CC_1_VERSION="1"
CC_1_PEERS="1_2 2_2"                                       #安装到那些peer上面（格式：orgindex_peerindex），多个用空格隔开
CC_1_INIT="true"                                           #是否调用链码init方法（只有配置为"true"才调用）
CC_1_INIT_FUNCTION="Init"                                  #链码的init方法（CC_INIT为"true"时才进行配置）
#CC_1_SIGNATURE_POLICY="AND('Org1MSP.peer','Org2MSP.peer')" # 链码背书策略（如果不指定，默认使用通道配置中的策略作为链码背书策略）
CC_1_SEQUENCE="1"

#export TOP_PID=$$
#trap 'exit 1' TERM
#
#function exit_script(){
#  echo "aaaaaaaaaa"
#	kill -s TERM $TOP_PID
#}

function get_ORDERER_NAME() {
  local orderer_index=$1
  local orderer_name
  orderer_name=$(eval echo '$'"ORDERER_${orderer_index}_NAME")
  echo "${orderer_name}"
}
function parse_ORDERER_NAME() {
  local orderer_index=$1
  local orderer_name
  orderer_name=$(eval echo '$'"ORDERER_${orderer_index}_NAME")
  if [ "X${orderer_name}" == "X" ]; then
    fatalln "config ORDERER_${orderer_index}_NAME 不能为空。"
  fi
}

function get_ORDERER_ROOTPW() {
  local orderer_index=$1
  local orderer_rootpw
  orderer_rootpw=$(eval echo '$'"ORDERER_${orderer_index}_ROOTPW")
  echo "${orderer_rootpw}"
}
function parse_ORDERER_ROOTPW() {
  local orderer_index=$1
  local orderer_rootpw
  orderer_rootpw=$(eval echo '$'"ORDERER_${orderer_index}_ROOTPW")
  if [ "X${orderer_rootpw}" == "X" ]; then
    fatalln "config ORDERER_${orderer_index}_ROOTPW 不能为空。"
  fi
}

function get_ORDERER_PORT() {
  local orderer_index=$1
  local orderer_port
  orderer_port=$(eval echo '$'"ORDERER_${orderer_index}_PORT")
  echo "${orderer_port}"
}
function parse_ORDERER_PORT() {
  local orderer_index=$1
  local orderer_port
  orderer_port=$(eval echo '$'"ORDERER_${orderer_index}_PORT")
  if [ "X${orderer_port}" == "X" ]; then
    fatalln "config ORDERER_${orderer_index}_PORT 不能为空。"
  fi
}

function get_ORG_NAME() {
  local org_index=$1
  local org_name
  org_name=$(eval echo '$'"ORG_${org_index}_NAME")
  echo "${org_name}"
}
function parse_ORG_NAME() {
  local org_index=$1
  local org_name
  org_name=$(eval echo '$'"ORG_${org_index}_NAME")
  if [ "X${org_name}" == "X" ]; then
    fatalln "config ORG_${org_index}_NAME 不能为空。"
  fi
}

function get_ORG_MSP_NAME() {
  local org_index=$1
  local org_msp_name
  org_msp_name=$(eval echo '$'"ORG_${org_index}_MSP_NAME")
  echo "${org_msp_name}"
}
function parse_ORG_MSP_NAME() {
  local org_index=$1
  local org_msp_name
  org_msp_name=$(eval echo '$'"ORG_${org_index}_MSP_NAME")
  if [ "X${org_msp_name}" == "X" ]; then
    fatalln "config ORG_${org_index}_MSP_NAME 不能为空。"
  fi
}

function get_ORG_ANCHOR() {
  local org_index=$1
  local org_anchor
  org_anchor=$(eval echo '$'"ORG_${org_index}_ANCHOR")
  echo "${org_anchor}"
}
function parse_ORG_ANCHOR() {
  local org_index=$1
  local org_anchor
  org_anchor=$(eval echo '$'"ORG_${org_index}_ANCHOR")
  if [ "X${org_anchor}" == "X" ]; then
    fatalln "config ORG_${org_index}_ANCHOR 不能为空。"
  fi
}

function get_ORG_PEER_NUMBER() {
  local org_index=$1
  local org_peer_number
  org_peer_number=$(eval echo '$'"ORG_${org_index}_PEER_NUMBER")
  echo "${org_peer_number}"
}
function parse_ORG_PEER_NUMBER() {
  local org_index=$1
  local org_peer_number
  org_peer_number=$(eval echo '$'"ORG_${org_index}_PEER_NUMBER")
  if [ "X${org_peer_number}" == "X" ]; then
    fatalln "config ORG_${org_index}_ANCHOR 不能为空。"
  fi
}

function get_ORG_PEER_NAME() {
  local org_index=$1
  local peer_index=$2
  local org_peer_name
  org_peer_name=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_NAME")
  echo "${org_peer_name}"
}
function parse_ORG_PEER_NAME() {
  local org_index=$1
  local peer_index=$2
  local org_peer_name
  org_peer_name=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_NAME")
  if [ "X${org_peer_name}" == "X" ]; then
    fatalln "config ORG_${org_index}_PEER_${peer_index}_NAME 不能为空。"
  fi
}

function get_ORG_PEER_ROOTPW() {
  local org_index=$1
  local peer_index=$2
  local org_peer_rootpw
  org_peer_rootpw=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_ROOTPW")
  echo "${org_peer_rootpw}"
}
function parse_ORG_PEER_ROOTPW() {
  local org_index=$1
  local peer_index=$2
  local org_peer_rootpw
  org_peer_rootpw=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_ROOTPW")
  if [ "X${org_peer_rootpw}" == "X" ]; then
    fatalln "config ORG_${org_index}_PEER_${peer_index}_ROOTPW 不能为空。"
  fi
}

function get_ORG_PEER_PORT() {
  local org_index=$1
  local peer_index=$2
  local org_peer_port
  org_peer_port=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_PORT")
  echo "${org_peer_port}"
}
function parse_ORG_PEER_PORT() {
  local org_index=$1
  local peer_index=$2
  local org_peer_port
  org_peer_port=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_PORT")
  if [ "X${org_peer_port}" == "X" ]; then
    fatalln "config ORG_${org_index}_PEER_${peer_index}_PORT 不能为空。"
  fi
}

function get_CC_NAME() {
  local cc_index=$1
  local cc_name
  cc_name=$(eval echo '$'"CC_${cc_index}_NAME")
  echo "${cc_name}"
}
function parse_CC_NAME() {
  local cc_index=$1
  local cc_name
  cc_name=$(eval echo '$'"CC_${cc_index}_NAME")
  if [ "X${cc_name}" == "X" ]; then
    fatalln "config CC_${cc_index}_NAME 不能为空。"
  fi
}

function get_CC_VERSION() {
  local cc_index=$1
  local cc_version
  cc_version=$(eval echo '$'"CC_${cc_index}_VERSION")
  echo "${cc_version}"
}
function parse_CC_VERSION() {
  local cc_index=$1
  local cc_version
  cc_version=$(eval echo '$'"CC_${cc_index}_VERSION")
  if [ "X${cc_version}" == "X" ]; then
    fatalln "config CC_${cc_index}_VERSION 不能为空。"
  fi
}

function get_CC_PEERS() {
  local cc_index=$1
  local cc_peers
  cc_peers=$(eval echo '$'"CC_${cc_index}_PEERS")
  echo "${cc_peers}"
}
function parse_CC_PEERS() {
  local cc_index=$1
  local cc_peers
  cc_peers=$(eval echo '$'"CC_${cc_index}_PEERS")
  if [ "X${cc_peers}" == "X" ]; then
    fatalln "config CC_${cc_index}_PEERS 不能为空。"
  fi
}

function get_CC_SEQUENCE() {
  local cc_index=$1
  local cc_sequence
  cc_sequence=$(eval echo '$'"CC_${cc_index}_SEQUENCE")
  echo "${cc_sequence}"
}
function parse_CC_SEQUENCE() {
  local cc_index=$1
  local cc_sequence
  cc_sequence=$(eval echo '$'"CC_${cc_index}_SEQUENCE")
  if [ "X${cc_sequence}" == "X" ]; then
    fatalln "config CC_${cc_index}_SEQUENCE 不能为空。"
  fi
}

function get_CC_INIT_FUNCTION() {
  local cc_index=$1
  local cc_init_function
  cc_init_function=$(eval echo '$'"CC_${cc_index}_INIT_FUNCTION")
  echo "${cc_init_function}"
}
function parse_CC_INIT_FUNCTION() {
  local cc_index=$1
  local cc_init_function
  cc_init_function=$(eval echo '$'"CC_${cc_index}_INIT_FUNCTION")
  if [ "X${cc_init_function}" == "X" ]; then
    fatalln "config CC_${cc_index}_INIT_FUNCTION 不能为空。"
  fi
}

function get_CC_INIT() {
  local cc_index=$1
  local cc_init
  cc_init=$(eval echo '$'"CC_${cc_index}_INIT")
  echo "${cc_init}"
}

#function get_CC_SIGNATURE_POLICY() {
#  local cc_index=$1
#  local cc_signature_policy
#  cc_signature_policy=$(eval echo '$'"CC_${cc_index}_SIGNATURE_POLICY")
#  echo "${cc_signature_policy}"
#}
