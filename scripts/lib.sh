# 生成证书文件
function createCryptogen() {
  if [ -d "${PWD}/config/crypto-config" ]; then
    rm -Rf "${PWD}/config/crypto-config"
  fi

  # 生成证书配置
  cryptogen generate --config="${PWD}"/config/crypto-config.yaml --output "${PWD}"/config/crypto-config/
  if [[ $# -lt 0 ]]; then
    errorln "生成证书文件失败."
  fi

  printf "生成证书文件成功"
}

#生成创世区块文件
function createChannel() {

  if [ "X${PROFILE_GENESIS}" == "X" ]; then
    fatalln "创建通道失败：需要-CCg参数带上通道配置文件configtx.yaml中 Profiles 域中关于创世块的配置域的域名"
  fi

  if [ "X${PROFILE_CHANNEL}" == "X" ]; then
    fatalln "创建通道失败：需要-CCc参数带上通道配置文件configtx.yaml中 Profiles 域中关于通道配置域的域名"
  fi

  if [ "X${CHANNEL_NAME}" == "X" ]; then
    fatalln "创建通道失败：需要-CCcn参数带上通道名称"
  fi

  if [ -d "${PWD}/config/channel-artifacts/${CHANNEL_NAME}.tx" ]; then
    rm -Rf "${PWD}/config/channel-artifacts/${CHANNEL_NAME}.tx"
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
  println "清理完成。"
}
