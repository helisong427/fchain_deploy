#!/bin/bash

MAX_RETRY="5"
DELAY="3"

# fetchChannelConfig <org> <channel_id> <output_json>
# Writes the current channel config for a given channel to a JSON file
# NOTE: this must be run in a CLI container since it requires configtxlator
function fetchChannelConfig() {
  local tempDir="$1" output="$2"

  infoln "Fetching the most recent configuration block for the channel"
  set -x
  peer channel fetch config "${tempDir}"/config_block.pb \
    -o "${ORDERER_1_NAME}.${BASE_DOMAIN}:${ORDERER_1_PORT}" \
    --ordererTLSHostnameOverride "${ORDERER_1_NAME}.${BASE_DOMAIN}" \
    -c "${CHANNEL_NAME}" \
    --tls \
    --cafile "crypto-config/ordererOrganizations/${BASE_DOMAIN}/orderers/${ORDERER_1_NAME}.${BASE_DOMAIN}/msp/tlscacerts/tlsca.${BASE_DOMAIN}-cert.pem" \
    >&log.txt
  { set +x; } 2>/dev/null

  infoln "Decoding config block to JSON and isolating config to ${output}"
  set -x
  configtxlator proto_decode --input "${tempDir}"/config_block.pb --type common.Block | jq .data.data[0].payload.data.config >"${output}"
  { set +x; } 2>/dev/null
}

# createConfigUpdate <channel_id> <original_config.json> <modified_config.json> <output.pb>
# Takes an original and modified config, and produces the config update tx
# which transitions between the two
# NOTE: this must be run in a CLI container since it requires configtxlator
function createConfigUpdate() {
  local temp_dir="$1" original="$2" modified="$3" output="$4"

  set -x
  configtxlator proto_encode --input "${original}" --type common.Config >"${temp_dir}"/original_config.pb
  configtxlator proto_encode --input "${modified}" --type common.Config >"${temp_dir}"/modified_config.pb
  configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original "${temp_dir}"/original_config.pb --updated "${temp_dir}"/modified_config.pb >"${temp_dir}"/config_update.pb
  configtxlator proto_decode --input "${temp_dir}"/config_update.pb --type common.ConfigUpdate >"${temp_dir}"/config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat "${temp_dir}"/config_update.json)'}}}' | jq . >"${temp_dir}"/config_update_in_envelope.json
  configtxlator proto_encode --input "${temp_dir}"/config_update_in_envelope.json --type common.Envelope >"${output}"
  { set +x; } 2>/dev/null
}

# signConfigtxAsPeerOrg <org> <configtx.pb>
# Set the peerOrg admin of an org and sign the config update
function signConfigtxAsPeerOrg() {
  local ORG="$1" CONFIGTXFILE="$2"
  setGlobals $ORG
  set -x
  peer channel signconfigtx -f "${CONFIGTXFILE}"
  { set +x; } 2>/dev/null
}

function createChannelTx() {
  set -x
  configtxgen -profile TwoOrgsChannel \
    -outputCreateChannelTx "${DEPLOY_PATH}"/config/channel-artifacts/"${CHANNEL_NAME}".tx \
    -channelID "${CHANNEL_NAME}"
  local res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "创建通道TX文件(${CHANNEL_NAME}.tx)失败。"
}

function channelCreate() {

  setGlobals 1 1

  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel create \
      -o "${ORDERER_1_NAME}.${BASE_DOMAIN}:${ORDERER_1_PORT}" \
      -c "${CHANNEL_NAME}" \
      --ordererTLSHostnameOverride "${ORDERER_1_NAME}.${BASE_DOMAIN}" \
      -f "${DEPLOY_PATH}"/config/channel-artifacts/"${CHANNEL_NAME}".tx \
      --outputBlock "${DEPLOY_PATH}"/config/channel-artifacts/"${CHANNEL_NAME}".block \
      --tls \
      --cafile "crypto-config/ordererOrganizations/${BASE_DOMAIN}/orderers/${ORDERER_1_NAME}.${BASE_DOMAIN}/msp/tlscacerts/tlsca.${BASE_DOMAIN}-cert.pem" \
      >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "通道创建失败。"
}

function joinChannel() {

  local org_index="$1" peer_index="$2"

  setGlobals "${org_index}" "${peer_index}"

  local rc=1 COUNTER=1
  ## Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel join -b "${DEPLOY_PATH}"/config/channel-artifacts/"${CHANNEL_NAME}".block >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "After $MAX_RETRY attempts, peer${peer_index}.org${org_index} has failed to join channel '${CHANNEL_NAME}' "
}

function setAnchorPeer() {
  local org_index="$1"
  local org_name org_anchor_peer_index org_anchor_peer_name org_anchor_peer_port org_anchor_peer_domain
  local tempDir="${DEPLOY_PATH}/temp/createChannel/${CORE_PEER_LOCALMSPID}"

  org_name=$(get_ORG_NAME "${org_index}")
  org_anchor_peer_index=$(get_ORG_ANCHOR "${org_index}")
  org_anchor_peer_name=$(get_ORG_PEER_NAME "${org_index}" "${org_anchor_peer_index}")
  org_anchor_peer_port=$(get_ORG_PEER_PORT "${org_index}" "${org_anchor_peer_index}")
  org_anchor_peer_domain="${org_anchor_peer_name}.${org_name}.${BASE_DOMAIN}"

  setGlobals "${org_index}" "${org_anchor_peer_index}"

  rm -rf "${tempDir}" && mkdir -p "${tempDir}"

  fetchChannelConfig "${tempDir}" "${tempDir}"/"${CORE_PEER_LOCALMSPID}"_config.json
  infoln "Generating anchor peer update transaction for Org${org_index} on channel $CHANNEL_NAME"

  set -x
  # Modify the configuration to append the anchor peer
  jq '.channel_group.groups.Application.groups.'"${CORE_PEER_LOCALMSPID}"'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${org_anchor_peer_domain}'","port": "'${org_anchor_peer_port}'"}]},"version": "0"}}' "${tempDir}"/"${CORE_PEER_LOCALMSPID}"_config.json >"${tempDir}"/"${CORE_PEER_LOCALMSPID}"_modified_config.json
  { set +x; } 2>/dev/null

  # Compute a config update, based on the differences between
  # {orgmsp}config.json and {orgmsp}modified_config.json, write
  # it as a transaction to {orgmsp}anchors.tx
  createConfigUpdate \
    "${tempDir}" \
    "${tempDir}"/"${CORE_PEER_LOCALMSPID}"_config.json \
    "${tempDir}"/"${CORE_PEER_LOCALMSPID}"_modified_config.json \
    "${tempDir}"/"${CORE_PEER_LOCALMSPID}"_anchors.tx

  set -x
  peer channel update \
    -o "${ORDERER_1_NAME}.${BASE_DOMAIN}:${ORDERER_1_PORT}" \
    --ordererTLSHostnameOverride "${ORDERER_1_NAME}.${BASE_DOMAIN}" \
    -c "${CHANNEL_NAME}" -f "${tempDir}"/"${CORE_PEER_LOCALMSPID}"_anchors.tx \
    --tls \
    --cafile "crypto-config/ordererOrganizations/${BASE_DOMAIN}/orderers/${ORDERER_1_NAME}.${BASE_DOMAIN}/msp/tlscacerts/tlsca.${BASE_DOMAIN}-cert.pem" \
    >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Anchor peer update failed"
  successln "Anchor peer set for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"

}

function CHANNEL() {
  local mode="$1"

  if [ "X${mode}" == "Xstart" ]; then
    createChannelTx
    successln "创建通道TX文件(${CHANNEL_NAME}.tx)成功。"

    channelCreate
    successln "通道 '${CHANNEL_NAME}' 创建成功。"

    for ((i = 1; i <= ORG_NUMBER; i++)); do
      local org_peer_number
      org_peer_number=$(get_ORG_PEER_NUMBER "${i}")

      for ((ii = 1; ii <= org_peer_number; ii++)); do
        joinChannel "${i}" "${ii}"
        successln "org${i}-peer${ii} 加入通道成功。"
      done
    done

    for ((i = 1; i <= ORG_NUMBER; i++)); do
      setAnchorPeer "${i}"
      successln "org${i} 设置锚节点成功。"
    done

    infoln "======>   createChannel完成。"

  elif [ "X${mode}" == "Xclean" ]; then
    rm -rf "${DEPLOY_PATH}"/temp/createChannel "${DEPLOY_PATH}"/config/channel-artifacts/
  else
    fatalln "CHANNEL 函数的参数错误。"
  fi

}
