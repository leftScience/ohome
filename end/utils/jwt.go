package utils

import (
	"errors"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"github.com/spf13/viper"
)

type JwtClaims struct {
	ID        uint   `json:"id"`
	Name      string `json:"name"`
	TokenType string `json:"tokenType,omitempty"`
	jwt.RegisteredClaims
}

const (
	JwtTokenTypeAccess  = "access"
	JwtTokenTypeRefresh = "refresh"
)

// GenerateAccessToken 获取accessToken
func GenerateAccessToken(id uint, name string) (string, error) {
	token, err := generateToken(id, name, JwtTokenTypeAccess, viper.GetDuration("jwt.accessTokenExpires")*time.Minute)
	return token, err
}

// GenerateRefreshToken 获取refreshToken
func GenerateRefreshToken(id uint, name string) (string, error) {
	token, err := generateToken(id, name, JwtTokenTypeRefresh, viper.GetDuration("jwt.refreshTokenExpires")*time.Minute)
	return token, err
}

func generateToken(id uint, name string, tokenType string, expiresTime time.Duration) (string, error) {
	signKey, err := currentJWTSignKey()
	if err != nil {
		return "", err
	}

	iJwtCustClaims := JwtClaims{
		ID:        id,
		Name:      name,
		TokenType: strings.TrimSpace(tokenType),
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiresTime)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   "Token",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, iJwtCustClaims)
	return token.SignedString(signKey)
}

func ParseAccessToken(tokenStr string) (JwtClaims, error) {
	return ParseToken(tokenStr, JwtTokenTypeAccess)
}

func ParseRefreshToken(tokenStr string) (JwtClaims, error) {
	return ParseToken(tokenStr, JwtTokenTypeRefresh)
}

func ParseToken(tokenStr string, acceptedTypes ...string) (JwtClaims, error) {
	iJwtCustClaims := JwtClaims{}
	signKey, err := currentJWTSignKey()
	if err != nil {
		return iJwtCustClaims, err
	}

	token, err := jwt.ParseWithClaims(tokenStr, &iJwtCustClaims, func(token *jwt.Token) (interface{}, error) {
		return signKey, nil
	})

	if err == nil && !token.Valid {
		err = errors.New("无效的令牌")
	}
	if err == nil && !iJwtCustClaims.matchesTokenTypes(acceptedTypes...) {
		err = errors.New("无效的令牌类型")
	}

	return iJwtCustClaims, err
}

func currentJWTSignKey() ([]byte, error) {
	signKey := strings.TrimSpace(viper.GetString("jwt.signKey"))
	if signKey == "" {
		return nil, errors.New("jwt.signKey 未配置")
	}
	return []byte(signKey), nil
}

func (c JwtClaims) matchesTokenTypes(acceptedTypes ...string) bool {
	if len(acceptedTypes) == 0 {
		return true
	}

	actualType := strings.TrimSpace(strings.ToLower(c.TokenType))
	if actualType == "" {
		return true
	}

	for _, acceptedType := range acceptedTypes {
		if actualType == strings.TrimSpace(strings.ToLower(acceptedType)) {
			return true
		}
	}
	return false
}
