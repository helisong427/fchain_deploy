#!/bin/bash


# 安装环境配置检查
function check_env() {

  rm -rf $deploy_home/tools/*
  set -x
  go build -o $deploy_home/tools/yamlTools $deploy_home/yamltools

  if [[ $# -lt 0 ]] ; then
    errorln "build yamlTools error."
  fi
  set +x
  println "check env success."
}

