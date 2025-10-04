import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:plist_parser/plist_parser.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:uuid/uuid.dart';
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
  dynamic,
}

enum RootNodeType {
  array,
  map,
}

enum NodeConversionMode {
  json,
  yaml,
  plist,
}

Object? getDefaultValue(NodeType type) {
  switch (type) {
    case NodeType.string: return "";
    case NodeType.number: return 0;
    case NodeType.boolean: return false;
    case NodeType.empty: return null;
    case NodeType.array: return [];
    case NodeType.map: return {};
    case NodeType.date: return DateTime.now();
    case NodeType.data: return Uint8List(4);
    case NodeType.dynamic: return null;
  }
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
    case NodeType.dynamic: return "Custom";
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
  String id;
  int index = 0;
  NodeData({required this.children}) : id = Uuid().v4();

  factory NodeData.fromBinary(Uint8List bytes) {
    throw UnimplementedError('fromBinary must be implemented by subclasses.');
  }

  factory NodeData.fromXml(Uint8List bytes) {
    throw UnimplementedError('fromXml must be implemented by subclasses.');
  }

  Node get node;
  bool get isRoot => false;
}

class Node extends NodeData {
  Object? input;
  List<NodeAttribute> attributes;

  /// - 0: Not parent
  /// - 1: Array
  /// - 2: Map
  int isParentType;

  Node({required this.input, super.children = const [], this.attributes = const [], this.isRoot = false, this.isParentType = 0});

  @override
  bool isRoot;

  @override
  Node get node => this;

  NodeType get type => _identify();
  NodeType identify({bool debug = false}) => _identify(debug: debug);
  bool get hasChildren => children.isNotEmpty;

  Uint8List attributesToBinary() {
    List<int> bytes = [];
    for (NodeAttribute attribute in attributes) bytes.addAll([...utf8.encode(attribute.name), 0x00, ...utf8.encode(attribute.value), 0x00]);
    return Uint8List.fromList(bytes);
  }

  static Uint8List toBinary(NodeData node) {
    if (node is Node) {
      int type = node.type.index;

      List<int> process() {
        switch (node.type) {
          case NodeType.string: return [...utf8.encode(node.input as String), 0x00];
          case NodeType.number:
            ByteData data = ByteData(8);
            if (node.input is int) data.setInt64(0, node.input as int);
            if (node.input is double) data.setFloat64(0, node.input as double);
            return data.buffer.asUint8List();
          case NodeType.empty: return [];
          case NodeType.data: return node.input as Uint8List;
          case NodeType.date:
            ByteData data = ByteData(8);
            data.setInt64(0, (node.input as DateTime).millisecondsSinceEpoch);
            return data.buffer.asUint8List();
          case NodeType.boolean: return [(node.input as bool) ? 1 : 0];
          case NodeType.map:
          case NodeType.array:
            ByteData length = ByteData(4);
            length.setInt32(0, node.children.length);
            List<int> bytes = [];
            for (Uint8List child in node.children.map((x) => toBinary(x))) bytes.addAll(child);
            return [...length.buffer.asUint8List(), ...bytes];

            // First we say how many children there are.
            // Then we use [Node.toBinary] on those children too.
          case NodeType.dynamic:
            return (node.input as CustomNode).toBinary();
        }
      }

      List<int> bytes = process();
      ByteData length = ByteData(8);
      length.setUint64(0, bytes.length);
      return Uint8List.fromList([...utf8.encode("NODE"), type & 0xFF, ...length.buffer.asUint8List(), ...bytes]);

      // First, we'll include "NODE" in UTF8 as the first 4 bytes.
      // Second, we'll include the type as a single-byte integer.
      // Then we'll include the length of the contents as an unsigned 64-bit integer.
      // Finally, we'll include the actual content.
    } else if (node is NodeKeyValuePair) {
      // First, we'll include "NVKP" (NodeKeyValuePair) in UTF8 as the first 4 bytes.
      // Then we'll include the null-terminated key.
      // Finally we'll call [Node.toBinary] on the contents.
      return Uint8List.fromList([...utf8.encode("NKVP"), ...utf8.encode(node.key), 0x00, ...toBinary(node.node)]);
    } else {
      throw UnimplementedError();
    }
  }

  static Object? toJson(NodeData input, NodeConversionMode mode) {
    Object? process(NodeData input) {
      if (input is Node) {
        NodeType type = input.type;

        if (type == NodeType.empty) {
          return null;
        } else if (type == NodeType.string) {
          return input.input as String;
        } else if (type == NodeType.number) {
          return input.input as num;
        } else if (type == NodeType.boolean) {
          return input.input == true;
        } else if (type == NodeType.dynamic) {
          return input.input;
        } else if (type == NodeType.date) {
          return switch (mode) {
            NodeConversionMode.json => (input.input as DateTime).toIso8601String(),
            NodeConversionMode.plist || NodeConversionMode.yaml => input.input as DateTime,
          };
        } else if (type == NodeType.data) {
          return switch (mode) {
            NodeConversionMode.json || NodeConversionMode.yaml => base64.encode(input.input as List<int>),
            NodeConversionMode.plist => input.input as Uint8List,
          };
        } else if (type == NodeType.array || type == NodeType.map) {
          return input.children.map((x) => process(x)).toList();
        } else {
          throw UnimplementedError();
        }
      } else if (input is NodeKeyValuePair) {
        return {
          input.key: process(input.node),
        };
      } else {
        throw UnimplementedError();
      }
    }

    return process(input);
  }

  NodeType _identify({bool debug = false}) {
    if (debug) Logger.print('Node $id debug: children=$children (${children.runtimeType}) isEmpty=${children.isEmpty}');

    if (isParentType == 1) {
      return NodeType.map;
    } else if (isParentType == 2) {
      return NodeType.array;
    } else if (input == null) {
      return NodeType.empty;
    } else if (input is String) {
      return NodeType.string;
    } else if (input is num) {
      return NodeType.number;
    } else if (input is bool) {
      return NodeType.boolean;
    } else if (input is DateTime) {
      return NodeType.date;
    } else if (input is Uint8List) {
      return NodeType.data;
    } else if (input is CustomNode) {
      return NodeType.dynamic;
    } else {
      throw UnimplementedError();
    }
  }

  String valueToString() {
    switch (type) {
      case NodeType.map:
      case NodeType.array: return "${children.length} Children";
      case NodeType.boolean: return (input as bool) ? "True" : "False";
      case NodeType.data: return "0x${(input as Uint8List).map((b) => b.toRadixString(16).padLeft(2, '0')).join("")}";
      case NodeType.date: return DateFormat("MMM d, y h:mm a").format(input as DateTime);
      case NodeType.empty: return "Null";
      case NodeType.number: return input.toString();
      case NodeType.string: return input.toString();
      case NodeType.dynamic: return input.toString();
    }
  }
}

class NodeAttribute {
  String name;
  String value;

  NodeAttribute(this.name, this.value);
}

class NodeKeyValuePair extends NodeData {
  String key;
  Node value;

  NodeKeyValuePair({required this.key, required this.value}) : super(children: value.children);

  @override
  Node get node => value;
}

class RootNode {
  List<NodeData> children;
  RootNodeType type;
  Map<String, NodeData> _lookup = {};

  RootNode({required this.children, required this.type}) {
    rebuild();
  }

  RootNode.clean({required this.type}) : children = const [] {
    rebuild();
  }

  static late RootNode instance;

  void rebuild() {
    _buildRootLookup();
  }

  void _buildRootLookup() {
    _lookup = {};
    for (NodeData child in children) _buildLookup(child);
    Logger.print("Built root lookup of ${_lookup.length} entries");
  }

  void _buildLookup(NodeData node) {
    _lookup[node.id] = node;
    for (NodeData child in node.children) _buildLookup(child);
  }

  Object? _toJson(NodeConversionMode mode) => _toSpecified(rootNodeTypeToNodeType(type), children, (x) => Node.toJson(x, mode));
  Object? toJson() => _toJson(NodeConversionMode.json);
  XmlDocument toPlist({bool showNull = false}) => _toPlist(_toJson(NodeConversionMode.plist));

  String toJsonString() {
    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  String toYamlString() {
    return json2yaml(toJson() as Map<String, dynamic>);
  }

  String toPlistString({bool showNull = false, bool pretty = true, String indent = '  '}) {
    return _toPlist(toJson(), showNull: showNull).toXmlString(pretty: pretty, indent: indent);
  }

  Uint8List toBinary() {
    ByteData length = ByteData(8)..setUint64(0, children.length);
    int headerSize = 64;
    ByteData headerSizeData = ByteData(2)..setUint16(0, headerSize);

    List<int> header = [...utf8.encode("DICTIONARY" /* 10 chars */), ...headerSizeData.buffer.asUint8List()];
    if (header.length < headerSize) header.addAll(List.filled(headerSize - header.length, 0x00));

    List<int> body = [...length.buffer.asUint8List(), ...children.expand((x) => Node.toBinary(x))];
    return Uint8List.fromList([...header, ...body]);

    // The first 10 bytes are the UTF8 of "DICTIONARY".
    // The header offset is then included as an unsigned 16-bit integer.
    // The body is first an unsigned 64-bit integer with the length of the children, followed by the children contents. This is continued in [Node.toBinary].
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
    Node process(Object? input, [int index = -1]) {
      if (input is List) {
        return Node(isParentType: 1, input: null, children: input.map((value) {
          index++;
          return process(value, index);
        }).toList(), attributes: []);
      } else if (input is Map) {
        return Node(isParentType: 2, input: null, children: input.entries.map((entry) {
          return NodeKeyValuePair(key: entry.key.toString(), value: process(entry.value));
        }).toList(), attributes: []);
      } else if (input is Node) {
        return input;
      } else {
        return Node(input: input, children: [], attributes: []);
      }
    }
    
    if (input is Map) {
      int index = -1;

      Iterable<NodeKeyValuePair> objects = input.entries.map((entry) {
        index++;
        return NodeKeyValuePair(key: entry.key.toString(), value: process(entry.value, index));
      });

      return RootNode(children: objects.toList(), type: RootNodeType.map);
    } else if (input is List) {
      int index = -1;

      Iterable<Node> objects = input.map((value) {
        index++;
        return process(value, index);
      });

      return RootNode(children: objects.toList(), type: RootNodeType.array);
    } else {
      throw UnimplementedError();
    }
  }

  static RootNode fromJson(String raw) {
    return fromObject(jsonDecode(raw));
  }

  static RootNode fromPlist(String input) {
    return fromObject(PlistParser().parse(input));
  }

  static RootNode fromYaml(String input) {
    return fromObject(loadYaml(input));
  }

  static RootNode fromXml(String input) {
    throw UnimplementedError();
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

  static void assignInstance(RootNode value) {
    instance = value;
  }
}

class CustomNode {
  String key;
  String value;

  CustomNode(this.key, this.value);

  Uint8List toBinary() {
    return Uint8List.fromList([...utf8.encode(key), 0x00, ...utf8.encode(value), 0x00]);
  }
}