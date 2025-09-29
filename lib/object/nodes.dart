import 'dart:convert';
import 'dart:typed_data';

import 'package:json2yaml/json2yaml.dart';
import 'package:plist_parser/plist_parser.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

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

NodeType rootNodeTypeToNodeType(RootNodeType type) {
  switch (type) {
    case RootNodeType.map: return NodeType.map;
    case RootNodeType.array: return NodeType.array;
  }
}

Object? _toSpecified(NodeType type, List<NodeData> children, Object? Function(NodeData value) toCallback) {
  if (type == NodeType.map) {
    Map<String, dynamic> output = {};

    for (NodeData child in children) {
      if (child is! NodeKeyValuePair) continue;
      output[child.key] = toCallback.call(child.value);
    }

    return output;
  } else if (type == NodeType.array) {
    return children.map((x) => toCallback.call(x)).toList();
  } else {
    return null;
  }
}

abstract class NodeData {
  List<NodeData> children;
  NodeData({required this.children});

  factory NodeData.fromBinary(Uint8List bytes) {
    throw UnimplementedError('fromBinary must be implemented by subclasses.');
  }

  Node get node;
  bool get isRoot => false;

  Uint8List toBinary();
  Object? toJson();
}

abstract class Node<T> extends NodeData {
  NodeType type;
  T input;

  Node({required this.type, required this.input, required super.children});
  bool get hasChildren => children.isNotEmpty;
  T get defaultValue;

  @override
  Node get node => this;
}

class RootTreeNode extends Node<void> {
  final RootNode root;
  RootTreeNode({required this.root, required super.children, required super.type}) : super(input: null);

  @override
  void get defaultValue => throw UnimplementedError();

  @override
  bool get isRoot => true;

  @override
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
  
  @override
  Object? toJson() => _toSpecified(type, children, (x) => x.toJson());
}

class NodeKeyValuePair extends NodeData {
  String key;
  Node value;

  NodeKeyValuePair({required this.key, required this.value}) : super(children: value.children);

  @override
  Node get node => value;

  @override
  Uint8List toBinary() {
    return Uint8List.fromList([...utf8.encode(key), 0x00, ...value.toBinary()]);
  }

  @override
  Object? toJson() {
    return {key: value.toJson()};
  }
}

class RootNode {
  List<NodeData> children;
  RootNodeType type;

  RootNode({required this.children, required this.type});
  RootNode.clean({required this.type}) : children = const [];

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

  Object? toJson() => _toSpecified(rootNodeTypeToNodeType(type), children, (x) => x.toJson());
  XmlDocument toPlist({bool showNull = false}) => _toPlist(toJson());

  String toJsonString() {
    return jsonEncode(toJson());
  }

  String toYamlString() {
    return json2yaml(toJson() as Map<String, dynamic>);
  }

  String toPlistString({bool showNull = false, bool pretty = true, String indent = '  '}) {
    return _toPlist(toJson(), showNull: showNull).toXmlString(pretty: pretty, indent: indent);
  }

  static XmlDocument _toPlist(Object? input, {bool showNull = false}) {
    XmlNode? process(Object? value) {
      if (value == null) {
        return showNull ? XmlElement(XmlName("null")) : null;
      } else if (value is String) {
        return XmlElement(XmlName("string"), [], [XmlText(value)]);
      } else if (value is int) {
        return XmlElement(XmlName("integer"), [], [XmlText(value.toString())]);
      } else if (value is double) {
        return XmlElement(XmlName("real"), [], [XmlText(value.toString())]);
      } else if (value is bool) {
        return XmlElement(XmlName(value ? "true" : "false"));
      } else if (value is DateTime) {
        return XmlElement(XmlName("date"), [], [XmlText(value.toUtc().toIso8601String())]);
      } else if (value is Uint8List) {
        return XmlElement(XmlName("data"), [], [XmlText(base64Encode(value))]);
      } else if (value is List) {
        return XmlElement(XmlName("array"), [], value.map((x) => process(x)).whereType<XmlNode>());
      } else if (value is Map) {
        List<XmlNode> children = [];

        value.forEach((key, value) {
          XmlNode? node = process(value);

          if (node != null) {
            children.add(XmlElement(XmlName("key"), [], [XmlText(key)]));
            children.add(node);
          }
        });

        return XmlElement(XmlName("dict"), [], children);
      } else {
        Logger.warn("Invalid plist type: ${value.runtimeType}");
        return null;
      }
    }

    XmlBuilder builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('plist', nest: () {
      builder.attribute('version', '1.0');
    });

    XmlDocument document = builder.buildDocument();
    document.rootElement.children.add(process(input)!);
    return document;
  }

  static RootNode fromObject(Object? input) {
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

  static RootNode fromJson(String raw) {
    return RootNode.fromObject(jsonDecode(raw));
  }

  static RootNode fromPlist(String input) {
    return fromObject(PlistParser().parse(input));
  }

  static RootNode fromYaml(String input) {
    return loadYaml(input);
  }

  static RootNode? tryParse(String raw) {
    try {
      Logger.print("Trying JSON...");
      return RootNode.fromJson(raw);
    } catch (a) {
      try {
        Logger.print("Trying YAML...");
        return RootNode.fromYaml(raw);
      } catch (b) {
        try {
          Logger.print("Trying PList...");
          return RootNode.fromPlist(raw);
        } catch (c) {
          Logger.warn("Unable to parse input: ${[a, b, c].join(", ")}");
          return null;
        }
      }
    }
  }
}

class StringNode extends Node<String> {
  StringNode(String input) : super(type: NodeType.string, input: input, children: []);

  @override
  Uint8List toBinary() {
    return utf8.encode(input);
  }

  @override
  Object? toJson() {
    return input;
  }

  @override
  String get defaultValue => "";
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

  @override
  Object? toJson() {
    return input;
  }

  @override
  num get defaultValue => 0;
}

class BooleanNode extends Node<bool> {
  BooleanNode(bool input) : super(type: NodeType.boolean, input: input, children: []);

  @override
  Uint8List toBinary() {
    return Uint8List.fromList([input ? 1 : 0]);
  }

  @override
  Object? toJson() {
    return input;
  }

  @override
  bool get defaultValue => false;
}

class EmptyNode extends Node<void> {
  EmptyNode() : super(type: NodeType.empty, input: null, children: []);

  @override
  Uint8List toBinary() {
    return Uint8List(0);
  }

  @override
  Object? toJson() {
    return null;
  }

  @override
  void get defaultValue {}
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

  @override
  Object? toJson() => _toSpecified(type, children, (x) => x.toJson());

  @override
  void get defaultValue {}
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

  @override
  Object? toJson() => _toSpecified(type, children, (x) => x.toJson());

  @override
  void get defaultValue {}
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

  @override
  Object? toJson() {
    return input.toIso8601String();
  }

  @override
  DateTime get defaultValue => DateTime.now();
}

class DataNode extends Node<Uint8List> {
  DataNode(Uint8List input) : super(type: NodeType.data, input: input, children: []);

  @override
  Uint8List toBinary() {
    return input;
  }

  @override
  Object? toJson() {
    return base64Encode(input);
  }

  @override
  Uint8List get defaultValue => Uint8List(0);
}