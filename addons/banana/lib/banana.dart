import 'dart:async';

import 'package:dictionaries/addons.dart';
import 'package:flutter/material.dart';

DictionariesAddon load() {
  return MakeRootSayBanana();
}

void banana(BuildContext context) {
  showDialog(context: context, builder: (context) => AlertDialog(
    content: Text('BANANA 🍌'),
  ));
}

class MakeRootSayBanana extends DictionariesAddon {
  MakeRootSayBanana() : super(
    name: "Banana",
    description: "BANANA! This addon is a showcase of what you can do with addons.",
    id: "com.calebh101.banana",
    version: "1.0.0A",
    authors: ["Calebh101"],
    doNotShow: false,
  );

  @override
  FutureOr<void> onRegister(bool debug) {
    DictionariesWidgetInjection<DictionariesRootNodeWidget>(target: DictionariesWidgetInjectionTarget.rootNode, build: (context, widget) {
      return widget..nameText = SelectableText("Banana!")..addWidget(DictionariesRootNodeSlot.beforeContextMenuButton, IconButton(onPressed: () {
        banana(context);
      }, icon: Text('🍌')));
    }).inject(context);

    DictionariesMenuBarInjection(["File"], [
      DictionariesMenuBarEntry("Say Banana", onActivate: (context) {
        banana(context);
      }),
      DictionariesMenuBarEntry.divider("BananaDivider"),
    ], rightAfter: DictionariesMenuBarPosition.leading()).inject(context);

    DictionariesTheme(
      "Banana!",
      codeTheme: DictionariesTheme.defaultCodeTheme,
      darkTheme: null,
      lightTheme: ThemeData(
        brightness: Brightness.light,

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
          primary: Colors.yellow.shade700,
          secondary: Colors.yellow.shade600,
          tertiary: Colors.amber,
          surface: Colors.yellow.shade50,
        ),
        scaffoldBackgroundColor: Colors.yellow.shade100,
        cardTheme: CardThemeData(
          color: Colors.yellow.shade50,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow.shade700,
            foregroundColor: Colors.black,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.yellow.shade600,
          foregroundColor: Colors.black,
        ),
        iconTheme: IconThemeData(
          color: Colors.yellow.shade800,
        ),
        dividerColor: Colors.yellow.shade300,
      ),
    ).inject(context, "banana");
  }
}