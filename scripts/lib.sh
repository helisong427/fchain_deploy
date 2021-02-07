
# 生成证书文件
function createCryptogen() {
  if [ -d "${DEPLOY_PATH}/config/crypto-config" ]; then
    rm -Rf "${DEPLOY_PATH}/config/crypto-config"
  fi

  # 生成证书配置
  cryptogen generate --config="${DEPLOY_PATH}"/config/crypto-config.yaml --output "${DEPLOY_PATH}"/config/crypto-config/
  if [[ $# -lt 0 ]]; then
    errorln "生成证书文件失败."
  fi

  printf "生成证书文件成功"
}

#生成创世区块文件
function createConfig() {

  if [ "X${PROFILE_GENESIS}" == "X" ]; then
    fatalln "创建通道失败：需要-CCg参数带上通道配置文件configtx.yaml中 Profiles 域中关于创世块的配置域的域名"
  fi

  if [ "X${PROFILE_CHANNEL}" == "X" ]; then
    fatalln "创建通道失败：需要-CCc参数带上通道配置文件configtx.yaml中 Profiles 域中关于通道配置域的域名"
  fi

  if [ "X${CHANNEL_NAME}" == "X" ]; then
    fatalln "创建通道失败：需要-CCcn参数带上通道名称"
  fi

  if [ -d "./config/channel-artifacts/${CHANNEL_NAME}.tx" ]; then
    rm -Rf "./config/channel-artifacts/${CHANNEL_NAME}.tx"
  fi

  if [ -d "./config/system-genesis-block/genesis.block" ]; then
    rm -Rf "./config/system-genesis-block/genesis.block"
  fi

  if [ -d "./config/crypto-config" ]; then
    rm -Rf "./config/crypto-config"
  fi

  # 生成证书配置
  cryptogen generate --config="${PWD}"/config/crypto-config.yaml --output "${PWD}"/config/crypto-config/
  if [[ $# -lt 0 ]]; then
    errorln "生成证书文件失败."
  fi

  println "生成证书文件完成。"

  set -x
  configtxgen -profile "${PROFILE_GENESIS}" -channelID system-channel -outputBlock "${PWD}"/config/system-genesis-block/genesis.block
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "创建通道失败：创建创世区块文件失败。"
  fi

  set -x
  configtxgen -profile "${PROFILE_CHANNEL}" -outputCreateChannelTx "${PWD}"/config/channel-artifacts/"${CHANNEL_NAME}".tx -channelID "${CHANNEL_NAME}"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "创建通道失败：创建通道失败。"
  fi

  println "创建通道成功。"
}

function createOrgAnchor() {

  if [ "X${PROFILE_CHANNEL}" == "X" ]; then
    fatalln "创建锚节点失败：需要-COAc参数带上通道配置文件configtx.yaml中 Profiles 域中关于通道配置域的域名"
  fi

  if [ "X${ORG_MSP_NAME}" == "X" ]; then
    fatalln "创建锚节点失败：需要-COAomn参数带上组织的msp名称，定义在通道配置文件configtx.yaml中 Organizations.org 里面"
  fi

  if [ "X${CHANNEL_NAME}" == "X" ]; then
    fatalln "创建锚节点失败：需要-COAcn参数带上通道名称"
  fi

  if [ -d "${PWD}/config/system-genesis-block/${ORG_MSP_NAME}.tx" ]; then
    rm -Rf "${PWD}/config/system-genesis-block/${ORG_MSP_NAME}.tx"
  fi

  set -x
  configtxgen -profile "${PROFILE_CHANNEL}" -outputAnchorPeersUpdate "${PWD}"/config/channel-artifacts/"${ORG_MSP_NAME}".tx -channelID "${CHANNEL_NAME}" -asOrg "${ORG_MSP_NAME}"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "创建锚节点失败：创建锚节点失败。"
  fi

  println "创建组织${ORG_MSP_NAME}锚节点成功。"
}

function startupOrder() {
  if [ "X${ORDERER_HOSTNAME}" == "X" ]; then
    fatalln "启动orderer失败：需要-SOh参数带上orderer hostname 在cryptoconfig.yaml中定义"
  fi

  if [ "X${ORDERER_name}" == "X" ]; then
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

  sshpass -p "${ROOT_PASSWORD}" ssh root@"${ORDERER_name}" <<eeooff0
  if [ ! -d /var/hyperledger ]; then
    mkdir /var/hyperledger
  fi
eeooff0

  sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${ORDERER_HOSTNAME}".md5 root@"${ORDERER_name}":/var/hyperledger/"${ORDERER_HOSTNAME}".md5
  sshpass -p "${ROOT_PASSWORD}" ssh root@"${ORDERER_name}" >./temp/"${ORDERER_HOSTNAME}"Md5.log <<eeooff1
  cd /var/hyperledger
  if [ -f "${ORDERER_HOSTNAME}".tar ]; then
    md5sum -c "${ORDERER_HOSTNAME}".md5
  else
    echo "NOT_EXIST"
  fi
eeooff1

  ret=$(awk 'END{print}' ./temp/"${ORDERER_HOSTNAME}"Md5.log | awk -F" " '{print $2}')
  if [ "X${ret}" != "XOK" ]; then
    sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${ORDERER_HOSTNAME}".tar root@"${ORDERER_name}":/var/hyperledger/"${ORDERER_HOSTNAME}".tar
  fi

  sshpass -p "${ROOT_PASSWORD}" ssh root@"${ORDERER_name}" >./temp/"${ORDERER_HOSTNAME}"DockerLoad.log <<eeooff2
  cd /var/hyperledger && rm -rf ./config/crypto-config/ordererOrganizations/lianxiang.com/orderers/"${ORDERER_HOSTNAME}".lianxiang.com/ ./images/files/orderer/ && tar -xf "${ORDERER_HOSTNAME}".tar
  docker load < ./images/files/orderer/*.gz
eeooff2

  peerImage=$(awk 'END{print}' ./temp/"${ORDERER_HOSTNAME}"DockerLoad.log | awk -F"Loaded image: " '{print $2}')
  peerImageName=$(echo "${peerImage}" | awk -F":" '{print $1}')
  sshpass -p "${ROOT_PASSWORD}" ssh root@"${ORDERER_name}" >./temp/"${ORDERER_HOSTNAME}"DockerTag.log <<eeooff3

  docker rm "${ORDERER_name}" -f
  IMAGE_TAG=$IMAGETAG docker-compose -f /var/hyperledger/config/docker/docker-compose-"${ORDERER_HOSTNAME}".yaml up -d
eeooff3


  println "启动${ORDERER_HOSTNAME}完成。"
}

function startupPeer() {

  if [ "X${PEER_HOSTNAME}" == "X" ]; then
    fatalln "启动peer失败：需要-SPpn参数带上peer name，默认是peer0、peer1 这种格式"
  fi

  if [ "X${ORG_HOSTNAME}" == "X" ]; then
    fatalln "启动peer失败：需要-SPon参数带上org name 在crypto-config.yaml中定义（注意需要小写）"
  fi

  if [ "X${PEER_name}" == "X" ]; then
    fatalln "启动peer失败：需要-SPd参数带上peer domain 为peer所规划的服务的域名"
  fi

  if [ "X${ROOT_PASSWORD}" == "X" ]; then
    fatalln "启动peer失败：需要-SPp参数服务器的root密码"
  fi

  peerOrgName="${PEER_HOSTNAME}"."${ORG_HOSTNAME}"

#  ssh root@"${PEER_name}" <<eeooff
#eeooff

  # 打包orderer配置文件和镜像
  rm -rf ./temp/"${PEER_HOSTNAME}".tar && tar -cf ./temp/"${peerOrgName}".tar  \
  ./config/crypto-config/peerOrganizations/"${ORG_HOSTNAME}".lianxiang.com/peers/"${peerOrgName}".lianxiang.com \
  ./images/files/peer/ ./config/docker/docker-compose-"${peerOrgName}".yaml
  cd "${PWD}"/temp && rm -rf "${peerOrgName}".md5 && md5sum "${peerOrgName}".tar >"${peerOrgName}".md5 && cd ..

  sshpass -p "${ROOT_PASSWORD}" ssh root@"${PEER_name}" <<eeooff0
  if [ ! -d /var/hyperledger ]; then
    mkdir /var/hyperledger
  fi
eeooff0

  sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${peerOrgName}".md5 root@"${PEER_name}":/var/hyperledger/"${peerOrgName}".md5
  sshpass -p "${ROOT_PASSWORD}" ssh root@"${PEER_name}" >./temp/"${peerOrgName}"Md5.log <<eeooff1
  cd /var/hyperledger
  if [ -f "${peerOrgName}".tar ]; then
    md5sum -c "${peerOrgName}".md5
  else
    echo "NOT_EXIST"
  fi
eeooff1

  ret=$(awk 'END{print}' ./temp/"${peerOrgName}"Md5.log | awk -F" " '{print $2}')
  if [ "X${ret}" != "XOK" ]; then
    sshpass -p "${ROOT_PASSWORD}" scp "${PWD}"/temp/"${peerOrgName}".tar root@"${PEER_name}":/var/hyperledger/"${peerOrgName}".tar
  fi

  sshpass -p "${ROOT_PASSWORD}" ssh root@"${PEER_name}" >./temp/"${peerOrgName}"DockerLoad.log <<eeooff2
  cd /var/hyperledger && rm -rf ./config/crypto-config/peerOrganizations/"${ORG_HOSTNAME}".lianxiang.com/peers/"${peerOrgName}".lianxiang.com/ ./images/files/peer/ && tar -xf "${peerOrgName}".tar
  docker load < ./images/files/peer/*.gz

eeooff2


  peerImage=$(awk 'END{print}' ./temp/"${peerOrgName}"DockerLoad.log | awk -F"Loaded image: " '{print $2}')
  peerImageName=$(echo "${peerImage}" | awk -F":" '{print $1}')
  sshpass -p "${ROOT_PASSWORD}" ssh root@"${PEER_name}" >./temp/"${peerOrgName}"DockerTag.log <<eeooff3

  docker rm "${PEER_name}" -f
  docker-compose -f /var/hyperledger/config/docker/docker-compose-"${peerOrgName}".yaml up -d
eeooff3

    println "启动${peerOrgName}成功。"
}




function clean() {
  if [ -d "${PWD}/config/channel-artifacts" ]; then
    rm -Rf "${PWD}/config/channel-artifacts"
  fi

  if [ -d "${PWD}/config/system-genesis-block" ]; then
    rm -Rf "${PWD}/config/system-genesis-block"
  fi

  if [ -d "${PWD}/config/crypto-config" ]; then
    rm -Rf "${PWD}/config/crypto-config"
  fi

  # 远程清理orderer



  println "清理完成。"
}



#function createChannel() {
#
#}