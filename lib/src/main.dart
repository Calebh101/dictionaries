import 'package:dictionaries/src/editor.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:dictionaries/src/preview.dart';
import 'package:dictionaries/tabview.dart';
import 'package:flutter/material.dart';

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
  UserFocusedTabViewController<ObjectEditorTabType>? controller;
  List<UserFocusedTab<ObjectEditorTabType>> tabs = [];
  int currentIndex = 0;

  @override
  void initState() {
    root = widget.root;
    tabs = [ObjectEditorTabType.base, ObjectEditorTabType.settings].map((x) => UserFocusedTab<ObjectEditorTabType>(attachment: x, child: objectEditorTabTypeContent(context, x, root), thumbnail: objectEditorTabTypeToWidget(x), reorderable: false)).toList();
    controller = UserFocusedTabViewController(tabs);
    super.initState();
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
              UserFocusedTabView(
                borderRadius: 12,
                reorderable: true,
                controller: controller!,
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
                    controller!.addTab(UserFocusedTab(child: objectEditorTabTypeContent(context, type, root), thumbnail: objectEditorTabTypeToWidget(type), attachment: type, showCloseButton: true));
                  }
                }),
              ),
            ],
          ),
        ),
      ),
      body: UserFocusedTabViewContent(controller: controller!),
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