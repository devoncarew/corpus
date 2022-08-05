import 'dart:io';

import 'package:path/path.dart' as path;

class Cache {
  final Directory cacheDir = Directory('cache');

  Directory getCreateCacheDirectory(String name) {
    var dir = Directory(path.join(cacheDir.path, name));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Directory get archivesDir => getCreateCacheDirectory('archives');

  Directory get packagesDir => getCreateCacheDirectory('packages');

  Directory get usageDir => getCreateCacheDirectory('usage');
}
