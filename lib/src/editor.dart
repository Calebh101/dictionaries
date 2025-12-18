import 'dart:async';

import 'package:any_date/any_date.dart';
import 'package:collection/collection.dart';
import 'package:dictionaries/addons.dart';
import 'package:dictionaries/files/files.dart';
import 'package:dictionaries/main.dart';
import 'package:dictionaries/src/nodeenums.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' as cm;
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:http/http.dart' as http;
import 'package:localpkg_flutter/localpkg.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:undo/undo.dart';

bool throwOnBinary = false; // Debug option
String? currentFileName;
List<NodeData> currentExpanded = [];
bool isCurrentlyShowingMoveUpDownOverlay = false;
List<MoveUpDownWidget> moveUpDownWidgets = [];
StreamController<void> moveUpDownWidgetsChanged = StreamController.broadcast();

enum EditorSource {
  local,
  online,
  created,
}

class ObjectEditorDesktop extends StatefulWidget {
  late ObjectEditorState state;
  final EditorSource source;
  ObjectEditorDesktop({super.key, required this.source});

  @override
  State<ObjectEditorDesktop> createState() => state = ObjectEditorState();
}

class ObjectEditorState extends State<ObjectEditorDesktop> {
  final ChangeStack changes = ChangeStack(limit: 200);
  late final TreeController<NodeData> controller;

  ScrollController scrollController1 = ScrollController();
  Map<String, ({TextEditingController controller, GlobalKey key})> formControllers = {};
  Map<String, ({TextEditingController controller, GlobalKey key})> keyControllers = {};

  @override
  void initState() {
    Node root = Node(input: RootNode.instance, children: RootNode.instance.children, isRoot: true);
    controller = TreeController<NodeData>(roots: [root], childrenProvider: (node) => node.children, parentProvider: (node) => node.getParentAsNodeData());
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
              bool result = await saveFile(name: currentFileName ?? "MyDictionary", bytes: RootNode.instance.toBinary(), mime: "application/c-dict", extension: "dictionary");
              if (result == false) return;
              SnackBarManager.show(context, "Saved file to $currentFileName!");
            }),
            if (widget.source == EditorSource.online && sourceUri != null)
            ...[
              MenuDivider(),
              MenuButton(text: Text("Download Original File"), onTap: () async {
                try {
                  SnackBarManager.show(context, "Loading...");
                  var response = await http.get(sourceUri!);
                  if (!(response.statusCode >= 200 && response.statusCode < 300)) throw Exception("Invalid status code: ${response.statusCode}");
                  var bytes = response.bodyBytes;
                  if (bytes.isEmpty) throw Exception("No data was received.");
                  var name = (getFileNameFromResponse(response) ?? sourceUri!.pathSegments.lastOrNull ?? "filename").split(".");
                  Logger.print("Found name of $name");
                  saveFile(name: name.length <= 1 ? name.first : name.sublist(0, name.length - 1).join("."), bytes: bytes, mime: response.headers["content-type"] ?? "", extension: name.lastOrNull ?? "");
                } catch (e) {
                  Logger.warn("Unable to download file: $e");
                  SnackBarManager.show(context, "Unable to download file: $e");
                }
              }),
            ],
          ])),
          MenuDivider(),
          MenuButton(text: Text("Return to Home"), onTap: () async {
            bool? result = await ConfirmationDialogue.show(context: context, title: "Are You Sure?", description: "Are you sure you want to return to the home page? All unsaved data will be lost.");
            Logger.print("Received result of $result");
            if (result == true) SimpleNavigator.navigate(context: context, page: Home(), mode: NavigatorMode.pushReplacement);
          }),
        ])),
        BarButton(text: Text("Edit"), submenu: SubMenu(menuItems: [
          MenuButton(text: Text("Undo"), onTap: changes.canUndo ? () {
            changes.undo();
            refresh(rebuild: true);
          } : null, shortcut: SingleActivator(LogicalKeyboardKey.keyZ, control: true)),
          MenuButton(text: Text("Redo"), onTap: changes.canRedo ? () {
            changes.redo();
            refresh(rebuild: true);
          } : null, shortcut: SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true)),
        ]))
      ],
      child: AnimatedTreeView<NodeData>(treeController: controller, nodeBuilder: (context, entry) {
        if (entry.node.isRoot) {
          Node node = entry.node as Node;
          RootNode root = node.input as RootNode;

          List<cm.ContextMenuEntry> contextMenuEntries = [
            cm.MenuItem(label: "New Child", icon: Icons.add, onSelected: () {
              Node newNode = Node(input: "New String");
              NodeData newData = root.type == RootNodeType.map ? NodeKeyValuePair(key: "New String", value: newNode) : newNode;

              var change = Change<String>(
                newData.id,
                () {
                  entry.node.children.add(newData);
                  Logger.print("Added child ${newData.runtimeType} (currently ${entry.node.children.length} children)");
                  refresh(rebuild: true);
                },
                (id) {
                  entry.node.children.removeWhere((x) => x.id == id);
                  Logger.print("Removed child $id (currently ${entry.node.children.length} children)");
                  refresh(rebuild: true);
                }
              );

              changes.add(change);
              refresh(rebuild: true);
            }),
          ];

          return TreeDragTarget<NodeData>(
            node: node,
            onWillAcceptWithDetails: (details) => true,
            onNodeAccepted: (details) {
              NodeData dragged = details.draggedNode;
              AllNodeData oldParent = details.draggedNode.parent!;

              late void Function() changeFunction;
              late int changeIndex;

              if (oldParent is NodeData) {
                Logger.print("Dragging ${dragged.id} to new parent ${details.targetNode.id} from parent ${oldParent.id}");

                changeFunction = () {
                  changeIndex = oldParent.children.indexWhere((x) => x.id == dragged.id);
                  oldParent.children.removeAt(changeIndex);
                  refresh(rebuild: true);
                };
              } else if (oldParent is RootNode) {
                Logger.print("Dragging ${dragged.id} to new parent root");
                if (details.targetNode.isRoot) return;

                changeFunction = () {
                  changeIndex = oldParent.children.indexWhere((x) => x.id == dragged.id);
                  oldParent.children.removeAt(changeIndex);
                  refresh(rebuild: true);
                };
              } else {
                throw UnimplementedError();
              }

              var change = Change<TreeDragAndDropDetails<NodeData>>(
                details,
                () {
                  changeFunction.call();
                  dragged.parent = details.targetNode;
                  details.targetNode.children.add(dragged);
                },
                (old) {
                  if (oldParent is NodeData) {
                    oldParent.children.insert(changeIndex, details.draggedNode);
                  } else if (oldParent is RootNode) {
                    oldParent.children.insert(changeIndex, details.draggedNode);
                  }

                  dragged.parent = old.draggedNode.parent;
                  old.targetNode.children.removeWhere((x) => x.id == dragged.id);
                  refresh(rebuild: true);
                },
              );

              changes.add(change);
              refresh(rebuild: true);
            },
            builder: (context, details) {
              var contextMenu = cm.ContextMenu(entries: contextMenuEntries);

              return DictionariesRootNodeWidget(
                entry: entry,
                trailingPadding: 40,
                expandIcon: ExpandIcon(
                  size: 24,
                  padding: EdgeInsets.zero,
                  isExpanded: entry.isExpanded,
                  onPressed: (value) => controller.toggleExpansion(node),
                ),
                nameText: SelectableText("Root", textAlign: TextAlign.left),
                childrenCountText: SelectableText("${node.children.length} ${Word.fromCount(node.children.length, singular: Word("Child"), plural: Word("Children")).toString()}"),
                typeSelector: DropdownButton<RootNodeType>(items: RootNodeType.values.map((type) {
                  return DropdownMenuItem<RootNodeType>(
                    alignment: AlignmentGeometry.center,
                    value: type,
                    child: Text(nodeTypeToString(rootNodeTypeToNodeType(type)), textAlign: TextAlign.center),
                  );
                }).toList(), onChanged: (type) {
                  if (type == null) return;
                  if (type == root.type) return;

                  late void Function() change;
                  late void Function(({RootNodeType type, Iterable<NodeData> children}) r) undo;

                  var old = (
                    type: root.type,
                    children: List<NodeData>.from(root.children),
                  );

                  root.type = type;
                  Logger.print("Set root type to ${root.type}");

                  if (type == RootNodeType.map) {
                    change = () {
                      List<NodeKeyValuePair> children = [];

                      for (NodeData child in root.children) {
                        if (child is Node) {
                          children.add(NodeKeyValuePair(key: child.index.toString(), value: child));
                        } else if (child is NodeKeyValuePair) {
                          children.add(child);
                        }
                      }

                      root.children.clear();
                      for (var child in children) root.children.add(child);
                      refresh(rebuild: true);
                    };
                  } else if (type == RootNodeType.array) {
                    change = () {
                      List<Node> children = [];

                      for (NodeData child in root.children) {
                        if (child is Node) {
                          children.add(child);
                        } else if (child is NodeKeyValuePair) {
                          children.add(child.node);
                        }
                      }

                      root.children.clear();
                      for (var child in children) root.children.add(child);
                      refresh(rebuild: true);
                    };
                  }

                  undo = (r) {
                    Logger.print("Restoring root data: $r");
                    root.type = r.type;
                    root.children.clear();

                    for (var child in r.children) {
                      root.children.add(child);
                    }

                    Logger.print("Added ${root.children.length} children from ${r.children.length} provided");
                    refresh(rebuild: true);
                  };

                  var changeData = Change<({RootNodeType type, Iterable<NodeData> children})>(
                    old,
                    change,
                    undo,
                  );

                  changes.add(changeData);
                  refresh();
                }, value: root.type),
                contextMenuButton: IconButton(onPressed: () async {
                  var box = context.findRenderObject() as RenderBox;
                  var pos = box.localToGlobal(Offset.zero);
                  var previous = contextMenu.position == null ? null : Offset(contextMenu.position!.dx, contextMenu.position!.dy);
                  contextMenu.position = pos;
                  await contextMenu.show(context);
                  contextMenu.position = previous;
                }, icon: Icon(Icons.more_vert), padding: EdgeInsets.zero),
                indentGuide: IndentGuide.connectingLines(
                  indent: 24,
                  thickness: 1,
                  color: Colors.grey,
                ),
              ).apply(context, DictionariesWidgetInjectionTarget.rootNode);
            },
          );
        }

        NodeData data = entry.node;
        String title = "Unknown";
        bool hasKey = false;
        Widget? keyWidget;

        double fontSize = 14;
        double height = 22;

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
              style: TextStyle(fontSize: fontSize),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                errorStyle: TextStyle(fontSize: fontSize - 3)
              ),
              onChanged: (value) {
                (keyControllers[data.id]!.key.currentState as FormState).save();
              },
              onSaved: (source) {
                if (source == null) return;
                bool result = (keyControllers[data.id]!.key.currentState as FormState).validate();
                if (result == false) return;

                var change = Change<String>(
                  data.key,
                  () => debug(() => data.key = source),
                  (old) => debug(() {
                    data.key = old;
                    keyControllers[data.id]?.controller.text = old;
                    refresh(rebuild: true);
                  }),
                );

                changes.add(change);
                Logger.print("Setting key with change ${change.runtimeType}...");
                setState(() {});
              },
              validator: (value) {
                if (value == null) return "Value cannot be empty.";
                AllNodeData? parent = data.parent;
                Logger.print("Found parent of type ${parent.runtimeType}");

                if (parent is NodeData) {
                  if (parent.children.whereType<NodeKeyValuePair>().any((x) => x.key == value && x.id == data.id)) return "This key already exists.";
                } else if (parent is RootNode) {
                  if (parent.children.whereType<NodeKeyValuePair>().any((x) => x.key == value && x.id == data.id)) return "This key already exists.";
                }

                return null;
              },
            ),
          );
        }

        return SizedBox(
          height: height,
          child: TreeDragTarget<NodeData>(
            node: data,
            onWillAcceptWithDetails: (details) {
              return data.node.type == NodeType.map || data.node.type == NodeType.array;
            },
            onNodeAccepted: (details) {
              NodeData dragged = details.draggedNode;
              AllNodeData oldParent = details.draggedNode.parent!;

              late void Function() changeFunction;
              late int changeIndex;

              if (oldParent is NodeData) {
                Logger.print("Dragging ${dragged.id} to new parent ${details.targetNode.id} from parent ${oldParent.id}");
                if (oldParent.id == details.targetNode.id) return;

                changeFunction = () {
                  changeIndex = oldParent.children.indexWhere((x) => x.id == dragged.id);
                  oldParent.children.removeAt(changeIndex);
                  refresh(rebuild: true);
                };
              } else if (oldParent is RootNode) {
                Logger.print("Dragging ${dragged.id} to new parent root");
                if (details.targetNode.isRoot) return;

                changeFunction = () {
                  changeIndex = oldParent.children.indexWhere((x) => x.id == dragged.id);
                  oldParent.children.removeAt(changeIndex);
                  refresh(rebuild: true);
                };
              } else {
                throw UnimplementedError();
              }

              var change = Change<TreeDragAndDropDetails<NodeData>>(
                details,
                () {
                  changeFunction.call();
                  dragged.parent = details.targetNode;
                  details.targetNode.children.add(dragged);
                },
                (old) {
                  if (oldParent is NodeData) {
                    oldParent.children.insert(changeIndex, details.draggedNode);
                  } else if (oldParent is RootNode) {
                    oldParent.children.insert(changeIndex, details.draggedNode);
                  }

                  dragged.parent = old.draggedNode.parent;
                  old.targetNode.children.removeWhere((x) => x.id == dragged.id);
                  refresh(rebuild: true);
                },
              );

              changes.add(change);
              refresh(rebuild: true);
            },
            builder: (context, details) {
              Color getExpandIconColor() {
                return switch (Theme.brightnessOf(context)) {
                  Brightness.light => Colors.black54,
                  Brightness.dark => Colors.white60,
                };
              }

              return InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: TreeIndentation(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: data.children.isNotEmpty ? ExpandIcon(
                            padding: EdgeInsets.zero,
                            isExpanded: entry.isExpanded,
                            color: getExpandIconColor(),
                            onPressed: (value) => controller.toggleExpansion(entry.node),
                          ) : (data.node.isParentType > 0 ? IconButton(
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            color: getExpandIconColor(),
                            icon: Icon(Icons.remove),
                          ) : null),
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
                          child: IconButton(onPressed: () {}, icon: Icon(Icons.drag_handle), padding: EdgeInsets.symmetric(vertical: 0, horizontal: 8)),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double maxWidth = MediaQuery.of(context).size.width;
                              double width2 = 100;
                              double width3 = maxWidth * 0.3;
                              double width1 = constraints.maxWidth - width2 - width3 - 48 - 36;

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

                              late Widget valueChild;

                              if (data.node.type == NodeType.boolean) {
                                valueChild = DropdownButton<bool>(isDense: true, style: TextStyle(fontSize: fontSize), value: data.node.input as bool, items: [
                                  DropdownMenuItem(child: Text("True"), value: true),
                                  DropdownMenuItem(child: Text("False"), value: false),
                                ], onChanged: (value) {
                                  if (value == null) return;

                                  Change<bool> change = Change<bool>(
                                    data.node.input == true,
                                    () {
                                      data.node.input = value;
                                      setState(() {});
                                    },
                                    (old) {
                                      data.node.input = old;
                                      setState(() {});
                                    },
                                  );

                                  changes.add(change);
                                  setState(() {});
                                });
                              } else if (data.node.isParentType > 0) {
                                valueChild = SelectableText("${data.node.children.length} ${Word.fromCount(data.node.children.length, singular: Word("Child"), plural: Word("Children")).toString()}", style: TextStyle(fontSize: fontSize));
                              } else if (data.node.type == NodeType.empty) {
                                valueChild = Text("Null", style: TextStyle(fontSize: fontSize));
                              } else {
                                valueChild = Form(
                                  key: formControllers[data.id]!.key,
                                  child: TextFormField(
                                    controller: formControllers[data.id]!.controller,
                                    style: TextStyle(fontSize: fontSize),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      errorStyle: TextStyle(fontSize: fontSize - 3),
                                    ),
                                    onChanged: (source) {
                                      Logger.print("Editing complete");
                                      (formControllers[data.id]!.key.currentState as FormState).save();
                                    },
                                    onSaved: (source) {
                                      if (source == null) return;
                                      bool result = (formControllers[data.id]!.key.currentState as FormState).validate();
                                      if (result == false) return;

                                      var value = get(source);
                                      if (value == null) return;
                                      Logger.print("Found value of type ${value.runtimeType}...");

                                      var change = Change<Object?>(
                                        copy(data.node.input),
                                        () {
                                          Logger.print("Setting value... (text: $source) (value: ${value.runtimeType} ${value.hashCode})");
                                          data.node.input = get(source);
                                          refresh();
                                        },
                                        (value) {
                                          Logger.print("Setting value... (value: ${value.runtimeType} ${value.hashCode})");
                                          data.node.input = value;
                                          formControllers[data.id]?.controller.text = data.node.valueToString();
                                          refresh();
                                        },
                                      );

                                      changes.add(change);
                                      refresh();
                                    },
                                    validator: (value) {
                                      if (value == null) return "Value cannot be empty.";
                                      if (get(value) == null) return "Value is invalid.";
                                      return null;
                                    },
                                  ),
                                );
                              }

                              List<cm.ContextMenuEntry> contextMenuEntries = [
                                if (data.node.type == NodeType.array || data.node.type == NodeType.map)
                                cm.MenuItem(label: "New Child", icon: Icons.add, onSelected: () {
                                  Node newNode = Node(input: "New String");
                                  NodeData newData = data.node.type == NodeType.map ? NodeKeyValuePair(key: "New String", value: newNode) : newNode;

                                  var change = Change<String>(
                                    newData.id,
                                    () {
                                      data.children.add(newData);
                                      Logger.print("Added child ${newData.runtimeType} (currently ${entry.node.children.length} children)");
                                      refresh(rebuild: true);
                                    },
                                    (id) {
                                      data.children.removeWhere((x) => x.id == id);
                                      Logger.print("Removed child $id (currently ${entry.node.children.length} children)");
                                      refresh(rebuild: true);
                                    }
                                  );

                                  changes.add(change);
                                  refresh(rebuild: true);
                                }),
                                cm.MenuItem(label: "Delete", icon: Icons.delete, onSelected: () {
                                  AllNodeData? parent = data.parent;
                                  Logger.print("Found parent of type ${parent.runtimeType} from ID ${data.parent}");
                                  if (parent == null) return;

                                  int getIndex(List<NodeData> children) {
                                    return children.indexWhere((x) => x.id == data.id);
                                  }

                                  int index = getIndex(() {
                                    if (parent is NodeData) {
                                      return parent.children;
                                    } else if (parent is RootNode) {
                                      return parent.children;
                                    } else {
                                      throw UnimplementedError();
                                    }
                                  }());

                                  var change = Change<({AllNodeData parent, NodeData node, int index})>(
                                    (parent: parent, node: data, index: index),
                                    () {
                                      if (parent is NodeData) {
                                        parent.children.removeAt(index);
                                      } else if (parent is RootNode) {
                                        parent.children.removeAt(index);
                                      } else {
                                        return;
                                      }

                                      Logger.print("Removed child of ID ${data.id}");
                                    },
                                    (r) {
                                      if (parent is NodeData) {
                                        parent.children.insert(r.index, r.node);
                                      } else if (parent is RootNode) {
                                        parent.children.insert(r.index, r.node);
                                      } else {
                                        return;
                                      }

                                      Logger.print("Added child of ID ${r.node.id} at index ${r.index}");
                                    }
                                  );

                                  changes.add(change);
                                  refresh(rebuild: true);
                                })
                              ];

                              var contextMenu = cm.ContextMenu(entries: contextMenuEntries);

                              return TreeRowContainer(
                                id: data.id,
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
                                        child: valueChild,
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

                                        late void Function() change;
                                        late void Function(({Object? input, int parentType, Iterable<NodeData> children}) r) undo;

                                        var old = (
                                          input: copy(data.node.input),
                                          parentType: data.node.isParentType,
                                          children: List<NodeData>.from(data.children),
                                        );

                                        if (type == NodeType.map) {
                                          change = () {
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
                                            for (var child in children) data.node.children.add(child);
                                            refresh(rebuild: true);
                                          };
                                        } else if (type == NodeType.array) {
                                          change = () {
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
                                            for (var child in children) data.node.children.add(child);
                                            refresh(rebuild: true);
                                          };
                                        } else {
                                          change = () {
                                            data.node.isParentType = 0;
                                            data.node.children.clear();
                                            data.node.input = getDefaultValue(type);
                                            refresh(rebuild: true);
                                          };
                                        }

                                        undo = (r) {
                                          Logger.print("Restoring data: $r");
                                          data.node.isParentType = r.parentType;
                                          data.node.input = r.input;
                                          data.node.children.clear();

                                          for (var child in r.children) {
                                            data.node.children.add(child);
                                          }

                                          Logger.print("Now type ${data.node.type}:${data.node.isParentType} with ${data.node.children.length} children");
                                          refresh(rebuild: true);
                                        };

                                        var changeData = Change<({Object? input, int parentType, Iterable<NodeData> children})>(
                                          old,
                                          change,
                                          undo,
                                        );

                                        changes.add(changeData);
                                        Logger.print("Changing node to $type... (value of ${data.node.input}) (${[data.node.input.runtimeType, data.node.type, data.node.identify(debug: true), data.children.isEmpty].join(" - ")}) (${data.children.length} children)");
                                        refresh();
                                      }, value: data.node.type),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        return IconButton(onPressed: () async {
                                          var box = context.findRenderObject() as RenderBox;
                                          var pos = box.localToGlobal(Offset.zero);
                                          var previous = contextMenu.position == null ? null : Offset(contextMenu.position!.dx, contextMenu.position!.dy);
                                          contextMenu.position = pos;
                                          await contextMenu.show(context);
                                          contextMenu.position = previous;
                                        }, icon: Icon(Icons.more_vert), padding: EdgeInsets.zero);
                                      }
                                    ),
                                    Builder(
                                      builder: (context) {
                                        var parent = data.parent;
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
                                          var change = Change<(int index, int factor, NodeData data)>(
                                            (index, factor, data),
                                            () {
                                              children.removeAt(index);
                                              children.insert(index - factor, data);
                                            },
                                            (data) {
                                              children.removeAt(data.$1 - data.$2);
                                              children.insert(data.$1, data.$3);
                                            }
                                          );

                                          changes.add(change);
                                          refresh(rebuild: true);
                                        }

                                        return MoveUpDownWidget(onMoveUp: index == 0 ? null : (context) => move(1), onMoveDown: index == children.length - 1 ? null : (context) => move(-1), id: data.id);
                                      },
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
            }
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
  final String id;
  const TreeRowContainer({super.key, required this.child, required this.id});

  @override
  State<TreeRowContainer> createState() => _TreeRowContainerState();
}

class _TreeRowContainerState extends State<TreeRowContainer> {
  bool hover = false;
  StreamSubscription? subscription;

  void set(bool status) {
    hover = status;
    setState(() {});
  }

  @override
  void initState() {
    subscription = moveUpDownWidgetsChanged.stream.listen((_) => setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color = Colors.transparent;
    bool moveUpDownWidgetIsShown = moveUpDownWidgets.where((x) => x.isShown).any((x) => x.id == widget.id);

    if (moveUpDownWidgetIsShown) {
      color = Theme.of(context).brightness == Brightness.light ? const Color.fromARGB(255, 202, 202, 202) : const Color.fromARGB(255, 26, 35, 46);
    }

    if (hover) {
      color = Theme.of(context).brightness == Brightness.light ? const Color.fromARGB(255, 231, 231, 231) : const Color.fromARGB(255, 43, 57, 75);
    }

    return MouseRegion(
      onEnter: (event) => set(true),
      onExit: (event) => set(false),
      child: Container(
        color: color,
        padding: EdgeInsets.symmetric(vertical: 0),
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
  final String id;

  late final _MoveUpDownWidgetState _state;
  MoveUpDownWidget({super.key, required this.id, required this.onMoveUp, required this.onMoveDown, this.showOnEnter = true, this.hideAllOnContact = true});

  @override
  State<MoveUpDownWidget> createState() => _state = _MoveUpDownWidgetState();

  bool get isShown => _state.isShown;

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
  bool isShown = false;

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
    Logger.verbose("Showing...");
    isShown = true;

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
            WidgetsBinding.instance.addPostFrameCallback((d) => show());
          }, icon: Icon(Icons.arrow_upward)),
          IconButton(onPressed: () {
            hide();
          }, icon: Icon(Icons.cancel_outlined)),
          if (widget.onMoveDown != null)
          IconButton(onPressed: () {
            hide();
            widget.onMoveDown!.call(context);
            WidgetsBinding.instance.addPostFrameCallback((d) => show());
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
            offset: Offset(-40, -56 + ((3 - elements) * 12)),
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
    moveUpDownWidgetsChanged.sink.add(null);
  }

  void hide() {
    if (entry == null) return;
    Logger.verbose("Hiding entry of type ${entry.runtimeType}...");
    isShown = false;
    entry?.remove();
    entry = null;
    isCurrentlyShowingMoveUpDownOverlay = false;
    moveUpDownWidgetsChanged.sink.add(null);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        if (widget.showOnEnter) show();
      },
      child: CompositedTransformTarget(
        link: link,
        child: IconButton(
          onPressed: () => show(),
          icon: getIcon(),
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
        ),
      ),
    );
  }

  Widget getIcon() {
    double size = 14;

    return Center(
      child: Column(
        children: [
          SizedBox(child: Icon(Icons.arrow_upward, size: size), height: size - 5),
          SizedBox(child: Icon(Icons.arrow_downward, size: size), height: size - 5),
        ],
      ),
    );
  }
}