import 'dart:io';

import 'api.dart';
import 'pub.dart';
import 'utils.dart';

class Report {
  final PackageInfo packageInfo;

  Report(this.packageInfo);

  File generateReport(List<ApiUsage> usages, {bool showSrcReferences = false}) {
    var usage = ApiUsage.combine(packageInfo, usages);

    var file = File('reports/${packageInfo.name}.md');
    file.parent.createSync();
    var buf = StringBuffer();

    buf.writeln('# Report for package:${packageInfo.name}');
    buf.writeln();
    buf.writeln('## General info');
    buf.writeln();
    buf.writeln(packageInfo.description);
    buf.writeln();
    buf.writeln('- pub page: https://pub.dev/packages/${packageInfo.name}');
    buf.writeln(
        '- docs: https://pub.dev/documentation/${packageInfo.name}/latest/');
    buf.writeln('- dependent packages: '
        'https://pub.dev/packages?q=dependency%3A${packageInfo.name}&sort=top');
    buf.writeln();
    buf.writeln('Stats for ${packageInfo.name} v${packageInfo.version} pulled '
        'from ${usage.corpusPackages.length} packages.');

    var packagesReferences = usage.referringPackages;
    var libraryReferences = usage.referringLibraries;

    // Library references
    buf.writeln();
    buf.writeln('## Library references');
    buf.writeln();
    buf.writeln('### Library references from packages');
    buf.writeln();
    for (var entry in packagesReferences.sortedLibraryReferences.entries) {
      var val = entry.value;
      var count = usage.corpusPackages.length;
      var references = pluralize(val, 'reference');
      buf.writeln(
          '- ${entry.key} - $val package $references (${percent(val, count)})');
      var library = entry.key;
      if (showSrcReferences && library.contains('/src/')) {
        for (var entity in packagesReferences.getLibraryReferences(entry.key)) {
          buf.writeln('  - ${entity.toString()}');
        }
      }
    }
    buf.writeln();
    buf.writeln('### Library references from libraries');
    buf.writeln();
    for (var entry in libraryReferences.sortedLibraryReferences.entries) {
      var val = entry.value;
      var count = libraryReferences.entityCount;
      var references = pluralize(val, 'reference');
      buf.writeln(
          '- ${entry.key} - $val library $references (${percent(val, count)})');
      var library = entry.key;
      if (showSrcReferences && library.contains('/src/')) {
        for (var entity in libraryReferences.getLibraryReferences(entry.key)) {
          buf.writeln('  - ${entity.toString()}');
        }
      }
    }

    // Class references
    buf.writeln();
    buf.writeln('## Class references');
    buf.writeln();
    buf.writeln('### Class references from packages');
    buf.writeln();
    for (var entry in packagesReferences.sortedClassReferences.entries) {
      var val = entry.value;
      var count = usage.corpusPackages.length;
      var references = pluralize(val, 'reference');
      buf.writeln(
          '- ${entry.key} - $val package $references (${percent(val, count)})');
    }
    buf.writeln();
    buf.writeln('### Class references from libraries');
    buf.writeln();
    for (var entry in libraryReferences.sortedClassReferences.entries) {
      var val = entry.value;
      var count = libraryReferences.entityCount;
      var references = pluralize(val, 'reference');
      buf.writeln(
          '- ${entry.key} - $val library $references (${percent(val, count)})');
    }

    // Top-level symbols
    if (packagesReferences.sortedTopLevelReferences.isNotEmpty ||
        libraryReferences.sortedTopLevelReferences.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Top-level symbols');
      buf.writeln();
      buf.writeln('### Top-level symbols references from packages');
      buf.writeln();
      for (var entry in packagesReferences.sortedTopLevelReferences.entries) {
        var val = entry.value;
        var count = usage.corpusPackages.length;
        var references = pluralize(val, 'reference');
        buf.writeln(
            '- ${entry.key} - $val package $references (${percent(val, count)})');
      }
      buf.writeln();
      buf.writeln('### Top-level symbol references from libraries');
      buf.writeln();
      for (var entry in libraryReferences.sortedTopLevelReferences.entries) {
        var val = entry.value;
        var count = libraryReferences.entityCount;
        var references = pluralize(val, 'reference');
        buf.writeln(
            '- ${entry.key} - $val library $references (${percent(val, count)})');
      }
    }

    // Corpus
    buf.writeln();
    buf.writeln('## Corpus packages');
    buf.writeln();
    for (var package in usage.corpusPackages) {
      buf.writeln('- ${package.name} v${package.version}');
    }

    file.writeAsStringSync(buf.toString());

    return file;
  }
}
