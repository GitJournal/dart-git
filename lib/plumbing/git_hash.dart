import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import 'package:dart_git/exceptions.dart';

class GitHash implements Comparable<GitHash> {
  late Uint8List _bytes;

  Uint8List get bytes => _bytes;

  GitHash.fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      _bytes = Uint8List(0);
      return;
    }

    if (bytes.length != 20) {
      throw Exception('Hash size must be 20');
    }
    _bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  GitHash(String sha) {
    if (sha.length != 40) {
      throw Exception('Hash size is not 40');
    }

    _bytes = Uint8List(20);
    var j = 0;
    for (var i = 0; i < sha.length; i += 2) {
      var hexChar = sha.substring(i, i + 2);
      var num = int.tryParse(hexChar, radix: 16);
      if (num == null) {
        throw GitHashStringNotHexadecimal();
      }
      _bytes[j] = num;
      j++;
    }
  }

  GitHash.compute(List<int> data) {
    _bytes = sha1.convert(data).bytes as Uint8List;
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

  /// Only returns the first 7 characters of the hash
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
    if (_bytes.isEmpty && other._bytes.isEmpty) {
      return true;
    } else if (_bytes.isEmpty && other._bytes.isNotEmpty) {
      return other._bytes.every((e) => e == 0);
    } else if (_bytes.isNotEmpty && other._bytes.isEmpty) {
      return _bytes.every((e) => e == 0);
    }
    return _listEq(_bytes, other._bytes);
  }

  @override
  int get hashCode => Object.hashAll(_bytes);

  static final Function _listEq = const ListEquality().equals;

  @override
  int compareTo(GitHash other) {
    if (isEmpty) {
      if (other.isEmpty) return 0;
      return -1;
    } else if (other.isEmpty) {
      return 0;
    }

    for (var i = 0; i < 20; i++) {
      if (bytes[i] == other.bytes[i]) continue;
      return bytes[i].compareTo(other.bytes[i]);
    }

    return 0;
  }
}
