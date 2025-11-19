import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dictionaries/main.dart';
import 'package:dictionaries/recursive_caster.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:path/path.dart' as p;
import 'package:styled_logger/styled_logger.dart';

(int major, int minor, int patch)? getPythonVersion(String python) {
  try {
    final result = Process.runSync(python, ['--version']);

    if (result.exitCode != 0) {
      Logger.error("Error versioning $python: ${result.stderr}");
      return null;
    }

    final output = (result.stdout as String).isNotEmpty ? result.stdout : result.stderr;
    String version = output.toString().trim();
    RegExp regex = RegExp(r'Python (\d+)\.(\d+)\.(\d+)');
    final match = regex.firstMatch(version);

    if (match != null) {
      return (int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
    } else {
      return null;
    }
  } catch (e) {
    Logger.error('Failed to version $python: $e');
    return null;
  }
}

List<File> findPythons([List<String>? extras]) {
  if (kIsWeb) return [];
  extras ??= [];
  Set<File> found = {};

  final pathEnv = Platform.environment['PATH'] ?? '';
  final paths = pathEnv.split(Environment.isWindows ? ';' : ':');
  final possible = Environment.isWindows ? ['python.exe', 'python3.exe'] : ['python', 'python3'];

  for (var dir in paths) {
    for (var py in possible) {
      final file = File([dir, Platform.pathSeparator, py].join(""));

      if (file.existsSync()) {
        Logger.verbose("Found potential python: ${file.path}");
        var version = getPythonVersion(py);
        if (version == null) continue;
        Logger.verbose("> Version: $version");

        if (version.$1 >= 3) {
          if (version.$2 >= 10) {
            Logger.verbose("> Succeeded");
            found.add(file);
          } else {
            Logger.verbose("> Failed: Minor version isn't high enough");
          }
        } else {
          Logger.verbose("> Failed: Major version isn't high enough");
        }
      }
    }
  }

  Logger.print("Found ${found.length} valid pythons");
  return found.toList();
}

class Addon {
  static const bool enabled = true;

  final String id;
  final String name;
  final String version;
  final String description;
  final String? website;
  final List<String> authors;
  final Directory path;

  List<AddonFunction> functions = [];
  List<String> logs = [];

  Addon({required this.id, required this.authors, required this.description, required this.name, required this.version, required this.website, required this.path});

  File get main => File(p.joinAll([path.path, "main.py"]));

  static List<Addon> addons = [];

  static Addon? fromJson(Object? input) {
    if (input is! Map) return null;

    try {
      return Addon(id: input["id"], authors: RecursiveCaster.cast<List<String>>(input["authors"]), description: input["description"], name: input["name"], version: input["version"], website: input["website"], path: Directory(input["path"]));
    } catch (e) {
      Logger.warn("Invalid addon: $e (from ${jsonEncode(input)})");
      return null;
    }
  }

  void handleStdout(Addon addon, String? stdout, [String? stderr]) {
    bool isStderr = stderr != null;

    for (String line in (stdout ?? stderr).toString().split("\n")) {
      if (line.startsWith("_DICTIONARIES_INTERNAL_API_CALL")) {
        String text = line.split(":").sublist(1).join(":").trim();
        Map message = jsonDecode(text);

        String type = message["type"];
        Map data = message["data"];

        switch (type) {
          case "function.register":
            var f = AddonFunction.fromJson(data["function"]);
            if (f != null) addon.functions.add(f);
            break;
          default: Logger.warn("Message from $id: Unrecognized type: $type"); break;
        }
      } else {
        Logger.verbose("Addon $id: $line");
        logs.add(line);
      }
    }
  }

  static void init() async {
    Logger.print("Initializing addons...");
    File addonsFile = File(p.joinAll([(await maindir).path, "addons.json"]));
    if (!addonsFile.existsSync()) addonsFile.writeAsStringSync("{}");
    List addonData = jsonDecode(addonsFile.readAsStringSync())["addons"] ?? [];
    addons = addonData.map((x) => Addon.fromJson(x)).whereType<Addon>().toList();
    Logger.print("Found ${addons.length} addons");
    File python = findPythons().first;

    for (var a in addons) {
      Logger.print("Running ${a.main.path} with python ${python.path}");
      var process = await Process.start(python.path, [a.main.path], workingDirectory: a.path.path);

      process.stdout.listen((bytes) => a.handleStdout(a, utf8.decode(bytes)));
      process.stderr.listen((bytes) => a.handleStdout(a, null, utf8.decode(bytes)));
    }
  }

  static void runFunction(String addonId, String functionId) async {
    Addon? addon = addons.firstWhereOrNull((x) => x.id == addonId);
    if (addon == null) throw Exception("Addon $addonId doesn't exist.");
    AddonFunction? function = addon.functions.firstWhereOrNull((x) => x.id == functionId);
    if (function == null) throw Exception("Function $functionId in addon $addonId doesn't exist.");
  }
}

class AddonFunction {
  final String id;
  final String name;
  final String description;
  final List<DictionariesAddonFunctionInputType> inputs;
  final List<DictionariesAddonFunctionOutputType> outputs;

  const AddonFunction({required this.id, required this.name, required this.description, required this.inputs, required this.outputs});

  static AddonFunction? fromJson(Object? input) {
    if (input is! Map) return null;

    try {
      var a = AddonFunction(id: input["id"], name: input["name"], description: input["description"], inputs: (input["inputs"] as List).map((x) => DictionariesAddonFunctionInputType.from(x)).toList(), outputs: (input["inputs"] as List).map((x) => DictionariesAddonFunctionOutputType.from(x)).toList());
      Logger.print("Registered function ${a.id}");
      return a;
    } catch (e) {
      Logger.warn("Invalid addon function: $e (from ${jsonEncode(input)})");
      return null;
    }
  }
}

enum DictionariesAddonFunctionInputType {
  plistUtf8(1),
  jsonUtf8(2),
  yamlUtf8(3),
  dictionaryRaw(4);

  final int value;
  const DictionariesAddonFunctionInputType(this.value);

  static DictionariesAddonFunctionInputType from(int value) {
    return DictionariesAddonFunctionInputType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid value: $value'),
    );
  }
}

enum DictionariesAddonFunctionOutputType {
  plistUtf8(1),
  jsonUtf8(2),
  yamlUtf8(3),
  dictionaryRaw(4);

  final int value;
  const DictionariesAddonFunctionOutputType(this.value);

  static DictionariesAddonFunctionOutputType from(int value) {
    return DictionariesAddonFunctionOutputType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid value: $value'),
    );
  }
}

enum DictionariesDialogueModuleType {
  text(1),
  button(2),
  stringInput(3);

  final int value;
  const DictionariesDialogueModuleType(this.value);
}
