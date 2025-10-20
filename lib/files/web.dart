import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dictionaries/src/editor.dart';
import 'package:web/web.dart' as web;

Future<bool> saveFile({
  required String name,
  required Uint8List bytes,
  String extension = "dictionary",
  String mime = "application/c-dict",
}) async {
  final blob = web.Blob([bytes].jsify() as JSArray<web.BlobPart>, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()..href = url..download = "$name.$extension"..click();

  web.URL.revokeObjectURL(url);
  currentFileName = name;
  return true;
}