import 'package:dictionaries/object/main.dart';
import 'package:dictionaries/object/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

class ObjectEditorPreview extends StatefulWidget {
  final DataType type;
  final RootNode root;
  const ObjectEditorPreview({super.key, required this.type, required this.root});

  @override
  State<ObjectEditorPreview> createState() => _ObjectEditorPreviewState();
}

class _ObjectEditorPreviewState extends State<ObjectEditorPreview> {
  ScrollController scrollController = ScrollController();
  ScrollController horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    String? text = compileByType(widget.type, widget.root);

    return SizedBox(
      width: screen.width,
      height: screen.height,
      child: Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        controller: scrollController,
        notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
        child: Scrollbar(
          thumbVisibility: true,
          trackVisibility: true,
          controller: horizontalScrollController,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
          child: Stack(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () {
                    if (text == null) return;
                    Clipboard.setData(ClipboardData(text: text));
                  }, icon: Icon(Icons.copy))
                ],
              ),
              text != null ? SingleChildScrollView(
                scrollDirection: Axis.vertical,
                controller: scrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: horizontalScrollController,
                  child: HighlightView(
                    text,
                    language: dataTypeToLanguage(widget.type),
                    theme: Theme.of(context).brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme,
                    padding: const EdgeInsets.all(12),
                    textStyle: const TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 16,
                    ),
                  ),
                ),
              ) : Text("No preview available."),
            ],
          ),
        ),
      ),
    );
  }
}