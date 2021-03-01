#!/bin/bash

function CA_parseConfig() {

  ## ca images tag 配置解析
  if [ "X${CA_IMAGE_TAG}" == "X" ]; then
    fatalln "config CA_IMAGE_TAG 不能为空。"
  fi
  infoln "CA_IMAGE_TAG=${CA_IMAGE_TAG}"

  ## root ca 配置解析
  if [ "X${CA_ROOT_NAME}" == "X" ]; then
    fatalln "config CA_ROOT_NAME 不能为空。"
  fi
  infoln "CA_ROOT_NAME=${CA_ROOT_NAME}"

  if [ "X${CA_ROOT_ROOTPW}" == "X" ]; then
    fatalln "config CA_ROOT_ROOTPW 不能为空。"
  fi
  infoln "CA_ROOT_ROOTPW=${CA_ROOT_ROOTPW}"

  if [ "X${CA_ROOT_PORT}" == "X" ]; then
    fatalln "config CA_ROOT_PORT 不能为空。"
  fi
  infoln "CA_ROOT_PORT=${CA_ROOT_PORT}"

  ## orderer ca 配置解析
  if [ "X${CA_ORDERER_NAME}" == "X" ]; then
    fatalln "config CA_ORDERER_NAME 不能为空。"
  fi
  infoln "CA_ORDERER_NAME=${CA_ORDERER_NAME}"

  if [ "X${CA_ORDERER_ROOTPW}" == "X" ]; then
    fatalln "config CA_ORDERER_ROOTPW 不能为空。"
  fi
  infoln "CA_ORDERER_ROOTPW=${CA_ORDERER_ROOTPW}"

  if [ "X${CA_ORDERER_PORT}" == "X" ]; then
    fatalln "config CA_ORDERER_PORT 不能为空。"
  fi
  infoln "CA_ORDERER_PORT=${CA_ORDERER_PORT}"

  ## org ca 配置解析
  if [ "${ORG_NUMBER}" -lt 1 ]; then
    fatalln "config ORG_NUMBER 需要大于0"
  fi

  for ((i = 1; i <= ORG_NUMBER; i++)); do
    local ca_org_name ca_org_rootpw ca_org_port

    parse_CA_ORG_NAME "${i}"
    ca_org_name=$(get_CA_ORG_NAME "${i}")
    infoln "CA_ORG_${i}_NAME=${ca_org_name}"

    parse_CA_ORG_ROOTPW "${i}"
    ca_org_rootpw=$(get_CA_ORG_ROOTPW "${i}")
    infoln "CA_ORG_${i}_ROOTPW=${ca_org_rootpw}"

    parse_CA_ORG_PORT "${i}"
    ca_org_port=$(get_CA_ORG_PORT "${i}")
    infoln "CA_ORG_${i}_PORT=${ca_org_port}"
  done
}

function CA() {

  local mode="$1"

  CA_parseConfig

  if [ "X${mode}" == "Xstart" ]; then

    infoln "======>   所有peer ${mode} 完成。"
  elif [ "X${mode}" == "Xclean" ]; then

    infoln "======>   所有peer ${mode} 完成。"

  else
    fatalln "NETWORK 函数的参数错误。"
  fi

}
