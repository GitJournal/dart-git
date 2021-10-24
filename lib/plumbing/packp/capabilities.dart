import 'dart:convert';
import 'dart:typed_data';

import 'capability.dart';

export 'capability.dart';

class Capabilities {
  var map = <String, List<String>>{};

  static Capabilities decodeString(String input) =>
      Capabilities.decode(Uint8List.fromList(utf8.encode(input)));

  Capabilities.decode(Uint8List bytes) {
    // foo
  }

  Capabilities();

  List<String>? get(String key) => map[key];
  int get length => map.length;
  bool supports(String key) => map.containsKey(key);

  void set(String key, String value) {
    map[key] = [value];
  }

  void add(String key, String value) {
    var v = map[key];
    if (v == null) {
      map[key] = [value];
    } else {
      v.add(value);
      map[key] = v;
    }
  }

  void enable(String key) {
    map[key] = [];
  }

  String encode() {
    return '';
  }
}

class CapabilitiesArgumentRequiredException {
  final String key;
  CapabilitiesArgumentRequiredException(this.key);
}

class CapabilitiesArgumentsNotAllowedException {
  final String key;
  CapabilitiesArgumentsNotAllowedException(this.key);
}

class CapabilitiesEmptyArgumentException {
  final String key;
  CapabilitiesEmptyArgumentException(this.key);
}

class CapabilitiesMultipleArgumentsException {
  final String key;
  CapabilitiesMultipleArgumentsException(this.key);
}

var known = {
  Capability.MultiACK,
  Capability.MultiACKDetailed,
  Capability.NoDone,
  Capability.ThinPack,
  Capability.Sideband,
  Capability.Sideband64k,
  Capability.OFSDelta,
  Capability.Agent,
  Capability.Shallow,
  Capability.DeepenSince,
  Capability.DeepenNot,
  Capability.DeepenRelative,
  Capability.NoProgress,
  Capability.IncludeTag,
  Capability.ReportStatus,
  Capability.DeleteRefs,
  Capability.Quiet,
  Capability.Atomic,
  Capability.PushOptions,
  Capability.AllowTipSHA1InWant,
  Capability.AllowReachableSHA1InWant,
  Capability.PushCert,
  Capability.SymRef,
};

var requiresArguments = {
  Capability.Agent,
  Capability.PushCert,
  Capability.SymRef,
};

var multipleArgument = {
  Capability.SymRef,
};
