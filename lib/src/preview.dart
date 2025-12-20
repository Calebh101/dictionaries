import 'package:dictionaries/src/main.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dictionaries/lib/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';

class PreviewSettings {
  final int tabLength;
  final bool pretty;
  final bool plistExportNulls;

  const PreviewSettings({this.tabLength = 2, this.pretty = true, this.plistExportNulls = false});
}

class ObjectEditorPreview extends StatefulWidget {
  final DataType type;
  final RootNode root;
  const ObjectEditorPreview({super.key, required this.type, required this.root});

  @override
  State<ObjectEditorPreview> createState() => _ObjectEditorPreviewState();
}

class _ObjectEditorPreviewState extends State<ObjectEditorPreview> {
  ScrollController verticalScrollController = ScrollController();
  ScrollController horizontalScrollController = ScrollController();
  String? text;
  PreviewSettings settings = PreviewSettings();

  @override
  void initState() {
    compile();
    super.initState();
  }

  void compile() {
    text = compileByType(widget.type, widget.root, settings);
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLight = !isDark;

    if (text == null) {
      return Center(
        child: Text("No preview available."),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dataTypeToPrettyString(widget.type)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {
            Clipboard.setData(ClipboardData(text: text!));
          }, icon: Icon(Icons.copy)),
          IconButton(onPressed: () {
            compile();
            setState(() {});
          }, icon: Icon(Icons.refresh)),
        ],
      ),
      body: Scrollbar(
        controller: verticalScrollController,
        child: SingleChildScrollView(
          controller: verticalScrollController,
          child: Scrollbar(
            controller: horizontalScrollController,
            notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 4,
                ),
                child: HighlightView(
                  text!,
                  language: dataTypeToLanguage(widget.type),
                  theme: isLight ? atomOneLightTheme : gruvboxDarkTheme,
                  padding: EdgeInsets.all(12),
                  textStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}