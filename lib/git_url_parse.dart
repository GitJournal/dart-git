library git_url_parse;

import 'package:meta/meta.dart';

@immutable
class GitUrlParseResult {
  final int port;
  final String resource;
  final String user;
  final String path;
  final String protocol;
  final String token;

  GitUrlParseResult({
    required this.port,
    required this.resource,
    required this.user,
    required this.path,
    required this.protocol,
    required this.token,
  });

  @override
  String toString() {
    return 'GitUrlParseResult(port: $port, resource: $resource, user: $user, path: $path, protocol: $protocol, token: $token)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GitUrlParseResult &&
        other.port == port &&
        other.resource == resource &&
        other.user == user &&
        other.path == path &&
        other.protocol == protocol &&
        other.token == token;
  }

  @override
  int get hashCode {
    return port.hashCode ^
        resource.hashCode ^
        user.hashCode ^
        path.hashCode ^
        protocol.hashCode ^
        token.hashCode;
  }
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
    protocol = isSshUrl(url) ? 'ssh' : 'file';
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
