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
}

abstract class Node<T> extends NodeData {
  final NodeType type;
  final T? input;
  final List<NodeData> children;

  const Node({required this.type, required this.input, required this.children});
  bool get hasChildren => children.isNotEmpty;
}

class NodeKeyValuePair extends NodeData {
  final String key;
  final Node value;

  const NodeKeyValuePair({required this.key, required this.value});
}

class StringNode extends Node<String> {
  const StringNode(String input) : super(type: NodeType.string, input: input, children: const []);
}

class NumberNode extends Node<num> {
  const NumberNode(num input) : super(type: NodeType.number, input: input, children: const []);
}

class BooleanNode extends Node<bool> {
  const BooleanNode(bool input) : super(type: NodeType.boolean, input: input, children: const []);
}

class EmptyNode extends Node<void> {
  const EmptyNode() : super(type: NodeType.empty, input: null, children: const []);
}

class ArrayNode extends Node<void> {
  const ArrayNode(List<Node> input) : super(type: NodeType.array, input: null, children: input);
}

class MapNode extends Node<void> {
  const MapNode(List<NodeKeyValuePair> input) : super(type: NodeType.map, input: null, children: input);
}

class DateNode extends Node<DateTime> {
  const DateNode(DateTime input) : super(type: NodeType.date, input: input, children: const []);
}

class DataNode extends Node<Uint8List> {
  const DataNode(Uint8List input) : super(type: NodeType.data, input: input, children: const []);
}