library;

import 'dart:async';

import 'package:dictionaries/main.dart';
import 'package:flutter/material.dart';
import 'package:dictionaries/src/widgetframework.dart';

export 'package:dictionaries/src/widgetframework.dart';

/// This class is what you base your entire addon around.
/// You will make a new class that inherits this class and provides the info and permissions.
abstract class DictionariesAddon {
  final String name;
  final String id;
  final String version;
  final String? description;
  final List<String> authors;
  final Uri? mainpage;
  final Uri? repository;
  final bool alwaysEnableThisAddon;

  DictionariesAddon({
    required this.name,
    required this.id,
    required this.version,
    this.authors = const [],
    this.description,
    this.mainpage,
    this.repository,
    this.alwaysEnableThisAddon = false,
  });

  FutureOr<void> register() async {
    injectedAddons.add(this);
    await onRegister();
  }

  FutureOr<void> onRegister();
}

abstract class DictionariesUIInjection {
  const DictionariesUIInjection();

  void register() {
    injectedAddonUIs.add(this);
  }
}

enum DictionariesWidgetInjectionTarget {
  rootNode,
}

final class DictionariesWidgetInjection extends DictionariesUIInjection {
  final DictionariesWidgetInjectionTarget target;
  final DictionariesWidget Function(BuildContext context, DictionariesWidget widget) build;

  const DictionariesWidgetInjection({required this.target, required this.build});
}

final class DictionariesMaterialAppInjection extends DictionariesUIInjection {
  final MaterialApp Function(BuildContext context, MaterialApp widget) build;

  const DictionariesMaterialAppInjection({required this.build});
}