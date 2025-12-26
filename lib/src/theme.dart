import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';

class DictionariesTheme {
  final String name;
  final Map<String, TextStyle> Function(Brightness brightness) codeTheme;
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;

  const DictionariesTheme(this.name, {
    required this.codeTheme,
    required this.lightTheme,
    required this.darkTheme,
  });

  static const String defaultTheme = "com.calebh101.dictionaries.basic";
  static final Map<String, TextStyle> Function(Brightness brightness) defaultCodeTheme = (brightness) => brightness == Brightness.light ? atomOneLightTheme : gruvboxDarkTheme;
}

typedef DictionariesThemeData = ({String id, String? addon, DictionariesTheme theme});

List<DictionariesThemeData> defaultThemes = [];
List<DictionariesThemeData> injectedThemes = [];
List<DictionariesThemeData> get allThemes => defaultThemes + injectedThemes;
DictionariesThemeData? activeTheme;

void addDefaultTheme(String id, DictionariesTheme theme) {
  if (!defaultThemes.any((x) => x.id == id)) defaultThemes.add((id: id, addon: null, theme: theme));
}

void addInjectedTheme(String addon, String id, DictionariesTheme theme) {
  if (!injectedThemes.any((x) => x.id == id)) injectedThemes.add((id: id, addon: addon, theme: theme));
}

void getDefaultThemes() => [
  ("basic", DictionariesTheme(
    "Basic Theme",
    codeTheme: DictionariesTheme.defaultCodeTheme,
    lightTheme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
  )),
  ("highcontrast", DictionariesTheme(
    "High Contrast",
    codeTheme: DictionariesTheme.defaultCodeTheme,
    lightTheme: ThemeData.light(),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: Color(0xFF000000),
        primary: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
        secondary: Color(0xFF000000),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        error: Color(0xFFFFFFFF),
        onError: Color(0xFF000000),
      ),
    ),
  )),
].forEach((x) => addDefaultTheme("com.calebh101.dictionaries.${x.$1}", x.$2));

void applyTheme([String? target]) {
  target ??= DictionariesTheme.defaultTheme;
  var o = allThemes.firstWhereOrNull((x) => x.id == target);
  activeTheme = o;

  if (o == null) {
    Logger.warn("Invalid theme: $target");
    if (target != DictionariesTheme.defaultTheme) applyTheme();
  } else {
    Logger.print("Activated theme: $target");
    saveTheme(target);
  }
}

void saveTheme(String id) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("theme", id);
  Logger.print("Saved theme: $id");
}