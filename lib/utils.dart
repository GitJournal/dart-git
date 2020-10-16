import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

/// Splits path into 2 strings 'a/b/c' -> 'a' 'b/c'
Tuple2<String, String> splitPath(String str) {
  var i = str.indexOf(p.separator);
  if (i == -1) {
    return Tuple2(str, '');
  }
  if (i == str.length - 1) {
    return Tuple2(str.substring(0, str.length - 1), '');
  }

  return Tuple2(str.substring(0, i), str.substring(i + 1));
}
