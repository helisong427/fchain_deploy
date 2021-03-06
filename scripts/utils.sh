#!/bin/bash


C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# Print the usage message
function printHelp() {
  USAGE="$1"

  if [ "$USAGE" == "up" ]; then
    println "Usage: "
    println "  deploy.sh \033[0;32mup\033[0m [Flags]"
    println
    println "    Flags:"
    println
    println "    -h - Print this message"
    println
    println " Possible Mode and flag combinations"
    println "   \033[0;32mup\033[0m "
    println
    println " Examples:"
    println "   deploy.sh up"
  elif [ "$USAGE" == "createChannel" ]; then
    println "Usage: "
    println "  deploy.sh \033[0;32mcreateChannel\033[0m [Flags]"
    println
    println "    Flags:"
    println "    -CCg <genesis profile> - （必须）通道配置文件configtx.yaml中 Profiles 域中关于创世块的配置域的域名"
    println "    -CCc <channel profile> - （必须）通道配置文件configtx.yaml中 Profiles 域中关于通道配置域的域名"
    println "    -CCcn <channel name> - （非必须）通道名称，默认为mychannel"
    println
    println "    -h - Print this message"
    println
    println " Possible Mode and flag combinations"
    println "   \033[0;32mcreateChannel\033[0m -CCg TwoOrgsOrdererGenesis -CCc TwoOrgsChannel -CCcn mychannel"
    println
    println " Examples:"
    println "   deploy.sh createChannel -CCg TwoOrgsOrdererGenesis -CCc TwoOrgsChannel -CCcn mychannel"
  elif [ "$USAGE" == "clean" ]; then
    println "Usage: "
    println "  deploy.sh \033[0;32clean\033[0m [Flags]"
    println
    println "    Flags:"
    println
    println "    -h - Print this message"
    println
    println " Possible Mode and flag combinations"
    println "   \033[0;32createOrgAnchor\033[0m clean"
    println
    println " Examples:"
    println "   deploy.sh clean"
  else
    println "Usage: "
    println "  deploy.sh <Mode> [Flags]"
    println "    Modes:"
    println "      \033[0;32mcreateConfig\033[0m - 根据configtx.yaml和crypto-config.yaml配置文件，生成msp、创世区块、通道block文件"
    println "      \033[0;32mcreateOrgAnchor\033[0m - 生成组织的锚节点block文件"
    println "      \033[0;32mstartupOrder\033[0m - 安装orderer节点"
    println "      \033[0;32mstartupPeer\033[0m - 安装peer节点"
    println "      \033[0;32mclean\033[0m - 清理安装环境"
    println
    println " Examples:"
    println "   deploy.sh createConfig -CCg TwoOrgsOrdererGenesis -CCc TwoOrgsChannel -CCcn mychannel"
    println "   deploy.sh createOrgAnchor -COAc TwoOrgsChannel -COAomn Org1MSP -COAcn mychannel"
    println "   deploy.sh startupOrder -SOh orderer0 -SOd orderer0.lianxiang.com -SOp rootpasswd"
    println "   deploy.sh startupPeer -SPpn peer0 -SPon org1 -SPd peer0.org1.lianxiang.com -SPp rootpasswd"
    println "   deploy.sh clean"
  fi
}



# println echos string
function println() {
  echo -e "$1"
}

# errorln echos i red color
function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}


export -f errorln
export -f successln
export -f infoln
export -f warnln
