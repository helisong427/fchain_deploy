#!/bin/bash

function generateCrypto() {

  if [ -d "${DEPLOY_PATH}/config/crypto-config" ]; then
    rm -Rf "${DEPLOY_PATH}/config/crypto-config"
  fi

  # 生成证书配置
  if [ "X${CRYPTO}" == "XCRYPTOGEN" ]; then
    if ! which cryptogen; then
      fatalln "cryptogen tool not found. exiting"
    fi

    cryptogen generate --config="${DEPLOY_PATH}"/config/crypto-config.yaml --output "${DEPLOY_PATH}"/config/crypto-config/
    if [[ $# -lt 0 ]]; then
      errorln "生成证书文件失败."
    fi

    infoln "生成证书文件完成。"

    #  elif [ "X${CRYPTO}" != "XCA" ]; then
    #
    #  IMAGE_TAG=${CA_IMAGETAG} docker-compose -f $COMPOSE_FILE_CA up -d 2>&1

  fi

}

function createConsortium() {

  if which configtxgen -ne 0; then
    fatalln "configtxgen tool not found."
  fi

  if [ -f "${DEPLOY_PATH}/config/system-genesis-block/genesis.block" ]; then
    rm -Rf "${DEPLOY_PATH}/config/system-genesis-block/genesis.block"
  fi

  set -x
  configtxgen -profile "${PROFILE_GENESIS}" -channelID system-channel -outputBlock "${DEPLOY_PATH}"/config/system-genesis-block/genesis.block
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "创建通道失败：创建创世区块文件失败。"
  fi

  infoln "生成创世区块完成。"
}

function startupOrderer() {

  local temp_dir orderer_name="$1" orderer_domain="$2" orderer_rootpw="$3" mode="$4"

  if [ "X${orderer_name}" == "X" ]; then
    fatalln "启动orderer失败：startupOrderer，第一个参数（orderer name）为空。"
  fi

  if [ "X${orderer_domain}" == "X" ]; then
    fatalln "启动orderer失败：startupOrderer，第二个参数（orderer domain）为空。"
  fi

  if [ "X${orderer_rootpw}" == "X" ]; then
    fatalln "启动orderer失败：startupOrderer，第三个参数（orderer root passwd）为空。"
  fi

  temp_dir="${DEPLOY_PATH}/temp/${orderer_name}"

  if [ "X${mode}" == "Xstart" ]; then

    rm -rf "${temp_dir}" && mkdir -p "${temp_dir}"

    # 打包orderer配置文件和镜像
    tar -cf "${temp_dir}"/"${orderer_name}".tar \
      config/crypto-config/ordererOrganizations/"${BASE_DOMAIN}"/orderers/"${orderer_name}"."${BASE_DOMAIN}"/ \
      images/files/orderer/ \
      config/system-genesis-block/genesis.block \
      config/docker/docker-compose-"${orderer_name}".yaml

    # cd "${temp_dir}" && md5sum "${orderer_name}".tar >"${orderer_name}".md5 && cd "${DEPLOY_PATH}"
    set -e
    pushd "${temp_dir}" >/dev/null 2>&1
    md5sum "${orderer_name}".tar >"${orderer_name}".md5
    popd >/dev/null 2>&1
    set +e

    sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >/dev/null 2>&1 <<eeooff0
      if [ ! -d /var/hyperledger ]; then
        mkdir /var/hyperledger
      fi
      exit
eeooff0

    sshpass -p "${orderer_rootpw}" scp "${temp_dir}"/"${orderer_name}".md5 root@"${orderer_domain}":/var/hyperledger/"${orderer_name}".md5

    sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >"${temp_dir}"/"${orderer_name}"_md5.txt <<eeooff1
      cd /var/hyperledger
      if [ -f "${orderer_name}".tar ]; then
        md5sum -c "${orderer_name}".md5
      fi
      exit
eeooff1

    local ret
    ret=$(grep "${orderer_name}".tar "${temp_dir}"/"${orderer_name}"_md5.txt | awk -F" " '{print $2}' | tr -d '\n\r')
    if [ "X${ret}" != "XOK" ] && [ "X${ret}" != "X确定" ] && [ "X${ret}" != "X成功" ]; then
      sshpass -p "${orderer_rootpw}" scp "${temp_dir}"/"${orderer_name}".tar root@"${orderer_domain}":/var/hyperledger/"${orderer_name}".tar
    else
      infoln "${orderer_name}.tar 文件存在，不需要上传。"
    fi

    sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >"${temp_dir}"/"${orderer_name}"_dockerLoad.txt <<eeooff2
      cd /var/hyperledger && \
      rm -rf ./config/crypto-config/ordererOrganizations/"${BASE_DOMAIN}"/orderers/"${orderer_name}"."${BASE_DOMAIN}"/ ./images/files/orderer/ && \
      tar -xf "${orderer_name}".tar && \
      docker load < ./images/files/orderer/*.gz
      exit
eeooff2

    sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >"${temp_dir}"/"${orderer_name}"_dockerUp.txt <<eeooff3
      cd  /var/hyperledger/config/docker
      IMAGE_TAG="$IMAGE_TAG" docker-compose -f docker-compose-"${orderer_name}".yaml up -d
      docker ps
      exit
eeooff3

    infoln "启动${orderer_name}完成。"

  elif [ "X${mode}" == "Xclean" ]; then
    rm -rf "${DEPLOY_PATH}/config/crypto-config/" "${temp_dir}" && mkdir -p "${temp_dir}"

    sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >"${temp_dir}"/"${orderer_name}"_dockerDown.txt <<eeooff3
      cd  /var/hyperledger/config/docker
      docker rm ${orderer_domain} -vf
      docker volume rm docker_${orderer_domain}
      exit
eeooff3

  else
    fatalln "startupOrderer 函数的参数错误。"
  fi

}

function startupPeer() {

  local peer_name="$1" org_name="$2" peer_domain="$3" peer_rootpw="$4" mode="$5"

  if [ "X${peer_name}" == "X" ]; then
    fatalln "启动peer失败：startupPeer 第一个参数（peer name）为空。"
  fi

  if [ "X${org_name}" == "X" ]; then
    fatalln "启动peer失败：startupPeer 第二个参数（org name）为空。"
  fi

  if [ "X${peer_domain}" == "X" ]; then
    fatalln "启动peer失败：startupPeer 第三个参数（peer domain）为空。"
  fi

  if [ "X${peer_rootpw}" == "X" ]; then
    fatalln "启动peer失败：startupPeer 第四个参数（peer root passwd）为空。"
  fi

  local peerOrgName="${peer_name}"."${org_name}"
  local temp_dir="${DEPLOY_PATH}/temp/${peerOrgName}"

  if [ "X${mode}" == "Xstart" ]; then
    rm -rf "${temp_dir}" && mkdir -p "${temp_dir}"
    # 打包orderer配置文件和镜像
    tar -cf "${temp_dir}"/"${peerOrgName}".tar \
      config/crypto-config/peerOrganizations/"${org_name}"."${BASE_DOMAIN}"/peers/"${peerOrgName}"."${BASE_DOMAIN}" \
      images/files/peer/ \
      config/docker/docker-compose-"${peerOrgName}".yaml

    #cd "${temp_dir}" && md5sum "${peerOrgName}".tar >"${peerOrgName}".md5 && cd "${DEPLOY_PATH}"
    set -e
    pushd "${temp_dir}" >/dev/null 2>&1
    md5sum "${peerOrgName}".tar >"${peerOrgName}".md5
    popd >/dev/null 2>&1
    set +e

    sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >/dev/null 2>&1 <<eeooff0
      if [ ! -d /var/hyperledger ]; then
        mkdir /var/hyperledger
      fi
      exit
eeooff0

    sshpass -p "${peer_rootpw}" scp "${temp_dir}"/"${peerOrgName}".md5 root@"${peer_domain}":/var/hyperledger/"${peerOrgName}".md5
    sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >"${temp_dir}"/"${peerOrgName}"_md5.txt <<eeooff1
      cd /var/hyperledger
      if [ -f "${peerOrgName}".tar ]; then
        md5sum -c "${peerOrgName}".md5
      fi
      exit
eeooff1

    local ret
    ret=$(grep "${peerOrgName}".tar "${temp_dir}/${peerOrgName}"_md5.txt | awk -F" " '{print $2}' | tr -d '\n\r')
    if [ "X${ret}" != "XOK" ] && [ "X${ret}" != "X确定" ] && [ "X${ret}" != "X成功" ]; then
      sshpass -p "${peer_rootpw}" scp "${temp_dir}"/"${peerOrgName}".tar root@"${peer_domain}":/var/hyperledger/"${peerOrgName}".tar
    else
      infoln "${peerOrgName}.tar 文件存在，不需要上传。"
    fi

    sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >"${temp_dir}"/"${peerOrgName}"_dockerLoad.txt <<eeooff2
      cd /var/hyperledger && \
      rm -rf ./config/crypto-config/peerOrganizations/"${org_name}"."${BASE_DOMAIN}"/peers/"${peerOrgName}"."${BASE_DOMAIN}"/ ./images/files/peer/ && tar -xf "${peerOrgName}".tar && \
      docker load < ./images/files/peer/*.gz
      exit
eeooff2

    sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >"${temp_dir}"/"${peerOrgName}"_dockerUp.txt <<eeooff3
      cd /var/hyperledger/config/docker
      IMAGE_TAG="${IMAGE_TAG}"  docker-compose -f docker-compose-"${peerOrgName}".yaml up -d
      docker ps
      exit
eeooff3

    infoln "启动${peerOrgName}成功。"

  elif [ "X${mode}" == "Xclean" ]; then

    rm -rf "${temp_dir}" && mkdir -p "${temp_dir}"

    sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >"${temp_dir}"/"${peerOrgName}"_dockerDown.txt <<eeooff3
      cd /var/hyperledger/config/docker
      docker rm ${peer_domain} -vf
      docker volume rm docker_${peer_domain}
      docker ps
      exit
eeooff3

  else
    fatalln "startupPeer 函数的参数错误。"
  fi

}

function NETWORK_parseConfig() {

  ## 基础配置解析
  if [ "X${CRYPTO}" != "XCA" ] && [ "X${CRYPTO}" != "XCRYPTOGEN" ]; then
    fatalln "config CRYPTO 只能为'CA'或者'CRYPTOGEN'。"
  fi
  infoln "CRYPTO=${CRYPTO}"

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

  ## ORDERER 配置解析
  if [ "${ORDERER_NUMBER}" -lt 1 ]; then
    fatalln "config ORDERER_NUMBER 需要大于0"
  fi
  infoln "ORDERER_NUMBER=$ORDERER_NUMBER"
  for ((i = 1; i <= ORDERER_NUMBER; i++)); do
    local orderer_name orderer_rootpw orderer_port

    parse_ORDERER_NAME "${i}"
    orderer_name=$(get_ORDERER_NAME "${i}")
    infoln "ORDERER_${i}_NAME=${orderer_name}.${BASE_DOMAIN}"

    parse_ORDERER_ROOTPW "${i}"
    orderer_rootpw=$(get_ORDERER_ROOTPW "${i}")
    infoln "ORDERER_${i}_ROOTPW=${orderer_rootpw}"

    parse_ORDERER_PORT "${i}"
    orderer_port=$(get_ORDERER_PORT "${i}")
    infoln "ORDERER_${i}_PORT=${orderer_port}"
  done

  ## ORG 配置解析
  if [ "${ORG_NUMBER}" -lt 1 ]; then
    fatalln "config ORG_NUMBER 需要大于0"
  fi
  infoln "ORG_NUMBER=$ORG_NUMBER"

  for ((i = 1; i <= ORG_NUMBER; i++)); do

    local org_name org_msp_name org_anchor org_peer_number

    parse_ORG_NAME "${i}"
    org_name=$(get_ORG_NAME "${i}")
    infoln "ORG_${i}_NAME=${org_name}"

    parse_ORG_MSP_NAME "${i}"
    org_msp_name=$(get_ORG_MSP_NAME "${i}")
    infoln "ORG_${i}_MSP_NAME=${org_msp_name}"

    parse_ORG_ANCHOR "${i}"
    org_anchor=$(get_ORG_ANCHOR "${i}")
    infoln "ORG_${i}_ANCHOR=${org_anchor}"

    parse_ORG_PEER_NUMBER "${i}"
    org_peer_number=$(get_ORG_PEER_NUMBER "${i}")
    infoln "ORG_${i}_PEER_NUMBER=${org_peer_number}"

    for ((ii = 1; ii <= org_peer_number; ii++)); do

      local org_peer_name org_peer_rootpw org_peer_port

      parse_ORG_PEER_NAME "${i}" "${ii}"
      org_peer_name=$(get_ORG_PEER_NAME "${i}" "${ii}")
      infoln "ORG_${i}_PEER_${ii}_NAME=${org_peer_name}.${org_name}.${BASE_DOMAIN}"

      parse_ORG_PEER_ROOTPW "${i}" "${ii}"
      org_peer_rootpw=$(get_ORG_PEER_ROOTPW "${i}" "${ii}")
      infoln "ORG_${i}_PEER_${ii}_ROOTPW=${org_peer_rootpw}"

      parse_ORG_PEER_PORT "${i}" "${ii}"
      org_peer_port=$(get_ORG_PEER_PORT "${i}" "${ii}")
      infoln "ORG_${i}_PEER_${ii}_PORT=${org_peer_port}"
    done

  done

}

function NETWORK() {

  local mode="$1"

  NETWORK_parseConfig

  if [ "X${mode}" == "Xstart" ]; then
    if [ ! -d "${DEPLOY_PATH}/config/crypto-config/peerOrganizations" ]; then
      generateCrypto "a"
      createConsortium
    fi
  elif [ "X${mode}" == "Xclean" ]; then
    rm -rf "${DEPLOY_PATH}/config/crypto-config/"
  else
    fatalln "NETWORK 函数的参数错误。"
  fi

  for ((i = 1; i <= ORDERER_NUMBER; i++)); do
    local orderer_name orderer_rootpw
    orderer_name=$(get_ORDERER_NAME "${i}")
    orderer_rootpw=$(get_ORDERER_ROOTPW "${i}")
    startupOrderer "${orderer_name}" "${orderer_name}.${BASE_DOMAIN}" "${orderer_rootpw}" "${mode}"
  done

  infoln "======>   所有orderer ${mode} 完成。"

  for ((i = 1; i <= ORG_NUMBER; i++)); do
    local org_name org_peer_number
    org_name=$(get_ORG_NAME "${i}")
    org_peer_number=$(get_ORG_PEER_NUMBER "${i}")

    for ((ii = 1; ii <= org_peer_number; ii++)); do
      local org_peer_name org_peer_rootpw
      org_peer_name=$(get_ORG_PEER_NAME "${i}" "${ii}")
      org_peer_rootpw=$(get_ORG_PEER_ROOTPW "${i}" "${ii}")
      startupPeer "${org_peer_name}" "${org_name}" "${org_peer_name}.${org_name}.${BASE_DOMAIN}" "${org_peer_rootpw}" "${mode}"
    done
  done

  infoln "======>   所有peer ${mode} 完成。"

  if [ "X${mode}" == "Xstart" ]; then
    CHANNEL start
  elif [ "X${mode}" == "Xclean" ]; then
    CHANNEL clean
  else
    fatalln "NETWORK 函数的参数错误。"
  fi

}
