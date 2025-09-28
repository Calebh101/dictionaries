import 'package:flutter/material.dart';

enum ObjectEditorTabType {
  base,
  json,
  yaml,
  plist,
  settings,
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

Widget objectEditorTabTypeContent(ObjectEditorTabType input) {}

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
}