import 'package:dictionaries/addons.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:make_root_say_banana/make_root_say_banana.dart' as make_root_say_banana;

Future<void> loadAddons() async {
  Logger.print("Loading addons...");
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getStringList("enabledAddons") ?? [];

  List<DictionariesAddon> potentialAddons = getPotentialAddons();
  List<DictionariesAddon> loadedAddons = [];

  for (var id in enabled) {
    int i = potentialAddons.indexWhere((x) => x.id == id);
    if (i >= 0) loadedAddons.add(potentialAddons[i]);
  }

  for (var addon in potentialAddons) {
    if (kDebugMode && addon.alwaysEnableThisAddon && !loadedAddons.any((x) => x.id == addon.id)) loadedAddons.add(addon);
  }

  Logger.print("Found ${loadedAddons.length} addons to load out of ${potentialAddons.length} available");

  for (var addon in loadedAddons) {
    Logger.print("Registering addon ${addon.id} version ${addon.version} by ${addon.authors.isEmpty ? "John Noauthor" : addon.authors.join(", ")}...");
    addon.register();
  }
}

List<DictionariesAddon> getPotentialAddons() => [
  make_root_say_banana.load(),
];