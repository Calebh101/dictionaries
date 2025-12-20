library;

import 'dart:async';

import 'package:dictionaries/addons.dart';
import 'package:dictionaries/main.dart';
import 'package:dictionaries/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:styled_logger/styled_logger.dart';

export 'package:dictionaries/src/widgetframework.dart';
export 'package:dictionaries/src/menubar.dart' show DictionariesMenuBarEntry;
export 'package:dictionaries/src/nodes.dart' show RootNode;
export 'package:dictionaries/src/theme.dart' show DictionariesTheme;

/// This class is what you base your entire addon around.
/// You will make a new class that inherits this class and provides the info and permissions.
abstract class DictionariesAddon {
  /// The name of your addon.
  final String name;

  /// The ID of your addon. This should follow the Java naming procedure, and the final identifier should be lower snake case. Example:
  ///
  /// `com.calebh101.oc_snapshot`
  final String id;

  /// The version of your addon. This can be in any format you like.
  final String version;

  /// The optional short description of your addon.
  final String? description;

  /// A list of names of who made this, This can be in any format you like.
  final List<String> authors;

  /// A link to your addon's optional "main page". Take this how you'd like, but [repository] is a separate property for an addon's repository.
  final Uri? mainpage;

  /// An addon's open source repository.
  ///
  /// Reminder: Your addon must be open-source and publicly available to be able to be used in Dictionaries!
  final Uri? repository;

  /// If this addon should be completely ignored by the loader.
  final bool doNotShow;

  /// This class is what you base your entire addon around.
  /// You will make a new class that inherits this class and provides the info and permissions.
  DictionariesAddon({
    required this.name,
    required this.id,
    required this.version,
    this.authors = const [],
    this.description,
    this.mainpage,
    this.repository,
    this.doNotShow = false,
  });

  /// This is called to register your addon.
  /// **Do not call this yourself**.
  FutureOr<void> register(bool debug) async {
    injectedAddons.add(this);
    await onRegister(debug);
  }

  /// This is called when your addon is registered. You don't call this, but you *override* this in your class.
  ///
  /// You should put all injections you do and/or background services you start in here.
  FutureOr<void> onRegister(bool debug) {}

  /// This is called when your addon is disengaged. You should stop all background processes when this is called.
  void onDisengage() {}

  bool get doShow => !doNotShow;

  /// Get your addon's current [AddonContext]. This is used for identification in injections.
  AddonContext get context => AddonContext.fromId(id);

  /// Get your addon's current [AddonContext]. This is used for identification in injections.
  AddonContext get addonContext => context;
}

abstract class DictionariesUIInjection {
  const DictionariesUIInjection();

  void inject(AddonContext context) {
    injectedAddonUIs.add((this, context));
  }
}

enum DictionariesWidgetInjectionTarget {
  rootNode,
}

final class DictionariesWidgetInjection<T extends DictionariesWidget> extends DictionariesUIInjection {
  final DictionariesWidgetInjectionTarget target;
  final DictionariesWidget Function(BuildContext context, T widget) _build;

  DictionariesWidget build(BuildContext context, DictionariesWidget widget) {
    if (widget is T) {
      return _build(context, widget);
    } else {
      Logger.warn("Detected type mismatch when building ${this.runtimeType}.");
      return widget;
    }
  }

  const DictionariesWidgetInjection({required this.target, required DictionariesWidget Function(BuildContext context, T widget) build}) : _build = build;
}

final class DictionariesMaterialAppInjection extends DictionariesUIInjection {
  final MaterialApp Function(BuildContext context, MaterialApp widget) build;

  const DictionariesMaterialAppInjection({required this.build});

  void inject(AddonContext context) {
    injectedAddonUIs.add((this, context));
  }
}

class DictionariesMenuBarInjection {
  final List<String> keys;
  final List<DictionariesMenuBarEntry> entries;
  final DictionariesMenuBarPosition? rightAfter;

  const DictionariesMenuBarInjection(this.keys, this.entries, {this.rightAfter});

  void inject(AddonContext context) {
    injectedMenuEntries.add((this, context));
  }
}

class DictionariesMenuBarPosition {
  final bool leading;
  final String? text;

  const DictionariesMenuBarPosition.fromKey(String key) : text = key, leading = false;
  const DictionariesMenuBarPosition.leading() : text = null, leading = true;
}

class AddonLogger {
  static void print(AddonContext context, Object? input, {List<Object?>? attachments}) {
    Logger.print("${context.id}: $input", attachments: attachments);
  }

  static void warn(AddonContext context, Object? input, {List<Object?>? attachments}) {
    Logger.warn("Addon: $input", attachments: attachments);
  }

  static void error(AddonContext context, Object? input, {List<Object?>? attachments}) {
    Logger.error("Addon: $input", attachments: attachments);
  }
}

class AddonContext {
  final String id;
  const AddonContext.fromId(this.id);
}

extension DictionariesThemeInjection on DictionariesTheme {
  void inject(AddonContext context, String id) {
    addTheme("${context.id}.$id", this);
  }
}