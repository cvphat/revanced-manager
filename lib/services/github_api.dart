import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_cache_lts/dio_http_cache_lts.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:native_dio_client/native_dio_client.dart';
import 'package:revanced_manager/models/github_latest_release.dart';
import 'package:revanced_manager/models/patch.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timeago/timeago.dart';

@lazySingleton
class GithubAPI {
  late Dio _dio = Dio();
  final DioCacheManager _dioCacheManager = DioCacheManager(CacheConfig());

  final Options _cacheOptions = buildCacheOptions(
    const Duration(hours: 6),
    maxStale: const Duration(days: 1),
  );
  final Map<String, String> repoAppPath = {
    'com.google.android.youtube': 'youtube',
    'com.google.android.apps.youtube.music': 'music',
    'com.twitter.android': 'twitter',
    'com.reddit.frontpage': 'reddit',
    'com.zhiliaoapp.musically': 'tiktok',
    'de.dwd.warnapp': 'warnwetter',
    'com.garzotto.pflotsh.ecmwf_a': 'ecmwf',
    'com.spotify.music': 'spotify',
  };

  Future<void> initialize(String repoUrl) async {
    try {
      _dio = Dio(
        BaseOptions(
          baseUrl: repoUrl,
        ),
      )..httpClientAdapter = NativeAdapter();

      _dio.interceptors.add(_dioCacheManager.interceptor);
      _dio.addSentry(
        captureFailedRequests: true,
      );
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
    }
  }

  Future<void> clearAllCache() async {
    try {
      await _dioCacheManager.clearAll();
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
    }
  }

  Future<GithubLatestRelease?> getLatestRelease(String repoName) async {
    try {
      final response = await _dio.get(
        '/repos/$repoName/releases/latest',
        options: _cacheOptions,
      );
      return response.data != null
          ? GithubLatestRelease.fromJson(response.data)
          : null;
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
  }

  Future<List<String>> getCommits(
    String packageName,
    String repoName,
    DateTime since,
  ) async {
    final String path =
        'src/main/kotlin/app/revanced/patches/${repoAppPath[packageName]}';
    try {
      final response = await _dio.get(
        '/repos/$repoName/commits',
        queryParameters: {
          'path': path,
          'since': since.toIso8601String(),
        },
        options: _cacheOptions,
      );
      final List<dynamic> commits = response.data;
      return commits
          .map(
            (commit) => (commit['commit']['message']).split('\n')[0] +
                ' - ' +
                commit['commit']['author']['name'] +
                '\n' as String,
          )
          .toList();
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return List.empty();
    }
  }

  Future<File?> getLatestReleaseFile(String extension, String repoName) async {
    try {
      final release = await getLatestRelease(repoName);
      if (release != null) {
        final asset = release.assets.firstWhereOrNull(
          (asset) => asset.name.endsWith(extension),
        );
        if (asset != null) {
          return await DefaultCacheManager().getSingleFile(
            asset.browserDownloadUrl,
          );
        }
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
    return null;
  }

  Future<List<Patch>> getPatches(String repoName) async {
    List<Patch> patches = [];
    try {
      final File? f = await getLatestReleaseFile('.json', repoName);
      if (f != null) {
        final List<dynamic> list = jsonDecode(f.readAsStringSync());
        patches = list.map((patch) => Patch.fromJson(patch)).toList();
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return List.empty();
    }
    return patches;
  }

  Future<String?> getLatestReleaseVersion(
    String extension,
    String repoName,
  ) async {
    try {
      final release = await getLatestRelease(repoName);
      if (release != null) {
        return release.tagName;
      } else {
        return 'Unknown';
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
  }

  Future<String?> getLatestReleaseTime(
    String extension,
    String repoName,
  ) async {
    try {
      final release = await getLatestRelease(repoName);
      if (release != null) {
        final timestamp = release.publishedAt;
        return format(timestamp, locale: 'en_short');
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
    return null;
  }
}
