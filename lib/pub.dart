import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/retry.dart';

typedef PackageFilter = bool Function(PackageInfo packageInfo);

/// Utilities to query pub.dev.
class Pub {
  late final Client _client;

  Pub() {
    _client = RetryClient(
      Client(),
      when: (response) => const [502, 503].contains(response.statusCode),
    );
  }

  Future<List<PackageInfo>> popularDependenciesOf(
    String packageName, {
    int? limit,
    PackageFilter? filter,
  }) async {
    List<PackageInfo> result = await _packagesForSearch(
      'dependency:$packageName',
      limit: limit,
      sort: 'top',
      filter: filter,
    ).toList();
    return result;
  }

  Future<List<String>> dependenciesOf(
    String packageName, {
    int? limit,
  }) async {
    return await _packageNamesForSearch(
      'dependency:$packageName',
      limit: limit,
      sort: 'top',
    ).toList();
  }

  Future<PackageInfo> getPackageInfo(String pkgName) async {
    final json = await _getJson(Uri.https('pub.dev', 'api/packages/$pkgName'));

    return PackageInfo.from(json /*, options: options*/);
  }

  Future<PackageOptions> getPackageOptions(String packageName) async {
    final json = await _getJson(
        Uri.https('pub.dev', 'api/packages/$packageName/options'));
    return PackageOptions.from(json);
  }

  Future<PackageScore> getPackageScore(String packageName) async {
    final json =
        await _getJson(Uri.https('pub.dev', 'api/packages/$packageName/score'));
    return PackageScore.from(json);
  }

  Stream<PackageInfo> _packagesForSearch(
    String query, {
    int page = 1,
    int? limit,
    String? sort,
    PackageFilter? filter,
  }) async* {
    final uri = Uri.parse('https://pub.dev/api/search');

    int count = 0;

    for (;;) {
      final targetUri = uri.replace(queryParameters: {
        'q': query,
        'page': page.toString(),
        if (sort != null) 'sort': sort,
      });

      final map = await _getJson(targetUri);

      for (var packageName in (map['packages'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e['package'] as String?)) {
        var packageInfo = await getPackageInfo(packageName!);

        if (filter == null || filter(packageInfo)) {
          count++;
          yield packageInfo;
        }
      }

      if (map.containsKey('next')) {
        page = page + 1;
      } else {
        break;
      }

      if (limit != null && count >= limit) {
        break;
      }
    }
  }

  Stream<String> _packageNamesForSearch(
    String query, {
    int page = 1,
    int? limit,
    String? sort,
  }) async* {
    final uri = Uri.parse('https://pub.dev/api/search');

    int count = 0;

    for (;;) {
      final targetUri = uri.replace(queryParameters: {
        'q': query,
        'page': page.toString(),
        if (sort != null) 'sort': sort,
      });

      final map = await _getJson(targetUri);

      for (var packageName in (map['packages'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e['package'] as String?)) {
        count++;
        yield packageName!;
      }

      if (map.containsKey('next')) {
        page = page + 1;
      } else {
        break;
      }

      if (limit != null && count >= limit) {
        break;
      }
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final result = await _client.get(uri);
    if (result.statusCode == 200) {
      return jsonDecode(result.body) as Map<String, dynamic>;
    } else {
      throw StateError('Error getting `$uri` - ${result.statusCode}');
    }
  }

  void close() {
    _client.close();
  }
}

class PackageInfo {
  // {
  // "name":"usage",
  // "latest":{
  //   "version":"4.0.2",
  //   "pubspec":{
  //     "name":"usage",
  //     "version":"4.0.2",
  //     "description":"A Google Analytics wrapper for command-line, web, and Flutter apps.",
  //     "repository":"https://github.com/dart-lang/wasm",
  //     "environment":{
  //       "sdk":">=2.12.0-0 <3.0.0"
  //     },
  //     "dependencies":{
  //       "path":"^1.8.0"
  //     },
  //     "dev_dependencies":{
  //       "pedantic":"^1.9.0",
  //       "test":"^1.16.0"
  //     }
  //   },
  //   "archive_url":"https://pub.dartlang.org/packages/usage/versions/4.0.2.tar.gz",
  //   "published":"2021-03-30T17:44:54.093423Z"
  // },

  final Map<String, dynamic> json;

  PackageInfo.from(this.json);

  String get name => json['name'];
  String get description => _pubspec['description'];

  String? get repository => _pubspec['repository'];
  String? get homepage => _pubspec['homepage'];

  String? get repo => repository ?? homepage;
  String? get sdkConstraint => (_pubspec['environment'] ?? {})['sdk'];

  String get version => _latest['version'];
  String get archiveUrl => _latest['archive_url'];
  DateTime get publishedDate => DateTime.parse(_published);

  String get _published => _latest['published'];

  late final Map<String, dynamic> _latest = json['latest'];
  late final Map<String, dynamic> _pubspec = _latest['pubspec'];

  @override
  String toString() => '$name: $version';

  String? constraintFor(String name) {
    if (_pubspec['dependencies'] is Map) {
      var constraint = _pubspec['dependencies'][name];
      if (constraint != null) {
        if (constraint is String && constraint.isEmpty) return 'any';
        return constraint;
      }
    }

    if (_pubspec['dev_dependencies'] is Map) {
      var constraint = _pubspec['dev_dependencies'][name];
      if (constraint != null) {
        if (constraint is String && constraint.isEmpty) return 'any';
        return constraint;
      }
    }

    return null;
  }

  String? constraintType(String name) {
    if (_pubspec['dependencies'] is Map) {
      var deps = _pubspec['dependencies'] as Map;
      if (deps.containsKey(name)) {
        return 'regular';
      }
    }

    if (_pubspec['dev_dependencies'] is Map) {
      var deps = _pubspec['dev_dependencies'] as Map;
      if (deps.containsKey(name)) {
        return 'dev';
      }
    }

    return null;
  }
}

class PackageOptions {
  // {"isDiscontinued":false,"replacedBy":null,"isUnlisted":true}

  final Map<String, dynamic> json;

  PackageOptions.from(this.json);

  bool get isDiscontinued => json['isDiscontinued'];
  String? get replacedBy => json['replacedBy'];
  bool get isUnlisted => json['isUnlisted'];
}

class PackageScore {
  // {
  //   grantedPoints: 85, maxPoints: 140, likeCount: 0, popularityScore: 0.0,
  //   tags: [sdk:dart, sdk:flutter, platform:android, platform:ios, ...],
  //   lastUpdated: 2022-09-16T10:33:33.105325Z
  // }

  final Map<String, dynamic> json;

  PackageScore.from(this.json);

  int get grantedPoints => json['grantedPoints'];
  int get maxPoints => json['maxPoints'];
  int get likeCount => json['likeCount'];
  double get popularityScore => json['popularityScore'];
}
