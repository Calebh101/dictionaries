import 'package:dictionaries/addons.dart';
import 'package:dictionaries/src/debugaddonloader.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';

import 'package:banana/banana.dart' as banana;
import 'package:dictionaries_oc_snapshot/dictionaries_oc_snapshot.dart' as oc_snapshot;

Future<void> loadAddons([String? idToLoad]) async {
  Logger.print("Loading addons...");
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getStringList("enabledAddons") ?? [];

  List<DictionariesAddon> potentialAddons = getPotentialAddons().entries.where((x) => idToLoad == null ? true : (x.key == idToLoad)).map((x) => x.value).toList();
  List<(DictionariesAddon, bool debug)> loadedAddons = [];

  if (kDebugMode) {
    for (var addon in loadDebugAddons().entries.where((x) => idToLoad == null ? true : (x.key == idToLoad)).map((x) => x.value)) {
      if (addon.doShow && !loadedAddons.any((x) => x.$1.id == addon.id)) {
        loadedAddons.add((addon, true));
      }
    }
  }

  for (var id in enabled) {
    int i = potentialAddons.indexWhere((x) => x.id == id);
    if (i >= 0) loadedAddons.add((potentialAddons[i], false));
  }

  Logger.print("Found ${loadedAddons.length} addons to load out of ${potentialAddons.length} available after targeting ${idToLoad ?? "all"}");

  for (var addon in loadedAddons) {
    Logger.print("Registering ${addon.$2 ? "debug" : "release"} addon ${addon.$1.id} version ${addon.$1.version} by ${addon.$1.authors.isEmpty ? "John Noauthor" : addon.$1.authors.join(", ")}...");
    addon.$1.register(addon.$2);
  }
}

/// After an addon is developed, its load function is ran here so it can be loaded with all of the other addons.
///
/// Each `load` function should return a [DictionariesAddon] object that defines the required details about the addon.
Map<String, DictionariesAddon> getPotentialAddons() => {
  "com.calebh101.banana": banana.load(),
  "com.calebh101.oc_snapshot": oc_snapshot.load(),
};

Map<String, DictionariesAddon> getAllAddons() {
  return {
    ...getPotentialAddons(),
    ...loadDebugAddons(),
  };
}