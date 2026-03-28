package utils

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"github.com/spf13/viper"
)

func TestGenerateAndParseAccessTokenUsesCurrentSignKey(t *testing.T) {
	restore := snapshotJWTConfig()
	defer restore()

	viper.Set("jwt.signKey", "test-sign-key-A")
	viper.Set("jwt.accessTokenExpires", 30)

	token, err := GenerateAccessToken(1, "tester")
	if err != nil {
		t.Fatalf("GenerateAccessToken() error = %v", err)
	}

	if _, err := ParseAccessToken(token); err != nil {
		t.Fatalf("ParseAccessToken() error = %v", err)
	}

	viper.Set("jwt.signKey", "test-sign-key-B")
	if _, err := ParseAccessToken(token); err == nil {
		t.Fatal("ParseAccessToken() should fail after sign key changes")
	}
}

func TestParseTokenEnforcesTokenType(t *testing.T) {
	restore := snapshotJWTConfig()
	defer restore()

	viper.Set("jwt.signKey", "test-sign-key-types")
	viper.Set("jwt.accessTokenExpires", 30)
	viper.Set("jwt.refreshTokenExpires", 30)

	accessToken, err := GenerateAccessToken(1, "tester")
	if err != nil {
		t.Fatalf("GenerateAccessToken() error = %v", err)
	}
	refreshToken, err := GenerateRefreshToken(1, "tester")
	if err != nil {
		t.Fatalf("GenerateRefreshToken() error = %v", err)
	}

	if _, err := ParseAccessToken(accessToken); err != nil {
		t.Fatalf("ParseAccessToken(access) error = %v", err)
	}
	if _, err := ParseRefreshToken(refreshToken); err != nil {
		t.Fatalf("ParseRefreshToken(refresh) error = %v", err)
	}
	if _, err := ParseAccessToken(refreshToken); err == nil {
		t.Fatal("ParseAccessToken(refreshToken) should fail")
	}
	if _, err := ParseRefreshToken(accessToken); err == nil {
		t.Fatal("ParseRefreshToken(accessToken) should fail")
	}
}

func TestParseTokenAllowsLegacyTokenWithoutType(t *testing.T) {
	restore := snapshotJWTConfig()
	defer restore()

	viper.Set("jwt.signKey", "test-sign-key-legacy")

	legacyToken, err := jwt.NewWithClaims(jwt.SigningMethodHS256, JwtClaims{
		ID:   7,
		Name: "legacy",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   "Token",
		},
	}).SignedString([]byte("test-sign-key-legacy"))
	if err != nil {
		t.Fatalf("SignedString() error = %v", err)
	}

	if _, err := ParseAccessToken(legacyToken); err != nil {
		t.Fatalf("ParseAccessToken(legacy) error = %v", err)
	}
	if _, err := ParseRefreshToken(legacyToken); err != nil {
		t.Fatalf("ParseRefreshToken(legacy) error = %v", err)
	}
}

func snapshotJWTConfig() func() {
	signKey := viper.Get("jwt.signKey")
	accessExpires := viper.Get("jwt.accessTokenExpires")
	refreshExpires := viper.Get("jwt.refreshTokenExpires")

	return func() {
		viper.Set("jwt.signKey", signKey)
		viper.Set("jwt.accessTokenExpires", accessExpires)
		viper.Set("jwt.refreshTokenExpires", refreshExpires)
	}
}
