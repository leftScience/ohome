package main

import (
	"fmt"
	"os"

	"ohome/conf"
	"ohome/global"
	"ohome/updater"
)

func main() {
	conf.InitConfig()
	global.Logger = conf.InitLogger()
	server := updater.NewAPIServer()
	if err := server.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
