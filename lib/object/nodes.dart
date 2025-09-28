import 'dart:convert';
import 'dart:typed_data';

enum NodeType {
  string,
  number, // int or double
  boolean,
  empty,
  array,
  map,
  date,
  data,
}

abstract class NodeData {
  const NodeData();
  Uint8List toBinary();

  factory NodeData.fromBinary(Uint8List bytes) {
    throw UnimplementedError('fromBinary must be implemented by subclasses');
  }
}

abstract class Node<T> extends NodeData {
  final NodeType type;
  final T input;
  final List<NodeData> children;

  const Node({required this.type, required this.input, required this.children});
  bool get hasChildren => children.isNotEmpty;
}

class NodeKeyValuePair extends NodeData {
  final String key;
  final Node value;

  const NodeKeyValuePair({required this.key, required this.value});

  @override
  Uint8List toBinary() {
    return Uint8List.fromList([...utf8.encode(key), 0x00, ...value.toBinary()]);
  }
}

class RootNode {
  final List<NodeData> children;
  const RootNode({required this.children});

  Uint8List toBinary() {
    List<Uint8List> chunks = children.map((x) => x.toBinary()).toList();
    int totalLength = chunks.fold(0, (sum, chunk) => sum + chunk.length);
    Uint8List combined = Uint8List(totalLength);
    int offset = 0;

    for (Uint8List chunk in chunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return combined;
  }
}

class StringNode extends Node<String> {
  const StringNode(String input) : super(type: NodeType.string, input: input, children: const []);

  @override
  Uint8List toBinary() {
    return utf8.encode(input);
  }
}

class NumberNode extends Node<num> {
  const NumberNode(num input) : super(type: NodeType.number, input: input, children: const []);

  @override
  Uint8List toBinary() {
    Uint8List output = Uint8List(9);
    ByteData data = ByteData(8);

    if (input is int) {
      output[0] = 0;
      data.setUint64(0, input as int);
    } else if (input is double) {
      output[0] = 1;
      data.setFloat64(0, input as double);
    }

    output.setRange(1, data.lengthInBytes + 1, data.buffer.asUint8List());
    return output;
  }
}

class BooleanNode extends Node<bool> {
  const BooleanNode(bool input) : super(type: NodeType.boolean, input: input, children: const []);

  @override
  Uint8List toBinary() {
    return Uint8List.fromList([input ? 1 : 0]);
  }
}

class EmptyNode extends Node<void> {
  const EmptyNode() : super(type: NodeType.empty, input: null, children: const []);

  @override
  Uint8List toBinary() {
    return Uint8List(0);
  }
}

class ArrayNode extends Node<void> {
  const ArrayNode(List<Node> input) : super(type: NodeType.array, input: null, children: input);

  @override
  Uint8List toBinary() {
    int headerLength = 5;
    List<Uint8List> childrenBytes = children.map((x) => x.toBinary()).toList();
    int totalLength = headerLength + childrenBytes.fold(0, (sum, b) => sum + b.length);
    Uint8List data = Uint8List(totalLength);
    ByteData lengthData = ByteData(headerLength);

    lengthData.setUint32(0, children.length);
    data[0] = 1;
    data.setRange(1, headerLength, lengthData.buffer.asUint8List());
    int offset = headerLength;

    for (Uint8List child in childrenBytes) {
      data.setRange(offset, offset + child.length, child);
      offset += child.length;
    }

    return data;
  }
}

class MapNode extends Node<void> {
  const MapNode(List<NodeKeyValuePair> input) : super(type: NodeType.map, input: null, children: input);

  @override
  Uint8List toBinary() {
    int headerLength = 5;
    List<Uint8List> childrenBytes = children.map((x) => x.toBinary()).toList();
    int totalLength = headerLength + childrenBytes.fold(0, (sum, b) => sum + b.length);
    Uint8List data = Uint8List(totalLength);
    ByteData lengthData = ByteData(headerLength);

    lengthData.setUint32(0, children.length);
    data[0] = 0;
    data.setRange(1, headerLength, lengthData.buffer.asUint8List());
    int offset = headerLength;

    for (Uint8List child in childrenBytes) {
      data.setRange(offset, offset + child.length, child);
      offset += child.length;
    }

    return data;
  }
}

class DateNode extends Node<DateTime> {
  const DateNode(DateTime input) : super(type: NodeType.date, input: input, children: const []);

  @override
  Uint8List toBinary() {
    int ms = DateTime.now().millisecondsSinceEpoch;
    ByteData data = ByteData(8);
    data.setInt64(0, ms);
    return data.buffer.asUint8List();
  }
}

class DataNode extends Node<Uint8List> {
  const DataNode(Uint8List input) : super(type: NodeType.data, input: input, children: const []);

  @override
  Uint8List toBinary() {
    return input;
  }
}