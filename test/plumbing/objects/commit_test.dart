import 'dart:convert';
import 'dart:typed_data';

import 'package:file/local.dart';
import 'package:test/test.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/storage/object_storage_fs.dart';
import 'package:dart_git/utils/result.dart';

void main() {
  var contents = '''tree 272aca6dd8feabd4affc881c6cad18f396189344
parent 69cf15d1783f903287d0bebc870e11b2992bc4f6
author Vishesh Handa <me@vhanda.in> 1600114796 +0200
committer Vishesh Handa <me@vhanda.in> 1600114796 +0200

git status: Make it behave more like the real git status

Also add tons of comments
''';

  test('Git Commit', () async {
    const fs = LocalFileSystem();
    var objStorage = ObjectStorageFS('', fs);

    var obj = await objStorage
        .readObjectFromPath('test/data/commit-object')
        .getOrThrow();
    var hash = GitHash('57bdd0dbc9868e53aead3c91714c282647265254');

    expect(obj is GitCommit, true);
    var commitObj = obj as GitCommit;

    expect(commitObj.author.email, 'me@vhanda.in');
    expect(commitObj.author.name, 'Vishesh Handa');
    expect(commitObj.author.date, DateTime.utc(2020, 9, 14, 20, 19, 56));
    expect(commitObj.author.timezoneOffset, 200);

    expect(commitObj.committer.email, 'me@vhanda.in');
    expect(commitObj.committer.name, 'Vishesh Handa');
    expect(commitObj.committer.date, DateTime.utc(2020, 9, 14, 20, 19, 56));
    expect(commitObj.committer.timezoneOffset, 200);

    expect(commitObj.treeHash,
        GitHash('272aca6dd8feabd4affc881c6cad18f396189344'));
    expect(commitObj.message,
        'git status: Make it behave more like the real git status\n\nAlso add tons of comments\n');
    expect(commitObj.parents,
        [GitHash('69cf15d1783f903287d0bebc870e11b2992bc4f6')]);

    expect(utf8.decode(commitObj.serializeData()), contents);
    expect(commitObj.hash, hash);
  });

  test('Commit with GPG', () {
    var rawStr = '''tree 29ff16c9c14e2652b22f8b78bb08a5a07930c147
parent 206941306e8a8af65b66eaaaea388a7ae24d49a0
parent 206941306e8a8af65b66eaaaea388a7ae24d49a2
author Thibault Polge <thibault@thb.lt> 1527025023 +0200
committer Thibault Polge <thibault@thb.lt> 1527025044 +0200
gpgsig -----BEGIN PGP SIGNATURE-----
 iQIzBAABCAAdFiEExwXquOM8bWb4Q2zVGxM2FxoLkGQFAlsEjZQACgkQGxM2FxoL
 kGQdcBAAqPP+ln4nGDd2gETXjvOpOxLzIMEw4A9gU6CzWzm+oB8mEIKyaH0UFIPh
 rNUZ1j7/ZGFNeBDtT55LPdPIQw4KKlcf6kC8MPWP3qSu3xHqx12C5zyai2duFZUU
 wqOt9iCFCscFQYqKs3xsHI+ncQb+PGjVZA8+jPw7nrPIkeSXQV2aZb1E68wa2YIL
 3eYgTUKz34cB6tAq9YwHnZpyPx8UJCZGkshpJmgtZ3mCbtQaO17LoihnqPn4UOMr
 V75R/7FjSuPLS8NaZF4wfi52btXMSxO/u7GuoJkzJscP3p4qtwe6Rl9dc1XC8P7k
 NIbGZ5Yg5cEPcfmhgXFOhQZkD0yxcJqBUcoFpnp2vu5XJl2E5I/quIyVxUXi6O6c
 /obspcvace4wy8uO0bdVhc4nJ+Rla4InVSJaUaBeiHTW8kReSFYyMmDCzLjGIu1q
 doU61OM3Zv1ptsLu3gUE6GU27iWYj2RWN3e3HE4Sbd89IFwLXNdSuM0ifDLZk7AQ
 WBhRhipCCgZhkj9g2NEk7jRVslti1NdN5zoQLaJNqSwO1MtxTmJ15Ksk3QP6kfLB
 Q52UWybBzpaP9HEd4XnR+HuQ4k2K0ns2KgNImsNvIyFwbpMUyUWLMPimaV1DWUXo
 5SBjDB/V/W2JBFR+XKHFJeFwYhj7DD/ocsGr4ZMx/lgc8rjIBkI=
 =lgTX
 -----END PGP SIGNATURE-----

Create first draft''';

    var commitObj = GitCommit.parse(utf8.encode(rawStr) as Uint8List, null)!;
    expect(utf8.decode(commitObj.serializeData()), rawStr);
  });

  test('Author Parse', () {
    var str = 'Vishesh Handa <me@vhanda.in> 1600114796 -0800';
    var author = GitAuthor.parse(str)!;

    expect(author.name, 'Vishesh Handa');
    expect(author.email, 'me@vhanda.in');
    expect(author.date, DateTime.utc(2020, 9, 14, 20, 19, 56));
    expect(author.timezoneOffset, -800);

    expect(author.serialize(), str);
  });

  test('Author Serialize', () {
    var author = GitAuthor(
      name: 'Vishesh Handa',
      email: 'me@vhanda.in',
      date: DateTime.utc(2020, 9, 14, 20, 19, 56),
      timezoneOffset: -800,
    );

    var str = 'Vishesh Handa <me@vhanda.in> 1600114796 -0800';
    expect(author.serialize(), str);
  });

  test('Author Serialize negative', () {
    var author = GitAuthor(
      name: 'Vishesh Handa',
      email: 'me@vhanda.in',
      date: DateTime.utc(2020, 9, 14, 20, 19, 56),
      timezoneOffset: 0,
    );

    var str = 'Vishesh Handa <me@vhanda.in> 1600114796 +0000';
    expect(author.serialize(), str);
  });
}
