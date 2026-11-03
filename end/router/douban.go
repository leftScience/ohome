package router

import (
	"ohome/api"

	"github.com/gin-gonic/gin"
)

func InitDoubanRoutes() {
	RegisterRouter(func(rgPublic *gin.RouterGroup, rgAuth *gin.RouterGroup) {
		doubanApi := api.NewDoubanApi()

		rgPublic.GET("douban", doubanApi.Doc)
		rgPublic.GET("douban/health", doubanApi.Health)

		// categories
		rgPublic.GET("douban/categories", doubanApi.GetAllCategories)
		rgPublic.GET("douban/movie/categories", doubanApi.GetMovieCategories)
		rgPublic.GET("douban/tv/categories", doubanApi.GetTvCategories)
		rgPublic.GET("douban/playlet/categories", doubanApi.GetPlayletCategories)
		rgPublic.GET("douban/audiobook/categories", doubanApi.GetAudiobookCategories)

		// image proxy
		rgPublic.GET("douban/image", doubanApi.GetImage)

		// movie ranking
		rgPublic.GET("douban/movie/recent_hot", doubanApi.GetMovieRecentHot)
		rgPublic.GET("douban/movie/hot", doubanApi.GetMovieHot)
		rgPublic.GET("douban/movie/hot/:type", doubanApi.GetMovieHot)
		rgPublic.GET("douban/movie/latest", doubanApi.GetMovieLatest)
		rgPublic.GET("douban/movie/latest/:type", doubanApi.GetMovieLatest)
		rgPublic.GET("douban/movie/top", doubanApi.GetMovieTop)
		rgPublic.GET("douban/movie/top/:type", doubanApi.GetMovieTop)
		rgPublic.GET("douban/movie/underrated", doubanApi.GetMovieUnderrated)
		rgPublic.GET("douban/movie/underrated/:type", doubanApi.GetMovieUnderrated)

		// tv ranking
		rgPublic.GET("douban/tv/recent_hot", doubanApi.GetTvRecentHot)
		rgPublic.GET("douban/tv/drama", doubanApi.GetTvDrama)
		rgPublic.GET("douban/tv/drama/:type", doubanApi.GetTvDrama)
		rgPublic.GET("douban/tv/variety", doubanApi.GetTvVariety)
		rgPublic.GET("douban/tv/variety/:type", doubanApi.GetTvVariety)

		// playlet ranking
		rgPublic.GET("douban/playlet/recent_hot", doubanApi.GetPlayletRecentHot)
		rgPublic.GET("douban/playlet/hot", doubanApi.GetPlayletHot)
		rgPublic.GET("douban/playlet/hot/:type", doubanApi.GetPlayletHot)

		// audiobook ranking
		rgPublic.GET("douban/audiobook/recent_hot", doubanApi.GetAudiobookRecentHot)
		rgPublic.GET("douban/audiobook/hot", doubanApi.GetAudiobookHot)
		rgPublic.GET("douban/audiobook/hot/:type", doubanApi.GetAudiobookHot)

		// legacy
		rgPublic.GET("douban/recent_hot", doubanApi.GetRecentHotLegacy)
	})
}
