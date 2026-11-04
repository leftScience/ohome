package service

import "testing"

func TestQuarkTVAccessTokenCacheIsolatedByRefreshToken(t *testing.T) {
	clearCachedQuarkTVAccessToken("")
	t.Cleanup(func() { clearCachedQuarkTVAccessToken("") })

	cacheQuarkTVAccessToken("refresh-a", "access-a", 3600)
	cacheQuarkTVAccessToken("refresh-b", "access-b", 3600)

	if got, ok := getCachedQuarkTVAccessToken("refresh-a"); !ok || got != "access-a" {
		t.Fatalf("token a = %q ok=%v", got, ok)
	}
	if got, ok := getCachedQuarkTVAccessToken("refresh-b"); !ok || got != "access-b" {
		t.Fatalf("token b = %q ok=%v", got, ok)
	}

	clearCachedQuarkTVAccessToken("refresh-a")
	if _, ok := getCachedQuarkTVAccessToken("refresh-a"); ok {
		t.Fatal("token a should be cleared")
	}
	if got, ok := getCachedQuarkTVAccessToken("refresh-b"); !ok || got != "access-b" {
		t.Fatalf("token b should remain, got %q ok=%v", got, ok)
	}
}
