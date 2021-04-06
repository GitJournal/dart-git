import 'package:test/test.dart';

import 'package:dart_git/git_url_parse.dart';

var INPUT = <String, GitUrlParseResult>{
  // Secure Shell Transport Protocol (SSH)
  'ssh://user@host.xz:42/path/to/repo.git/': GitUrlParseResult(
    port: 42,
    resource: 'host.xz',
    user: 'user',
    path: '/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'git+ssh://git@host.xz/path/name.git': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'git',
    path: '/path/name.git',
    protocol: 'git+ssh',
    token: '',
  ),

  'ssh://user@host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'user',
    path: '/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'ssh://host.xz:5497/path/to/repo.git/': GitUrlParseResult(
    port: 5497,
    resource: 'host.xz',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'ssh://host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'git@domain.xxx.com:42foo/bar.git': GitUrlParseResult(
    port: -1,
    resource: 'domain.xxx.com',
    user: 'git',
    path: '42foo/bar.git',
    protocol: 'ssh',
    token: '',
  ),

  'ssh://user@host.xz/~user/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'user',
    path: '/~user/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'ssh://host.xz/~user/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/~user/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'ssh://user@host.xz/~/path/to/repo.git': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'user',
    path: '/~/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'ssh://host.xz/~/path/to/repo.git': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/~/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'user@host.xz:/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'user',
    path: '/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'user@host.xz:~user/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'user',
    path: '~user/path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'user@host.xz:path/to/repo.git': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'user',
    path: 'path/to/repo.git',
    protocol: 'ssh',
    token: '',
  ),

  'rsync://host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'rsync',
    token: '',
  ),

  // Git Transport Protocol

  'git://host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'git',
    token: '',
  ),

  'git://host.xz/~user/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/~user/path/to/repo.git',
    protocol: 'git',
    token: '',
  ),

  // HTTP/S Transport Protocol
  'http://host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'http',
    token: '',
  ),

  'https://host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'https',
    token: '',
  ),

  'https://token:x-oauth-basic@host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'token:x-oauth-basic',
    path: '/path/to/repo.git',
    token: 'token',
    protocol: 'https',
  ),

  'https://x-token-auth:token@host.xz/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'x-token-auth:token',
    path: '/path/to/repo.git',
    token: 'token',
    protocol: 'https',
  ),

  'https://user@bitbucket.org/user/repo': GitUrlParseResult(
    port: -1,
    resource: 'bitbucket.org',
    user: 'user',
    path: '/user/repo',
    protocol: 'https',
    token: '',
  ),

  'https://user@organization.git.cloudforge.com/name.git': GitUrlParseResult(
    port: -1,
    resource: 'organization.git.cloudforge.com',
    user: 'user',
    path: '/name.git',
    protocol: 'https',
    token: '',
  ),

  'https://token:x-oauth-basic@github.com/owner/name.git': GitUrlParseResult(
    port: -1,
    resource: 'github.com',
    user: 'token:x-oauth-basic',
    path: '/owner/name.git',
    protocol: 'https',
    token: 'token',
  ),

  'https://x-token-auth:token@bitbucket.org/owner/name.git': GitUrlParseResult(
    port: -1,
    resource: 'bitbucket.org',
    user: 'x-token-auth:token',
    path: '/owner/name.git',
    protocol: 'https',
    token: 'token',
  ),

  '/path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: '',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'file',
    token: '',
  ),

  'path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: '',
    user: '',
    path: 'path/to/repo.git',
    protocol: 'file',
    token: '',
  ),

  '~/path/to/repo.git': GitUrlParseResult(
    port: -1,
    resource: '',
    user: '',
    path: '~/path/to/repo.git',
    protocol: 'file',
    token: '',
  ),

  'file:///path/to/repo.git/': GitUrlParseResult(
    port: -1,
    resource: '',
    user: '',
    path: '/path/to/repo.git',
    protocol: 'file',
    token: '',
  ),

  'git@host.xz:path/name.git': GitUrlParseResult(
    port: -1,
    resource: 'host.xz',
    user: 'git',
    path: 'path/name.git',
    protocol: 'ssh',
    token: '',
  ),

  /*
  'git@github.com/vhanda/journal.git': GitUrlParseResult(
    port: -1,
    resource: 'github.com',
    user: 'git',
    path: 'vhanda/journal.git',
    protocol: 'ssh',
    token: '',
  ),
  */
};

void main() {
  group('all', () {
    INPUT.forEach((String url, GitUrlParseResult result) {
      test(url, () {
        expect(gitUrlParse(url), result);
      });
    });
  });
}
