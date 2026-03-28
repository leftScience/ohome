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
	if len(os.Args) > 1 && os.Args[1] == "run-current-server" {
		if err := updater.RunCurrentServerForeground(); err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		return
	}
	server := updater.NewAPIServer()
	if err := server.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
