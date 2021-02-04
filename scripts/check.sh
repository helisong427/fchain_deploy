#!/bin/bash

function buildYamlTools() {
  rm -rf "$PWD/tools/*"
  set -x
  cd "$PWD/yamltools" && go build -o "$PWD/tools/yamlTools"
  ret=$#
  set +x
  if [[ ret -lt 0 ]]; then
    errorln "build yamlTools error."
  fi

  println "build yamlTools success"
}


# 安装环境配置检查
function check_env() {

  println "check env success."
}
