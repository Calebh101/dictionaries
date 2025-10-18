import 'package:dictionaries/src/nodeenums.dart';

void _debug(Object? input) {
  // ignore: avoid_print
  print("Signatures: $input");
}

void main(List<String> arguments) {
  int i = 0;

  for (NodeType type in NodeType.values) {
    int signature = getSignature(0, type);
    _debug("0 (NODE): $type of index $i ($signature) (${[signature].formatBytes()})");
    i++;
  }

  (() {
    int signature = getSignature(1);
    _debug("1 (NKVP): $signature (${[signature].formatBytes()})");
  })();
}

int getSignature(int varient, [NodeType? type]) {
  return ((varient & 0x07) << 5) | ((type?.index ?? 0) & 0x1F);
}

extension ByteFormatter on List<int> {
  String formatBytes({String delim = ", ", int max = 10}) {
    List<int> values = this;
    bool moreThanMax = false;

    if (values.length > max) {
      values = values.sublist(0, max);
      moreThanMax = true;
    }

    return [...values.map((x) => "0x${x.toRadixString(16).toUpperCase().padLeft(2, 0.toString())}"), if (moreThanMax) ...["${length - max} more..."]].join(delim);
  }
}