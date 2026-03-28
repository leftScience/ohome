package main

import (
	"fmt"
	"ohome/buildinfo"
	"ohome/cmd"
)

/**
@title go项目实战
@Description 练手项目
@Version 0.0.1
*/

func main() {
	defer cmd.Clear()

	fmt.Printf("ohome server version=%s commit=%s buildTime=%s channel=%s\n", buildinfo.CleanVersion(), buildinfo.Commit, buildinfo.BuildTime, buildinfo.CleanChannel())
	cmd.Start()
}
