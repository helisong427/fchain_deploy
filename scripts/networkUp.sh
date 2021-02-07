
function generateConfig() {

  which cryptogen
    if ! which cryptogen; then
      fatalln "cryptogen tool not found. exiting"
    fi

  if [ -d "${PWD}/config/crypto-config" ]; then
    rm -Rf "${PWD}/config/crypto-config"
  fi

  # 生成证书配置
  cryptogen generate --config="${PWD}"/config/crypto-config.yaml --output "${PWD}"/config/crypto-config/
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


  if [ -d "${PWD}/config/system-genesis-block/genesis.block" ]; then
    rm -Rf "${PWD}/config/system-genesis-block/genesis.block"
  fi

  set -x
  configtxgen -profile "${PROFILE_GENESIS}" -channelID system-channel -outputBlock "${PWD}"/config/system-genesis-block/genesis.block
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "创建通道失败：创建创世区块文件失败。"
  fi

  infoln "生成创世区块完成。"
}



function startupOrder() {

  ORDERER_HOSTNAME="$1"
  ORDERER_DOMAIN="$2"
  ROOT_PASSWORD="$3"

  if [ "X${ORDERER_HOSTNAME}" == "X" ]; then
    fatalln "启动orderer失败：需要-SOh参数带上orderer hostname 在cryptoconfig.yaml中定义"
  fi

  if [ "X${ORDERER_DOMAIN}" == "X" ]; then
    fatalln "启动orderer失败：需要-SOd参数带上orderer domain 为orderer所规划的服务的域名"
  fi

  if [ "X${ROOT_PASSWORD}" == "X" ]; then
    fatalln "启动orderer失败：需要-SOp参数服务器的root密码"
  fi

  # 打包orderer配置文件和镜像
  rm -rf ./temp/"${ORDERER_HOSTNAME}".tar && tar -cf ./temp/"${ORDERER_HOSTNAME}".tar \
  ./config/crypto-config/ordererOrganizations/lianxiang.com/orderers/"${ORDERER_HOSTNAME}".lianxiang.com/ \
  ./images/files/orderer/ ./config/system-genesis-block/genesis.block ./config/docker/docker-compose-"${ORDERER_HOSTNAME}".yaml
  cd "${PWD}"/temp && rm -rf "${ORDERER_HOSTNAME}".md5 && md5sum "${ORDERER_HOSTNAME}".tar >"${ORDERER_HOSTNAME}".md5 && cd ..

  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${ORDERER_DOMAIN}" > /dev/null 2>&1  <<eeooff0
  if [ ! -d /var/hyperledger ]; then
    mkdir /var/hyperledger
  fi
  exit
eeooff0

  sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${ORDERER_HOSTNAME}".md5 root@"${ORDERER_DOMAIN}":/var/hyperledger/"${ORDERER_HOSTNAME}".md5

  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${ORDERER_DOMAIN}" >./temp/"${ORDERER_HOSTNAME}"_md5.log <<eeooff1
  cd /var/hyperledger
  if [ -f "${ORDERER_HOSTNAME}".tar ]; then
    md5sum -c "${ORDERER_HOSTNAME}".md5
  else
    echo "NOT_EXIST"
  fi
  exit
eeooff1

  ret=$(awk 'END{print}' ./temp/"${ORDERER_HOSTNAME}"Md5.log | awk -F" " '{print $2}')
  if [ "X${ret}" != "XOK" ]; then
    sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${ORDERER_HOSTNAME}".tar root@"${ORDERER_DOMAIN}":/var/hyperledger/"${ORDERER_HOSTNAME}".tar
  fi

  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${ORDERER_DOMAIN}" >./temp/"${ORDERER_HOSTNAME}"_dockerLoad.log <<eeooff2
  cd /var/hyperledger && rm -rf ./config/crypto-config/ordererOrganizations/lianxiang.com/orderers/"${ORDERER_HOSTNAME}".lianxiang.com/ ./images/files/orderer/ && tar -xf "${ORDERER_HOSTNAME}".tar
  docker load < ./images/files/orderer/*.gz
  exit
eeooff2

  peerImage=$(awk 'END{print}' ./temp/"${ORDERER_HOSTNAME}"DockerLoad.log | awk -F"Loaded image: " '{print $2}')
  peerImageName=$(echo "${peerImage}" | awk -F":" '{print $1}')
  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${ORDERER_DOMAIN}" >./temp/"${ORDERER_HOSTNAME}"_containerUp.log <<eeooff3

  docker rm "${ORDERER_DOMAIN}" -f
  IMAGE_TAG="$IMAGE_TAG" docker-compose -f /var/hyperledger/config/docker/docker-compose-"${ORDERER_HOSTNAME}".yaml up -d
  docker ps
  exit
eeooff3

  infoln "启动${ORDERER_HOSTNAME}完成。"
}



function startupPeer() {

  PEER_HOSTNAME="$1"
  ORG_HOSTNAME="$2"
  PEER_DOMAIN="$3"
  ROOT_PASSWORD="$4"

  if [ "X${PEER_HOSTNAME}" == "X" ]; then
    fatalln "启动peer失败：需要-SPpn参数带上peer name，默认是peer0、peer1 这种格式"
  fi

  if [ "X${ORG_HOSTNAME}" == "X" ]; then
    fatalln "启动peer失败：需要-SPon参数带上org name 在crypto-config.yaml中定义（注意需要小写）"
  fi

  if [ "X${PEER_DOMAIN}" == "X" ]; then
    fatalln "启动peer失败：需要-SPd参数带上peer domain 为peer所规划的服务的域名"
  fi

  if [ "X${ROOT_PASSWORD}" == "X" ]; then
    fatalln "启动peer失败：需要-SPp参数服务器的root密码"
  fi

  peerOrgName="${PEER_HOSTNAME}"."${ORG_HOSTNAME}"

#  ssh root@"${PEER_DOMAIN}" <<eeooff
#eeooff

  # 打包orderer配置文件和镜像
  rm -rf ./temp/"${peerOrgName}".tar && tar -cf ./temp/"${peerOrgName}".tar  \
  ./config/crypto-config/peerOrganizations/"${ORG_HOSTNAME}".lianxiang.com/peers/"${peerOrgName}".lianxiang.com \
  ./images/files/peer/ ./config/docker/docker-compose-"${peerOrgName}".yaml
  cd "${PWD}"/temp && rm -rf "${peerOrgName}".md5 && md5sum "${peerOrgName}".tar >"${peerOrgName}".md5 && cd ..

  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${PEER_DOMAIN}" > /dev/null 2>&1 <<eeooff0
  if [ ! -d /var/hyperledger ]; then
    mkdir /var/hyperledger
  fi
  exit
eeooff0

  sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${peerOrgName}".md5 root@"${PEER_DOMAIN}":/var/hyperledger/"${peerOrgName}".md5
  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${PEER_DOMAIN}" >./temp/"${peerOrgName}"Md5.log <<eeooff1
  cd /var/hyperledger
  if [ -f "${peerOrgName}".tar ]; then
    md5sum -c "${peerOrgName}".md5
  else
    echo "NOT_EXIST"
  fi
  exit
eeooff1

  ret=$(awk 'END{print}' ./temp/"${peerOrgName}"Md5.log | awk -F" " '{print $2}')
  if [ "X${ret}" != "XOK" ]; then
    sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${peerOrgName}".tar root@"${PEER_DOMAIN}":/var/hyperledger/"${peerOrgName}".tar
  fi

  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${PEER_DOMAIN}" >./temp/"${peerOrgName}"DockerLoad.log <<eeooff2
  cd /var/hyperledger && rm -rf ./config/crypto-config/peerOrganizations/"${ORG_HOSTNAME}".lianxiang.com/peers/"${peerOrgName}".lianxiang.com/ ./images/files/peer/ && tar -xf "${peerOrgName}".tar
  docker load < ./images/files/peer/*.gz
  exit
eeooff2


  peerImage=$(awk 'END{print}' ./temp/"${peerOrgName}"DockerLoad.log | awk -F"Loaded image: " '{print $2}')
  peerImageName=$(echo "${peerImage}" | awk -F":" '{print $1}')
  sshpass -p "${ROOT_PASSWORD}" ssh -tt root@"${PEER_DOMAIN}" >./temp/"${peerOrgName}"DockerTag.log <<eeooff3

  docker rm "${PEER_DOMAIN}" -f
  IMAGE_TAG="${IMAGE_TAG}" docker-compose -f /var/hyperledger/config/docker/docker-compose-"${peerOrgName}".yaml up -d
  docker ps
  exit
eeooff3

    infoln "启动${peerOrgName}成功。"
}
