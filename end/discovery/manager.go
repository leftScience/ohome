package discovery

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/spf13/viper"
)

const (
	DefaultVersion      = "0.0.1"
	DefaultPort         = 18090
	ServiceType         = "_ohome._tcp"
	ServiceDomain       = "local."
	DefaultAPIBasePath  = "/api/v1"
	DefaultProbePath    = "/api/v1/public/discovery"
	DefaultInstanceFile = "ohome.instance-id"
)

var Default *Manager

type Options struct {
	Port           int
	ServiceName    string
	Version        string
	APIBasePath    string
	Capabilities   []string
	InstanceIDPath string
}

type Info struct {
	InstanceID   string   `json:"instanceId"`
	ServiceName  string   `json:"serviceName"`
	Version      string   `json:"version"`
	APIBaseURL   string   `json:"apiBaseUrl"`
	Port         int      `json:"port"`
	Capabilities []string `json:"capabilities"`
}

type Manager struct {
	instanceID   string
	serviceName  string
	version      string
	apiBasePath  string
	port         int
	capabilities []string
}

func Initialize() (*Manager, error) {
	options := Options{
		Port:           configuredPort(),
		ServiceName:    configuredServiceName(),
		Version:        DefaultVersion,
		APIBasePath:    DefaultAPIBasePath,
		Capabilities:   defaultCapabilities(),
		InstanceIDPath: defaultInstanceIDPath(),
	}
	return NewManager(options)
}

func NewManager(options Options) (*Manager, error) {
	port := options.Port
	if port <= 0 {
		port = DefaultPort
	}

	serviceName := strings.TrimSpace(options.ServiceName)
	if serviceName == "" {
		serviceName = "Smart Zone"
	}

	version := strings.TrimSpace(options.Version)
	if version == "" {
		version = DefaultVersion
	}

	apiBasePath := normalizeAPIBasePath(options.APIBasePath)
	instanceIDPath := strings.TrimSpace(options.InstanceIDPath)
	if instanceIDPath == "" {
		instanceIDPath = filepath.Join("data", DefaultInstanceFile)
	}

	instanceID, err := ensureInstanceID(instanceIDPath)
	if err != nil {
		return nil, err
	}

	return &Manager{
		instanceID:   instanceID,
		serviceName:  serviceName,
		version:      version,
		apiBasePath:  apiBasePath,
		port:         port,
		capabilities: normalizeCapabilities(options.Capabilities),
	}, nil
}

func (m *Manager) InstanceID() string {
	if m == nil {
		return ""
	}
	return m.instanceID
}

func (m *Manager) ServiceName() string {
	if m == nil {
		return ""
	}
	return m.serviceName
}

func (m *Manager) Version() string {
	if m == nil {
		return ""
	}
	return m.version
}

func (m *Manager) Port() int {
	if m == nil {
		return DefaultPort
	}
	return m.port
}

func (m *Manager) APIBasePath() string {
	if m == nil {
		return DefaultAPIBasePath
	}
	return m.apiBasePath
}

func (m *Manager) DiscoveryInfo(origin string) Info {
	baseURL := strings.TrimRight(strings.TrimSpace(origin), "/") + m.apiBasePath + "/"
	return Info{
		InstanceID:   m.instanceID,
		ServiceName:  m.serviceName,
		Version:      m.version,
		APIBaseURL:   baseURL,
		Port:         m.port,
		Capabilities: append([]string(nil), m.capabilities...),
	}
}

func (m *Manager) MDNSTextRecords() []string {
	return []string{
		"id=" + m.instanceID,
		"name=" + m.serviceName,
		"path=" + m.apiBasePath,
		"ver=" + m.version,
	}
}

func (m *Manager) MDNSInstanceName() string {
	shortID := m.instanceID
	if len(shortID) > 8 {
		shortID = shortID[:8]
	}
	return fmt.Sprintf("%s-%s", m.serviceName, shortID)
}

func configuredPort() int {
	port, err := strconv.Atoi(strings.TrimSpace(viper.GetString("server.port")))
	if err != nil || port <= 0 {
		return DefaultPort
	}
	return port
}

func configuredServiceName() string {
	configured := strings.TrimSpace(viper.GetString("discovery.serviceName"))
	if configured != "" {
		return configured
	}

	hostName, err := os.Hostname()
	if err != nil {
		return "Smart Zone"
	}
	hostName = strings.TrimSpace(hostName)
	if hostName == "" {
		return "Smart Zone"
	}
	return hostName
}

func defaultCapabilities() []string {
	return []string{
		"auth.login",
		"discovery.http",
		"discovery.mdns",
	}
}

func normalizeCapabilities(values []string) []string {
	if len(values) == 0 {
		return defaultCapabilities()
	}

	result := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}
	if len(result) == 0 {
		return defaultCapabilities()
	}
	return result
}

func normalizeAPIBasePath(value string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return DefaultAPIBasePath
	}
	if !strings.HasPrefix(trimmed, "/") {
		trimmed = "/" + trimmed
	}
	return strings.TrimRight(trimmed, "/")
}

func ensureInstanceID(path string) (string, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", err
	}

	if existing, err := os.ReadFile(path); err == nil {
		value := strings.TrimSpace(string(existing))
		if value != "" {
			return value, nil
		}
	} else if !os.IsNotExist(err) {
		return "", err
	}

	value, err := newInstanceID()
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(path, []byte(value+"\n"), 0o644); err != nil {
		return "", err
	}
	return value, nil
}

func newInstanceID() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func defaultInstanceIDPath() string {
	driver := strings.ToLower(strings.TrimSpace(viper.GetString("DB.driver")))
	dsn := strings.TrimSpace(viper.GetString("DB.dsn"))

	if driver == "" {
		driver = detectDriverFromDSN(dsn)
	}

	if driver == "sqlite" {
		if dbPath, ok := resolveSQLitePath(dsn); ok {
			return filepath.Join(filepath.Dir(dbPath), DefaultInstanceFile)
		}
	}

	return filepath.Join("data", DefaultInstanceFile)
}

func detectDriverFromDSN(dsn string) string {
	lowerDSN := strings.ToLower(strings.TrimSpace(dsn))
	if strings.Contains(lowerDSN, "@tcp(") || strings.Contains(lowerDSN, "charset=") {
		return "mysql"
	}
	return "sqlite"
}

func resolveSQLitePath(dsn string) (string, bool) {
	trimmed := strings.TrimSpace(dsn)
	if trimmed == "" {
		return filepath.Join("data", "ohome.db"), true
	}

	lower := strings.ToLower(trimmed)
	if trimmed == ":memory:" || strings.Contains(lower, "mode=memory") {
		return "", false
	}

	if strings.HasPrefix(lower, "file:") {
		filePath := strings.TrimPrefix(trimmed, "file:")
		filePath = strings.SplitN(filePath, "?", 2)[0]
		if strings.TrimSpace(filePath) == "" {
			return "", false
		}
		return filePath, true
	}

	return strings.SplitN(trimmed, "?", 2)[0], true
}
