import 'package:dictionaries/main.dart';
import 'package:dictionaries/object/nodes.dart' as obj;
import 'package:flutter/foundation.dart';

Uint8List finalResult(int type, Uint8List input) {
  int headerSize = 6;
  Uint8List output = Uint8List(input.length + headerSize);

  output[0] = type & 0xFF;
  output[1] = version.major & 0xFF;
  output[2] = version.intermediate & 0xFF;
  output[3] = version.minor & 0xFF;
  output[4] = version.patch & 0xFF;
  output[5] = version.release & 0xFF;

  output.setRange(headerSize, input.length + headerSize, input);
  return output;
}

Uint8List binaryFromObjectNode(obj.RootNode root) {
  return finalResult(0, root.toBinary());
}