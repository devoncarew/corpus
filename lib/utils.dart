import 'dart:io';

import 'package:cli_util/cli_logging.dart';

String percent(int val, int count) {
  return '${(val * 100 / count).round()}%';
}

String pluralize(int count, String word, {String? plural}) {
  return count == 1 ? word : (plural ?? '${word}s');
}

Future<ProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool verbose = false,
  Logger? logger,
}) async {
  if (verbose) {
    print('$executable ${arguments.join(' ')}');
  }

  var result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    String out = result.stdout;
    if (out.isNotEmpty) {
      logger == null ? print(out.trimRight()) : logger.stdout(out.trimRight());
    }
    out = result.stderr;
    if (out.isNotEmpty) {
      logger == null ? print(out.trimRight()) : logger.stderr(out.trimRight());
    }
  }
  return result;
}
