import 'dart:convert';
import 'dart:typed_data';

import 'package:dictionaries/main.dart';
import 'package:dictionaries/object/editor.dart';
import 'package:intl/intl.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:localpkg/functions.dart';
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
          case NodeType.string: return utf8.encode(node.input as String);
          case NodeType.number:
            ByteData data = ByteData(8);
            if (node.input is int) data.setInt64(0, node.input as int, IntParser.defaultEndian);
            if (node.input is double) data.setFloat64(0, node.input as double, IntParser.defaultEndian);
            return data.buffer.asUint8List();
          case NodeType.empty: return [];
          case NodeType.data: return node.input as Uint8List;
          case NodeType.date:
            ByteData data = ByteData(8);
            data.setInt64(0, (node.input as DateTime).millisecondsSinceEpoch, IntParser.defaultEndian);
            return data.buffer.asUint8List();
          case NodeType.boolean: return [(node.input as bool) ? 1 : 0];
          case NodeType.map:
          case NodeType.array:
            ByteData length = ByteData(8)..setUint64(0, node.children.length, IntParser.defaultEndian);
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
      length.setUint64(0, bytes.length, IntParser.defaultEndian);
      return Uint8List.fromList([...length.buffer.asUint8List(), ...utf8.encode("NODE"), type, ...bytes]);

      // First, we'll include "NODE" in UTF8 as the first 4 bytes.
      // Second, we'll include the type as a single-byte integer.
      // Then we'll include the length of the contents as an unsigned 64-bit integer.
      // Finally, we'll include the actual content.
    } else if (node is NodeKeyValuePair) {
      List<int> bytes = [...utf8.encode(node.key), 0x00, ...toBinary(node.node)];
      ByteData length = ByteData(8);
      length.setUint64(0, bytes.length, IntParser.defaultEndian);
      return Uint8List.fromList([...length.buffer.asUint8List(), ...utf8.encode("NKVP"), ...bytes]);

      // First, we'll include "NVKP" (NodeKeyValuePair) in UTF8 as the first 4 bytes.
      // Then we'll include the null-terminated key.
      // Finally we'll call [Node.toBinary] on the contents.
      // The length is calculated based on the key, null terminator, and size of the child binary alltogether.
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
    ByteData length = ByteData(8)..setUint64(0, children.length, IntParser.defaultEndian);
    int headerSize = 128;
    ByteData headerSizeData = ByteData(2)..setUint16(0, headerSize, IntParser.defaultEndian);
    Uint8List headerSizeBytes = headerSizeData.buffer.asUint8List();

    Logger.print("Writing header... (headerSizeBytes: ${headerSizeBytes.map((x) => "0x${x.toRadixString(16).padLeft(2, "0")}")})");
    List<int> header = [...utf8.encode("DICTIONARY"), ...headerSizeBytes, ...version.toBinary()];
    if (header.length < headerSize) header.addAll(List.filled(headerSize - header.length, 0x00));

    List<int> body = [...length.buffer.asUint8List(), ...children.expand((x) => Node.toBinary(x))];
    return Uint8List.fromList([...header, ...body, ...utf8.encode("CALEBH101")]);

    // The first 10 bytes are the UTF8 of "DICTIONARY".
    // The application version is then included. This is exactly 10 bytes.
    // The header offset is then included as an unsigned 16-bit integer.
    // The header is then padded.
    // The body is first an unsigned 64-bit integer with the length of the children, followed by the children contents. This is continued in [Node.toBinary].
    // Finally, we add a small watermark :)
  }

  static RootNode? fromBinary(Uint8List bytes) {
    try {
      int i = 0;

      NodeData process(Uint8List bytes, int layer, int start) {
        try {
          Logger.verbose("Processing $i:$layer of ${bytes.length} bytes...");
          String magic = ascii.decode(bytes.sublist(0, 4));
          Logger.verbose("Found node $i:$layer:$magic at offset $start (0x${start.toRadixString(16).toUpperCase().padLeft(2, '0')}) of ${bytes.length} bytes: ${bytes.map((x) => "0x${x.toRadixString(16).padLeft(2, '0').toUpperCase()}")}");
          i++;

          if (magic == "NODE") {
            Uint8List typeBytes = bytes.sublist(4, 5);
            Logger.verbose("Found type bytes of $typeBytes");
            NodeType type = NodeType.values[typeBytes.first];
            Uint8List content = bytes.sublist(5);

            switch (type) {
              case NodeType.boolean: return Node(input: content.first == 1 ? true : false);
              case NodeType.data: return Node(input: content);
              case NodeType.empty: return Node(input: null);
              case NodeType.number: return Node(input: content.toInt64());
              case NodeType.date:
                int ms = content.toInt64();
                DateTime date = DateTime.fromMillisecondsSinceEpoch(ms);
                return Node(input: date);
              case NodeType.string:
                String text = ascii.decode(content);
                return Node(input: text);
              case NodeType.dynamic:
                int offset = 0;
                String key = "";
                String value = "";

                while (content[offset] != 0) {
                  key += ascii.decode([content[offset]]);
                  offset++;
                }

                offset++;

                while (content[offset] != 0) {
                  value += ascii.decode([content[offset]]);
                  offset++;
                }

                CustomNode data = CustomNode(key, value);
                return Node(input: data);
              case NodeType.map:
              case NodeType.array:
                int offset = 8;

                try {
                  int length = content.sublist(0, 8).toUint64();
                  List<NodeData> children = [];

                  for (int i = 0; i < length; i++) {
                    int size = content.sublist(offset, offset + 8).toUint64();
                    if (offset + 8 + size > content.length) throw Exception("Child node length ($size) exceeds remaining content (${content.length - offset - 8}) at offset $offset (byte $offset / ${content.length})");

                    Uint8List child = content.sublist(offset + 8, offset + 8 + size);
                    Logger.verbose("$i[$offset]. Found element of ${child.length} bytes (expected $size bytes)");

                    children.add(process(child, layer + 1, start + offset));
                    offset += 8 + 4 + size;
                  }

                  return Node(input: null, children: children);
                } catch (e) {
                  rethrow;
                }
            }
          } else if (magic == "NKVP") {
            int nullIndex = bytes.sublist(4).indexOf(0x00);
            List<int> asciiBytes = (nullIndex != -1) ? bytes.sublist(0, nullIndex) : bytes;
            Uint8List child = bytes.sublist(nullIndex + 1 + 8);
            Logger.verbose("First null index is $nullIndex/${bytes.length - 4}, leaving ${child.length} bytes: ${child.format()}");
            return NodeKeyValuePair(key: ascii.decode(asciiBytes), value: process(child, layer + 1, start + child.length) as Node);
          } else {
            throw Exception("Found invalid magic of ${bytes.sublist(0, 4).map((x) => "0x${x.toRadixString(16).toUpperCase().padLeft(0, '0')}")} at offset $start (0x${start.toRadixString(16).toUpperCase().padLeft(2, '0')})");
          }
        } catch (e) {
          rethrow;
          throw Exception("Exception ${e.runtimeType} at offset $start (0x${start.toRadixString(16).toUpperCase().padLeft(2, '0')}): $e");
        }
      }

      if (ascii.decode(bytes.sublist(0, 10)) != "DICTIONARY") throw Exception("Invalid magic.");
      int headerSize = bytes.sublist(10, 12).toUint16();
      Version fileVersion = Version.parseBinary(bytes.sublist(12, 22));
      Logger.print("Found file details: headerSize=$headerSize version=$fileVersion");

      Uint8List content = bytes.sublist(headerSize);
      int offset = 8;
      int rootLength = content.sublist(0, offset).toUint64();
      Logger.print("Found $rootLength children of ${content.length} bytes");
      List<NodeData> children = [];

      for (int i = 0; i < rootLength; i++) {
        offset += 8;
        int length = content.sublist(offset - 8, offset).toUint64();
        Logger.print("$i[${offset - 8}]. Found length of $length from $headerSize");
        Uint8List bytes = content.sublist(offset, offset + length);
        children.add(process(bytes, 0, headerSize  + (offset - 8)));
        offset += length + 8;
      }

      return RootNode(children: children, type: children.every((x) => x is Node) ? RootNodeType.array : (children.every((x) => x is NodeKeyValuePair) ? RootNodeType.map : throw UnimplementedError("Inconsistent children")));
    } catch (e) {
      if (throwOnBinary) rethrow;
      Logger.warn("Unable to parse RootNode from binary: $e");
      return null;
    }
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

  static RootNode? tryParse(Uint8List raw) {
    RootNode? fromBinary = RootNode.fromBinary(raw);
    if (fromBinary != null) return fromBinary;

    try {
      Logger.print("Trying JSON...");
      return RootNode.fromJson(ascii.decode(raw));
    } catch (a) {
      try {
        Logger.print("Trying YAML...");
        return RootNode.fromYaml(ascii.decode(raw));
      } catch (b) {
        try {
          Logger.print("Trying PList...");
          return RootNode.fromPlist(ascii.decode(raw));
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