import 'package:dictionaries/src/editor.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:dictionaries/src/preview.dart';
import 'package:flutter/material.dart';
import 'package:dictionaries/lib/reorderable_tabbar.dart';
import 'package:styled_logger/styled_logger.dart';

enum DataType {
  json,
  yaml,
  plist,
  xml,
}

enum ObjectEditorTabType {
  base,
  json,
  yaml,
  plist,
  xml,
  settings,
}

String dataTypeToLanguage(DataType input) {
  switch (input) {
    case DataType.json: return "json";
    case DataType.yaml: return "yaml";
    case DataType.plist: return "xml";
    case DataType.xml: return "xml";
  }
}

String dataTypeToPrettyString(DataType input) {
  switch (input) {
    case DataType.json: return "JSON";
    case DataType.yaml: return "YAML";
    case DataType.plist: return "PList";
    case DataType.xml: return "XML";
  }
}

ObjectEditorTabType dataTypeToObjectEditorTabType(DataType input) {
  switch (input) {
    case DataType.json: return ObjectEditorTabType.json;
    case DataType.yaml: return ObjectEditorTabType.yaml;
    case DataType.plist: return ObjectEditorTabType.plist;
    case DataType.xml: return ObjectEditorTabType.xml;
  }
}

String? compileByType(DataType type, RootNode root) {
  switch (type) {
    case DataType.json: return root.toJsonString();
    case DataType.yaml: return root.toYamlString();
    case DataType.plist: return root.toPlistString();
    case DataType.xml: return root.toXmlString();
  }
}

class ObjectEditorPage extends StatefulWidget {
  final RootNode root;
  const ObjectEditorPage({super.key, required this.root});

  @override
  State<ObjectEditorPage> createState() => _ObjectEditorPageState();
}

class _ObjectEditorPageState extends State<ObjectEditorPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late RootNode root;
  TabController? controller;
  List<({ObjectEditorTabType type, Widget content})> tabs = [];
  int currentIndex = 0;

  @override
  void initState() {
    root = widget.root;
    tabs = [ObjectEditorTabType.base, ObjectEditorTabType.settings].map((x) => (type: x, content: objectEditorTabTypeContent(context, x, root))).toList();
    initTabController();
    super.initState();
  }

  void initTabController() {
    currentIndex = controller?.index ?? currentIndex;
    controller?.dispose();
    controller = TabController(length: tabs.length, vsync: this);
    navigate(currentIndex);
  }

  void navigate(int index) {
    if (index + 1 > (controller?.length ?? 0)) index = (controller?.length ?? 1) - 1;
    currentIndex = index;
    Logger.print("Navigating to tab ${index + 1}/${controller?.length ?? 0}...");
    controller?.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(["Dictionaries"].join(" - ")),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Row(
            children: [
              Expanded(
                child: ReorderableTabBar(
                  controller: controller,
                  buildDefaultDragHandles: false,
                  isScrollable: true,
                  tabBorderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  onReorder: (oldIndex, newIndex) {
                    var tab = tabs[oldIndex];
                    if (tab is! ObjectEditorPreview) return;

                    while (tabs[newIndex] is! ObjectEditorPreview) {
                      newIndex++;
                      if (newIndex + 1 > tabs.length) return;
                    }

                    tabs.removeAt(oldIndex);
                    tabs.insert(newIndex, tab);
                    setState(() {});
                  },
                  tabs: [
                    ...List.generate(tabs.length, (i) {
                      var child = tabs[i];
                      bool preview = child is ObjectEditorPreview;
                  
                      return Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            objectEditorTabTypeToWidget(child.type),
                            if (preview) ...[
                              SizedBox(width: 8),
                              IconButton(onPressed: () {
                                if (tabs.indexOf(child) == controller!.index) navigate(controller!.index - 1);
                                tabs.remove(child);
                                initTabController();
                                setState(() {});
                              }, icon: Icon(Icons.cancel_outlined)),
                            ],
                          ],
                        ),
                      );
                    }),
                  ].map((x) => Padding(
                    padding: EdgeInsetsGeometry.all(8),
                    child: x,
                  )).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: PopupMenuButton<Object>(icon: Icon(Icons.add), itemBuilder: (context) {
                  return [
                    ...List.generate(DataType.values.length, (i) {
                      DataType type = DataType.values[i];
    
                      return PopupMenuItem(
                        value: type,
                        child: Text("${dataTypeToPrettyString(type)} Preview"),
                      );
                    })
                  ];
                }, onSelected: (value) {
                  if (value is DataType) {
                    var type = dataTypeToObjectEditorTabType(value);
                    tabs.add((type: type, content: objectEditorTabTypeContent(context, type, root)));
                    initTabController();
                    setState(() {});
                    navigate(tabs.length - 1);
                  }
                }),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(physics: NeverScrollableScrollPhysics(), controller: controller, children: [
        ...List.generate(tabs.length, (i) {
          var child = tabs[i];
      
          return Center(
            child: child.content,
          );
        }),
      ]),
    );
  }

  Widget objectEditorTabTypeToWidget(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.base: return Icon(Icons.edit);
      case ObjectEditorTabType.json: return Text("JSON");
      case ObjectEditorTabType.yaml: return Text("YAML");
      case ObjectEditorTabType.plist: return Text("PList");
      case ObjectEditorTabType.xml: return Text("XML");
      case ObjectEditorTabType.settings: return Icon(Icons.settings);
    }
  }

  DataType? objectEditorTabTypeToObjectType(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.json: return DataType.json;
      case ObjectEditorTabType.yaml: return DataType.yaml;
      case ObjectEditorTabType.plist: return DataType.plist;
      case ObjectEditorTabType.xml: return DataType.xml;
      default: return null;
    }
  }

  Widget objectEditorTabTypeContent(BuildContext context, ObjectEditorTabType objectEditorTabType, RootNode root) {
    RootNode.assignInstance(widget.root);
    
    switch (objectEditorTabType) {
      case ObjectEditorTabType.base: return ObjectEditorDesktop(key: ValueKey('tab.base'));
      case ObjectEditorTabType.settings: return ObjectEditorSettings(key: ValueKey('tab.settings'));

      default: 
        DataType? type = objectEditorTabTypeToObjectType(objectEditorTabType);
        if (type == null) throw Exception("Invalid editor type: $objectEditorTabType");
        return ObjectEditorPreview(type: type, root: root, key: ValueKey("tab.${type.name}"));
    }
  }

  bool isObjectEditorTabTypePreview(ObjectEditorTabType objectEditorTabType) {
    return objectEditorTabType == ObjectEditorTabType.json || objectEditorTabType == ObjectEditorTabType.yaml || objectEditorTabType == ObjectEditorTabType.plist;
  }
  
  @override
  bool get wantKeepAlive => true;
}

class ObjectEditorSettings extends StatefulWidget {
  const ObjectEditorSettings({super.key});

  @override
  State<ObjectEditorSettings> createState() => _ObjectEditorSettingsState();
}

class _ObjectEditorSettingsState extends State<ObjectEditorSettings> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}