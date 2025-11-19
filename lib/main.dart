import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dictionaries/src/addons.dart';
import 'package:dictionaries/src/editor.dart';
import 'package:dictionaries/src/main.dart';
import 'package:dictionaries/src/nodes.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:localpkg_flutter/localpkg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:dictionaries/files/files.dart';

final Version version = Version.parse("0.0.0A");
final Version binaryVersion = Version.parse("1.0.0A");

Uri? sourceUri;

Future<void> main() async {
  if (kDebugMode) Logger.enable();
  if (kDebugMode) Logger.setVerbose(true);

  Logger.print("Found application directory as ${(await maindir).path}");
  if (Addon.enabled) Addon.init();
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
      title: "Dictionaries",
    );
  }
}

abstract class HomeNode {
  final String text;
  final String description;
  final IconData? icon;
  final Widget? child;
  final int id;

  static int _currentId = 0;
  HomeNode({required this.text, required this.description, this.icon, this.child}) : id = _currentId++;
}

class HomeOption extends HomeNode {
  final Future<void> Function() onActivate;
  HomeOption(String text, {required super.description, super.icon, super.child, required this.onActivate}) : super(text: text);
}

class HomeMenu extends HomeNode {
  final List<HomeOption> options;
  HomeMenu(String text, {required super.description, required this.options, super.icon, super.child}) : super(text: text);
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const int download_loading = 0x100;

  int status = 0; // I'm a nerd, so we're using bitwise operators for this
  TextEditingController urlController = TextEditingController();

  bool flagSet(int flag) {
    return (status & flag) != 0;
  }

  void setFlags(List<int> flags) {
    setState(() => flags.forEach((flag) => status |= flag));
  }

  bool activateEditor(Uint8List raw, EditorSource source) {
    Widget? widget = decideEditor(raw, source);
    if (widget == null) return SnackBarManager.show(context, "Invalid file type.").thenReturn(false);
    SimpleNavigator.navigate(context: context, page: EditorMainPage(child: widget), mode: NavigatorMode.pushReplacement);
    return true;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (ScreenTooSmallWidget.compare(context) == false) {
      return ScreenTooSmallWidget();
    }

    List<HomeNode> children = [
      HomeOption("Create", description: "Create a new dictionary.", icon: Icons.add, onActivate: () async {
        activateEditor(utf8.encode(jsonEncode({})), EditorSource.created);
      }),
      HomeMenu("Upload", description: "Upload an existing dictionary.", icon: Icons.upload, child: flagSet(download_loading) ? CircularProgressIndicator() : null, options: [
        HomeOption("Upload from File", description: "Upload an existing dictionary from a file.", icon: Icons.upload, onActivate: () async {
          var result = await FilePicker.platform.pickFiles(withData: true);
          SnackBarManager.show(context, "Loading...");
          Uint8List? bytes = result?.files.firstOrNull?.bytes;
          if (bytes == null || bytes.isEmpty) return;
          activateEditor(bytes, EditorSource.local);
        }),
        HomeOption("Download from Online", description: "Download an existing dictionary to import.", icon: Icons.download, child: flagSet(download_loading) ? CircularProgressIndicator() : null, onActivate: () async {
          if (flagSet(download_loading)) return;

          String? path = await showDialog<String>(
            context: context,
            builder: (context) {
              return AlertDialog(
                icon: Icon(Icons.link),
                title: Text("Download from URL"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: urlController,
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () {
                    Navigator.of(context).pop();
                  }, child: Text("Cancel")),
                  TextButton(onPressed: () {
                    Navigator.of(context).pop(urlController.text);
                  }, child: Text("Done")),
                ],
              );
            },
          );

          if (path == null) return;
          Uri? url = Uri.tryParse(path);
          if (url == null) return SnackBarManager.show(context, "Invalid URL.").toVoid();
          sourceUri = url;

          SnackBarManager.show(context, "Loading...");
          setFlags([download_loading]);
          setState(() {});

          try {
            var response = await http.get(url);
            if (!(response.statusCode >= 200 && response.statusCode < 300)) throw Exception("Invalid status code: ${response.statusCode}");
            var bytes = response.bodyBytes;
            if (bytes.isEmpty) throw Exception("No data was received.");
            activateEditor(bytes, EditorSource.online);
          } catch (e) {
            Logger.warn("Unable to download file: $e");
            SnackBarManager.show(context, "Unable to download file: $e");
          }
        }),
      ]),
    ];

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Text("Welcome to Dictionaries!", style: TextStyle(fontSize: 48)),
            Text("Dictionaries is a tool to view and edit data files like JSON, YAML, and more in a user-friendly and intuitive tree view."),
            Text("Dictionaries includes lots of user-friendly functions to help with managing these different data types."),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(children.length, (i) {
                HomeNode child = children[i];
                double size = 48;

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Tooltip(
                    message: child.description,
                    child: ElevatedButton(onPressed: () async {
                      Logger.print("Activated button of type ${child.runtimeType}: ${child.text}");

                      if (child is HomeOption) {
                        Logger.print("Starting function ${child.id}...");
                        child.onActivate.call();
                      } else if (child is HomeMenu) {
                        var result = await showMenu<int>(context: context, positionBuilder: (context, constraints) {
                          double x = constraints.maxWidth / 2;
                          double y = constraints.maxHeight / 2;
                          return RelativeRect.fromLTRB(x, y, x, y);
                        }, items: child.options.map((item) {
                          return PopupMenuItem(
                            value: item.id,
                            child: Row(
                              children: [
                                item.child != null ? Padding(
                                  padding: EdgeInsets.all(0),
                                  child: SizedBox(
                                    width: size,
                                    height: size,
                                    child: item.child,
                                  ),
                                ) : (item.icon != null ? Icon(item.icon, size: size) : null),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(item.text),
                                      Text(item.description, style: TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ].whereType<Widget>().toList(),
                            ),
                          );
                        }).whereType<PopupMenuItem<int>>().toList());

                        HomeNode? widget = child.options.firstWhereOrNull((x) => x.id == result);
                        Logger.print("Got result of $result (${result.runtimeType}) of type ${widget.runtimeType}");
                        if (widget == null) return;
                        if (widget is! HomeOption) throw UnimplementedError();
                        Logger.print("Starting function ${child.id}:${widget.id}...");
                        widget.onActivate.call();
                      }
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
            Spacer(),
            Spacer(),
            ...(() {
              String delim = " • ";
              double? fontSize = 12;

              return [
                Text(["Made by Calebh101", "Version $version"].join(delim), style: TextStyle(fontSize: fontSize)),
                if (version.isBeta)
                Text(["This is a beta version of Dictionaries. Use at your own risk."].join(delim), style: TextStyle(fontSize: fontSize)),
              ];
            })(),
          ],
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

Widget? decideEditor(Uint8List raw, EditorSource source) {
  var root = RootNode.tryParse(raw);
  if (root == null) return null;
  return ObjectEditorPage(root: root, source: source);
}

({bool value, String string}) returnRecord() {
  final record = (value: true, string: "yes");
  return record;
}

class ScreenTooSmallWidget extends StatefulWidget {
  const ScreenTooSmallWidget({super.key});
  static const threshold = Size(600, 400);

  /// True if the screen is big enough.
  static bool compare(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return screen.width > threshold.width && screen.height > threshold.height;
  }

  @override
  State<ScreenTooSmallWidget> createState() => _ScreenTooSmallWidgetState();
}

class _ScreenTooSmallWidgetState extends State<ScreenTooSmallWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Uh oh!", style: TextStyle(fontSize: 48)),
              Text("Your screen is too small! This application needs a larger screen to operate correctly.", softWrap: true),
              Text("However, you can still convert your file to a Dictionary."),
              TextButton(onPressed: () async {
                Logger.print("Starting upload...");
                var result = await FilePicker.platform.pickFiles(withData: true);
                Uint8List? bytes = result?.files.firstOrNull?.bytes;
                Logger.print("Found ${bytes?.length ?? -1} bytes");
                if (bytes == null || bytes.isEmpty) return;

                var root = RootNode.tryParse(bytes);
                if (root == null) return SnackBarManager.show(context, "Unable to parse file.").toVoid();

                var binary = root.toBinary();
                Logger.print("Found binary of ${binary.length} bytes, saving...");
                List<String> name = (result?.names.firstOrNull ?? "MyDictionary").split(".");
                bool saved = await saveFile(name: name.sublist(0, name.length - 1).join("."), bytes: binary, mime: "application/c-dict", extension: "dictionary");

                if (saved) {
                  Logger.print("File saved.");
                  SnackBarManager.show(context, "File saved!");
                } else {
                  Logger.warn("File not saved.");
                  SnackBarManager.show(context, "Unable to save file.");
                }
              }, child: Text("Convert to Dictionary")),
            ],
          ),
        ),
      ),
    );
  }
}

bool debug(void Function() function) {
  Logger.print("Debug: Running function ${function.hashCode}...");

  try {
    function.call();
    return true;
  } catch (e) {
    Logger.warn("Debug: Function ${function.hashCode} failed: $e");
    return false;
  }
}

Object? copy(Object? input) {
  if (input is DateTime) {
    return input.copyWith();
  } else if (input is Uint8List) {
    return Uint8List.fromList(input);
  } else {
    return input;
  }
}

String? getFileNameFromResponse(http.Response response) {
  final contentDisposition = response.headers['content-disposition'];
  if (contentDisposition == null) return null;

  final regex = RegExp(r'filename="?([^"]+)"?');
  final match = regex.firstMatch(contentDisposition);
  return match?.group(1);
}

Future<Directory> get maindir async => (await getApplicationSupportDirectory())..create(recursive: true);