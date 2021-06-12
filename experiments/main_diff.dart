import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:diff_match_patch/src/diff.dart';

var a = '''one
two
three
''';

var b = '''one
three
four
''';

void main() {
  var res = linesToChars(a, b);
  var chars1 = res['chars1'] as String;
  var chars2 = res['chars2'] as String;
  var lineArray = res['lineArray'] as List<String>;
  print(chars1.codeUnits);
  print(chars2.codeUnits);
  print(lineArray);

  var dmp = DiffMatchPatch();
  var diffObjects = dmp.diff(chars1, chars2);
  charsToLines(diffObjects, lineArray);

  print(diffObjects);
}
