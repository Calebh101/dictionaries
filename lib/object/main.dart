import 'package:dictionaries/object/editor.dart';
import 'package:dictionaries/object/nodes.dart';
import 'package:dictionaries/object/preview.dart';
import 'package:flutter/material.dart';

enum DataType {
  json,
  yaml,
  plist,
}

enum ObjectEditorTabType {
  base,
  json,
  yaml,
  plist,
  settings,
}

String dataTypeToLanguage(DataType input) {
  switch (input) {
    case DataType.json: return "json";
    case DataType.yaml: return "yaml";
    case DataType.plist: return "xml";
  }
}

String dataTypeToPrettyString(DataType input) {
  switch (input) {
    case DataType.json: return "JSON";
    case DataType.yaml: return "YAML";
    case DataType.plist: return "PList";
  }
}

ObjectEditorTabType dataTypeToObjectEditorTabType(DataType input) {
  switch (input) {
    case DataType.json: return ObjectEditorTabType.json;
    case DataType.yaml: return ObjectEditorTabType.yaml;
    case DataType.plist: return ObjectEditorTabType.plist;
  }
}

String? compileByType(DataType type, RootNode root) {
  switch (type) {
    case DataType.json: return root.toJsonString();
    case DataType.yaml: return root.toYamlString();
    case DataType.plist: return root.toPlistString();
  }
}

class ObjectEditorPage extends StatefulWidget {
  final RootNode root;
  const ObjectEditorPage({super.key, required this.root});

  @override
  State<ObjectEditorPage> createState() => _ObjectEditorPageState();
}

class _ObjectEditorPageState extends State<ObjectEditorPage> {
  late RootNode root;
  List<ObjectEditorTabType> tabs = [ObjectEditorTabType.base, ObjectEditorTabType.settings];

  @override
  void initState() {
    root = widget.root;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(["Dictionaries"].join(" - ")),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(50),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    tabs: [
                      ...List.generate(tabs.length, (i) {
                        ObjectEditorTabType type = tabs[i];
                    
                        return Center(
                          child: objectEditorTabTypeToWidget(type),
                        );
                      }),
                    ].map((x) => Padding(
                      padding: EdgeInsetsGeometry.all(8),
                      child: x,
                    )).toList(), isScrollable: false,
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
                      tabs.add(dataTypeToObjectEditorTabType(value));
                      setState(() {});
                    }
                  }),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(physics: NeverScrollableScrollPhysics(), children: [
          ...List.generate(tabs.length, (i) {
            ObjectEditorTabType type = tabs[i];
        
            return Center(
              child: objectEditorTabTypeContent(context, type, widget.root),
            );
          }),
        ]),
      ),
    );
  }

  Widget objectEditorTabTypeToWidget(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.base: return Icon(Icons.edit);
      case ObjectEditorTabType.json: return Text("JSON");
      case ObjectEditorTabType.yaml: return Text("YAML");
      case ObjectEditorTabType.plist: return Text("PList");
      case ObjectEditorTabType.settings: return Icon(Icons.settings);
    }
  }

  DataType? objectEditorTabTypeToObjectType(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.json: return DataType.json;
      case ObjectEditorTabType.yaml: return DataType.yaml;
      case ObjectEditorTabType.plist: return DataType.plist;
      default: return null;
    }
  }

  Widget objectEditorTabTypeContent(BuildContext context, ObjectEditorTabType objectEditorTabType, RootNode root) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.base: return ObjectEditorDesktop(root: widget.root);
      case ObjectEditorTabType.settings: return ObjectEditorSettings();

      default: 
        DataType? type = objectEditorTabTypeToObjectType(objectEditorTabType);
        if (type == null) throw Exception("Invalid editor type: $objectEditorTabType");
        return ObjectEditorPreview(type: type, root: root);
    }
  }
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