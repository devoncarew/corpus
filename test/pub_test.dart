import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:corpus/pub.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('PackageInfo', () {
    test('parse pub.dev results', () {
      var packageInfo = PackageInfo.from(jsonDecode(_pubSampleData));

      checkThat(packageInfo.name).equals('usage');
      checkThat(packageInfo.version).equals('4.0.2');
      checkThat(packageInfo.archiveUrl).isNotNull();
      checkThat(packageInfo.publishedDate).isNotNull();
    });
  });
}

final String _pubSampleData = '''
{
  "name": "usage",
  "latest": {
    "version": "4.0.2",
    "pubspec": {
      "name": "usage",
      "version": "4.0.2",
      "description": "A Google Analytics wrapper for command-line, web, and Flutter apps.",
      "repository": "https://github.com/dart-lang/wasm",
      "environment": {
        "sdk":">=2.12.0-0 <3.0.0"
      },
      "dependencies": {
        "path":"^1.8.0"
      },
      "dev_dependencies": {
        "pedantic":"^1.9.0",
        "test":"^1.16.0"
      }
    },
    "archive_url": "https://pub.dartlang.org/packages/usage/versions/4.0.2.tar.gz",
    "published": "2021-03-30T17:44:54.093423Z"
  }
}
''';
