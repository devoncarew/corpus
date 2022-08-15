import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as path;
// ignore: implementation_imports
import 'package:surveyor/src/visitors.dart';

import 'pub.dart';
import 'utils.dart';

// todo: report extension method usage

class ApiUsage {
  final PackageInfo package;

  final References fromPackages;
  final References fromLibraries;

  ApiUsage(this.package, this.fromPackages, this.fromLibraries);

  static CollectedApiUsage combine(
    PackageInfo targetPackage,
    List<ApiUsage> usages,
  ) {
    var corpusPackages = <PackageInfo>[];

    var referringPackages = References();
    var referringLibraries = References();

    for (var usage in usages) {
      corpusPackages.add(usage.package);

      referringPackages.combineWith(usage.fromPackages);
      referringLibraries.combineWith(usage.fromLibraries);
    }

    return CollectedApiUsage(
      targetPackage,
      corpusPackages,
      referringPackages,
      referringLibraries,
    );
  }

  void toFile(File file) {
    Map json = {
      'packages': fromPackages.toJson(),
      'libraries': fromLibraries.toJson(),
    };
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(json));
  }

  String describeUsage() {
    int libraryCount = fromPackages.sortedLibraryReferences.length;
    int classCount = fromPackages.sortedClassReferences.length;
    int symbolCount = fromPackages.sortedTopLevelReferences.length;
    return 'referenced $libraryCount ${pluralize(libraryCount, 'library', plural: 'libraries')}, '
        '$classCount ${pluralize(classCount, 'class', plural: 'classes')}, '
        'and $symbolCount top-level ${pluralize(symbolCount, 'symbol')}';
  }

  static ApiUsage fromFile(PackageInfo packageInfo, File file) {
    var json =
        JsonDecoder().convert(file.readAsStringSync()) as Map<String, dynamic>;
    return ApiUsage(
      packageInfo,
      References.fromJson(json['packages']),
      References.fromJson(json['libraries']),
    );
  }
}

class CollectedApiUsage {
  final PackageInfo targetPackage;

  final List<PackageInfo> corpusPackages;

  final References referringPackages;
  final References referringLibraries;

  CollectedApiUsage(
    this.targetPackage,
    this.corpusPackages,
    this.referringPackages,
    this.referringLibraries,
  );
}

class ApiUseCollector extends RecursiveAstVisitor implements AstContext {
  final PackageInfo targetPackage;
  final PackageInfo usingPackage;
  final Directory usingPackageDir;
  late PackageEntity usingPackageEntity;

  References referringPackages = References();
  References referringLibraries = References();

  String? _currentFilePath;

  ApiUseCollector(this.targetPackage, this.usingPackage, this.usingPackageDir) {
    usingPackageEntity = PackageEntity(usingPackage.name);
  }

  String get targetName => targetPackage.name;

  ApiUsage get usage =>
      ApiUsage(usingPackage, referringPackages, referringLibraries);

  String get currentPackage => usage.package.name;

  @override
  void setFilePath(String filePath) {
    _currentFilePath = filePath;
  }

  @override
  void setLineInfo(LineInfo lineInfo) {}

  @override
  void visitImportDirective(ImportDirective node) {
    var uri = node.uriContent;

    if (uri != null && uri.startsWith('package:')) {
      if (uri.startsWith('package:$targetName/')) {
        referringPackages.addLibraryReference(uri, usingPackageEntity);
        var relativeLibraryPath =
            path.relative(_currentFilePath!, from: usingPackageDir.path);
        referringLibraries.addLibraryReference(
            uri, LibraryEntity(currentPackage, relativeLibraryPath));
      }
    }

    super.visitImportDirective(node);
  }

  @override
  void visitNamedType(NamedType node) {
    super.visitNamedType(node);

    _handleType(node.type);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);

    var element = node.staticElement;
    if (element != null && element.kind == ElementKind.GETTER) {
      // We only want library getters.
      if (element.enclosingElement!.kind != ElementKind.COMPILATION_UNIT) {
        return;
      }

      var library = element.library;
      if (library == null || library.isInSdk) {
        return;
      }

      var libraryUri = library.librarySource.uri;
      if (libraryUri.scheme == 'package' &&
          libraryUri.pathSegments.first == targetName) {
        referringPackages.addTopLevelReference(
            element.name!, usingPackageEntity);
        var relativeLibraryPath =
            path.relative(_currentFilePath!, from: usingPackageDir.path);
        referringLibraries.addTopLevelReference(
            element.name!, LibraryEntity(currentPackage, relativeLibraryPath));
      }
    }
  }

  // @override
  // visitMethodInvocation(MethodInvocation node) {
  //   return super.visitMethodInvocation(node);

  //   // todo:
  // }

  void _handleType(DartType? type) {
    var element = type?.element;
    if (element != null) {
      var library = element.library;
      if (library == null || library.isInSdk) {
        return;
      }

      var libraryUri = library.librarySource.uri;
      if (libraryUri.scheme == 'package' &&
          libraryUri.pathSegments.first == targetName) {
        referringPackages.addClassReference(element.name!, usingPackageEntity);
        var relativeLibraryPath =
            path.relative(_currentFilePath!, from: usingPackageDir.path);
        referringLibraries.addClassReference(
            element.name!, LibraryEntity(currentPackage, relativeLibraryPath));
      }
    }
  }
}

/// A referring entity - either a package or a library.
abstract class Entity {
  String toJson();

  static Entity fromJson(String json) {
    List l = json.split(':');
    if (l.first == 'package') {
      return PackageEntity(l[1]);
    } else {
      return LibraryEntity(l[1], l[2]);
    }
  }
}

class PackageEntity extends Entity {
  final String name;

  PackageEntity(this.name);

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    return other is PackageEntity && name == other.name;
  }

  @override
  String toJson() => 'package:$name';

  @override
  String toString() => 'package:$name';
}

class LibraryEntity extends Entity {
  final String package;
  final String libraryPath;

  LibraryEntity(this.package, this.libraryPath);

  @override
  int get hashCode => package.hashCode ^ libraryPath.hashCode;

  @override
  bool operator ==(Object other) {
    return other is LibraryEntity &&
        package == other.package &&
        libraryPath == other.libraryPath;
  }

  @override
  String toJson() => 'library:$package:$libraryPath';

  @override
  String toString() => 'package:$package/$libraryPath';
}

class References {
  final EntityReferences _libraryReferences = EntityReferences();
  final EntityReferences _classReferences = EntityReferences();
  final EntityReferences _topLevelReferences = EntityReferences();

  References();

  factory References.fromJson(Map<String, dynamic> json) {
    var refs = References();

    refs._libraryReferences.fromJson(json['library']);
    refs._classReferences.fromJson(json['class']);
    refs._topLevelReferences.fromJson(json['topLevel']);

    return refs;
  }

  Set<Entity> get allEntities {
    var result = <Entity>{};

    result.addAll(_libraryReferences.entities);
    result.addAll(_classReferences.entities);
    result.addAll(_topLevelReferences.entities);

    return result;
  }

  int get entityCount => allEntities.length;

  void addLibraryReference(String ref, Entity entity) {
    _libraryReferences.add(ref, entity);
  }

  void addClassReference(String ref, Entity entity) {
    _classReferences.add(ref, entity);
  }

  void addTopLevelReference(String ref, Entity entity) {
    _topLevelReferences.add(ref, entity);
  }

  Set<Entity> getLibraryReferences(String ref) {
    return _libraryReferences._references[ref]!;
  }

  Map<String, int> get sortedLibraryReferences =>
      _libraryReferences.sortedReferences;

  Map<String, int> get sortedClassReferences =>
      _classReferences.sortedReferences;

  Map<String, int> get sortedTopLevelReferences =>
      _topLevelReferences.sortedReferences;

  void combineWith(References references) {
    _libraryReferences.combineWith(references._libraryReferences);
    _classReferences.combineWith(references._classReferences);
    _topLevelReferences.combineWith(references._topLevelReferences);
  }

  Map toJson() {
    return {
      'library': _libraryReferences.toJson(),
      'class': _classReferences.toJson(),
      'topLevel': _topLevelReferences.toJson(),
    };
  }
}

class EntityReferences {
  final Map<String, Set<Entity>> _references = {};

  EntityReferences();

  Set<Entity> get entities {
    var result = <Entity>{};
    for (var key in _references.keys) {
      result.addAll(_references[key]!);
    }
    return result;
  }

  void add(String ref, Entity entity) {
    _references.putIfAbsent(ref, () => {});
    _references[ref]!.add(entity);
  }

  Map<String, int> get sortedReferences => _sortByCount(_references);

  Map<String, int> _sortByCount(Map<String, Set<Entity>> refs) {
    List<String> keys = refs.keys.toList();
    keys.sort((a, b) => refs[b]!.length - refs[a]!.length);
    return Map.fromIterable(keys, value: (key) => refs[key]!.length);
  }

  void combineWith(EntityReferences other) {
    for (var entry in other._references.entries) {
      for (var entity in entry.value) {
        add(entry.key, entity);
      }
    }
  }

  void fromJson(Map json) {
    for (var key in json.keys) {
      List entities = json[key];
      for (var entity in entities) {
        add(key, Entity.fromJson(entity));
      }
    }
  }

  Map toJson() {
    return {
      for (var entry in _references.entries)
        entry.key: entry.value.map((entity) => entity.toJson()).toList()
    };
  }
}
