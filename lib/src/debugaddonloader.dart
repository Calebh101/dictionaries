import 'package:dictionaries/addons.dart';

import 'package:banana/banana.dart' as banana;
import 'package:dictionaries_oc_snapshot/dictionaries_oc_snapshot.dart' as oc_snapshot;

/// When making a new addon, you can add your addon's load function here so it will be added as a debug addon in the loader. These addons are always enabled.
///
/// Addons from this function are always loaded before `getPotentialAddons` in `addonloader`. If you put an addon both in `getPotentialAddons` and `loadDebugAddons`, `loadDebugAddons` takes priority.
///
/// Each `load` function should return a [DictionariesAddon] object that defines the required details about the addon.
Map<String, DictionariesAddon> loadDebugAddons() => {
  "com.calebh101.banana": banana.load(),
  "com.calebh101.oc_snapshot": oc_snapshot.load(),
};