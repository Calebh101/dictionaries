import 'dart:async';

import 'package:dictionaries/addons.dart';
import 'package:flutter/material.dart';

DictionariesAddon load() {
  return MakeRootSayBanana();
}

class MakeRootSayBanana extends DictionariesAddon {
  MakeRootSayBanana() : super(
    name: "Make Root Say Banana",
    description: "Make the root node say 'Banana' instead.",
    id: "com.calebh101.make_root_say_banana",
    version: "1.0.0A",
    authors: ["Calebh101"],
    doNotShow: false,
  );

  @override
  FutureOr<void> onRegister(bool debug) {
    DictionariesWidgetInjection(target: DictionariesWidgetInjectionTarget.rootNode, build: (context, widget) {
    widget = widget as DictionariesRootNodeWidget;
    return widget..nameText = SelectableText("Banana!")..addWidget(DictionariesRootNodeSlot.beforeContextMenuButton, IconButton(onPressed: () {
      showDialog(context: context, builder: (context) => AlertDialog(
        content: Text('BANANA 🍌'),
      ));
    }, icon: Text('🍌')));
  }).register();
  }
}