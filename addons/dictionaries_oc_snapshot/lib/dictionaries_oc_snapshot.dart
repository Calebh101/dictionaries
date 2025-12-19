import 'dart:async';
import 'dart:io';

import 'package:dictionaries/addons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oc_snapshot/oc_snapshot.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

late bool forceUpdateSchema;
OpenCoreVersion? openCoreVersion;

DictionariesAddon load() {
  return OcSnapshotAddon();
}

void showSnackBar(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

void snapshot(BuildContext context, bool clean) async {
  final data = RootNode.instance.toJson();
  if (data is! Map) return;
  String? selected = await FilePicker.platform.getDirectoryPath(dialogTitle: "Select your OC Folder");
  if (!context.mounted) return;
  Directory directory = Directory(selected ?? "");

  if (!directory.existsSync()) {
    showSnackBar(context, "Invalid OC folder.");
    return;
  }

  while (true) {
    if (!context.mounted) return;
    File opencore = File(p.join(directory.path, "OpenCore.efi"));
    Directory oc = Directory(p.join(directory.path, "OC"));

    Directory acpi = Directory(p.join(directory.path, "ACPI"));
    Directory kexts = Directory(p.join(directory.path, "Kexts"));
    Directory drivers = Directory(p.join(directory.path, "Drivers"));
    Directory tools = Directory(p.join(directory.path, "Tools"));

    if ([acpi, kexts, drivers, tools].any((x) => !x.existsSync())) {
      if (oc.existsSync()) {
        AddonLogger.print("Subfolder OC detected, rebasing there...");
        directory = oc;
        continue;
      } else {
        AddonLogger.print("Either ACPI, Kexts, Drivers, or Tools doesn't exist in OC folder");
        showSnackBar(context, "Either ACPI, Kexts, Drivers, or Tools doesn't exist in your OC folder.");
        break;
      }
    }

    if (!opencore.existsSync()) {
      AddonLogger.print("OpenCore.efi doesn't exist, ignoring.");
    }

    final result = OCSnapshot.snapshot(data, files: (acpi: OCSnapshot.listDirectory(acpi), kexts: OCSnapshot.listKexts(kexts), drivers: OCSnapshot.listDirectory(drivers), tools: OCSnapshot.listDirectory(tools)), opencoreVersion: openCoreVersion, opencoreHash: opencore.existsSync() ? await hash(opencore) : null, clean: clean, forceUpdateSchema: forceUpdateSchema, onLog: AddonLogger.print);

    RootNode.instance.reapply(result, null);
    AddonLogger.print("Returned from snapshotting");
    if (!context.mounted) return;
    showSnackBar(context, "Done snapshotting!");
    break;
  }
}

Future<String> hash(File file) async {
  final stream = file.openRead();
  final hash = await md5.bind(stream).first;
  return hash.toString();
}

class OcSnapshotAddon extends DictionariesAddon {
  OcSnapshotAddon() : super(
    name: "OC Snapshot",
    description: "A port of CorpNewt's OC Snapshot feature from ProperTree.",
    mainpage: Uri.parse("https://github.com/Calebh101/oc_snapshot"),
    id: "com.calebh101.oc_snapshot",
    version: "0.0.1A",
    authors: ["Calebh101"],
    doNotShow: false,
  );

  @override
  FutureOr<void> onRegister(bool debug) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    forceUpdateSchema = prefs.getBool("forceUpdateSchema") ?? false;

    if (!kIsWeb) {
      DictionariesMenuBarInjection(["File"], [
        DictionariesMenuBarEntry.divider("OCSnapshotDivider"),
        DictionariesMenuBarEntry("OC Snapshot", onActivate: (context) {
          snapshot(context, false);
        }),
        DictionariesMenuBarEntry("OC Clean Snapshot", onActivate: (context) {
          snapshot(context, true);
        }),
        DictionariesMenuBarEntry("Change OC Snapshot Configuration", onActivate: (context) {
          showDialog(context: context, builder: (context) {
            return AlertDialog(
              title: Text("OC Snapshot Configuration"),
              content: OcSnapshotAddonConfigurationEditor(),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("OK")),
              ],
            );
          });
        }),
      ]).inject(context);
    }
  }
}

class OcSnapshotAddonConfigurationEditor extends StatefulWidget {
  const OcSnapshotAddonConfigurationEditor({super.key});

  @override
  State<OcSnapshotAddonConfigurationEditor> createState() => _OcSnapshotAddonConfigurationEditorState();
}

class _OcSnapshotAddonConfigurationEditorState extends State<OcSnapshotAddonConfigurationEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(value: forceUpdateSchema, onChanged: (value) async {
          if (value == null) return;
          forceUpdateSchema = value;
          setState(() {});

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool("forceUpdateSchema", value);
        }, title: Text("Force Update Schema"), subtitle: Text("Add missing or remove erroneous keys from existing snapshot entries.")),
      ],
    );
  }
}