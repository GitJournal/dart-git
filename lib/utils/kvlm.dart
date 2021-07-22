import 'dart:convert';
import 'dart:typed_data';

import 'package:charcode/charcode.dart';

import 'package:dart_git/utils/ascii_helper.dart';
import 'package:dart_git/utils/uint8list.dart';

Map<String, dynamic> kvlmParse(Uint8List raw) {
  var dict = <String, dynamic>{};

  var start = 0;
  while (true) {
    var spaceIndex = raw.indexOf($space, start);
    var newLineIndex = raw.indexOf($newLine, start);

    if (spaceIndex == -1 && newLineIndex == -1) {
      break;
    }

    if (newLineIndex < spaceIndex || spaceIndex == -1) {
      assert(newLineIndex == start);

      dict['_'] = utf8.decode(raw.sublistView(start + 1));
      break;
    }

    var key = raw.sublistView(start, spaceIndex);
    var end = spaceIndex;
    while (true) {
      end = raw.indexOf($newLine, end + 1);
      if (raw[end + 1] != $space) {
        break;
      }
    }

    var value = raw.sublistView(spaceIndex + 1, end);
    var valueStr = utf8.decode(value).replaceAll('\n ', '\n');

    var keyStr = utf8.decode(key);
    if (dict.containsKey(keyStr)) {
      var dictVal = dict[keyStr];
      if (dictVal is List) {
        dict[keyStr] = [...dictVal, valueStr];
      } else {
        dict[keyStr] = [dictVal, valueStr];
      }
    } else {
      dict[keyStr] = valueStr;
    }

    start = end + 1;
  }

  return dict;
}

Uint8List kvlmSerialize(Map<String, dynamic> kvlm) {
  var bytesBuilder = BytesBuilder(copy: false);

  kvlm.forEach((key, val) {
    if (key == '_') {
      return;
    }

    if (val is! List) {
      val = [val];
    }

    for (var v in val) {
      bytesBuilder
        ..add(utf8.encode(key))
        ..addByte($space)
        ..add(utf8.encode(v.replaceAll('\n', '\n ')))
        ..addByte($newLine);
    }
  });

  bytesBuilder
    ..addByte($newLine)
    ..add(utf8.encode(kvlm['_']));
  return bytesBuilder.toBytes();
}
