#!/bin/bash

# Set environment variables for the peer org
function setGlobals() {
    org_index="$1"
    peer_index="$2"

    org_name=$(eval echo '$'"org_${org_index}_name")
    org_msp=$(eval echo '$'"org_${org_index}_msp_name")
    org_domain="${org_name}.${base_domain}"

    peer_name=$(eval echo '$'"org_${org_index}_peer_${peer_index}_name")
    peer_port=$(eval echo '$'"org_${org_index}_peer_${peer_index}_port")

    export CORE_PEER_LOCALMSPID="${org_msp}"
    export CORE_PEER_TLS_ROOTCERT_FILE="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_domain}/peers/${peer_name}.${org_domain}/tls"
    export CORE_PEER_MSPCONFIGPATH="${DEPLOY_PATH}/config/crypto-config/peerOrganizations/${org_domain}/users/Admin@${org_domain}/msp"
    export CORE_PEER_ADDRESS="${peer_name}.${org_domain}:${peer_port}"

}

verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}


# parsePeerConnectionParameters $@
# Helper function that sets the peer connection parameters for a chaincode
# operation
parsePeerConnectionParameters() {
  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.org$1"
    ## Set peer addresses
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    ## Set path to TLS certificate
    TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_ORG$1_CA")
    PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    # shift by one to get to the next organization
    shift
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}
