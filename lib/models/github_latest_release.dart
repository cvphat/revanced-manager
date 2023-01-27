import 'package:json_annotation/json_annotation.dart';

part 'github_latest_release.g.dart';

@JsonSerializable()
class GithubLatestRelease {
  final int id;
  final String name;
  final String body;
  @JsonKey(name: 'tag_name')
  final String tagName;
  @JsonKey(name: 'published_at')
  final DateTime publishedAt;
  final List<GithubReleaseAsset> assets;

  const GithubLatestRelease({
    required this.id,
    required this.name,
    required this.body,
    required this.tagName,
    required this.publishedAt,
    this.assets = const [],
  });

  factory GithubLatestRelease.fromJson(Map<String, dynamic> json) =>
      _$GithubLatestReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$GithubLatestReleaseToJson(this);
}

@JsonSerializable()
class GithubReleaseAsset {
  final int id;
  final String name;
  final int size;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'browser_download_url')
  final String browserDownloadUrl;
  @JsonKey(name: 'content_type')
  final String contentType;

  const GithubReleaseAsset({
    required this.id,
    required this.name,
    required this.size,
    required this.createdAt,
    required this.browserDownloadUrl,
    required this.contentType,
  });

  factory GithubReleaseAsset.fromJson(Map<String, dynamic> json) =>
      _$GithubReleaseAssetFromJson(json);

  Map<String, dynamic> toJson() => _$GithubReleaseAssetToJson(this);
}
