#!/bin/bash

########### 基本配置
# 生成配置文件的方式，支持两种方式：CA和CRYPTOGEN
readonly CRYPTO="CA1"
readonly CHANNEL_NAME="mychannel"
#通道配置文件configtx.yaml中 Profiles 域中关于创世块的配置域的域名
readonly PROFILE_GENESIS="TwoOrgsOrdererGenesis"
readonly IMAGE_TAG="amd64-2.2.1-bf63e7cb0"
readonly BASE_DOMAIN="lianxiang.com"

########### orderer 多节点配置
readonly ORDERER_NUMBER="3"
readonly ORDERER_1_NAME="orderer0"
readonly ORDERER_1_ROOTPW="lighting8000"
readonly ORDERER_1_PORT="7050"

readonly ORDERER_2_NAME="orderer1"
readonly ORDERER_2_ROOTPW="lighting"
readonly ORDERER_2_PORT="8050"

readonly ORDERER_3_NAME="orderer2"
readonly ORDERER_3_ROOTPW="heyufeng"
readonly ORDERER_3_PORT="9050"

########### org和peer 多节点配置
readonly ORG_NUMBER="2"
readonly ORG_1_NAME="org1"
readonly ORG_1_MSP_NAME="Org1MSP"
readonly ORG_1_ANCHOR="1"
readonly ORG_1_PEER_NUMBER="2"
readonly ORG_1_PEER_1_NAME="peer0"
readonly ORG_1_PEER_1_ROOTPW="lighting8000"
readonly ORG_1_PEER_1_PORT="7051"
readonly ORG_1_PEER_2_NAME="peer1"
readonly ORG_1_PEER_2_ROOTPW="lighting"
readonly ORG_1_PEER_2_PORT="8051"

readonly ORG_2_NAME="org2"
readonly ORG_2_MSP_NAME="Org2MSP"
readonly ORG_2_ANCHOR="1"
readonly ORG_2_PEER_NUMBER="2"
readonly ORG_2_PEER_1_NAME="peer0"
readonly ORG_2_PEER_1_ROOTPW="heyufeng"
readonly ORG_2_PEER_1_PORT="11051"
readonly ORG_2_PEER_2_NAME="peer1"
readonly ORG_2_PEER_2_ROOTPW="heyufeng"
readonly ORG_2_PEER_2_PORT="10051"

########### 链码配置
readonly CC_NUMBER="1"
readonly CC_1_NAME="abstore"
readonly CC_1_VERSION="1"
readonly CC_1_PEERS="1_2 2_2"                                                   #安装到那些peer上面（格式：orgindex_peerindex），多个用空格隔开
readonly CC_1_INIT="true"                                                       #是否调用链码init方法（只有配置为"true"才调用）
readonly CC_1_INIT_FUNCTION="{\"Args\":[\"Init\",\"a\",\"100\",\"b\",\"100\"]}" #链码的init方法调用（CC_INIT为"true"时才进行配置）
#CC_1_SIGNATURE_POLICY="AND('Org1MSP.peer','Org2MSP.peer')" # 链码背书策略（如果不指定，默认使用通道配置中的策略作为链码背书策略）
readonly CC_1_SEQUENCE="1"

function get_ORDERER_NAME() {
  local orderer_name orderer_index="$1"
  orderer_name=$(eval echo '$'"ORDERER_${orderer_index}_NAME")
  echo "${orderer_name}"
}
function parse_ORDERER_NAME() {
  local orderer_name orderer_index="$1"
  orderer_name=$(eval echo '$'"ORDERER_${orderer_index}_NAME")
  if [ "X${orderer_name}" == "X" ]; then
    fatalln "config ORDERER_${orderer_index}_NAME 不能为空。"
  fi
}

function get_ORDERER_ROOTPW() {
  local orderer_rootpw orderer_index="$1"
  orderer_rootpw=$(eval echo '$'"ORDERER_${orderer_index}_ROOTPW")
  echo "${orderer_rootpw}"
}
function parse_ORDERER_ROOTPW() {
  local orderer_rootpw orderer_index="$1"
  orderer_rootpw=$(eval echo '$'"ORDERER_${orderer_index}_ROOTPW")
  if [ "X${orderer_rootpw}" == "X" ]; then
    fatalln "config ORDERER_${orderer_index}_ROOTPW 不能为空。"
  fi
}

function get_ORDERER_PORT() {
  local orderer_port orderer_index="$1"
  orderer_port=$(eval echo '$'"ORDERER_${orderer_index}_PORT")
  echo "${orderer_port}"
}
function parse_ORDERER_PORT() {
  local orderer_port orderer_index="$1"
  orderer_port=$(eval echo '$'"ORDERER_${orderer_index}_PORT")
  if [ "X${orderer_port}" == "X" ]; then
    fatalln "config ORDERER_${orderer_index}_PORT 不能为空。"
  fi
}

function get_ORG_NAME() {
  local org_name org_index="$1"
  org_name=$(eval echo '$'"ORG_${org_index}_NAME")
  echo "${org_name}"
}
function parse_ORG_NAME() {
  local org_name org_index="$1"
  org_name=$(eval echo '$'"ORG_${org_index}_NAME")
  if [ "X${org_name}" == "X" ]; then
    fatalln "config ORG_${org_index}_NAME 不能为空。"
  fi
}

function get_ORG_MSP_NAME() {
  local org_msp_name org_index="$1"
  org_msp_name=$(eval echo '$'"ORG_${org_index}_MSP_NAME")
  echo "${org_msp_name}"
}
function parse_ORG_MSP_NAME() {
  local org_msp_name org_index="$1"
  org_msp_name=$(eval echo '$'"ORG_${org_index}_MSP_NAME")
  if [ "X${org_msp_name}" == "X" ]; then
    fatalln "config ORG_${org_index}_MSP_NAME 不能为空。"
  fi
}

function get_ORG_ANCHOR() {
  local org_anchor org_index="$1"
  org_anchor=$(eval echo '$'"ORG_${org_index}_ANCHOR")
  echo "${org_anchor}"
}
function parse_ORG_ANCHOR() {
  local org_anchor org_index="$1"
  org_anchor=$(eval echo '$'"ORG_${org_index}_ANCHOR")
  if [ "X${org_anchor}" == "X" ]; then
    fatalln "config ORG_${org_index}_ANCHOR 不能为空。"
  fi
}

function get_ORG_PEER_NUMBER() {
  local org_peer_number org_index="$1"
  org_peer_number=$(eval echo '$'"ORG_${org_index}_PEER_NUMBER")
  echo "${org_peer_number}"
}
function parse_ORG_PEER_NUMBER() {
  local org_peer_number org_index="$1"
  org_peer_number=$(eval echo '$'"ORG_${org_index}_PEER_NUMBER")
  if [ "X${org_peer_number}" == "X" ]; then
    fatalln "config ORG_${org_index}_ANCHOR 不能为空。"
  fi
}

function get_ORG_PEER_NAME() {
  local org_peer_name org_index="$1" peer_index="$2"
  org_peer_name=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_NAME")
  echo "${org_peer_name}"
}
function parse_ORG_PEER_NAME() {
  local org_peer_name org_index="$1" peer_index="$2"
  org_peer_name=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_NAME")
  if [ "X${org_peer_name}" == "X" ]; then
    fatalln "config ORG_${org_index}_PEER_${peer_index}_NAME 不能为空。"
  fi
}

function get_ORG_PEER_ROOTPW() {
  local org_peer_rootpw org_index="$1" peer_index="$2"
  org_peer_rootpw=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_ROOTPW")
  echo "${org_peer_rootpw}"
}
function parse_ORG_PEER_ROOTPW() {
  local org_peer_rootpw org_index="$1" peer_index="$2"
  org_peer_rootpw=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_ROOTPW")
  if [ "X${org_peer_rootpw}" == "X" ]; then
    fatalln "config ORG_${org_index}_PEER_${peer_index}_ROOTPW 不能为空。"
  fi
}

function get_ORG_PEER_PORT() {
  local org_peer_port org_index="$1" peer_index="$2"
  org_peer_port=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_PORT")
  echo "${org_peer_port}"
}
function parse_ORG_PEER_PORT() {
  local org_peer_port org_index="$1" peer_index="$2"
  org_peer_port=$(eval echo '$'"ORG_${org_index}_PEER_${peer_index}_PORT")
  if [ "X${org_peer_port}" == "X" ]; then
    fatalln "config ORG_${org_index}_PEER_${peer_index}_PORT 不能为空。"
  fi
}

function get_CC_NAME() {
  local cc_name cc_index="$1"
  cc_name=$(eval echo '$'"CC_${cc_index}_NAME")
  echo "${cc_name}"
}
function parse_CC_NAME() {
  local cc_name cc_index="$1"
  cc_name=$(eval echo '$'"CC_${cc_index}_NAME")
  if [ "X${cc_name}" == "X" ]; then
    fatalln "config CC_${cc_index}_NAME 不能为空。"
  fi
}

function get_CC_VERSION() {
  local cc_version cc_index="$1"
  cc_version=$(eval echo '$'"CC_${cc_index}_VERSION")
  echo "${cc_version}"
}
function parse_CC_VERSION() {
  local cc_version cc_index="$1"
  cc_version=$(eval echo '$'"CC_${cc_index}_VERSION")
  if [ "X${cc_version}" == "X" ]; then
    fatalln "config CC_${cc_index}_VERSION 不能为空。"
  fi
}

function get_CC_PEERS() {
  local cc_peers cc_index="$1"
  cc_peers=$(eval echo '$'"CC_${cc_index}_PEERS")
  echo "${cc_peers}"
}
function parse_CC_PEERS() {
  local cc_peers cc_index="$1"
  cc_peers=$(eval echo '$'"CC_${cc_index}_PEERS")
  if [ "X${cc_peers}" == "X" ]; then
    fatalln "config CC_${cc_index}_PEERS 不能为空。"
  fi
}

function get_CC_SEQUENCE() {
  local cc_sequence cc_index="$1"
  cc_sequence=$(eval echo '$'"CC_${cc_index}_SEQUENCE")
  echo "${cc_sequence}"
}
function parse_CC_SEQUENCE() {
  local cc_sequence cc_index="$1"
  cc_sequence=$(eval echo '$'"CC_${cc_index}_SEQUENCE")
  if [ "X${cc_sequence}" == "X" ]; then
    fatalln "config CC_${cc_index}_SEQUENCE 不能为空。"
  fi
}

function get_CC_INIT_FUNCTION() {
  local cc_init_function cc_index="$1"
  cc_init_function=$(eval echo '$'"CC_${cc_index}_INIT_FUNCTION")
  echo "${cc_init_function}"
}
function parse_CC_INIT_FUNCTION() {
  local cc_init_function cc_index="$1"
  cc_init_function=$(eval echo '$'"CC_${cc_index}_INIT_FUNCTION")
  if [ "X${cc_init_function}" == "X" ]; then
    fatalln "config CC_${cc_index}_INIT_FUNCTION 不能为空。"
  fi
}

function get_CC_INIT() {
  local cc_init cc_index="$1"
  cc_init=$(eval echo '$'"CC_${cc_index}_INIT")
  echo "${cc_init}"
}

#function get_CC_SIGNATURE_POLICY() {
#  local cc_index="$1"
#  local cc_signature_policy
#  cc_signature_policy=$(eval echo '$'"CC_${cc_index}_SIGNATURE_POLICY")
#  echo "${cc_signature_policy}"
#}


