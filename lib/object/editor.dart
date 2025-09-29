import 'dart:convert';

import 'package:dictionaries/object/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:localpkg/dialogue.dart';
import 'package:menu_bar/menu_bar.dart';

class ObjectEditorDesktop extends StatefulWidget {
  final RootNode root;
  const ObjectEditorDesktop({super.key, required this.root});

  @override
  State<ObjectEditorDesktop> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditorDesktop> {
  late final TreeController<NodeData> controller;
  ScrollController scrollController1 = ScrollController();

  @override
  void initState() {
    controller = TreeController<NodeData>(roots: widget.root.children, childrenProvider: (node) => node.children);
    super.initState();
  }

  void refresh({bool tree = false}) {
    if (tree) controller.rebuild();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MenuBarWidget(
      barButtons: [
        BarButton(text: Text("File"), submenu: SubMenu(
          menuItems: [
            MenuButton(text: Text("Copy as JSON"), onTap: () {
              Object? data = widget.root.toJson();
              String text = jsonEncode(data);

              Clipboard.setData(ClipboardData(text: text));
              SnackBarManager.show(context, "Copied ${text.codeUnits.length} bytes!");
            }),
            MenuButton(text: Text("Copy as YAML"), onTap: () {
              Object? data = widget.root.toYaml();
              String text = json2yaml(data as Map<String, dynamic>);

              Clipboard.setData(ClipboardData(text: text));
              SnackBarManager.show(context, "Copied ${text.codeUnits.length} bytes!");
            }),
          ],
        )),
      ],
      child: AnimatedTreeView<NodeData>(treeController: controller, nodeBuilder: (context, entry) {
        late Node node;
        NodeData data = entry.node;
        String title = "Unknown";
      
        if (data is Node) {
          node = data;
          title = "";
        }
      
        if (data is NodeKeyValuePair) {
          node = data.value;
          title = data.key;
        }
      
        return InkWell(
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: TreeIndentation(
              child: Row(
                children: [
                  if (data.children.isNotEmpty)
                  ExpandIcon(
                    size: 24,
                    isExpanded: entry.isExpanded,
                    onPressed: (value) => controller.toggleExpansion(entry.node),
                  )
                  else
                  SizedBox(
                    width: 40,
                    height: 32,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double maxWidth = MediaQuery.of(context).size.width;
                        double width2 = 100;
                        double width3 = maxWidth * 0.3;
                        double width1 = constraints.maxWidth - width2 - width3;
      
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: width1,
                              child: SelectableText(title, textAlign: TextAlign.left),
                            ),
                            SizedBox(
                              width: width3,
                              child: node.input != null ? SelectableText(node.input.toString(), textAlign: TextAlign.center) : SizedBox.shrink(),
                            ),
                            SizedBox(
                              width: width2,
                              child: DropdownButton<NodeType>(items: NodeType.values.map((type) {
                                return DropdownMenuItem<NodeType>(
                                  alignment: AlignmentGeometry.center,
                                  value: type,
                                  child: Text(nodeTypeToString(type), textAlign: TextAlign.center),
                                );
                              }).toList(), onChanged: (value) {
                                if (value == null) return;
                                node.type = value;
                                node.input = node.defaultValue;
                                node.children.clear();
                                refresh(tree: true);
                              }, value: node.type),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ),
              guide: IndentGuide.connectingLines(
                indent: 24,
                thickness: 1,
                color: Colors.grey,
              ),
              entry: entry,
            ),
          ),
        );
      }),
    );
  }
}

class EditorNodeWidgetData {
  late final List<Widget> columns;

  EditorNodeWidgetData(Widget column1, Widget column2, Widget column3) {
    columns = [column1, column2, column3];
  }
}