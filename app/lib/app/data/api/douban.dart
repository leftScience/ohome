import '../../utils/http_client.dart';
import '../models/douban_models.dart';

class DoubanRepository {
  DoubanRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient.instance;

  final HttpClient _httpClient;

  Future<DoubanCategories> getCategories() {
    return _httpClient.get<DoubanCategories>(
      'public/douban/categories',
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return DoubanCategories.fromJson(data);
        }
        throw ApiException('豆瓣分类响应格式错误');
      },
    );
  }

  Future<DoubanRankingResponse> getMovieRanking({
    required String category,
    required String type,
    int page = 1,
    int limit = 100,
  }) {
    return _httpClient.get<DoubanRankingResponse>(
      'public/douban/movie/recent_hot',
      queryParameters: <String, dynamic>{
        'category': category,
        'type': type,
        'page': page,
        'limit': limit,
      },
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return DoubanRankingResponse.fromJson(data);
        }
        throw ApiException('豆瓣榜单响应格式错误');
      },
    );
  }

  Future<DoubanRankingResponse> getTvRanking({
    required String category,
    required String type,
    int page = 1,
    int limit = 100,
  }) {
    return _httpClient.get<DoubanRankingResponse>(
      'public/douban/tv/recent_hot',
      queryParameters: <String, dynamic>{
        'category': category,
        'type': type,
        'page': page,
        'limit': limit,
      },
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return DoubanRankingResponse.fromJson(data);
        }
        throw ApiException('豆瓣榜单响应格式错误');
      },
    );
  }

  Future<DoubanRankingResponse> getPlayletRanking({
    required String category,
    required String type,
    int page = 1,
    int limit = 100,
  }) {
    return _httpClient.get<DoubanRankingResponse>(
      'public/douban/playlet/recent_hot',
      queryParameters: <String, dynamic>{
        'category': category,
        'type': type,
        'page': page,
        'limit': limit,
      },
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return DoubanRankingResponse.fromJson(data);
        }
        throw ApiException('短剧榜单响应格式错误');
      },
    );
  }

  Future<DoubanRankingResponse> getAudiobookRanking({
    required String category,
    required String type,
    int page = 1,
    int limit = 100,
  }) {
    return _httpClient.get<DoubanRankingResponse>(
      'public/douban/audiobook/recent_hot',
      queryParameters: <String, dynamic>{
        'category': category,
        'type': type,
        'page': page,
        'limit': limit,
      },
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return DoubanRankingResponse.fromJson(data);
        }
        throw ApiException('有声书榜单响应格式错误');
      },
    );
  }
}
