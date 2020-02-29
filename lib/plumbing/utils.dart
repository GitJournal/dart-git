import 'dart:typed_data';

Uint8List shaToBytes(String sha) {
  var bytes = Uint8List(20);
  var j = 0;
  for (var i = 0; i < sha.length; i += 2) {
    var hexChar = sha.substring(i, i + 2);
    var num = int.parse(hexChar, radix: 16);
    bytes[j] = num;
    j++;
  }

  return bytes;
}

String shaBytesToString(List<int> sha) {
  var buf = StringBuffer();
  for (var i = 0; i < sha.length; i++) {
    var s = sha[i].toRadixString(16).padLeft(2, '0');
    buf.write(s);
  }
  return buf.toString();
}
