import 'package:test/test.dart';

import 'package:dart_git/plumbing/git_hash.dart';

void main() {
  test('Equality', () {
    var a = GitHash('31a7e081a28f149ee98ffd13ba1a6d841a5f46fd');
    var b = GitHash('31a7e081a28f149ee98ffd13ba1a6d841a5f46fd');
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    var c = GitHash.fromBytes(a.bytes);
    expect(c, b);
    expect(c.hashCode, b.hashCode);

    var d = GitHash(a.toString());
    expect(d, b);
    expect(d.hashCode, b.hashCode);
  });

  test('Zero Equality', () {
    expect(GitHash.zero(), GitHash.zero());

    var zero = GitHash('0000000000000000000000000000000000000000');
    expect(zero, GitHash.zero());
  });
}
