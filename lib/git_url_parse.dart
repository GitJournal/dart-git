library git_url_parse;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'git_url_parse.freezed.dart';

@freezed
class GitUrlParseResult with _$GitUrlParseResult {
  factory GitUrlParseResult({
    required int port,
    required String resource,
    required String user,
    required String path,
    required String protocol,
    required String token,
  }) = _GitUrlParseResult;
}

GitUrlParseResult? gitUrlParse(String url) {
  var uri = Uri.tryParse(url);

  if (uri == null) {
    var pattern = '[A-Za-z][A-Za-z0-9+.-]*';
    if (!RegExp(pattern).hasMatch(url)) {
      return null;
    }

    var atIndexOf = url.indexOf('@');
    var colonIndexOf = url.indexOf(':');
    if (atIndexOf == -1 || colonIndexOf == -1) {
      return null;
    }
    if (atIndexOf > colonIndexOf) {
      return null;
    }

    var user = url.substring(0, atIndexOf);
    var host = url.substring(atIndexOf + 1, colonIndexOf);
    var path = url.substring(colonIndexOf + 1);

    // Remove trailing / if ends with .git
    if (path.endsWith('.git/')) {
      path = path.substring(0, path.length - 1);
    }

    return GitUrlParseResult(
      port: -1,
      resource: host,
      user: user,
      path: path,
      protocol: 'ssh',
      token: '',
    );
  }

  var token = '';

  if (uri.userInfo.isNotEmpty) {
    var splits = uri.userInfo.split(':');
    if (splits.length == 2) {
      if (splits[1] == 'x-oauth-basic') {
        token = splits[0];
      } else if (splits[0] == 'x-token-auth') {
        token = splits[1];
      }
    }
  }

  var protocol = uri.scheme;
  if (!uri.hasScheme) {
    if (isSshUrl(url)) {
      protocol = 'ssh';
    } else {
      protocol = 'file';
    }
  }

  // Remove trailing / if ends with .git
  var path = uri.path;
  if (path.endsWith('.git/')) {
    path = path.substring(0, path.length - 1);
  }

  return GitUrlParseResult(
    port: uri.hasPort ? uri.port : -1,
    resource: uri.host,
    user: uri.userInfo,
    path: path,
    protocol: protocol,
    token: token,
  );
}

bool isSshUrl(String url) {
  var pIndicatorIndex = url.indexOf('://');
  if (pIndicatorIndex != -1) {
    var protocols = url.substring(0, pIndicatorIndex).split('+');
    return protocols.contains('ssh') || protocols.contains('rsync');
  }

  // FIXME: Is there a better way?
  return url.indexOf('@') < url.indexOf(':');
}
