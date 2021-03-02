#!/bin/bash

function pushCcenvImagesFile() {
  local org_index="$1" peer_index="$2"
  local org_name org_domain peer_name peer_rootpw peer_domain
  local temp_dir="${DEPLOY_PATH}/temp/ccenv"

  org_name=$(get_ORG_NAME "${org_index}")
  org_domain="${org_name}.${BASE_DOMAIN}"
  peer_name=$(get_ORG_PEER_NAME "${org_index}" "${peer_index}")
  peer_rootpw=$(get_ORG_PEER_ROOTPW "${org_index}" "${peer_index}")
  peer_domain="${peer_name}.${org_domain}"

  mkdir -p "${temp_dir}"

  if [ ! -f "${temp_dir}/ccenv.tar" ]; then
    tar -cf "${temp_dir}/ccenv.tar" images/files/ccenv/ images/files/baseos/
  fi

  uploadFile "ccenv" "${temp_dir}" "${peer_rootpw}" "${peer_domain}"

#  sshpass -p "${peer_rootpw}" ssh -o StrictHostKeyChecking=no -tt root@"${peer_domain}" >"${temp_dir}"/ccenv_md5.txt <<eeooff1
#  cd /var/hyperledger
#  if [ -f ccenv.tar ]; then
#    echo "ccenv.tar EXIST"
#  fi
#  exit
#eeooff1
#
#  local ret
#  ret=$(grep -n '^ccenv.tar' "${temp_dir}"/ccenv_md5.txt | awk -F" " '{print $2}' | tr -d '\n\r')
#  if [ "X${ret}" != "XEXIST" ]; then
#    sshpass -p "${peer_rootpw}" scp -o StrictHostKeyChecking=no "${temp_dir}"/ccenv.tar root@"${peer_domain}":/var/hyperledger/ccenv.tar
#  else
#    infoln "ccenv.tar 文件存在，不需要上传。"
#  fi

  sshpass -p "${peer_rootpw}" ssh -o StrictHostKeyChecking=no -tt root@"${peer_domain}" >"${temp_dir}"/ccenv_dockerLoad.txt <<eeooff2
  cd /var/hyperledger
  if [ ! -f ./images/files/ccenv/*.tar ] || [ ! -f ./images/files/baseos/*.tar ]; then
     tar -xf ccenv.tar
  fi

  docker load < ./images/files/ccenv/*.tar
  docker load < ./images/files/baseos/*.tar
  exit
eeooff2
}

# 打包链码
function packageChaincode() {
  set -e
  pushd "${CC_SRC_PATH}" >/dev/null 2>&1
  GO111MODULE=on go mod vendor
  popd >/dev/null 2>&1
  set +e

  local temp_dir="${DEPLOY_PATH}"/temp/chaincode/"${CC_NAME}"
  rm -rf "${temp_dir}" && mkdir -p "${temp_dir}"
  set -x
  peer lifecycle chaincode package "${temp_dir}/${CC_NAME}".tar.gz --path "${CC_SRC_PATH}" --lang "${CC_RUNTIME_LANGUAGE}" --label "${CC_NAME}_${CC_VERSION}" >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode packaging has failed"
  successln "${CC_NAME} 链码打包完成。"
}

# 安装链码 参数：installChaincode org_index peer_index
function installChaincode() {
  local org_index="$1" peer_index="$2"
  local temp_dir="${DEPLOY_PATH}"/temp/chaincode/"${CC_NAME}"

  if [ ! -f "${DEPLOY_PATH}"/temp/chaincode/"${CC_NAME}"/"${CC_NAME}".tar.gz ]; then
    fatalln "链码文件${DEPLOY_PATH}/temp/chaincode/${CC_NAME}/${CC_NAME}.tar.gz 不存在。"
  fi

  pushCcenvImagesFile "${org_index}" "${peer_index}"

  setGlobals "${org_index}" "${peer_index}"

  set -x
  peer lifecycle chaincode install "${DEPLOY_PATH}"/temp/chaincode/"${CC_NAME}"/"${CC_NAME}".tar.gz >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "在 peer${peer_index}.org${org_index} 安装链码失败。"
  successln "在 peer${peer_index}.org${org_index} 安装链码成功。"
}

# 安装链码查询 queryInstalled org_index peer_index
function queryInstalled() {
  local org_index="$1" peer_index="$2"
  setGlobals "${org_index}" "${peer_index}"
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  #cat log.txt
  PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  verifyResult $res "在peer peer${peer_index}.org${org_index} 查询链码失败。"

  if [ "X${PACKAGE_ID}" == "X" ]; then
    errorln "在peer peer${peer_index}.org${org_index} 查询不到安装的链码（${CC_NAME}_${CC_VERSION}）。"
  else
    successln "在peer peer${peer_index}.org${org_index} 查询链码成功。链码ID：${PACKAGE_ID}"
  fi

}

# 审批链码 approveForMyOrg VERSION PEER ORG
function approveForMyOrg() {
  local org_index="$1" peer_index="$2"

  setGlobals "${org_index}" "${peer_index}"

  local orderer_name orderer_port orderer_domain orderer_ca
  orderer_name=$(get_ORDERER_NAME "1")
  orderer_port=$(get_ORDERER_PORT "1")
  orderer_domain="${orderer_name}.${BASE_DOMAIN}"
  orderer_ca="crypto-config/ordererOrganizations/${BASE_DOMAIN}/orderers/${orderer_domain}/msp/tlscacerts/tlsca.${BASE_DOMAIN}-cert.pem"

  set -x
  peer lifecycle chaincode approveformyorg \
    -o "${orderer_domain}":"${orderer_port}" \
    --ordererTLSHostnameOverride "${orderer_domain}" \
    --tls \
    --cafile "${orderer_ca}" \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --package-id "${PACKAGE_ID}" \
    --sequence "${CC_SEQUENCE}" \
    "${CC_INIT}" >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "链码在组织 (peer${peer_index}.org${org_index}) 的通道（${CHANNEL_NAME}）上审批失败。"
  successln "链码在组织 (peer${peer_index}.org${org_index}) 的通道（${CHANNEL_NAME}）上审批完成。"

}

# 检查链码是否审批通过 checkCommitReadiness VERSION PEER ORG
checkCommitReadiness() {
  local org_index="$1" peer_index="$2"
  setGlobals "${org_index}" "${peer_index}"
  shift 2

  infoln "Checking the commit readiness of the chaincode definition on peer0.org${org_index} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to check the commit readiness of the chaincode definition on peer0.org${org_index}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode checkcommitreadiness \
      --channelID "${CHANNEL_NAME}" \
      --name "${CC_NAME}" \
      --version "${CC_VERSION}" \
      --sequence "${CC_SEQUENCE}" \
      "${CC_INIT}" \
      --output json >&log.txt

    res=$?
    { set +x; } 2>/dev/null
    let rc=0
    for var in "$@"; do
      grep "$var: true" log.txt &>/dev/null || let rc=1
    done
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    infoln "Checking the commit readiness of the chaincode definition successful on peer${peer_index}.org${org_index} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Check commit readiness result on peer${peer_index}.org${org_index} is INVALID!"
  fi
}

# 提交链码 commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
commitChaincodeDefinition() {

  setGlobals "${org_index}" "${peer_index}"

  local orderer_name orderer_port orderer_ca
  orderer_name=$(get_ORDERER_NAME "1")
  orderer_port=$(get_ORDERER_PORT "1")
  orderer_domain="${orderer_name}.${BASE_DOMAIN}"
  orderer_ca="crypto-config/ordererOrganizations/${BASE_DOMAIN}/orderers/${orderer_domain}/msp/tlscacerts/tlsca.${BASE_DOMAIN}-cert.pem"

  parsePeerConnectionParameters "$@"
  set -x
  peer lifecycle chaincode commit \
    -o "${orderer_domain}":"${orderer_port}" \
    --ordererTLSHostnameOverride "${orderer_domain}" \
    --tls \
    --cafile "${orderer_ca}" \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    ${PEER_CONN_PARMS} \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    "${CC_INIT}" >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on $PEERS on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

# 查询链码提交 queryCommitted ORG
queryCommitted() {
  local org_index="$1" peer_index="$2"
  setGlobals "${org_index}" "${peer_index}"
  EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
  infoln "Querying chaincode definition on peer${peer_index}.org${org_index} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query committed status on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: '$CC_VERSION', Sequence: [0-9]*, Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    successln "Query chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Query chaincode definition result on peer0.org${ORG} is INVALID!"
  fi
}

chaincodeInvokeInit() {

  parsePeerConnectionParameters "$@"

  local orderer_name orderer_port orderer_ca
  orderer_name=$(get_ORDERER_NAME "1")
  orderer_port=$(get_ORDERER_PORT "1")
  orderer_domain="${orderer_name}.${BASE_DOMAIN}"
  orderer_ca="crypto-config/ordererOrganizations/${BASE_DOMAIN}/orderers/${orderer_domain}/msp/tlscacerts/tlsca.${BASE_DOMAIN}-cert.pem"

  infoln "invoke fcn call:${CC_INIT_FUNCTION}"
  set -x
  #FABRIC_LOGGING_SPEC=DEBUG
  peer chaincode invoke \
    -o "${orderer_domain}":"${orderer_port}" \
    --ordererTLSHostnameOverride "${orderer_domain}" \
    --tls \
    --cafile "${orderer_ca}" \
    -C "${CHANNEL_NAME}" \
    -n "${CC_NAME}" \
    "${PEER_CONN_PARMS}" \
    --isInit \
    -c "${CC_INIT_FUNCTION}" >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  successln "Invoke transaction successful on ${PEERS} on channel '$CHANNEL_NAME'"
}

# 参数解析
function CC_parseConfig() {




  if [ "${CC_NUMBER}" -lt 1 ]; then
    fatalln "config CC_NUMBER 需要大于0"
  fi
  infoln "CC_NUMBER=$CC_NUMBER"

  for ((i = 1; i <= CC_NUMBER; i++)); do

    local cc_name cc_version cc_peers cc_sequence cc_init cc_init_function
    parse_CC_NAME "${i}"
    cc_name=$(get_CC_NAME "${i}")
    infoln "CC_${i}_NAME=${cc_name}"

    if [ ! -d "${DEPLOY_PATH}/chaincode/${cc_name}/go" ]; then
      fatalln "链码${cc_name} 文件目录不存在（${DEPLOY_PATH}/chaincode/${cc_name}/go）。"
    fi

    parse_CC_VERSION "${i}"
    cc_version=$(get_CC_VERSION "${i}")
    infoln "CC_${i}_VERSION=${cc_version}"

    parse_CC_PEERS "${i}"
    cc_peers=$(get_CC_PEERS "${i}")
    infoln "CC_${i}_PEERS=${cc_peers}"

    parse_CC_SEQUENCE "${i}"
    cc_sequence=$(get_CC_SEQUENCE "${i}")
    infoln "CC_${i}_SEQUENCE=${cc_sequence}"

    cc_init=$(get_CC_INIT "${cc_index}") || true
    if [ "X${cc_init}" == "Xtrue" ]; then
      parse_CC_INIT_FUNCTION "${i}"
      cc_init_function=$(get_CC_INIT_FUNCTION "${i}")
      infoln "CC_${i}_INIT=${cc_init}"
      infoln "CC_${i}_INIT_FUNCTION=${cc_init_function}"
    fi

    local org_array=()
    IFS=" " read -r -a peers <<<"$cc_peers"
    for peer in "${peers[@]}"; do
      local org_index peer_index
      org_index=$(echo "${peer}" | awk -F"_" '{print $1}')
      peer_index=$(echo "${peer}" | awk -F"_" '{print "$2"}')

      parse_ORG_PEER_NAME "${org_index}" "${peer_index}"
      parse_ORG_PEER_ROOTPW "${org_index}" "${peer_index}"
      parse_ORG_PEER_PORT "${org_index}" "${peer_index}"

      local org_exist
      for org in "${org_array[@]}"; do
        if [[ "${org}" == "${org_index}" ]]; then
          org_exist="EXIST"
          break
        fi
      done

      if [ "X${org_exist}" != "XEXIST" ]; then
        org_array[${#org_array[*]}]="${org_index}"
      fi
    done

    if [ $((ORG_NUMBER)) -ne ${#org_array[@]} ]; then
      fatalln "CC_${i}_PEERS 配置错误，没有包含所有组织。"
    fi

  done
}

function CC_exportEnv() {
  local cc_index="$1"
  # 解析参数
  unset CC_NAME
  CC_NAME=$(get_CC_NAME "${cc_index}") || true

  unset CC_VERSION
  CC_VERSION=$(get_CC_VERSION "${cc_index}") || true

  unset CC_PEERS
  CC_PEERS=$(get_CC_PEERS "${cc_index}") || true

  unset CC_SEQUENCE
  CC_SEQUENCE=$(get_CC_SEQUENCE "${cc_index}") || true

  unset CC_INIT
  local cc_init
  cc_init=$(get_CC_INIT "${cc_index}") || true
  if [ "X${cc_init}" == "Xtrue" ]; then
    unset CC_INIT_FUNCTION
    CC_INIT_FUNCTION=$(get_CC_INIT_FUNCTION "${cc_index}") || true

    CC_INIT="--init-required"
  else
    CC_INIT=""
  fi

  #  unset CC_SIGNATURE_POLICY
  #  local cc_signature_policy
  #  cc_signature_policy=$(get_CC_SIGNATURE_POLICY "${cc_index}") || true
  #  if [ "X${cc_signature_policy}" == "X" ]; then
  #    CC_SIGNATURE_POLICY="--channel-config-policy"
  #  else
  #    CC_SIGNATURE_POLICY="--signature-policy ${cc_signature_policy}"
  #  fi

  unset CC_SRC_PATH
  CC_SRC_PATH="${DEPLOY_PATH}/chaincode/${CC_NAME}/go" || true

  unset CC_RUNTIME_LANGUAGE
  CC_RUNTIME_LANGUAGE="golang"

  unset CC_COLL_CONFIG
  CC_COLL_CONFIG=""

}

function CC_deploy() {
  infoln "======>   开始部署链码 ${CC_NAME} 。"
  packageChaincode

  local org_array=()
  IFS=" " read -r -a peers <<<"$CC_PEERS"
  for peer in "${peers[@]}"; do
    local org_index peer_index
    org_index=$(echo "${peer}" | awk -F"_" '{print $1}')
    peer_index=$(echo "${peer}" | awk -F"_" '{print $2}')

    installChaincode "${org_index}" "${peer_index}"
    queryInstalled "${org_index}" "${peer_index}"
    local org_exist
    for org in "${!org_array[@]}"; do
      if [[ ${org} -eq $((org_index)) ]]; then
        org_exist="EXIST"
        break
      fi
    done

    if [ "X${org_exist}" != "XEXIST" ]; then
      org_array[$((org_index))]=$((peer_index))
    fi
    org_exist=""
  done

  local checkCommitResult=""
  for org in "${!org_array[@]}"; do
    approveForMyOrg "${org}" "${org_array[$org]}"
    local org_msp_name
    org_msp_name=$(get_ORG_MSP_NAME "${org}")
    checkCommitResult="${checkCommitResult} \"${org_msp_name}\""
  done

  for org in "${!org_array[@]}"; do
    checkCommitReadiness "${org}" "${org_array[org]}" ${checkCommitResult}
  done

  local params
  for org in "${!org_array[@]}"; do
    params="${params} ${org} ${org_array[org]}"
  done

  commitChaincodeDefinition ${params}

  for org in "${!org_array[@]}"; do
    queryCommitted "${org}" "${org_array[org]}"
  done

  if [ "X${CC_INIT_FUNCTION}" == "X" ]; then
    infoln "链码${CC_NAME} 不需要执行初始化函数。"
  else
    chaincodeInvokeInit ${params}
  fi

  infoln "======>   ${CC_NAME} 链码部署完成。"
}

function CHAINCODE() {

  local mode="$1"

  CC_parseConfig

  for ((i = 1; i <= CC_NUMBER; i++)); do
    CC_exportEnv "${i}"
    if [ "X${mode}" == "Xstart" ]; then
      CC_deploy
    elif [ "X${mode}" == "Xclean" ]; then
      rm -rf "${DEPLOY_PATH}"/temp/chaincode/"${CC_NAME}"
    else
      fatalln " CHAINCODE 函数的参数错误。"
    fi
  done
}