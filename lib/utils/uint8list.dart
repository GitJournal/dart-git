import 'dart:typed_data';

extension View on Uint8List {
  Uint8List sublistView(int start, [int? end]) {
    return Uint8List.sublistView(this, start, end);
  }
}
