package buildinfo

import "strings"

var (
	Version   = "0.0.1"
	Commit    = "dev"
	BuildTime = ""
	Channel   = "stable"
)

func CleanVersion() string {
	version := strings.TrimSpace(Version)
	if version == "" {
		return "0.0.1"
	}
	return version
}

func CleanChannel() string {
	channel := strings.TrimSpace(Channel)
	if channel == "" {
		return "stable"
	}
	return channel
}
