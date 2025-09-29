import 'dart:convert';
import 'dart:typed_data';

Object transformMap(String raw) {
  Object input = jsonDecode(raw);

  Object? process(Object? input) {
    if (input is String) {
      DateTime? date = DateTime.tryParse(input);
      if (date != null) return date;

      try {
        Uint8List bytes = base64Decode(input);
        return bytes;
      } catch (_) {}
    } else if (input is Map) {
      for (String key in input.keys) {
        input[key] = process(input[key]);
      }
    } else if (input is List) {
      for (var item in input) {
        item = process(item);
      }
    }

    return input;
  }

  return process(input)!;
}