// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:dictionaries/object/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/functions.dart';
import 'package:styled_logger/styled_logger.dart';

final Version version = Version.parse("0.0.0A");

void main() {
  if (kDebugMode) Logger.enable();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: Home(),
    );
  }
}

class HomeOption {
  final String text;
  final String description;
  final IconData? icon;
  final Widget? child;
  final Future<void> Function() onActivate;

  const HomeOption(this.text, {required this.description, this.icon, this.child, required this.onActivate});
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const int download_loading = 0x100;

  int status = 0; // I'm a nerd, so we're using bitwise operators for this

  bool flagSet(int flag) {
    return (status & flag) != 0;
  }

  void setFlags(List<int> flags) {
    setState(() {
      for (int flag in flags) status |= flag;
    });
  }

  bool activateEditor(String raw) {
    Widget? widget = decideEditor(raw);
    if (widget == null) return SnackBarManager.show(context, "Invalid file type.").thenReturn(false);
    SimpleNavigator.navigate(context: context, page: EditorMainPage(child: widget));
    return true;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<HomeOption> children = [
      HomeOption("New", description: "Create a new dictionary.", icon: Icons.add, onActivate: () async {
        activateEditor(jsonEncode({
          "test1": {
            "test2": [
              "test3",
              4,
              {
                "test5": "test6",
              },
              [
                "test7",
                8,
                true,
              ]
            ],
            "test8": {
              "test9": 10,
              "test11": false,
            },
          }
        }));
      }),
      HomeOption("Upload", description: "Upload an existing dictionary.", icon: Icons.upload, onActivate: () async {}),
      HomeOption("Download", description: "Download an existing dictionary.", icon: Icons.download, child: flagSet(download_loading) ? CircularProgressIndicator() : null, onActivate: () async {
        if (flagSet(download_loading)) return;
      }),
    ];

    return Scaffold(
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(children.length, (i) {
            HomeOption child = children[i];
            double size = 48;
      
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Tooltip(
                message: child.description,
                child: ElevatedButton(onPressed: () {
                  Logger.print("Activated button: ${child.text}");
                  child.onActivate.call();
                }, child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      child.child != null ? Padding(
                        padding: EdgeInsets.all(0),
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: child.child,
                        ),
                      ) : (child.icon != null ? Icon(child.icon, size: size) : null),
                      Text(child.text),
                    ].whereType<Widget>().toList(),
                  ),
                )),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class EditorMainPage extends StatefulWidget {
  final Widget child;
  const EditorMainPage({super.key, required this.child});

  @override
  State<EditorMainPage> createState() => _EditorMainPageState();
}

class _EditorMainPageState extends State<EditorMainPage> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

Widget? decideEditor(String raw) {
  return ObjectEditorPage(value: jsonDecode(raw));
}