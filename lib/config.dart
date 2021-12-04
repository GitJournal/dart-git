import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/reference.dart';

class BranchConfig {
  final String name;
  String? remote;
  ReferenceName? merge;

  BranchConfig({required this.name, this.remote, this.merge});

  @override
  String toString() => 'Branch{name: $name, remote: $remote, merge: $merge}';

  String? trackingBranch() => merge?.branchName();
  String remoteTrackingBranch() => '$remote/${trackingBranch()}';
}

class GitRemoteConfig {
  final String name;
  final String url;
  final String fetch; // This should be a refspec

  GitRemoteConfig({
    required this.name,
    required this.url,
    required this.fetch,
  });
  GitRemoteConfig.create({required this.name, required this.url})
      : fetch = '+refs/heads/*:refs/remotes/$name/*';
}

class Config {
  bool? bare;
  Map<String, BranchConfig> branches = {};
  List<GitRemoteConfig> remotes = [];

  GitAuthor? user;

  late ConfigFile configFile;

  Config(String raw) {
    configFile = ConfigFile.parse(raw);
    for (var section in configFile.sections) {
      switch (section.name) {
        case 'branch':
          section.sections.forEach(_parseBranch);
          break;
        case 'remote':
          section.sections.forEach(_parseRemote);
          break;
        case 'user':
          _parseUser(section);
          break;
        case 'core':
          _parseCore(section);
          break;
      }
    }
  }

  BranchConfig? branch(String name) => branches[name];

  GitRemoteConfig? remote(String name) {
    return remotes.firstWhereOrNull((r) => r.name == name);
  }

  void _parseBranch(Section section) {
    var remote = '';
    ReferenceName? merge;

    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'remote':
          remote = entry.value;
          break;
        case 'merge':
          merge = ReferenceName(entry.value);
          break;
      }
    }

    branches[section.name] = BranchConfig(
      name: section.name,
      remote: remote,
      merge: merge,
    );
  }

  void _parseRemote(Section section) {
    var url = '';
    var fetch = '';

    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'url':
          url = entry.value;
          break;
        case 'fetch':
          fetch = entry.value;
          break;
      }
    }

    remotes.add(GitRemoteConfig(name: section.name, url: url, fetch: fetch));
  }

  void _parseUser(Section section) {
    var name = '';
    var email = '';
    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'name':
          name = entry.value;
          break;
        case 'email':
          email = entry.value;
          break;
      }
    }

    // The date doesn't matter
    user = GitAuthor(name: name, email: email);
  }

  void _parseCore(Section section) {
    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'bare':
          bare = entry.value == 'true';
          break;
      }
    }
  }

  String serialize() {
    // Remotes
    var remoteSection = getOrCreateSection('remote');
    var serializedRemotes = <String>{};
    for (var remote in remotes) {
      var rs = remoteSection.getOrCreateSection(remote.name);
      rs.options['url'] = remote.url;
      rs.options['fetch'] = remote.fetch;

      var _ = serializedRemotes.add(remote.name);
    }
    remoteSection.keepSections(serializedRemotes);

    // Branches
    var branchSection = getOrCreateSection('branch');
    var serializedBranches = <String>{};
    for (var branch in branches.values) {
      var bs = branchSection.getOrCreateSection(branch.name);
      if (branch.remote != null) {
        bs.options['remote'] = branch.remote!;
      }
      if (branch.merge != null) {
        bs.options['merge'] = branch.merge.toString();
        assert(branch.merge!.isBranch());
      }

      if (serializedRemotes.contains(branch.remote)) {
        var _ = serializedBranches.add(branch.name);
      }
    }
    branchSection.keepSections(serializedBranches);

    // Core
    if (bare != null) {
      var coreSection = getOrCreateSection('core');
      coreSection.options['bare'] = bare.toString();
    }

    // User
    if (user != null) {
      var sec = getOrCreateSection('user');
      sec.options['name'] = user!.name;
      sec.options['email'] = user!.email;
    }

    return configFile.serialize();
  }

  Section getOrCreateSection(String name) {
    assert(!name.contains(' '), "Section Names cannot contain spaces");

    var i = configFile.sections.indexWhere((s) => s.name == name);
    if (i == -1) {
      var s = Section(name);
      configFile.sections.add(s);
      return s;
    }

    return configFile.sections[i];
  }
}

Function _listEq = const ListEquality().equals;
Function _mapEq = const MapEquality().equals;

class Section {
  String name;
  Map<String, String> options = {};
  List<Section> sections = [];

  Section(this.name);

  bool get isEmpty => options.isEmpty && sections.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Section getOrCreateSection(String name) {
    var i = sections.indexWhere((s) => s.name == name);
    if (i == -1) {
      var s = Section(name);
      sections.add(s);
      return s;
    }

    return sections[i];
  }

  void keepSections(Set<String> names) {
    sections = sections.where((s) => names.contains(s.name)).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Section &&
          name == other.name &&
          _mapEq(options, other.options) &&
          _listEq(sections, other.sections);

  @override
  int get hashCode => name.hashCode ^ options.hashCode ^ sections.hashCode;

  void _writeSectionProps(StringBuffer buffer) {
    options.forEach((key, val) {
      buffer.write('\t');
      buffer.write('$key = $val\n');
    });
  }

  void write(StringBuffer buffer) {
    if (sections.isEmpty) {
      if (options.isEmpty) {
        return;
      }
      buffer.write('[$name]\n');
      _writeSectionProps(buffer);
      buffer.write('\n');
      return;
    }

    for (var subSec in sections) {
      assert(subSec.sections.isEmpty);
      buffer.write('[$name "${subSec.name}"]\n');
      subSec._writeSectionProps(buffer);
      buffer.write('\n');
    }
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    write(buffer);
    return buffer.toString();
  }
}

class ConfigFile {
  List<Section> sections = [];

  static final RegExp _blankLinePattern = RegExp(r'^\s*$');
  static final RegExp _commentPattern = RegExp(r'^\s*[;#]');
  static final RegExp _sectionPattern = RegExp(r'^\s*\[([^\]]+)]\s*$');
  static final RegExp _entryPattern = RegExp(r'^([^=]+)=(.*?)$');

  static ConfigFile parse(String content) {
    var config = ConfigFile();
    Section? currentSection;

    for (var line in LineSplitter.split(content)) {
      RegExpMatch? match;
      match = _commentPattern.firstMatch(line);
      if (match != null) {
        continue;
      }

      match = _blankLinePattern.firstMatch(line);
      if (match != null) {
        continue;
      }

      match = _sectionPattern.firstMatch(line);
      if (match != null) {
        assert(match.groupCount == 1);

        currentSection = null;
        var name = match.group(1)!;
        var sectionNames = name.split(' ');

        assert(sectionNames.length <= 2);
        for (var i = 0; i < sectionNames.length; i++) {
          var sectionName = sectionNames[i];
          if (i != 0) {
            assert(sectionName.startsWith('"'), 'Section name: $sectionName');
            assert(sectionName.endsWith('"'), 'Section name: $sectionName');
            sectionName = sectionName.substring(1, sectionName.length - 1);
          }

          var section = config.sections.firstWhereOrNull(
            (s) => s.name == sectionName,
          );
          if (section == null) {
            section = Section(sectionName);
            if (currentSection == null) {
              config.sections.add(section);
            } else {
              currentSection.sections.add(section);
            }
          }

          currentSection = section;
        }
        continue;
      }

      match = _entryPattern.firstMatch(line);
      if (match != null) {
        assert(currentSection != null);
        assert(match.groupCount == 2);

        var key = match[1]!.trim();
        var value = match[2]!.trim();
        currentSection!.options[key] = value;
        continue;
      }
    }

    return config;
  }

  String serialize() {
    var buffer = StringBuffer();

    for (var s in sections) {
      s.write(buffer);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigFile && _listEq(sections, other.sections);

  @override
  int get hashCode => Object.hashAll(sections);

  @override
  String toString() => serialize();
}
