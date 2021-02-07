MAX_RETRY="5"
DELAY="3"

function channelCreate() {
  setGlobals 1

  # Poll in case the raft leader is not set yet
  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel create -o "${orderer_1_name}.${base_domain}:${orderer_1_port}" -c "${CHANNEL_NAME}" --ordererTLSHostnameOverride \
      "${orderer_1_name}.${base_domain}" -f ./config/channel-artifacts/"${CHANNEL_NAME}".tx --outputBlock ./config/channel-artifacts/"${CHANNEL_NAME}".block \
      --tls --cafile "./crypto-config/ordererOrganizations/${base_domain}/orderers/${orderer_1_name}.${base_domain}/msp/tlscacerts/tlsca.${base_domain}-cert.pem" >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "Channel 创建失败。"
}

function joinChannel() {
  org_index="$1"
  peer_index="$2"

  setGlobals "${org_index}" "${peer_index}"
  local rc=1
  local COUNTER=1
  ## Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel join -b ./config/channel-artifacts/"${CHANNEL_NAME}".block >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "After $MAX_RETRY attempts, peer${peer_index}.org${org_index} has failed to join channel '${CHANNEL_NAME}' "
}



setAnchorPeer() {
  org_index="$1"

  org_name=$(eval echo '$'"org_${org_index}_name")
  org_anchor_peer_index=$(eval echo '$'"org_${org_index}_anchor")
  org_anchor_peer_name=$(eval echo '$'"org_${org_index}_peer_${org_anchor_peer_index}_name")

  org_anchor_peer_port=$(eval echo '$'"org_${org_index}_peer_${org_anchor_peer_index}_port")
  org_anchor_peer_domain="${org_anchor_peer_name}.${org_name}.${base_domain}"

  setGlobals "${org_index}" "${org_anchor_peer_index}"

  fetchChannelConfig ./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_config.json
  infoln "Generating anchor peer update transaction for Org${org_index} on channel $CHANNEL_NAME"

  set -x
  # Modify the configuration to append the anchor peer
  jq '.channel_group.groups.Application.groups.'"${CORE_PEER_LOCALMSPID}"'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "' \
    "${org_anchor_peer_domain}"'","port": '"${org_anchor_peer_port}"'}]},"version": "0"}}' \
    ./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_config.json >./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_modified_config.json
  { set +x; } 2>/dev/null

  # Compute a config update, based on the differences between
  # {orgmsp}config.json and {orgmsp}modified_config.json, write
  # it as a transaction to {orgmsp}anchors.tx
  createConfigUpdate ./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_config.json \
    ./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_modified_config.json ./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_anchors.tx

  peer channel update -o "${orderer_1_name}.${base_domain}:${orderer_1_port}" --ordererTLSHostnameOverride \
    "${orderer_1_name}.${base_domain}" -c "${CHANNEL_NAME}" -f ./temp/createChannel/"${CORE_PEER_LOCALMSPID}"_anchors.tx \
    --tls --cafile "./crypto-config/ordererOrganizations/${base_domain}/orderers/${orderer_1_name}.${base_domain}/msp/tlscacerts/tlsca.${base_domain}-cert.pem" >&log.txt
  res=$?
  cat log.txt
  verifyResult $res "Anchor peer update failed"
  successln "Anchor peer set for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"

}
