package main

import (
	"errors"
	"fmt"
	"github.com/spf13/viper"
	"gopkg.in/alecthomas/kingpin.v2"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

var (
	//valueType = []string{"bool", "string", "int", "int64", "float64"}

	tools = kingpin.New("yamlTool", "tools of yaml file.")

	modify      = tools.Command("modify", "modify yaml file")
	template    = modify.Flag("config", "The configuration template to use of yaml file").String()
	outputDir   = modify.Flag("output", "The output yaml file").String()
	changeValue = modify.Arg("modifyitem", "修改的内容，格式为：int item value").String()

	get    = tools.Command("get", "read yaml configuration item")
	config = get.Flag("config", "The yaml file of config").String()
)

func main() {
	kingpin.Version("0.0.1")
	switch kingpin.MustParse(tools.Parse(os.Args[1:])) {

	case modify.FullCommand():
		printResult(modifyConfig())

	case get.FullCommand():
		printResult(getConfig())
	}
}

func modifyConfig() (err error, str string) {

	s, err := os.Stat(*template)
	if err != nil || s.IsDir() {
		return errors.New("config模板文件不存在:" + *template), ""
	}

	_, fileName := filepath.Split(*template)

	s, err = os.Stat(*outputDir)
	if err != nil {
		return errors.New("output目录不存在:" + *outputDir), ""
	}

	v := viper.New()
	v.SetConfigFile(*template)
	v.SetConfigType("yaml")

	items := strings.Split(*changeValue, " ")
	if len(items) != 3 {
		return errors.New("modify 参数个数错误！"), ""
	}

	if err := v.ReadInConfig();err != nil {
		fmt.Printf("err:%s\n",err)
		return errors.New("viper 读取模板配置失败：" + err.Error()), ""
	}


	switch items[0] {
	case "bool":
		value, err := strconv.ParseBool(items[2])
		if err != nil {
			return errors.New("modify 参数值类型不匹配！"), ""
		}
		v.Set(items[1], value)
	case "string":
		v.Set(items[1], items[2])
	case "int":
		value, err := strconv.Atoi(items[2])
		if err != nil {
			return errors.New("modify 参数值类型不匹配！"), ""
		}
		v.Set(items[1], value)
	case "int64":
		value, err := strconv.ParseInt(items[2], 10, 64)
		if err != nil {
			return errors.New("modify 参数值类型不匹配！"), ""
		}
		v.Set(items[1], value)
	case "float64":
		value, err := strconv.ParseFloat(items[2], 32)
		if err != nil {
			return errors.New("modify 参数值类型不匹配！"), ""
		}
		v.Set(items[1], value)
	default:
		return errors.New("不支持的itemtype"), ""
	}

	fileAbs := filepath.Join(*outputDir, fileName)

	err = v.WriteConfigAs(fileAbs)
	if err != nil {
		return err, ""
	}

	return nil, ""
}

func getConfig() (err error, str string) {
	v := viper.New()
	v.SetConfigFile(*template)
	v.SetConfigType("yaml")



	return nil , ""
}

func printResult(err error, msg string) {
	if err != nil {
		fmt.Println("ERROR||", err.Error())
	} else {
		fmt.Println("SUCCESS||", msg)
	}
}
