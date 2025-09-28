import 'package:dictionaries/object/nodes.dart';
import 'package:flutter/material.dart';

class ObjectEditor extends StatefulWidget {
  const ObjectEditor({super.key});

  @override
  State<ObjectEditor> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditor> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class EditorTreeNode {
  final String title;
  final NodeType type;
  final List<EditorTreeNode> children;

  const EditorTreeNode({required this.title, required this.type, this.children = const []});
}