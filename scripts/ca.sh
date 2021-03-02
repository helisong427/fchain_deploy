#!/bin/bash

function CA_parseConfig() {

  ## ca images tag 配置解析
  if [ "X${CA_IMAGE_TAG}" == "X" ]; then
    fatalln "config CA_IMAGE_TAG 不能为空。"
  fi
  infoln "CA_IMAGE_TAG=${CA_IMAGE_TAG}"

  ## root ca 配置解析
  #  if [ "X${CA_ROOT_NAME}" == "X" ]; then
  #    fatalln "config CA_ROOT_NAME 不能为空。"
  #  fi
  #  infoln "CA_ROOT_NAME=${CA_ROOT_NAME}"
  #
  #  if [ "X${CA_ROOT_ROOTPW}" == "X" ]; then
  #    fatalln "config CA_ROOT_ROOTPW 不能为空。"
  #  fi
  #  infoln "CA_ROOT_ROOTPW=${CA_ROOT_ROOTPW}"
  #
  #  if [ "X${CA_ROOT_PORT}" == "X" ]; then
  #    fatalln "config CA_ROOT_PORT 不能为空。"
  #  fi
  #  infoln "CA_ROOT_PORT=${CA_ROOT_PORT}"

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

function createOrgCrypto() {

  local peer_name="$1" org_name="$2" ca_org_name="$3" ca_org_port="$4"
  local tls_cert_path="${DEPLOY_PATH}/config/ca_tls"
  local ca_domain="${ca_org_name}.${BASE_DOMAIN}"
  local peer_domain="${peer_name}.${org_name}.${BASE_DOMAIN}"

  echo
  echo "Enroll the CA admin"
  echo
  export FABRIC_CA_CLIENT_HOME="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_name}.${BASE_DOMAIN}/"

  mkdir -p "${FABRIC_CA_CLIENT_HOME}"

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@"${ca_domain}:${ca_org_port}" --caname "${ca_org_name}" --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: orderer' >"${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml

  echo
  echo "Register peer0"
  echo
  set -x
  fabric-ca-client register --caname "${org_name}" --id.name "${peer_name}" --id.secret "${peer_name}pw" --id.type peer --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  echo
  echo "Register user"
  echo
  set -x
  fabric-ca-client register --caname "${org_name}" --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  echo
  echo "Register the org admin"
  echo
  set -x
  fabric-ca-client register --caname "${org_name}" --id.name org1admin --id.secret org1adminpw --id.type admin --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  mkdir -p "${FABRIC_CA_CLIENT_HOME}/peers/${peer_name}.${org_name}.${BASE_DOMAIN}"

  echo
  echo "## Generate the peer0 msp"
  echo
  set -x
  fabric-ca-client enroll -u https://"${peer_name}:${peer_name}pw@${ca_domain}:${ca_org_port}" --caname "${org_name}" -M "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/msp --csr.hosts "${peer_domain}" --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${FABRIC_CA_CLIENT_HOME}"/"${peer_domain}"/msp/config.yaml

  echo
  echo "## Generate the peer0-tls certificates"
  echo
  set -x
  fabric-ca-client enroll -u https://"${peer_name}:${peer_name}pw@${ca_domain}:${ca_org_port}" --caname "${org_name}" -M "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls --enrollment.profile tls --csr.hosts "${peer_domain}" --csr.hosts "${ca_domain}" --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  cp "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/ca.crt
  cp "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/signcerts/* "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/server.crt
  cp "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/keystore/* "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/server.key

  mkdir "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts
  cp "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts/ca.crt

  mkdir "${FABRIC_CA_CLIENT_HOME}"/tlsca
  cp "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}/tlsca/tlsca.${org_name}.${BASE_DOMAIN}"-cert.pem

  mkdir "${FABRIC_CA_CLIENT_HOME}"/ca
  cp "${FABRIC_CA_CLIENT_HOME}"/peers/"${peer_domain}"/msp/cacerts/* "${FABRIC_CA_CLIENT_HOME}/ca/ca.${org_name}.${BASE_DOMAIN}"-cert.pem

  mkdir -p "${FABRIC_CA_CLIENT_HOME}"/users
  mkdir -p "${FABRIC_CA_CLIENT_HOME}"/users/User1@"${org_name}.${BASE_DOMAIN}"

  echo
  echo "## Generate the user msp"
  echo
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@"${ca_domain}:${ca_org_port}" --caname "${ca_name}" -M "${FABRIC_CA_CLIENT_HOME}/users/User1@${org_name}.${BASE_DOMAIN}/msp" --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${FABRIC_CA_CLIENT_HOME}/users/User1@${org_name}.${BASE_DOMAIN}/msp/config.yaml"

  mkdir -p "${FABRIC_CA_CLIENT_HOME}/users/Admin@${org_name}.${BASE_DOMAIN}"

  echo
  echo "## Generate the org admin msp"
  echo
  set -x
  fabric-ca-client enroll -u https://org1admin:org1adminpw@"${ca_domain}:${ca_org_port}" --caname "${ca_name}" -M "${FABRIC_CA_CLIENT_HOME}/users/Admin@${org_name}.${BASE_DOMAIN}/msp" --tls.certfiles "${tls_cert_path}/${ca_org_name}/tls-cert.pem"
  set +x

  cp "${FABRIC_CA_CLIENT_HOME}/msp/config.yaml" "${FABRIC_CA_CLIENT_HOME}/users/Admin@${org_name}.${BASE_DOMAIN}/msp/config.yaml"

}

function startup() {

  local temp_dir ca_name="$1" ca_rootpw="$2" ca_domain="$3" ca_port="$4" mode="$5"

  if [ "X${ca_name}" == "X" ]; then
    fatalln "启动ca失败：startup，第一个参数（ca name）为空。"
  fi

  if [ "X${ca_domain}" == "X" ]; then
    fatalln "启动ca失败：startup，第二个参数（ca domain）为空。"
  fi

  if [ "X${ca_rootpw}" == "X" ]; then
    fatalln "启动ca失败：startup，第三个参数（ca root passwd）为空。"
  fi

  if [ "X${ca_port}" == "X" ]; then
    fatalln "启动ca失败：startup，第四个参数（ca port）为空。"
  fi

  temp_dir="${DEPLOY_PATH}/temp/${ca_name}"

  if [ "X${mode}" == "Xstart" ]; then

    rm -rf "${temp_dir}" && mkdir -p "${temp_dir}"
    # 打包ca配置文件和镜像
    tar -cf "${temp_dir}"/"${ca_name}".tar \
      images/files/ca/ \
      config/docker/docker-compose-"${ca_name}".yaml

    uploadFile "${ca_name}" "${temp_dir}" "${ca_rootpw}" "${ca_domain}"

    sshpass -p "${ca_rootpw}" ssh -o StrictHostKeyChecking=no -tt root@"${ca_domain}" >"${temp_dir}"/"${ca_name}"_dockerLoad.txt <<eeooff
      cd /var/hyperledger && \
      rm -rf ./images/files/ca/ && \
      tar -xf "${ca_name}".tar && \
      docker load < ./images/files/ca/*.tar
      cd  /var/hyperledger/config/docker
      CA_IMAGE_TAG="$CA_IMAGE_TAG" CA_PORT="${ca_port}" docker-compose -f docker-compose-"${ca_name}".yaml up -d
      docker ps
      exit
eeooff

    local tls_file_path="${DEPLOY_PATH}/config/ca_tls/${ca_name}"
    mkdir -p "${tls_file_path}" && rm -rf "${tls_file_path}"/tls-cert.pem

    local rc=1 counter=1
    while [ $rc -ne 0 -a $counter -lt ${MAX_RETRY} ]; do
      sleep ${DELAY}
      set -x
      sshpass -p "${ca_rootpw}" scp -o StrictHostKeyChecking=no root@"${ca_domain}":/var/lib/docker/volumes/docker_"${ca_name}"."${BASE_DOMAIN}"/_data/tls-cert.pem "${tls_file_path}"/tls-cert.pem
      res=$?
      { set +x; } 2>/dev/null
      let rc=$res
      counter=$(expr $counter + 1)
    done

    infoln "启动${ca_name}完成。"

  elif [ "X${mode}" == "Xclean" ]; then

    sshpass -p "${ca_rootpw}" ssh -o StrictHostKeyChecking=no -tt root@"${ca_domain}" >"${temp_dir}"/"${ca_name}"_dockerDown.txt <<eeooff
      cd  /var/hyperledger/config/docker
      docker rm ${ca_domain} -vf
      docker volume rm docker_${ca_domain}
      exit
eeooff
    infoln " ${ca_name} ${mode} 完成。"

  else
    fatalln "startup 函数的参数错误。"
  fi

}

function CA() {

  local mode="$1"

  CA_parseConfig

  #startup "${CA_ROOT_NAME}" "${CA_ROOT_ROOTPW}" "${CA_ROOT_NAME}.${BASE_DOMAIN}" "${CA_ROOT_PORT}" "${mode}"

  startup "${CA_ORDERER_NAME}" "${CA_ORDERER_ROOTPW}" "${CA_ORDERER_NAME}.${BASE_DOMAIN}" "${CA_ORDERER_PORT}" "${mode}"

  for ((i = 1; i <= ORG_NUMBER; i++)); do
    local ca_name ca_rootpw ca_port
    ca_name=$(get_CA_ORG_NAME "${i}")
    ca_rootpw=$(get_CA_ORG_ROOTPW "${i}")
    ca_port=$(get_CA_ORG_PORT "${i}")
    startup "${ca_name}" "${ca_rootpw}" "${ca_name}.${BASE_DOMAIN}" "${ca_port}" "${mode}"
  done

  if [ "X${mode}" == "Xstart" ]; then
    infoln "======>   所有ca ${mode} 完成。"
  elif [ "X${mode}" == "Xclean" ]; then
    infoln "======>   所有ca ${mode} 完成。"
  else
    fatalln "NETWORK 函数的参数错误。"
  fi

}

function CA_createCrypto() {

  for ((i = 1; i <= ORG_NUMBER; i++)); do
    local ca_name ca_port org_name org_peer_number
    ca_name=$(get_CA_ORG_NAME "${i}")
    ca_port=$(get_CA_ORG_PORT "${i}")
    org_name=$(get_ORG_NAME "${i}")
    org_peer_number=$(get_ORG_PEER_NUMBER "${i}")

    for ((ii = 1; ii <= org_peer_number; ii++)); do
      local org_peer_name
      org_peer_name=$(get_ORG_PEER_NAME "${i}" "${ii}")

      createOrgCrypto "${org_peer_name}" "${org_name}" "${ca_name}" "${ca_port}"
    done

  done

}
