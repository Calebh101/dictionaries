import 'package:dictionaries/object/main.dart';
import 'package:flutter/material.dart';

class ObjectEditorPreview extends StatefulWidget {
  final ObjectType type;
  const ObjectEditorPreview({super.key, required this.type});

  @override
  State<ObjectEditorPreview> createState() => _ObjectEditorPreviewState();
}

class _ObjectEditorPreviewState extends State<ObjectEditorPreview> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}