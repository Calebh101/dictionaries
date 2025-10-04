import 'package:dictionaries/object/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:styled_logger/styled_logger.dart';

List<NodeData> currentExpanded = [];

class ObjectEditorDesktop extends StatefulWidget {
  const ObjectEditorDesktop({super.key});

  @override
  State<ObjectEditorDesktop> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditorDesktop> {
  late final TreeController<NodeData> controller;
  ScrollController scrollController1 = ScrollController();

  @override
  void initState() {
    Node root = Node(input: RootNode.instance, children: RootNode.instance.children, isRoot: true);
    controller = TreeController<NodeData>(roots: [root], childrenProvider: (node) => node.children);
    controller.expand(root);

    controller.addListener(() async {
      currentExpanded = controller.toggledNodes.toList();
    });

    reloadExpanded();
    super.initState();
  }

  void refresh({bool tree = false}) {
    if (tree) controller.rebuild();
    setState(() {});
  }

  void reloadExpanded() {
    Logger.print("Reloading ${currentExpanded.length} expansions...");
    for (NodeData node in currentExpanded) controller.expand(node);
  }

  @override
  Widget build(BuildContext context) {
    return MenuBarWidget(
      barButtons: [],
      child: AnimatedTreeView<NodeData>(treeController: controller, nodeBuilder: (context, entry) {
        if (entry.node.isRoot) {
          Node node = entry.node as Node;
          RootNode root = node.input as RootNode;

          return InkWell(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: TreeIndentation(
                child: Row(
                  children: [
                    ExpandIcon(
                      size: 24,
                      isExpanded: entry.isExpanded,
                      onPressed: (value) => controller.toggleExpansion(node),
                    ),
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
                                child: SelectableText("Root", textAlign: TextAlign.left),
                              ),
                              SizedBox(
                                width: width3,
                                child: Text("${node.children.length} Children"),
                              ),
                              SizedBox(
                                width: width2,
                                child: DropdownButton<RootNodeType>(items: RootNodeType.values.map((type) {
                                  return DropdownMenuItem<RootNodeType>(
                                    alignment: AlignmentGeometry.center,
                                    value: type,
                                    child: Text(nodeTypeToString(rootNodeTypeToNodeType(type)), textAlign: TextAlign.center),
                                  );
                                }).toList(), onChanged: (value) {
                                  if (value == null) return;
                                  refresh(tree: true);
                                }, value: root.type),
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
        }

        NodeData data = entry.node;
        String title = "Unknown";
      
        if (data is Node) {
          title = data.index.toString();
        }
      
        if (data is NodeKeyValuePair) {
          title = data.key;
        }

        if (data.node.type == NodeType.map || data.node.type == NodeType.array) {
          int i = 0;

          for (NodeData child in data.node.children) {
            child.index = i;
            i++;
          }
        }
      
        return InkWell(
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: TreeIndentation(
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 32,
                    child: data.children.isNotEmpty ? ExpandIcon(
                      size: 24,
                      isExpanded: entry.isExpanded,
                      onPressed: (value) => controller.toggleExpansion(entry.node),
                    ) : null,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double maxWidth = MediaQuery.of(context).size.width;
                        double width2 = 100;
                        double width3 = maxWidth * 0.3;
                        double width1 = constraints.maxWidth - width2 - width3;
      
                        return TreeRowContainer(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: width1,
                                child: SelectableText(title, textAlign: TextAlign.left),
                              ),
                              SizedBox(
                                width: width3,
                                child: data.node.input != null ? SelectableText(data.node.valueToString(), textAlign: TextAlign.center) : SizedBox.shrink(),
                              ),
                              SizedBox(
                                width: width2,
                                child: DropdownButton<NodeType>(isDense: true, items: NodeType.values.map((type) {
                                  return DropdownMenuItem<NodeType>(
                                    alignment: AlignmentGeometry.center,
                                    value: type,
                                    child: Text(nodeTypeToString(type), textAlign: TextAlign.center),
                                  );
                                }).toList(), onChanged: (type) {
                                  if (type == null) return;
                                  if (type == data.node.type) return;
                                  
                                  if (type == NodeType.map) {
                                    data.node.input = null;
                                    data.node.isParentType = 2;
                                    List<NodeKeyValuePair> children = [];
                          
                                    for (NodeData child in data.node.children) {
                                      if (child is Node) {
                                        children.add(NodeKeyValuePair(key: child.index.toString(), value: child));
                                      } else if (child is NodeKeyValuePair) {
                                        children.add(child);
                                      }
                                    }
                          
                                    data.node.children.clear();
                                    data.node.children = children;
                                  } else if (type == NodeType.array) {
                                    data.node.input = null;
                                    data.node.isParentType = 1;
                                    List<Node> children = [];
                          
                                    for (NodeData child in data.node.children) {
                                      if (child is Node) {
                                        children.add(child);
                                      } else if (child is NodeKeyValuePair) {
                                        children.add(Node(input: child.node.input));
                                      }
                                    }
                          
                                    data.node.children.clear();
                                    data.node.children = children;
                                  } else {
                                    data.node.isParentType = 0;
                                    data.children.clear();
                                    data.node.input = getDefaultValue(type);
                                  }
                          
                                  Logger.print("Changing node to $type... (value of ${data.node.input}) (${[data.node.input.runtimeType, data.node.type, data.node.identify(debug: true), data.children.isEmpty].join(" - ")}) (${data.children.length} children)");
                                  RootNode.instance.rebuild();
                                  refresh(tree: true);
                                }, value: data.node.type),
                              ),
                            ],
                          ),
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

class TreeRowContainer extends StatefulWidget {
  final Widget child;
  const TreeRowContainer({super.key, required this.child});

  @override
  State<TreeRowContainer> createState() => _TreeRowContainerState();
}

class _TreeRowContainerState extends State<TreeRowContainer> {
  bool hover = false;

  void set(bool status) {
    hover = status;
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => set(true),
      onExit: (event) => set(false),
      child: Container(
        color: hover ? (Theme.of(context).brightness == Brightness.light ? const Color.fromARGB(255, 202, 202, 202) : const Color.fromARGB(255, 26, 35, 46)) : Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: 5),
        child: widget.child,
      ),
    );
  }
}