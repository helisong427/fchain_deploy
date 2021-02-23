#!/bin/bash

# Set environment variables for the peer org
function setGlobals() {
  org_index="$1"
  peer_index="$2"

  local org_name org_msp org_domain peer_name peer_port
  org_name=$(get_ORG_NAME "${org_index}")
  org_msp=$(get_ORG_MSP_NAME "${org_index}")
  org_domain="${org_name}.${BASE_DOMAIN}"

  peer_name=$(get_ORG_PEER_NAME "${org_index}" "${peer_index}")
  peer_port=$(get_ORG_PEER_PORT "${org_index}" "${peer_index}")

  export CORE_PEER_LOCALMSPID="${org_msp}"
  export CORE_PEER_TLS_ROOTCERT_FILE="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_domain}/peers/${peer_name}.${org_domain}/tls/ca.crt"
  export CORE_PEER_TLS_CERT_FILE="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_domain}/peers/${peer_name}.${org_domain}/tls/server.crt"
  export CORE_PEER_TLS_KEY_FILE="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_domain}/peers/${peer_name}.${org_domain}/tls/server.key"
  export CORE_PEER_MSPCONFIGPATH="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_domain}/users/Admin@${org_domain}/msp"
  export CORE_PEER_ADDRESS="${peer_name}.${org_domain}:${peer_port}"
  export CORE_PEER_TLS_ENABLED=true
}

function verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}

# parsePeerConnectionParameters $@
# Helper function that sets the peer connection parameters for a chaincode
# operation
function parsePeerConnectionParameters() {
  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    local org_index=$1
    local peer_index=$2
    setGlobals "${org_index}" "${peer_index}"
    PEER="peer${peer_index}.org${org_index}"
    local org_name peer_name
    org_name=$(get_ORG_NAME "${org_index}")
    peer_name=$(get_ORG_PEER_NAME "${org_index}" "${peer_index}")
    ## Set peer addresses
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"

    ## Set path to TLS certificate
    PEER_CONN_PARMS="$PEER_CONN_PARMS --tlsRootCertFiles ${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_name}.${BASE_DOMAIN}/peers/${peer_name}.${org_name}.${BASE_DOMAIN}/tls/ca.crt"
    # shift by one to get to the next organization
    shift 2
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}
