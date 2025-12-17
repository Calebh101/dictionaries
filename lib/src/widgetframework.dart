import 'package:dictionaries/addons.dart';
import 'package:dictionaries/main.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';

abstract class DictionariesWidget {
  DictionariesWidget();

  Widget build(BuildContext context);

  Widget apply<T extends DictionariesWidget>(BuildContext context, DictionariesWidgetInjectionTarget target) {
    var w = this;

    for (var ui in injectedAddonUIs.whereType<DictionariesWidgetInjection>().where((x) => x.target == target)) {
      w = ui.build(context, w as T);
    }

    return w.build(context);
  }
}

class DictionariesRootNodeWidget extends DictionariesWidget {
  TreeEntry<NodeData> entry;
  ExpandIcon expandIcon;
  IndentGuide indentGuide;
  Widget nameText;
  Widget childrenCountText;
  Widget typeSelector;
  Widget contextMenuButton;

  DictionariesRootNodeWidget({
    required this.childrenCountText,
    required this.expandIcon,
    required this.nameText,
    required this.typeSelector,
    required this.entry,
    required this.indentGuide,
    required this.contextMenuButton,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: TreeIndentation(child: Row(
        children: [
          expandIcon,
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              double maxWidth = MediaQuery.of(context).size.width;
              double width2 = 100;
              double width3 = maxWidth * 0.3;
              double width1 = constraints.maxWidth - width2 - width3;

              return Row(
                children: [
                  SizedBox(
                    width: width1,
                    child: nameText,
                  ),
                  SizedBox(
                    width: width3,
                    child: childrenCountText,
                  ),
                  SizedBox(
                    width: width2,
                    child: typeSelector,
                  ),
                ],
              );
            }),
          ),
          contextMenuButton,
          SizedBox(width: 40),
        ],
      ), entry: entry, guide: indentGuide),
    );
  }
}