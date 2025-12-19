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

    for (var ui in injectedAddonUIs.map((x) => x.$1).whereType<DictionariesWidgetInjection>().where((x) => x.target == target)) {
      w = ui.build(context, w as T);
    }

    return w.build(context);
  }
}

/// Where the specified widget will be injected in the root node row. The order is as follows:
/// - `beforeExpandIcon`
/// - `afterExpandIcon`
/// - `beforeName`
/// - `afterName`
/// - `beforeChildrenCount`
/// - `afterChildrenCount`
/// - `beforeTypeSelector`
/// - `afterTypeSelector`
/// - `beforeContextMenuButton`
/// - `afterContextMenuButton`
enum DictionariesRootNodeSlot {
  beforeExpandIcon,
  afterExpandIcon,
  beforeName,
  afterName,
  beforeChildrenCount,
  afterChildrenCount,
  beforeTypeSelector,
  afterTypeSelector,
  beforeContextMenuButton,
  afterContextMenuButton,
}

class DictionariesRootNodeWidget extends DictionariesWidget {
  TreeEntry<NodeData> entry;
  ExpandIcon expandIcon;
  IndentGuide indentGuide;
  Widget nameText;
  Widget childrenCountText;
  Widget typeSelector;
  Widget contextMenuButton;
  double trailingPadding;

  final List<(DictionariesRootNodeSlot, Widget)> _addedWidgets = [];

  /// Add a new widget in the row.
  ///
  /// [slot] is the [DictionariesRootNodeSlot] specifying where it should be injected, and [widget] is the widget being injected.
  ///
  /// It's recommended to use [DictionariesRootNodeSlot] wisely, because multiple addons that process this widget are chained. For example, even though [childrenCountText] is right after [nameText], if you want to put something right after [nameText], don't use [DictionariesRootNodeSlot.beforeChildrenCount].
  void addWidget(DictionariesRootNodeSlot slot, Widget widget) {
    _addedWidgets.add((slot, widget));
  }

  List<Widget> _injectedAddedWidgets(DictionariesRootNodeSlot slot) {
    return _addedWidgets.where((x) => x.$1 == slot).map((x) => x.$2).toList();
  }

  DictionariesRootNodeWidget({
    required this.childrenCountText,
    required this.expandIcon,
    required this.nameText,
    required this.typeSelector,
    required this.entry,
    required this.indentGuide,
    required this.contextMenuButton,
    required this.trailingPadding,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: TreeIndentation(child: Row(
        children: [
          ..._injectedAddedWidgets(DictionariesRootNodeSlot.beforeExpandIcon),
          expandIcon,
          ..._injectedAddedWidgets(DictionariesRootNodeSlot.afterExpandIcon),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              double maxWidth = MediaQuery.of(context).size.width;
              double width2 = 100;
              double width3 = maxWidth * 0.3;
              double width1 = constraints.maxWidth - width2 - width3;

              return Row(
                children: [
                  ..._injectedAddedWidgets(DictionariesRootNodeSlot.beforeName),
                  SizedBox(
                    width: width1,
                    child: nameText,
                  ),
                  ..._injectedAddedWidgets(DictionariesRootNodeSlot.afterName),
                  ..._injectedAddedWidgets(DictionariesRootNodeSlot.beforeChildrenCount),
                  SizedBox(
                    width: width3,
                    child: childrenCountText,
                  ),
                  ..._injectedAddedWidgets(DictionariesRootNodeSlot.afterChildrenCount),
                  ..._injectedAddedWidgets(DictionariesRootNodeSlot.beforeTypeSelector),
                  SizedBox(
                    width: width2,
                    child: typeSelector,
                  ),
                  ..._injectedAddedWidgets(DictionariesRootNodeSlot.afterTypeSelector),
                ],
              );
            }),
          ),
          ..._injectedAddedWidgets(DictionariesRootNodeSlot.beforeContextMenuButton),
          contextMenuButton,
          ..._injectedAddedWidgets(DictionariesRootNodeSlot.afterContextMenuButton),
          SizedBox(width: trailingPadding),
        ],
      ), entry: entry, guide: indentGuide),
    );
  }
}