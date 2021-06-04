import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:diff_match_patch/src/diff.dart';

var a = '''Gujarat
Uttar Pradesh
Kolkata
Bihar
Jammu and Kashmir
''';

var b = '''Tamil Nadu
Gujarat
Andhra Pradesh
Bihar
Uttar pradesh
''';

void main() {
  // Characters
  var dmp = DiffMatchPatch();
  var d = dmp.diff('Hello World.', 'Goodbye World.');
  dmp.diffCleanupSemantic(d);
  // Result: [(-1, "Hello"), (1, "Goodbye"), (0, " World.")]
  print(d);

  // Lines
  var dmp2 = DiffMatchPatch();
  var res = linesToChars(a, b);
  /*
  var lineText1 = res['chars1'];
  var lineText2 = res['chars2'];
  var lineArray = res['lineArray'];
  */

  print(dmp2);
  print('res $res');
}

// FIXME: How to convert this to lines?
