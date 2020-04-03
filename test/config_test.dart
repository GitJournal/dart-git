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

[branch "foo"]
	remote = origin
	merge = refs/heads/master
[user]
	name = Mona Lisa
	email = mona@lisa.com
''';

    var config = Config(contents);
    expect(config.branches.length, 2);

    var branch = config.branches['master'];
    expect(branch.name, 'master');
    expect(branch.remote, 'origin');
    expect(branch.merge.value, 'refs/heads/master');

    branch = config.branches['foo'];
    expect(branch.name, 'foo');
    expect(branch.remote, 'origin');
    expect(branch.merge.value, 'refs/heads/master');

    expect(config.remotes.length, 1);
    var remote = config.remotes[0];
    expect(remote.name, 'origin');
    expect(remote.url, 'https://github.com/src-d/go-git.git');
    expect(remote.fetch, '+refs/heads/*:refs/remotes/origin/*');

    expect(config.user.name, 'Mona Lisa');
    expect(config.user.email, 'mona@lisa.com');
  });
}
