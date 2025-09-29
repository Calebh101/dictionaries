import 'package:dictionaries/main.dart';
import 'package:dictionaries/object/nodes.dart' as obj;
import 'package:flutter/foundation.dart';

Uint8List finalResult(int type, Uint8List input) {
  int headerSize = 16;
  Uint8List output = Uint8List(input.length + headerSize);
  output.setRange(0, 10, "DICTIONARY".codeUnits);

  output[10] = type & 0xFF;
  output[11] = version.major & 0xFF;
  output[12] = version.intermediate & 0xFF;
  output[13] = version.minor & 0xFF;
  output[14] = version.patch & 0xFF;
  output[15] = version.release & 0xFF;

  output.setRange(headerSize, input.length + headerSize, input);
  return output;
}

Uint8List binaryFromObjectNode(obj.RootNode root) {
  return finalResult(0, root.toBinary());
}