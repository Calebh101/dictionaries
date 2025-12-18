import 'package:dictionaries/addons.dart';
import 'package:dictionaries/src/debugaddonloader.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:make_root_say_banana/make_root_say_banana.dart' as make_root_say_banana;

Future<void> loadAddons() async {
  Logger.print("Loading addons...");
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getStringList("enabledAddons") ?? [];

  List<DictionariesAddon> potentialAddons = getPotentialAddons();
  List<(DictionariesAddon, bool debug)> loadedAddons = [];

  if (kDebugMode) {
    for (var addon in loadDebugAddons()) {
      if (addon.doShow && !loadedAddons.any((x) => x.$1.id == addon.id)) {
        loadedAddons.add((addon, true));
      }
    }
  }

  for (var id in enabled) {
    int i = potentialAddons.indexWhere((x) => x.id == id);
    if (i >= 0) loadedAddons.add((potentialAddons[i], false));
  }

  Logger.print("Found ${loadedAddons.length} addons to load out of ${potentialAddons.length} available");

  for (var addon in loadedAddons) {
    Logger.print("Registering ${addon.$2 ? "debug" : "release"} addon ${addon.$1.id} version ${addon.$1.version} by ${addon.$1.authors.isEmpty ? "John Noauthor" : addon.$1.authors.join(", ")}...");
    addon.$1.register(addon.$2);
  }
}

List<DictionariesAddon> getPotentialAddons() => [
  make_root_say_banana.load(),
];