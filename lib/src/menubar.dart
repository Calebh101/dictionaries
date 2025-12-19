import 'package:dictionaries/main.dart';
import 'package:flutter/material.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:menu_bar/src/entry.dart';

List<BarButton> generateMenuBarFromEntries(BuildContext context, List<DictionariesMenuBarEntry> entries) {
  return entries.map((x) {
    return BarButton(text: Text(x.text), submenu: SubMenu(menuItems: _generateMenuBarFromEntries(context, x.children)));
  }).whereType<BarButton>().toList();
}

List<MenuEntry> _generateMenuBarFromEntries(BuildContext context, List<DictionariesMenuBarEntry> entries) {
  return entries.map((x) {
    if (x.onActivate != null) {
      return MenuButton(text: Text(x.text), onTap: () => x.onActivate!(context), shortcut: x.shortcut);
    } else {
      return MenuButton(text: Text(x.text), submenu: SubMenu(menuItems: _generateMenuBarFromEntries(context, x.children)));
    }
  }).whereType<MenuEntry>().toList();
}

void injectAllMenuBarEntries(List<DictionariesMenuBarEntry> current, List<DictionariesMenuBarInjection> injections) {
  for (final injection in injections) {
    if (injection.keys.isEmpty) continue;
    bool invalid = false;
    DictionariesMenuBarEntry? currentEntry;

    for (int i = 0; i < injection.keys.length - 1; i++) {
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
          // The thing we're trying to travers into has an onActivate,
          // so we'll warn and ignore
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
    int after = injection.rightAfter != null ? l.indexWhere((x) => x.text == injection.rightAfter) : -1;
    l.insertAll(after >= 0 ? after + 1 : l.length, injection.entries);
  }
}

class DictionariesMenuBarEntry {
  final String text;
  final void Function(BuildContext context)? onActivate;
  final List<DictionariesMenuBarEntry> children;
  final MenuSerializableShortcut? shortcut;

  const DictionariesMenuBarEntry(this.text, {this.onActivate, this.shortcut, this.children = const []});
}

class DictionariesMenuBarInjection {
  final List<String> keys;
  final List<DictionariesMenuBarEntry> entries;
  final String? rightAfter;

  const DictionariesMenuBarInjection(this.keys, this.entries, {this.rightAfter});

  void inject() {
    injectedMenuEntries.add(this);
  }
}