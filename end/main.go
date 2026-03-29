package main

import (
	"fmt"
	"ohome/buildinfo"
	"ohome/cmd"
)

/**
@title 
@Description 
@Version 0.0.1
*/

func main() {
	fmt.Printf("ohome server version=%s commit=%s buildTime=%s channel=%s\n", buildinfo.CleanVersion(), buildinfo.Commit, buildinfo.BuildTime, buildinfo.CleanChannel())
	cmd.Start()
}
