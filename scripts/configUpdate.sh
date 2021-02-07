#!/bin/bash

# fetchChannelConfig <org> <channel_id> <output_json>
# Writes the current channel config for a given channel to a JSON file
# NOTE: this must be run in a CLI container since it requires configtxlator
fetchChannelConfig() {
  output=$1

  #setGlobals "${org_index}" "${peer_index}"

  infoln "Fetching the most recent configuration block for the channel"
  set -x

  peer channel fetch config ./temp/config_block.pb -o "${orderer_1_name}.${base_domain}:${orderer_1_port}" --ordererTLSHostnameOverride "${orderer_1_name}.${base_domain}" \
    -c "${CHANNEL_NAME}" --tls --cafile "./crypto-config/ordererOrganizations/${base_domain}/orderers/${orderer_1_name}.${base_domain}/msp/tlscacerts/tlsca.${base_domain}-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Decoding config block to JSON and isolating config to ${output}"
  set -x
  configtxlator proto_decode --input ./temp/config_block.pb --type common.Block | jq .data.data[0].payload.data.config >"${output}"
  { set +x; } 2>/dev/null
}

# createConfigUpdate <channel_id> <original_config.json> <modified_config.json> <output.pb>
# Takes an original and modified config, and produces the config update tx
# which transitions between the two
# NOTE: this must be run in a CLI container since it requires configtxlator
createConfigUpdate() {
  ORIGINAL=$1
  MODIFIED=$2
  OUTPUT=$3

  set -x
  configtxlator proto_encode --input "${ORIGINAL}" --type common.Config >./temp/createChannel/original_config.pb
  configtxlator proto_encode --input "${MODIFIED}" --type common.Config >./temp/createChannel/modified_config.pb
  configtxlator compute_update --channel_id "${CHANNEL}" --original ./temp/createChannel/original_config.pb --updated ./temp/createChannel/modified_config.pb >./temp/createChannel/config_update.pb
  configtxlator proto_decode --input ./temp/createChannel/config_update.pb --type common.ConfigUpdate >./temp/createChannel/config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat ./temp/createChannel/config_update.json)'}}}' | jq . >./temp/createChannel/config_update_in_envelope.json
  configtxlator proto_encode --input ./temp/createChannel/config_update_in_envelope.json --type common.Envelope >"${OUTPUT}"
  { set +x; } 2>/dev/null
}

# signConfigtxAsPeerOrg <org> <configtx.pb>
# Set the peerOrg admin of an org and sign the config update
signConfigtxAsPeerOrg() {
  ORG=$1
  CONFIGTXFILE=$2
  setGlobals $ORG
  set -x
  peer channel signconfigtx -f "${CONFIGTXFILE}"
  { set +x; } 2>/dev/null
}
