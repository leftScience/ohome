package middleware

import (
	"net/http"
	"ohome/dao"
	"ohome/global/constants"
	"ohome/utils"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	TOKEN_NAME   = "Authorization"
	TOKEN_PREFIX = "Bearer "
)

func Auth() func(c *gin.Context) {
	return authMiddleware(false)
}

func StreamAuth() func(c *gin.Context) {
	return authMiddleware(true)
}

func authMiddleware(statusOnly bool) func(c *gin.Context) {
	var userDao dao.UserDao

	return func(c *gin.Context) {
		token := resolveBearerToken(c)

		// Token不存在, 直接返回
		if token == "" || !strings.HasPrefix(token, TOKEN_PREFIX) {
			abortUnauthorized(c, statusOnly)
			return
		}

		// Token无法解析, 直接返回
		token = token[len(TOKEN_PREFIX):]
		iJwtCustClaims, err := utils.ParseAccessToken(token)
		nUserId := iJwtCustClaims.ID
		if err != nil || nUserId == 0 {
			abortUnauthorized(c, statusOnly)
			return
		}

		// 将用户信息存入上下文, 方便后续处理继续使用
		loginUser, err := userDao.GetLoginUserByID(nUserId)
		if err != nil || loginUser.RoleCode == "" {
			abortUnauthorized(c, statusOnly)
			return
		}
		c.Set(constants.LOGIN_USER, loginUser)
		c.Next()
	}
}

func resolveBearerToken(c *gin.Context) string {
	token := c.GetHeader(TOKEN_NAME)
	if token != "" {
		return token
	}

	// 允许通过查询参数 token/access_token 传递（用于流式播放等无法带头的场景）
	if q := strings.TrimSpace(c.Query("token")); q != "" {
		return TOKEN_PREFIX + q
	}
	if q := strings.TrimSpace(c.Query("access_token")); q != "" {
		return TOKEN_PREFIX + q
	}
	return ""
}

func abortUnauthorized(c *gin.Context, statusOnly bool) {
	if statusOnly {
		c.AbortWithStatus(http.StatusUnauthorized)
		return
	}
	utils.TokenFail(c)
}
