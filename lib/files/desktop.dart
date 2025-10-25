import 'dart:io';
import 'dart:typed_data';

import 'package:dictionaries/src/editor.dart';
import 'package:file_picker/file_picker.dart';

Future<bool> saveFile({
  required String name,
  required Uint8List bytes,
  required String extension,
  required String mime,
}) async {
  String? result = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Dictionary As...',
    fileName: [name, extension].join("."),
  );

  if (result != null) {
    File file = File(result);
    await file.writeAsBytes(bytes);
    currentFileName = name;
    return true;
  } else {
    return false;
  }
}