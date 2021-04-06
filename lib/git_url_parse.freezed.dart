// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides

part of git_url_parse;

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
class _$GitUrlParseResultTearOff {
  const _$GitUrlParseResultTearOff();

  _GitUrlParseResult call(
      {required int port,
      required String resource,
      required String user,
      required String path,
      required String protocol,
      required String token}) {
    return _GitUrlParseResult(
      port: port,
      resource: resource,
      user: user,
      path: path,
      protocol: protocol,
      token: token,
    );
  }
}

/// @nodoc
const $GitUrlParseResult = _$GitUrlParseResultTearOff();

/// @nodoc
mixin _$GitUrlParseResult {
  int get port => throw _privateConstructorUsedError;
  String get resource => throw _privateConstructorUsedError;
  String get user => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  String get protocol => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GitUrlParseResultCopyWith<GitUrlParseResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GitUrlParseResultCopyWith<$Res> {
  factory $GitUrlParseResultCopyWith(
          GitUrlParseResult value, $Res Function(GitUrlParseResult) then) =
      _$GitUrlParseResultCopyWithImpl<$Res>;
  $Res call(
      {int port,
      String resource,
      String user,
      String path,
      String protocol,
      String token});
}

/// @nodoc
class _$GitUrlParseResultCopyWithImpl<$Res>
    implements $GitUrlParseResultCopyWith<$Res> {
  _$GitUrlParseResultCopyWithImpl(this._value, this._then);

  final GitUrlParseResult _value;
  // ignore: unused_field
  final $Res Function(GitUrlParseResult) _then;

  @override
  $Res call({
    Object? port = freezed,
    Object? resource = freezed,
    Object? user = freezed,
    Object? path = freezed,
    Object? protocol = freezed,
    Object? token = freezed,
  }) {
    return _then(_value.copyWith(
      port: port == freezed
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      resource: resource == freezed
          ? _value.resource
          : resource // ignore: cast_nullable_to_non_nullable
              as String,
      user: user == freezed
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      path: path == freezed
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      protocol: protocol == freezed
          ? _value.protocol
          : protocol // ignore: cast_nullable_to_non_nullable
              as String,
      token: token == freezed
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
abstract class _$GitUrlParseResultCopyWith<$Res>
    implements $GitUrlParseResultCopyWith<$Res> {
  factory _$GitUrlParseResultCopyWith(
          _GitUrlParseResult value, $Res Function(_GitUrlParseResult) then) =
      __$GitUrlParseResultCopyWithImpl<$Res>;
  @override
  $Res call(
      {int port,
      String resource,
      String user,
      String path,
      String protocol,
      String token});
}

/// @nodoc
class __$GitUrlParseResultCopyWithImpl<$Res>
    extends _$GitUrlParseResultCopyWithImpl<$Res>
    implements _$GitUrlParseResultCopyWith<$Res> {
  __$GitUrlParseResultCopyWithImpl(
      _GitUrlParseResult _value, $Res Function(_GitUrlParseResult) _then)
      : super(_value, (v) => _then(v as _GitUrlParseResult));

  @override
  _GitUrlParseResult get _value => super._value as _GitUrlParseResult;

  @override
  $Res call({
    Object? port = freezed,
    Object? resource = freezed,
    Object? user = freezed,
    Object? path = freezed,
    Object? protocol = freezed,
    Object? token = freezed,
  }) {
    return _then(_GitUrlParseResult(
      port: port == freezed
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      resource: resource == freezed
          ? _value.resource
          : resource // ignore: cast_nullable_to_non_nullable
              as String,
      user: user == freezed
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      path: path == freezed
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      protocol: protocol == freezed
          ? _value.protocol
          : protocol // ignore: cast_nullable_to_non_nullable
              as String,
      token: token == freezed
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
class _$_GitUrlParseResult implements _GitUrlParseResult {
  _$_GitUrlParseResult(
      {required this.port,
      required this.resource,
      required this.user,
      required this.path,
      required this.protocol,
      required this.token});

  @override
  final int port;
  @override
  final String resource;
  @override
  final String user;
  @override
  final String path;
  @override
  final String protocol;
  @override
  final String token;

  @override
  String toString() {
    return 'GitUrlParseResult(port: $port, resource: $resource, user: $user, path: $path, protocol: $protocol, token: $token)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _GitUrlParseResult &&
            (identical(other.port, port) ||
                const DeepCollectionEquality().equals(other.port, port)) &&
            (identical(other.resource, resource) ||
                const DeepCollectionEquality()
                    .equals(other.resource, resource)) &&
            (identical(other.user, user) ||
                const DeepCollectionEquality().equals(other.user, user)) &&
            (identical(other.path, path) ||
                const DeepCollectionEquality().equals(other.path, path)) &&
            (identical(other.protocol, protocol) ||
                const DeepCollectionEquality()
                    .equals(other.protocol, protocol)) &&
            (identical(other.token, token) ||
                const DeepCollectionEquality().equals(other.token, token)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(port) ^
      const DeepCollectionEquality().hash(resource) ^
      const DeepCollectionEquality().hash(user) ^
      const DeepCollectionEquality().hash(path) ^
      const DeepCollectionEquality().hash(protocol) ^
      const DeepCollectionEquality().hash(token);

  @JsonKey(ignore: true)
  @override
  _$GitUrlParseResultCopyWith<_GitUrlParseResult> get copyWith =>
      __$GitUrlParseResultCopyWithImpl<_GitUrlParseResult>(this, _$identity);
}

abstract class _GitUrlParseResult implements GitUrlParseResult {
  factory _GitUrlParseResult(
      {required int port,
      required String resource,
      required String user,
      required String path,
      required String protocol,
      required String token}) = _$_GitUrlParseResult;

  @override
  int get port => throw _privateConstructorUsedError;
  @override
  String get resource => throw _privateConstructorUsedError;
  @override
  String get user => throw _privateConstructorUsedError;
  @override
  String get path => throw _privateConstructorUsedError;
  @override
  String get protocol => throw _privateConstructorUsedError;
  @override
  String get token => throw _privateConstructorUsedError;
  @override
  @JsonKey(ignore: true)
  _$GitUrlParseResultCopyWith<_GitUrlParseResult> get copyWith =>
      throw _privateConstructorUsedError;
}
