import 'package:dictionaries/object/nodes.dart';
import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class ObjectEditor extends StatefulWidget {
  final RootNode root;
  const ObjectEditor({super.key, required this.root});

  @override
  State<ObjectEditor> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditor> {
  ScrollController scrollController1 = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool small = MediaQuery.of(context).size.width < 300;

    return TreeView<NodeData>(tree: widget.root.children.map((child) {
      TreeViewNode<NodeData> process(NodeData child, [int level = 0]) {
        return TreeViewNode<NodeData>(child, children: child.children.map((child) => process(child, level + 1)).toList());
      }

      return process(child);
    }).toList());

    /*return AnimatedTreeView<NodeData>(treeController: controller, nodeBuilder: (context, entry) {
      late Node node;
      NodeData data = entry.node;
      String title = "Unknown";
    
      if (data is Node) {
        node = data;
        title = 0.toString();
      }
    
      if (data is NodeKeyValuePair) {
        node = data.value;
        title = data.key;
      }
    
      return small ? SizedBox.shrink() : InkWell(
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
                              setState(() {});
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
    });*/
  }
}

class EditorNodeWidgetData {
  late final List<Widget> columns;

  EditorNodeWidgetData(Widget column1, Widget column2, Widget column3) {
    columns = [column1, column2, column3];
  }
}