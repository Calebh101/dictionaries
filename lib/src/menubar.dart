import 'package:collection/equality.dart';
import 'package:dictionaries/addons.dart';
import 'package:dictionaries/main.dart';
import 'package:flutter/material.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:menu_bar/src/entry.dart';

List<BarButton> generateBarButtonsFromEntries(BuildContext context, List<DictionariesMenuBarEntry> entries) {
  return entries.map((x) {
    return BarButton(text: Text(x.text), submenu: SubMenu(menuItems: generateMenuBarFromEntries(context, [x.text], x.children)));
  }).whereType<BarButton>().toList();
}

List<MenuEntry> generateMenuBarFromEntries(BuildContext context, List<String> keys, List<DictionariesMenuBarEntry> entries) {
  return entries.map((x) {
    if (injectedMenuDeletions.any((y) => ListEquality().equals(y.$1.keys, [...keys, x.text]))) return null;

    if (x.divider) {
      return MenuDivider();
    } else if (x.onActivate != null) {
      return MenuButton(text: Text(x.text), onTap: () => x.onActivate!(context), shortcut: x.shortcut);
    } else if (x.children.isNotEmpty) {
      return MenuButton(text: Text(x.text), submenu: SubMenu(menuItems: generateMenuBarFromEntries(context, [...keys, x.text], x.children)));
    } else {
      return MenuButton(text: Text(x.text));
    }
  }).whereType<MenuEntry>().toList();
}

extension InjectAllMenuBarEntries on List<DictionariesMenuBarEntry> {
  List<DictionariesMenuBarEntry> inject(List<DictionariesMenuBarInjection> injections) {
    injectAllMenuBarEntries(this, injections);
    return this;
  }
}

void injectAllMenuBarEntries(List<DictionariesMenuBarEntry> current, List<DictionariesMenuBarInjection> injections) {
  for (final injection in injections) {
    bool invalid = false;
    DictionariesMenuBarEntry? currentEntry;

    for (int i = 0; i < injection.keys.length; i++) {
      final key = injection.keys[i];
      final l = currentEntry?.children ?? current;
      int index = l.indexWhere((x) => x.text == key);

      if (index < 0) {
        // Not found
        final e = DictionariesMenuBarEntry(key, children: []);
        l.add(e);
        currentEntry = e;
      } else {
        final e = l[index];

        if (e.onActivate != null) {
          // The thing we're trying to traverse into has an onActivate,
          // so we'll warn and ignore.
          Logger.warn("Menu bar injection tries to traverse into $key, but $key can't be traversed into! Full path: ${injection.keys.join("/")}");
          invalid = true;
          break;
        } else {
          currentEntry = e;
        }
      }
    }

    if (invalid) continue;
    final l = currentEntry?.children ?? current;
    int after = injection.rightAfter != null ? (injection.rightAfter!.leading ? -2 : l.indexWhere((x) => x.text == injection.rightAfter!.text)) : -1;
    l.insertAll(after >= 0 ? after + 1 : (after == -2 ? 0 : l.length), injection.entries);
  }
}

class DictionariesMenuBarEntry {
  final String text;
  final void Function(BuildContext context)? onActivate;
  final List<DictionariesMenuBarEntry> children;
  final MenuSerializableShortcut? shortcut;
  final bool divider;

  const DictionariesMenuBarEntry(this.text, {this.onActivate, this.shortcut, this.children = const []}) : divider = false;
  const DictionariesMenuBarEntry.divider(this.text) : onActivate = null, shortcut = null, children = const [], divider = true;

  static const String dividerAfterExport = "DividerAfterExport";
  static const String beforeDownloadOriginalFile = "BeforeDownloadOriginalFile";

  static const String debugAddonOptionsTopDivider = "DebugAddonOptionsTopDivider";
  static const String debugAddonOptionsSecondDivider = "DebugAddonOptionsSecondDivider";
  static const String debugAddonOptionsThirdDivider = "DebugAddonOptionsThirdDivider";
}