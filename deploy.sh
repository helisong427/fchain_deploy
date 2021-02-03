#!/bin/bash

deploy_home=$PWD

. config.sh
. scripts/utils.sh
. scripts/check.sh

#set -euo pipefail



if [[ $# -lt 0 ]] ; then
  printHelp
  exit 0
else
  shift
fi


if check_env; then
    fatalln "Unable to start network"
fi

