#!/bin/bash

function buildYamlTools() {
  rm -rf "$PWD/tools/*"
  set -x
  cd "$DEPLOY_PATH/yamltools" && go build -o "$DEPLOY_PATH/tools/yamlTools"
  ret=$#
  set +x
  if [[ ret -lt 0 ]]; then
    errorln "build yamlTools error."
  fi

  println "build yamlTools success"
}


# 安装环境配置检查
function check_env() {

  # 检查端口是否被占用

  #
  println "check env success."
}
