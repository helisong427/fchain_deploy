
function generateConfig() {

  which cryptogen
    if ! which cryptogen; then
      fatalln "cryptogen tool not found. exiting"
    fi

  if [ -d "./config/crypto-config" ]; then
    rm -Rf "./config/crypto-config"
  fi

  # 生成证书配置
  cryptogen generate --config=./config/crypto-config.yaml --output ./config/crypto-config/
  if [[ $# -lt 0 ]]; then
    errorln "生成证书文件失败."
  fi

  infoln "生成证书文件完成。"
}


function createConsortium() {

  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found."
  fi


  if [ -d "./config/system-genesis-block/genesis.block" ]; then
    rm -Rf "./config/system-genesis-block/genesis.block"
  fi

  set -x
  configtxgen -profile "${PROFILE_GENESIS}" -channelID system-channel -outputBlock ./config/system-genesis-block/genesis.block
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "创建通道失败：创建创世区块文件失败。"
  fi

  infoln "生成创世区块完成。"
}



function startupOrderer() {

  orderer_name="$1"
  orderer_domain="$2"
  orderer_rootpw="$3"

  if [ "X${orderer_name}" == "X" ]; then
    fatalln "启动orderer失败：startupOrderer，第一个参数（orderer name）为空。"
  fi

  if [ "X${orderer_domain}" == "X" ]; then
    fatalln "启动orderer失败：startupOrderer，第二个参数（orderer domain）为空。"
  fi

  if [ "X${orderer_rootpw}" == "X" ]; then
    fatalln "启动orderer失败：startupOrderer，第三个参数（orderer root passwd）为空。"
  fi

  mkdir -p ./temp/"${orderer_name}"
  # 打包orderer配置文件和镜像
  rm -rf ./temp/"${orderer_name}"/"${orderer_name}".tar && tar -cf ./temp/"${orderer_name}"/"${orderer_name}".tar \
  ./config/crypto-config/ordererOrganizations/"${base_domain}"/orderers/"${orderer_name}"."${base_domain}"/ \
  ./images/files/orderer/ ./config/system-genesis-block/genesis.block ./config/docker/docker-compose-"${orderer_name}".yaml
  cd ./temp/"${orderer_name}"/ && rm -rf "${orderer_name}".md5 && md5sum "${orderer_name}".tar >"${orderer_name}".md5 && cd "${DEPLOY_PATH}"

  sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" > /dev/null 2>&1  <<eeooff0
  if [ ! -d /var/hyperledger ]; then
    mkdir /var/hyperledger
  fi
  exit
eeooff0

  sshpass -p "${orderer_rootpw}" scp ./temp/"${orderer_name}"/"${orderer_name}".md5 root@"${orderer_domain}":/var/hyperledger/"${orderer_name}".md5

  sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >./temp/"${orderer_name}"/"${orderer_name}"_md5.log <<eeooff1
  cd /var/hyperledger
  if [ -f "${orderer_name}".tar ]; then
    md5sum -c "${orderer_name}".md5
  else
    echo "NOT_EXIST"
  fi
  exit
eeooff1

  ret=$(awk 'END{print}' ./temp/"${orderer_name}"/"${orderer_name}"_md5.log | awk -F" " '{print $2}')
  if [ "X${ret}" != "XOK" ]; then
    sshpass -p "${orderer_rootpw}" scp ./temp/"${orderer_name}"/"${orderer_name}".tar root@"${orderer_domain}":/var/hyperledger/"${orderer_name}".tar
  fi

  sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >./temp/"${orderer_name}"/"${orderer_name}"_dockerLoad.log <<eeooff2

  cd /var/hyperledger && rm -rf ./config/crypto-config/ordererOrganizations/"${base_domain}"/orderers/"${orderer_name}"."${base_domain}"/ \
  ./images/files/orderer/ && tar -xf "${orderer_name}".tar

  docker load < ./images/files/orderer/*.gz

  exit
eeooff2

  peerImage=$(awk 'END{print}' ./temp/"${orderer_name}"/"${orderer_name}"_dockerLoad.log | awk -F"Loaded image: " '{print $2}')
  peerImageName=$(echo "${peerImage}" | awk -F":" '{print $1}')
  sshpass -p "${orderer_rootpw}" ssh -tt root@"${orderer_domain}" >./temp/"${orderer_name}"/"${orderer_name}"_dockerUp.log <<eeooff3

  docker rm "${orderer_domain}" -f
  IMAGE_TAG="$IMAGE_TAG" docker-compose -f /var/hyperledger/config/docker/docker-compose-"${orderer_name}".yaml up -d
  docker ps
  exit
eeooff3

  infoln "启动${orderer_name}完成。"
}



function startupPeer() {

  peer_name="$1"
  org_name="$2"
  peer_domain="$3"
  peer_rootpw="$4"

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

  peerOrgName="${peer_name}"."${org_name}"

#  ssh root@"${peer_domain}" <<eeooff
#eeooff

  mkdir -p ./temp/"${peerOrgName}"
  # 打包orderer配置文件和镜像
  rm -rf ./temp/"${peerOrgName}"/"${peerOrgName}".tar && tar -cf ./temp/"${peerOrgName}"/"${peerOrgName}".tar  \
  ./config/crypto-config/peerOrganizations/"${org_name}"."${base_domain}"/peers/"${peerOrgName}"."${base_domain}" \
  ./images/files/peer/ ./config/docker/docker-compose-"${peerOrgName}".yaml

  cd ./temp/"${peerOrgName}"/ && rm -rf "${peerOrgName}".md5 && md5sum "${peerOrgName}".tar > "${peerOrgName}".md5 && cd "${DEPLOY_PATH}"

  sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" > /dev/null 2>&1 <<eeooff0
  if [ ! -d /var/hyperledger ]; then
    mkdir /var/hyperledger
  fi
  exit
eeooff0

  sshpass -p "${peer_rootpw}" scp ./temp/"${peerOrgName}"/"${peerOrgName}".md5 root@"${peer_domain}":/var/hyperledger/"${peerOrgName}".md5
  sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >./temp/"${peerOrgName}"/"${peerOrgName}"_md5.log <<eeooff1
  cd /var/hyperledger
  if [ -f "${peerOrgName}".tar ]; then
    md5sum -c "${peerOrgName}".md5
  else
    echo "NOT_EXIST"
  fi
  exit
eeooff1

  ret=$(awk 'END{print}' ./temp/"${peerOrgName}"/"${peerOrgName}"_md5.log | awk -F" " '{print $2}')
  if [ "X${ret}" != "XOK" ]; then
    sshpass -p "${peer_rootpw}" scp ./temp/"${peerOrgName}"/"${peerOrgName}".tar root@"${peer_domain}":/var/hyperledger/"${peerOrgName}".tar
  fi

  sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >./temp/"${peerOrgName}"/"${peerOrgName}"_dockerLoad.log <<eeooff2

  cd /var/hyperledger && rm -rf ./config/crypto-config/peerOrganizations/"${org_name}"."${base_domain}"/peers/"${peerOrgName}"."${base_domain}"/ \
  ./images/files/peer/ && tar -xf "${peerOrgName}".tar

  docker load < ./images/files/peer/*.gz

  exit
eeooff2

  peerImage=$(awk 'END{print}' ./temp/"${peerOrgName}"/"${peerOrgName}"_dockerLoad.log | awk -F"Loaded image: " '{print $2}')
  peerImageName=$(echo "${peerImage}" | awk -F":" '{print $1}')
  sshpass -p "${peer_rootpw}" ssh -tt root@"${peer_domain}" >./temp/"${peerOrgName}"/"${peerOrgName}"_dockerUp.log <<eeooff3

  docker rm "${peer_domain}" -f

  IMAGE_TAG="${IMAGE_TAG}" docker-compose -f /var/hyperledger/config/docker/docker-compose-"${peerOrgName}".yaml up -d

  docker ps

  exit
eeooff3

    infoln "启动${peerOrgName}成功。"
}

