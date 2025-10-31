import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bson/bson.dart';
import 'package:dictionaries/main.dart';
import 'package:dictionaries/src/editor.dart';
import 'package:dictionaries/src/main.dart';
import 'package:dictionaries/src/nodeenums.dart';
import 'package:intl/intl.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:localpkg_flutter/localpkg.dart';
import 'package:dictionaries/lib/plist_parser.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

int parentCount = 0;

void assignParents(NodeData node, [AllNodeData? parent]) {
  parentCount++;
  node.parent = parent;
  for (var child in node.children) assignParents(child, node);

  if (node is NodeKeyValuePair) {
    node.value.parent = node;
    assignParents(node.value, node);
  }
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
    case NodeType.date: return DateTime.fromMillisecondsSinceEpoch(0);
    case NodeType.data: return Uint8List(0);
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

abstract class AllNodeData {
  bool get isRootNode => this is RootNode;
}

abstract class NodeData extends AllNodeData {
  List<NodeData> _children;
  String id;
  AllNodeData? parent;

  NodeData({List<NodeData>? children, this.parent}) : _children = children ?? [], id = Uuid().v4();
  NodeData copy();

  Node get node;
  bool get isRoot => false;
  List<NodeData> get children => _children;
  int get index {
    if (parent is NodeData) {
      return (parent as NodeData).children.indexWhere((x) => x.id == id);
    } else if (parent is RootNode) {
      return (parent as RootNode).children.indexWhere((x) => x.id == id);
    } else {
      return 0;
    }
  }

  NodeData? getParentAsNodeData() {
    if (parent is NodeData) return parent as NodeData;
    return null;
  }

  set children(value) => _children;
}

class Node extends NodeData {
  Object? input;

  /// - 0: Not parent
  /// - 1: Array
  /// - 2: Map
  int isParentType;

  Node({required this.input, super.children, this.isRoot = false, this.isParentType = 0});

  @override
  bool isRoot;

  @override
  Node get node => this;

  NodeType get type => _identify();
  NodeType identify({bool debug = false}) => _identify(debug: debug);
  bool get hasChildren => children.isNotEmpty;
  bool get isDecimal => input is double;

  @override
  NodeData copy() {
    return Node(input: input, children: children.map((x) => x.copy()).toList(), isRoot: isRoot, isParentType: isParentType);
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
    if (debug) Logger.print('Node $id debug: type=${input.runtimeType} children=$children (${children.runtimeType}) isEmpty=${children.isEmpty}');

    if (isParentType == 1) {
      return NodeType.array;
    } else if (isParentType == 2) {
      return NodeType.map;
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
    } else {
      throw UnimplementedError();
    }
  }

  String valueToString() {
    switch (type) {
      case NodeType.boolean: return (input as bool) ? "True" : "False";
      case NodeType.data: return (input as Uint8List).formatHex();
      case NodeType.date: return DateFormat("MMM d, y h:mm a").format(input as DateTime);
      case NodeType.empty: return "Null";
      case NodeType.number: return input.toString();
      case NodeType.string: return input.toString();
      default: return "";
    }
  }
}

class NodeKeyValuePair extends NodeData {
  String key;
  Node value;

  NodeKeyValuePair({required this.key, required this.value}) : super(children: value.children);

  @override
  Node get node => value;

  @override
  NodeData copy() {
    return NodeKeyValuePair(key: key, value: value);
  }
}

class RootNode extends AllNodeData {
  List<NodeData> children;
  RootNodeType type;
  Map<String, AllNodeData> _lookup = {};
  Map<DataType, Object> _rawData = {};

  RootNode({required this.children, required this.type, Map<DataType, String>? rawData}) {
    if (rawData != null) _rawData = rawData;
    rebuild();
  }

  RootNode.clean({required this.type, Map<DataType, String>? rawData}) : children = const [] {
    if (rawData != null) _rawData = rawData;
    rebuild();
  }

  static const bool allowLookup = false;
  static const int tryYamlEditLimit = 1000;
  static const String fileMagic = "C-DICT";
  static late RootNode instance;
  static int nodes = 0;

  void rebuild() {
    _buildRootLookup();
    assignRootNodeParents();
  }

  void _buildRootLookup() {
    if (!allowLookup) return;
    _lookup = {};
    for (NodeData child in children) _buildLookup(child);
    Logger.print("Built root lookup of ${_lookup.length} entries");
  }

  void _buildLookup(NodeData node) {
    if (!allowLookup) return;
    _lookup[node.id] = node;
    if (node is NodeKeyValuePair) _buildLookup(node.value);
    for (NodeData child in node.children) _buildLookup(child);
    _lookup["root"] = this;
  }

  void assignRootNodeParents() {
    parentCount = 0;

    for (var child in children) {
      assignParents(child);
      child.parent = this;
    }

    Logger.print("Assigned $parentCount parents to RootNode!");
  }

  List<NodeData> get allChildren {
    List<NodeData> process(List<NodeData> children) {
      List<NodeData> results = [];

      for (var child in children) {
        results.add(child);
        results.addAll(process(child.children));
      }

      return results;
    }

    return process(children);
  }

  AllNodeData? lookup(String? key) {
    return _lookup.containsKey(key) ? _lookup[key] : null;
  }

  NodeData? lookupNodeData(String? key) {
    var result = lookup(key);
    if (result is NodeData) return result;
    return null;
  }

  T? getRawData<T>(DataType key) {
    if (!_rawData.containsKey(key)) return null;
    if (_rawData[key] is! T) return null;
    return _rawData[key] as T;
  }

  Object? _toJson(NodeConversionMode mode) => _toSpecified(rootNodeTypeToNodeType(type), children, (x) => Node.toJson(x, mode));
  Object? toJson() => _toJson(NodeConversionMode.json);
  XmlDocument toPlist({bool showNull = false}) => _toPlist(_toJson(NodeConversionMode.plist), showNull);

  String toJsonString() {
    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  String? tryYamlEdit() {
    if (allChildren.length > tryYamlEditLimit) return null;
    Logger.print("tryYamlEdit started with data ${_rawData.runtimeType} (${_rawData.keys.join(", ")})");
    String? raw = getRawData(DataType.yaml);
    if (raw == null) return null;

    YamlEditor editor = YamlEditor(raw);
    int updateCount = 0;
    Stopwatch stopwatch = Stopwatch()..start();

    void update(List<Object> keys, Object? input) {
      try {
        editor.update(keys, input);
        updateCount++;
      } catch (e, t) {
        Logger.warn("tryYamlEdit.update failed at update $updateCount with exception ${e.runtimeType}:\nSetting keys (${keys.join(", ")}) to value $input\n$e\nStack trace:\n$t");
      }
    }

    void process(List<Object> keys, AllNodeData node, bool insideNkvp) {
      if (node is NodeKeyValuePair) {
        return process([...keys, node.key], node.value, true);
      } else if (node is Node) {
        if (node.isParentType == 0) update([...keys, if (!insideNkvp) node.index], node.input);
        for (var child in node.children) process([...keys, if (!insideNkvp) node.index], child, false);
      } else if (node is RootNode) {
        for (var child in node.children) process([...keys, if (node.type == RootNodeType.array) child.index], child, false);
      }
    }

    Logger.print("tryYamlEdit setup after ${stopwatch.elapsedMilliseconds}ms");
    process([], this, false);
    String output = editor.toString();
    Logger.print("tryYamlEdit finished $updateCount updates after ${(stopwatch..stop()).elapsedMilliseconds}ms: ${raw.hashCode} vs ${output.hashCode}");
    return output;
  }

  String toYamlString() {
    return tryYamlEdit() ?? json2yaml(toJson() as Map<String, dynamic>);
  }

  String toPlistString({bool showNull = false, bool pretty = true, String indent = '  '}) {
    return _toPlist(toJson(), showNull).toXmlString(pretty: pretty, indent: indent);
  }

  Uint8List toBinary() {
    ByteData length = ByteData(8)..setUint64Safe(0, children.length, IntParser.defaultEndian);
    int headerSize = 128;
    ByteData headerSizeData = ByteData(2)..setUint16(0, headerSize, IntParser.defaultEndian);
    Uint8List headerSizeBytes = headerSizeData.buffer.asUint8List();

    Logger.print("Writing header... (headerSizeBytes: ${headerSizeBytes.map((x) => "0x${x.toRadixString(16).padLeft(2, "0")}")})");
    List<int> magic = utf8.encode(fileMagic);
    if (magic.length < 10) magic = [...magic, ...List.filled(10 - magic.length, 0x00)];

    List<int> header = [...magic, ...headerSizeBytes, ...binaryVersion.toBinary()];
    if (header.length < headerSize) header.addAll(List.filled(headerSize - header.length, 0x00));

    List<int> body = [...length.buffer.asUint8List(), ...children.expand((x) => NodeBinaryManager.nodeDataToBinary(x)), ...utf8.encode("Calebh101").padLeft(16, 0x00), 0x99];
    return Uint8List.fromList([...header, ...body]);

    // The first 10 bytes are the UTF8 of the file magic.
    // The binary version is then included. This is exactly 10 bytes.
    // The header offset is then included as an unsigned 16-bit integer.
    // We then add a watermark :)
    // The header is then padded.
    // The body is first an unsigned 64-bit integer with the length of the children, followed by the children contents. This is continued in [NodeBinaryManager.nodeDataToBinary].
    // I then add a 16 byte watermark :)
  }

  static RootNode? fromBinary(Uint8List bytes) {
    try {
      if (utf8.decode(bytes.sublist(0, fileMagic.length)) != fileMagic) throw Exception("Invalid magic.");
      if (bytes.last != 0x99) throw Exception("Invalid end of file.");
      bytes = bytes.sublist(0, bytes.length - 17); // Get rid of the watermark we added

      int headerSize = bytes.sublist(10, 12).toUint16();
      Version fileVersion = Version.parseBinary(bytes.sublist(12, 22));
      Logger.print("Found file details: headerSize=$headerSize version=$fileVersion");
      NodeBinaryManager.init(headerSize);

      Uint8List content = bytes.sublist(headerSize);
      int rootLength = content.sublist(0, 8).toUint64();
      Logger.print("Found $rootLength children of ${content.length} bytes");
      List<NodeData> children = NodeBinaryManager.childrenFromBinary(content.sublist(8));
      return RootNode(children: children, type: children.every((x) => x is Node) ? RootNodeType.array : (children.every((x) => x is NodeKeyValuePair) ? RootNodeType.map : throw Exception("Inconsistent children")));
    } catch (e) {
      if (throwOnBinary) rethrow;
      Logger.warn("Unable to parse RootNode from binary: $e");
      return null;
    }
  }

  static XmlDocument _toPlist(Object? input, bool showNull) {
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

  static RootNode fromObject(Object? input, Map<DataType, String>? rawData) {
    Logger.print("Constructing from object with rawData of type ${rawData.runtimeType}...");

    Node process(Object? input, [int index = -1]) {
      if (input is List && input is! Uint8List) {
        return Node(isParentType: 1, input: null, children: input.map((value) {
          index++;
          return process(value, index);
        }).toList());
      } else if (input is Map) {
        return Node(isParentType: 2, input: null, children: input.entries.map((entry) {
          return NodeKeyValuePair(key: entry.key.toString(), value: process(entry.value));
        }).toList());
      } else if (input is Node) {
        return input;
      } else {
        return Node(input: input, children: []);
      }
    }

    if (input is Map) {
      int index = -1;

      Iterable<NodeKeyValuePair> objects = input.entries.map((entry) {
        index++;
        return NodeKeyValuePair(key: entry.key.toString(), value: process(entry.value, index));
      });

      return RootNode(children: objects.toList(), type: RootNodeType.map, rawData: rawData);
    } else if (input is List) {
      int index = -1;

      Iterable<Node> objects = input.map((value) {
        index++;
        return process(value, index);
      });

      return RootNode(children: objects.toList(), type: RootNodeType.array, rawData: rawData);
    } else {
      throw UnimplementedError();
    }
  }

  static RootNode fromJson(String raw) {
    return fromObject(jsonDecode(raw), null);
  }

  static RootNode fromPlist(String input) {
    return fromObject(PlistParser().parse(input), null);
  }

  static RootNode fromBplist(Uint8List input) {
    return fromObject(PlistParser().parseBinaryBytes(input), null);
  }

  static RootNode fromYaml(String input) {
    return fromObject(loadYaml(input), {DataType.yaml: input});
  }

  static RootNode? tryParse(Uint8List raw) {
    RootNode? fromBinary = RootNode.fromBinary(raw);
    List<Object> errors = [];
    if (fromBinary != null) return fromBinary;

    List<RootNode Function(Uint8List raw)> functions = [
      (raw) => RootNode.fromJson(utf8.decode(raw)),
      (raw) => RootNode.fromYaml(utf8.decode(raw)),
      (raw) => RootNode.fromPlist(utf8.decode(raw)),
      (raw) => RootNode.fromObject(BsonCodec.deserialize(BsonBinary.from(raw)), null),
    ];

    for (var function in functions) {
      try {
        Logger.print("Trying function ${function.hashCode}...");
        return function.call(raw);
      } catch (e) {
        Logger.print("Function ${function.hashCode} failed: $e");
        errors.add(e);
      }
    }

    Logger.warn("Unable to parse input: ${errors.join(", ")}");
    return null;
  }

  static void assignInstance(RootNode value) {
    instance = value;
  }
}

class NodeBinaryManager {
  static void init(int headerSize) {
    RootNode.nodes = 0;
  }

  static int getSignature(int varient, [NodeType? type]) {
    // Generate 1 byte that contains the varient and the optional node type (if it's a standard [Node]).
    return ((varient & 0x07) << 5) | ((type?.index ?? 0) & 0x1F);
  }

  static List<int> nodeDataToBinary(NodeData node) {
    List<int> bytes;
    int signature;

    if (node is Node) {
      bytes = nodeToBinary(node);
      signature = getSignature(0, node.type);
    } else if (node is NodeKeyValuePair) {
      bytes = nkvpToBinary(node);
      signature = getSignature(1);
    } else {
      throw UnimplementedError();
    }

    DynamicNumber lengthData = DynamicNumber.fromNumber(bytes.length + 1 /* signature */);
    return [...lengthData.data, signature, ...bytes];
  }

  static List<int> nodeToBinary(Node node) {
    switch (node.type) {
      case NodeType.string: return utf8.encode(node.input as String);
      case NodeType.number:
        ByteData data = ByteData(8);
        if (node.input is int) data.setInt64Safe(0, node.input as int, IntParser.defaultEndian);
        if (node.input is double) data.setFloat64(0, node.input as double, IntParser.defaultEndian);
        return [node.input is double ? 1 : 0, ...data.buffer.asUint8List()];
      case NodeType.empty: return [];
      case NodeType.data: return node.input as Uint8List;
      case NodeType.date:
        ByteData data = ByteData(8)..setInt64Safe(0, (node.input as DateTime).millisecondsSinceEpoch, IntParser.defaultEndian);
        return data.buffer.asUint8List();
      case NodeType.boolean: return [(node.input as bool) ? 1 : 0];
      case NodeType.map:
      case NodeType.array:
        List<int> bytes = [];
        for (List<int> child in node.children.map((x) => nodeDataToBinary(x))) bytes.addAll(child);
        return bytes;
    }
  }

  static List<int> nkvpToBinary(NodeKeyValuePair node) {
    // Encode the key with a null terminator, then include
    return [...utf8.encode(node.key), 0x00, ...nodeDataToBinary(node.value)];
  }

  static Node nodeFromBinary(NodeType type, Uint8List content) {
    switch (type) {
      case NodeType.boolean: return Node(input: content.first == 1 ? true : false);
      case NodeType.data: return Node(input: content);
      case NodeType.empty: return Node(input: null);
      case NodeType.number: return Node(input: content.first == 0 ? content.sublist(1).toInt64() : content.sublist(1).toFloat64());
      case NodeType.date:
        int ms = content.toInt64();
        DateTime date = DateTime.fromMillisecondsSinceEpoch(ms);
        return Node(input: date);
      case NodeType.string:
        String text = utf8.decode(content, allowMalformed: true);
        return Node(input: text);
      case NodeType.map:
      case NodeType.array:
        Logger.verbose("Found node $type of ${content.length} bytes");
        return Node(input: null, children: childrenFromBinary(content), isParentType: type == NodeType.array ? 1 : 2);
    }
  }

  static NodeKeyValuePair nkvpFromBinary(Uint8List content) {
    String key = "";
    int offset = 0;

    while (content[offset] != 0x00) {
      key += utf8.decode([content[offset]]);
      offset++;
    }

    offset += 1; // Get past the null character.
    DynamicNumberMode lengthSignature = DynamicNumber.parseSignature(content[offset]);
    offset += lengthSignature.bytes + 1; // Get past the length signature and data.

    Uint8List bytes = content.sublist(offset);
    Logger.verbose("Found bytes: ${bytes.formatBytes(max: 30)} (dictionary: ${getSignature(0, NodeType.map).formatByte()})");
    return NodeKeyValuePair(key: key, value: nodeDataFromBinary(bytes) as Node);
  }

  static NodeData nodeDataFromBinary(Uint8List bytes) {
    int signature = bytes.first;
    int varient = (signature >> 5) & 0x07;
    Uint8List content = bytes.sublist(1);

    RootNode.nodes++; // A record for debugging
    Logger.verbose("${RootNode.nodes}. Found node of signature ${signature.formatByte()}");

    // [varient] is an unsigned 3-bit integer that represents the varient of node we're dealing with. This can be either a [Node] or a [NodeKeyValuePair]. However, if I decide to add more node types in the future, we have 7 integers that can be represented with this.

    if (varient == 0) { // [Node]
      int typeInt = signature & 0x1F;
      NodeType type = NodeType.values[typeInt];
      Node child = nodeFromBinary(type, content);

      Logger.verbose("${RootNode.nodes}. Found node data of type $type (signature of ${signature.formatByte()})");
      return child;

      // [typeInt] is an unsigned 5-bit integer representing the type of node. This gives us 31 values, which is plenty.
      // We then use the rest of the content to parse the child.
    } else if (varient == 1) { // [NodeKeyValuePair]
      Logger.verbose("${RootNode.nodes}. Found NKVP data (signature of ${signature.formatByte()})");
      return nkvpFromBinary(content);

      // Not much to do here, as the [nkvpFromBinary] function handles this for us, and we've already done the varient parsing above.
      // Note that the type byte's upper 5 bits are unused here; I wonder if there's a future use for them though...
    } else {
      // An alien node type has approached us, shoot it with an error
      throw UnimplementedError("Unrecognized node varient at node ${RootNode.nodes}: $varient");
    }
  }

  static List<NodeData> childrenFromBinary(Uint8List bytes) {
    List<NodeData> children = [];
    int offset = 0;

    while (offset < bytes.length) {
      Logger.verbose("Found new child at offset $offset");
      DynamicNumberMode lengthSignature = DynamicNumber.parseSignature(bytes[offset]);
      DynamicNumber length = DynamicNumber.fromBytes(bytes.sublist(offset, offset + lengthSignature.bytes + 1));
      Uint8List child = bytes.sublist(offset + lengthSignature.bytes + 1, offset + lengthSignature.bytes + 1 + length.value.floor());

      Logger.verbose("Found node data of ${child.length} bytes (expected ${length.value} bytes) at offset $offset");
      children.add(nodeDataFromBinary(child));
      offset += lengthSignature.bytes + 1 + length.value.floor();
      Logger.verbose("Children is now at ${children.length} and offset $offset");
    }

    return children;
  }
}