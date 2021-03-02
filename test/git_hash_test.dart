import 'package:dart_git/git_hash.dart';
import 'package:test/test.dart';

void main() {
  test('Equality', () {
    var a = GitHash('31a7e081a28f149ee98ffd13ba1a6d841a5f46fd');
    var b = GitHash('31a7e081a28f149ee98ffd13ba1a6d841a5f46fd');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
