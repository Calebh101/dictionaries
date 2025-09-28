import 'package:flutter/material.dart';

enum ObjectType {
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

class ObjectEditorPage extends StatefulWidget {
  final Map value;
  const ObjectEditorPage({super.key, required this.value});

  @override
  State<ObjectEditorPage> createState() => _ObjectEditorPageState();
}

class _ObjectEditorPageState extends State<ObjectEditorPage> {
  late Map value;
  List<ObjectEditorTabType> tabs = [ObjectEditorTabType.base, ObjectEditorTabType.settings];

  @override
  void initState() {
    value = widget.value;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length + 1,
      child: Scaffold(
        appBar: AppBar(
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
                  child: IconButton(onPressed: () {}, icon: Icon(Icons.add)),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(children: [
          ...List.generate(tabs.length, (i) {
            ObjectEditorTabType type = tabs[i];
        
            return Center(
              child: objectEditorTabTypeToWidget(type),
            );
          }),
        ]),
      ),
    );
  }

  Widget objectEditorTabTypeToWidget(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.base: return Text("Editor");
      case ObjectEditorTabType.json: return Text("JSON");
      case ObjectEditorTabType.yaml: return Text("YAML");
      case ObjectEditorTabType.plist: return Text("PList");
      case ObjectEditorTabType.settings: return Icon(Icons.settings);
    }
  }

  ObjectType? objectEditorTabTypeToObjectType(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.json: return ObjectType.json;
      case ObjectEditorTabType.yaml: return ObjectType.yaml;
      case ObjectEditorTabType.plist: return ObjectType.plist;
      default: return null;
    }
  }

  Widget objectEditorTabTypeContent(ObjectEditorTabType objectEditorTabType) {
    switch (objectEditorTabType) {
      case ObjectEditorTabType.base: return ObjectEditor();
      case ObjectEditorTabType.settings: return ObjectEditorSettings();

      default: 
        ObjectType? type = objectEditorTabTypeToObjectType(objectEditorTabType);
        if (type == null) throw Exception("Invalid editor type: $objectEditorTabType");
        return ObjectEditorPreview(type: type);
    }
  }
}

class ObjectEditor extends StatefulWidget {
  const ObjectEditor({super.key});

  @override
  State<ObjectEditor> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditor> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ObjectEditorPreview extends StatefulWidget {
  final ObjectType type;
  const ObjectEditorPreview({super.key, required this.type});

  @override
  State<ObjectEditorPreview> createState() => _ObjectEditorPreviewState();
}

class _ObjectEditorPreviewState extends State<ObjectEditorPreview> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
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