import 'dart:io';

import 'package:super_sync_codegen/super_sync_codegen.dart';

/// Usage: `dart run super_sync_codegen:super_sync_gen INPUT [OUTPUT]`
/// where INPUT is an OpenAPI yaml/json file and OUTPUT is the .dart target.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: super_sync_gen <openapi.yaml|json> [output.dart]');
    exitCode = 64;
    return;
  }
  final input = File(args[0]);
  if (!input.existsSync()) {
    stderr.writeln('Input not found: ${args[0]}');
    exitCode = 66;
    return;
  }
  final code = generateFromOpenApi(input.readAsStringSync());
  if (args.length >= 2) {
    File(args[1]).writeAsStringSync(code);
    stdout.writeln('Wrote ${args[1]}');
  } else {
    stdout.write(code);
  }
}
