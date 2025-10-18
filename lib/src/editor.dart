import 'package:any_date/any_date.dart';
import 'package:dictionaries/files/files.dart';
import 'package:dictionaries/main.dart';
import 'package:dictionaries/src/nodeenums.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' as cm;
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:localpkg_flutter/localpkg.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:styled_logger/styled_logger.dart';

bool throwOnBinary = false; // Debug option
String? currentFileName;
List<NodeData> currentExpanded = [];
bool isCurrentlyShowingMoveUpDownOverlay = false;
List<MoveUpDownWidget> moveUpDownWidgets = [];

class ObjectEditorDesktop extends StatefulWidget {
  const ObjectEditorDesktop({super.key});

  @override
  State<ObjectEditorDesktop> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditorDesktop> {
  late final TreeController<NodeData> controller;
  ScrollController scrollController1 = ScrollController();
  Map<String, ({TextEditingController controller, GlobalKey key})> formControllers = {};
  Map<String, ({TextEditingController controller, GlobalKey key})> keyControllers = {};

  @override
  void initState() {
    Node root = Node(input: RootNode.instance, children: RootNode.instance.children, isRoot: true);
    controller = TreeController<NodeData>(roots: [root], childrenProvider: (node) => node.children, parentProvider: (node) => RootNode.instance.lookupNodeData(node.parent));
    controller.expand(root);

    controller.addListener(() async {
      currentExpanded = controller.toggledNodes.toList();
    });

    reloadExpanded();
    super.initState();
  }

  void refresh({bool rebuild = false}) {
    if (rebuild) {
      controller.rebuild();
      RootNode.instance.rebuild();
    }

    setState(() {});
  }

  void reloadExpanded() {
    Logger.print("Reloading ${currentExpanded.length} expansions...");
    for (NodeData node in currentExpanded) controller.expand(node);
  }

  @override
  Widget build(BuildContext context) {
    return MenuBarWidget(
      barButtons: [
        BarButton(text: Text("File"), submenu: SubMenu(menuItems: [
          MenuButton(text: Text("Export As..."), submenu: SubMenu(menuItems: [
            MenuButton(text: Text("Export as Dictionary"), onTap: () async {
              bool result = await saveFile(name: currentFileName ?? "MyDictionary", bytes: RootNode.instance.toBinary());
              if (result == false) return;
              SnackBarManager.show(context, "Saved file to $currentFileName!");
            }),
          ])),
          MenuDivider(),
          MenuButton(text: Text("Return to Home"), onTap: () async {
            bool? result = await ConfirmationDialogue.show(context: context, title: "Are You Sure?", description: "Are you sure you want to return to the home page? All unsaved data will be lost.");
            Logger.print("Received result of $result");
            if (result == true) SimpleNavigator.navigate(context: context, page: Home(), mode: NavigatorMode.pushReplacement);
          }),
        ])),
      ],
      child: AnimatedTreeView<NodeData>(treeController: controller, nodeBuilder: (context, entry) {
        if (entry.node.isRoot) {
          Node node = entry.node as Node;
          RootNode root = node.input as RootNode;

          List<cm.ContextMenuEntry> contextMenuEntries = [
            cm.MenuItem(label: "New Child", icon: Icons.add, onSelected: () {
              Node node = Node(input: "New String");
              NodeData data = root.type == RootNodeType.map ? NodeKeyValuePair(key: "New String", value: node) : node;
              Logger.print("Adding child ${data.runtimeType}... (currently ${entry.node.children.length} children)");
              entry.node.children.add(data);
              refresh(rebuild: true);
              Logger.print("Added child ${data.runtimeType} (currently ${entry.node.children.length} children)");
            }),
          ];

          return TreeDragTarget<NodeData>(
            node: node,
            onWillAcceptWithDetails: (details) => true,
            onNodeAccepted: (details) {
              AllNodeData oldParent = details.draggedNode.getParent()!;

              if (oldParent is NodeData) {
                oldParent.children.removeWhere((x) => x.id == details.targetNode.id);
              } else if (oldParent is RootNode) {
                if (details.targetNode.isRoot) return;
                oldParent.children.removeWhere((x) => x.id == details.targetNode.id);
              }

              details.draggedNode.parent = "root";
              node.children.add(details.draggedNode);
              refresh(rebuild: true);
            },
            builder: (context, details) {
              return cm.ContextMenuRegion(
                contextMenu: cm.ContextMenu(entries: contextMenuEntries, padding: EdgeInsets.all(8)),
                child: InkWell(
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
                                        refresh(rebuild: true);
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
                ),
              );
            }
          );
        }

        NodeData data = entry.node;
        String title = "Unknown";
        bool hasKey = false;
        Widget? keyWidget;

        if (!formControllers.containsKey(data.id)) {
          formControllers[data.id] = (controller: TextEditingController(text: data.node.valueToString()), key: GlobalKey());
        }
      
        if (data is Node) {
          title = data.index.toString();
        }
      
        if (data is NodeKeyValuePair) {
          hasKey = true;
          title = data.key;
        }

        if (hasKey) {
          NodeKeyValuePair nkvp = data as NodeKeyValuePair;
          if (!keyControllers.containsKey(data.id)) keyControllers[data.id] = (controller: TextEditingController(text: nkvp.key), key: GlobalKey());

          keyWidget = Form(
            key: keyControllers[data.id]!.key,
            child: TextFormField(
              controller: keyControllers[data.id]!.controller,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (value) {
                (keyControllers[data.id]!.key.currentState as FormState).save();
              },
              onSaved: (source) {
                if (source == null) return;
                bool result = (keyControllers[data.id]!.key.currentState as FormState).validate();
                if (result == false) return;
                Logger.print("Setting key...");
                nkvp.key = source;
                setState(() {});
              },
              validator: (value) {
                if (value == null) return "Value cannot be empty.";
                AllNodeData? parent = RootNode.instance.lookup(data.parent ?? "");
                Logger.print("Found parent of type ${parent.runtimeType} from ID ${data.parent}");

                if (parent is NodeData) {
                  if (parent.children.whereType<NodeKeyValuePair>().any((x) => x.key == value)) return "This key already exists.";
                } else if (parent is RootNode) {
                  if (parent.children.whereType<NodeKeyValuePair>().any((x) => x.key == value)) return "This key already exists.";
                }

                return null;
              },
            ),
          );
        }

        if (data.node.type == NodeType.map || data.node.type == NodeType.array) {
          int i = 0;

          for (NodeData child in data.node.children) {
            child.index = i;
            i++;
          }
        }
      
        return TreeDragTarget<NodeData>(
          node: data,
          onWillAcceptWithDetails: (details) {
            return data.node.type == NodeType.map || data.node.type == NodeType.array;
          },
          onNodeAccepted: (details) {
            NodeData dragged = details.draggedNode;
            AllNodeData oldParent = details.draggedNode.getParent()!;

            if (oldParent is NodeData) {
              Logger.print("Dragging ${dragged.id} to new parent ${details.targetNode.id} from parent ${oldParent.id}");
              if (oldParent.id == details.targetNode.id) return;
              oldParent.children.removeWhere((x) => x.id == dragged.id);
              refresh(rebuild: true);
            } else if (oldParent is RootNode) {
              Logger.print("Dragging ${dragged.id} to new parent root");
              if (details.targetNode.isRoot) return;
              oldParent.children.removeWhere((x) => x.id == dragged.id);
              refresh(rebuild: true);
            } else {
              throw UnimplementedError();
            }

            dragged.parent = details.targetNode.id;
            details.targetNode.children.add(dragged);
            refresh(rebuild: true);
          },
          builder: (context, details) {
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
                      TreeDraggable<NodeData>(
                        node: data,
                        feedback: Material(
                          elevation: 4,
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Text(title),
                          ),
                        ),
                        child: IconButton(onPressed: () {}, icon: Icon(Icons.drag_handle)),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double maxWidth = MediaQuery.of(context).size.width;
                            double width2 = 100;
                            double width3 = maxWidth * 0.3;
                            double width1 = constraints.maxWidth - width2 - width3 - 48;
            
                            Object? get(String source) {
                              switch (data.node.type) {
                                case NodeType.string: return source;
                                case NodeType.number: return int.tryParse(source) ?? double.tryParse(source);
                                case NodeType.boolean: return bool.tryParse(source);
                                case NodeType.date: return AnyDate().tryParse(source);
                        
                                case NodeType.data:
                                  source = source.trim().replaceAll(RegExp("0x", caseSensitive: false), "").replaceAll(RegExp("[^a-zA-Z0-9]"), "").toUpperCase();
                                  if (RegExp("[^A-F0-9]").hasMatch(source)) return null;
                                  if (source.length % 2 != 0) source = "0$source";
                        
                                  int i = 0;
                                  List<int> bytes = [];
                        
                                  while (i < source.length) {
                                    if (i + 2 > source.length) return null;
                                    String byte = source.substring(i, i + 2);
                                    int? value = int.tryParse(byte, radix: 16);
                                    if (value != null) bytes.add(value);
                                    i += 2;
                                  }
                        
                                  return Uint8List.fromList(bytes);
                        
                                default: return null;
                              }
                            }
            
                            Widget valueChild = data.node.type == NodeType.boolean ? DropdownButton<bool>(isDense: true, value: data.node.input as bool, items: [
                              DropdownMenuItem(child: Text("True"), value: true),
                              DropdownMenuItem(child: Text("False"), value: false),
                            ], onChanged: (value) {
                              if (value == null) return;
                              data.node.input = value;
                              setState(() {});
                            }) : Form(
                              key: formControllers[data.id]!.key,
                              child: TextFormField(
                                controller: formControllers[data.id]!.controller,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                onChanged: (value) {
                                  (formControllers[data.id]!.key.currentState as FormState).save();
                                },
                                onSaved: (source) {
                                  if (source == null) return;
                                  bool result = (keyControllers[data.id]!.key.currentState as FormState).validate();
                                  if (result == false) return;
            
                                  var value = get(source);
                                  if (value == null) return;
            
                                  Logger.print("Setting value...");
                                  data.node.input = value;
                                  setState(() {});
                                },
                                validator: (value) {
                                  if (value == null) return "Value cannot be empty.";
                                  if (get(value) == null) return "Value is invalid.";
                                  return null;
                                },
                              ),
                            );
            
                            List<cm.ContextMenuEntry> contextMenuEntries = [
                              if (data.node.type == NodeType.array || data.node.type == NodeType.map)
                              cm.MenuItem(label: "New Child", icon: Icons.add, onSelected: () {
                                Node newNode = Node(input: "New String");
                                NodeData newData = data.node.type == NodeType.map ? NodeKeyValuePair(key: "New String", value: newNode) : newNode;
                                Logger.print("Adding child ${newData.runtimeType}... (currently ${entry.node.children.length} children)");
                                entry.node.children.add(newData);
                                refresh(rebuild: true);
                                Logger.print("Added child ${newData.runtimeType} (currently ${entry.node.children.length} children)");
                              }),
                              cm.MenuItem(label: "Delete", icon: Icons.delete, onSelected: () {
                                AllNodeData? parent = RootNode.instance.lookup(data.parent ?? "");
                                Logger.print("Found parent of type ${parent.runtimeType} from ID ${data.parent}");
                                if (parent == null) return;
                                
                                if (parent is NodeData) {
                                  parent.children.removeWhere((x) => x.id == data.id);
                                } else if (parent is RootNode) {
                                  parent.children.removeWhere((x) => x.id == data.id);
                                } else {
                                  return;
                                }
            
                                Logger.print("Removed child of ID ${data.id}");
                                refresh(rebuild: true);
                              })
                            ];
            
                            return cm.ContextMenuRegion(
                              contextMenu: cm.ContextMenu(entries: contextMenuEntries),
                              child: TreeRowContainer(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: width1,
                                      child: keyWidget ?? SelectableText(title, textAlign: TextAlign.left),
                                    ),
                                    SizedBox(
                                      width: width3,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: data.node.input != null ? valueChild : SizedBox.shrink(),
                                      ),
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
                                        refresh(rebuild: true);
                                      }, value: data.node.type),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        var parent = data.getParent();
                                        late List<NodeData> children;
                                        int index = 0;
            
                                        if (parent is NodeData) {
                                          children = parent.children;
                                        } else if (parent is RootNode) {
                                          children = parent.children;
                                        } else {
                                          throw UnimplementedError();
                                        }
            
                                        for (var child in children) {
                                          if (child.id == data.id) break;
                                          index++;
                                        }
            
                                        void move(int factor) {
                                          children.removeAt(index);
                                          children.insert(index - factor, data);
                                          refresh(rebuild: true);
                                        }
            
                                        return MoveUpDownWidget(onMoveUp: index == 0 ? null : (context) => move(1), onMoveDown: index == children.length - 1 ? null : (context) => move(-1));
                                      }
                                    ),
                                  ],
                                ),
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
          }
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

class MoveUpDownWidget extends StatefulWidget {
  final void Function(BuildContext context)? onMoveUp;
  final void Function(BuildContext context)? onMoveDown;

  final bool showOnEnter;
  final bool hideAllOnContact;

  late final _MoveUpDownWidgetState _state;
  MoveUpDownWidget({super.key, required this.onMoveUp, required this.onMoveDown, this.showOnEnter = true, this.hideAllOnContact = true});

  @override
  State<MoveUpDownWidget> createState() => _state = _MoveUpDownWidgetState();

  void show() {
    _state.show();
  }

  void hide() {
    _state.hide();
  }
}

class _MoveUpDownWidgetState extends State<MoveUpDownWidget> {
  OverlayEntry? entry;
  LayerLink link = LayerLink();

  @override
  void initState() {
    moveUpDownWidgets.add(widget);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void show() {
    if (widget.hideAllOnContact) {
      for (var child in moveUpDownWidgets) {
        if (widget == child) continue;
        child.hide();
      }
    }

    if (entry != null || isCurrentlyShowingMoveUpDownOverlay == true) return;
    isCurrentlyShowingMoveUpDownOverlay = true;
    Logger.print("Showing...");

    double elements = 0;
    for (var x in [true, widget.onMoveUp != null, widget.onMoveDown != null]) if (x) elements++;

    Widget popup = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onMoveUp != null)
          IconButton(onPressed: () {
            hide();
            widget.onMoveUp!.call(context);
          }, icon: Icon(Icons.arrow_upward)),
          IconButton(onPressed: () {
            hide();
          }, icon: Icon(Icons.cancel_outlined)),
          if (widget.onMoveDown != null)
          IconButton(onPressed: () {
            hide();
            widget.onMoveDown!.call(context);
          }, icon: Icon(Icons.arrow_downward)),
        ],
      ),
    );

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 48,
          height: elements * 48,
          child: CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            offset: Offset(-40, -48),
            child: Material(
              elevation: 4,
              color: Colors.transparent,
              child: popup,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(entry!);
  }

  void hide() {
    if (entry == null) return;
    Logger.print("Hiding entry of type ${entry.runtimeType}...");
    entry?.remove();
    entry = null;
    isCurrentlyShowingMoveUpDownOverlay = false;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        if (widget.showOnEnter) show();
      },
      child: CompositedTransformTarget(
        link: link,
        child: IconButton(onPressed: () => show(), icon: Icon(Icons.more_vert),
      )),
    );
  }
}