[![Dart](https://github.com/devoncarew/corpus/actions/workflows/dart.yml/badge.svg)](https://github.com/devoncarew/corpus/actions/workflows/dart.yml)

## What's this?

This is a tool to calculate the API usage for a package - what parts of a
package's API are typically used by other Dart packages and applications.

It is run from the command line:

```
dart bin/api_usage.dart <package-name>
```

It queries pub.dev for the packages that use `<package-name>`, downloads the
referencing packages, analyzes them, and determines which portions of the target
package's API are used. For an example usage report, see
[collection.md](doc/collection.md).

## Usage

To use this tool, clone the repo, and run:

```
dart bin/api_usage.dart <package-name>
```

Some available options are:

- `--package-limit`: limit the number of packages that are used for analysis
  (this defaults to all referencing packages on pub.dev), 
- `--show-src-references`: when there are references into a package's `lib/src/`
  directory (something that's generally not intended to be part of a package's
  public API), this option will include which package is using the `src/`
  library in the output
- `--include-old`: Include packages that haven't been published in the last
  year (these are normally excluded).

```
usage: dart bin/api_usage.dart [options] <package-name>

options:
-h, --help                     Print this usage information.
    --package-limit=<count>    Limit the number of packages usage data is collected from.
    --show-src-references      Report specific references to src/ libraries.
```
