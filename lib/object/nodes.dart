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

enum RootNodeType {
  array,
  map,
}

String nodeTypeToString(NodeType type) {
  switch (type) {
    case NodeType.string: return "String";
    case NodeType.number: return "Number";
    case NodeType.boolean: return "Boolean";
    case NodeType.empty: return "Null";
    case NodeType.array: return "Array";
    case NodeType.map: return "Dictionary";
    case NodeType.date: return "Date";
    case NodeType.data: return "Data";
  }
}

abstract class NodeData {
  final List<NodeData> children;
  NodeData({required this.children});

  factory NodeData.fromBinary(Uint8List bytes) {
    throw UnimplementedError('fromBinary must be implemented by subclasses.');
  }

  Uint8List toBinary();
}

abstract class Node<T> extends NodeData {
  NodeType type;
  T input;

  Node({required this.type, required this.input, required super.children});
  bool get hasChildren => children.isNotEmpty;
}

class NodeKeyValuePair extends NodeData {
  String key;
  Node value;

  NodeKeyValuePair({required this.key, required this.value}) : super(children: value.children);

  @override
  Uint8List toBinary() {
    return Uint8List.fromList([...utf8.encode(key), 0x00, ...value.toBinary()]);
  }
}

class RootNode {
  final List<NodeData> children;
  final RootNodeType type;
  RootNode({required this.children, required this.type});

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

  static RootNode fromJson(Object? input) {
    Node process(Object? input) {
      if (input is String) {
        return StringNode(input);
      } else if (input is num) {
        return NumberNode(input);
      } else if (input is bool) {
        return BooleanNode(input);
      } else if (input == null) {
        return EmptyNode();
      } else if (input is List) {
        return ArrayNode(input.map((value) {
          return process(value);
        }).toList());
      } else if (input is Map) {
        return MapNode(input.entries.map((entry) {
          return NodeKeyValuePair(key: entry.key.toString(), value: process(entry.value));
        }).toList());
      } else if (input is DateTime) {
        return DateNode(input);
      } else if (input is Uint8List) {
        return DataNode(input);
      } else if (input is Node) {
        return input;
      } else {
        throw UnimplementedError();
      }
    }
    
    if (input is Map) {
      Iterable<NodeKeyValuePair> objects = input.entries.map((entry) {
        return NodeKeyValuePair(key: entry.key.toString(), value: process(entry.value));
      });

      return RootNode(children: objects.toList(), type: RootNodeType.map);
    } else if (input is List) {
      Iterable<Node> objects = input.map((value) {
        return process(value);
      });

      return RootNode(children: objects.toList(), type: RootNodeType.array);
    } else {
      throw UnimplementedError();
    }
  }
}

class StringNode extends Node<String> {
  StringNode(String input) : super(type: NodeType.string, input: input, children: []);

  @override
  Uint8List toBinary() {
    return utf8.encode(input);
  }
}

class NumberNode extends Node<num> {
  NumberNode(num input) : super(type: NodeType.number, input: input, children: []);

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
  BooleanNode(bool input) : super(type: NodeType.boolean, input: input, children: []);

  @override
  Uint8List toBinary() {
    return Uint8List.fromList([input ? 1 : 0]);
  }
}

class EmptyNode extends Node<void> {
  EmptyNode() : super(type: NodeType.empty, input: null, children: []);

  @override
  Uint8List toBinary() {
    return Uint8List(0);
  }
}

class ArrayNode extends Node<void> {
  ArrayNode(List<Node> input) : super(type: NodeType.array, input: null, children: input);

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
  MapNode(List<NodeKeyValuePair> input) : super(type: NodeType.map, input: null, children: input);

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
  DateNode(DateTime input) : super(type: NodeType.date, input: input, children: []);

  @override
  Uint8List toBinary() {
    int ms = DateTime.now().millisecondsSinceEpoch;
    ByteData data = ByteData(8);
    data.setInt64(0, ms);
    return data.buffer.asUint8List();
  }
}

class DataNode extends Node<Uint8List> {
  DataNode(Uint8List input) : super(type: NodeType.data, input: input, children: []);

  @override
  Uint8List toBinary() {
    return input;
  }
}