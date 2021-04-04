// @dart=2.9

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:quiver/core.dart';

class GitHash {
  Uint8List _bytes;

  Uint8List get bytes => _bytes;

  GitHash.fromBytes(List<int> bytes) {
    if (bytes.length != 20) {
      throw Exception('Hash size must be 20');
    }
    _bytes = Uint8List.fromList(bytes);
  }

  GitHash(String sha) {
    if (sha.length != 40) {
      throw Exception('Hash size is not 40');
    }

    _bytes = Uint8List(20);
    var j = 0;
    for (var i = 0; i < sha.length; i += 2) {
      var hexChar = sha.substring(i, i + 2);
      var num = int.parse(hexChar, radix: 16);
      _bytes[j] = num;
      j++;
    }
  }

  GitHash.compute(List<int> data) {
    _bytes = sha1.convert(data).bytes;
  }

  GitHash.zero() {
    _bytes = Uint8List(0);
  }

  bool get isEmpty => _bytes.isEmpty;
  bool get isNotEmpty => _bytes.isNotEmpty;

  @override
  String toString() {
    if (isEmpty) {
      final _0 = '0'.codeUnitAt(0);
      var codes = List<int>.filled(40, _0);
      return String.fromCharCodes(codes);
    }

    var buf = StringBuffer();
    for (var i = 0; i < _bytes.length; i++) {
      var s = _bytes[i].toRadixString(16).padLeft(2, '0');
      buf.write(s);
    }
    return buf.toString();
  }

  String toOid() {
    var buf = StringBuffer();
    for (var i = 0; i < _bytes.length; i++) {
      var s = _bytes[i].toRadixString(16).padLeft(2, '0');
      buf.write(s);

      if (buf.length >= 7) {
        break;
      }
    }
    return buf.toString().substring(0, 7);
  }

  @override
  bool operator ==(Object other) {
    if (other is! GitHash) return false;
    return _listEq(_bytes, (other as GitHash)._bytes);
  }

  @override
  int get hashCode => hashObjects(_bytes);

  static final Function _listEq = const ListEquality().equals;
}
