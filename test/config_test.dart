import 'package:dart_git/config.dart';
import 'package:test/test.dart';

void main() {
  test('Config Branches Test', () async {
    var contents = '''[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[remote "origin"]
	url = https://github.com/src-d/go-git.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
	remote = origin
	merge = refs/heads/master
[user]
	name = Mona Lisa
''';

    var config = Config(contents);
    expect(config.branches.length, 1);

    var master = config.branches['master'];
    expect(master.name, 'master');
    expect(master.remote, 'origin');
    expect(master.merge.value, 'refs/heads/master');
  });
}
