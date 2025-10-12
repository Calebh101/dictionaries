import 'package:dictionaries/src/main.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dictionaries/lib/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';
import 'package:localpkg/dialogue.dart';

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
              Positioned(
                top: 0,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () {
                      if (text == null) return;
                      Clipboard.setData(ClipboardData(text: text));
                      SnackBarManager.show(context, "Copied ${text.split("\n").length} lines!");
                    }, icon: Icon(Icons.copy))
                  ],
                ),
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
                    theme: Theme.of(context).brightness == Brightness.dark ? gruvboxDarkTheme : atomOneLightTheme,
                    padding: const EdgeInsets.all(12),
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