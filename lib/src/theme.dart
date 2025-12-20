import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';
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

List<(String id, DictionariesTheme)> themes = [];
(String id, DictionariesTheme)? activeTheme;

void addTheme(String id, DictionariesTheme theme) {
  if (!themes.any((x) => x.$1 == id)) themes.add((id, theme));
}

void defaultThemes() => [
  ("basic", DictionariesTheme(
    "Basic Theme",
    codeTheme: DictionariesTheme.defaultCodeTheme,
    lightTheme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
  )),
].map((x) => addTheme("com.calebh101.dictionaries.${x.$1}", x.$2));

void applyTheme(String target) {
  var o = themes.firstWhereOrNull((x) => x.$1 == target);
  activeTheme = o;

  if (o == null) {
    Logger.warn("Invalid theme: $target");
    if (target != DictionariesTheme.defaultTheme) applyTheme(DictionariesTheme.defaultTheme);
  } else {
    Logger.print("Activated theme: $target");
  }
}