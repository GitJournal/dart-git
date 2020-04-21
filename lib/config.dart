import 'dart:convert';

import 'package:dart_git/branch.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/remote.dart';

class Config {
  bool bare;
  Map<String, Branch> branches = {};
  List<Remote> remotes = [];

  Author user;

  Config(String raw) {
    var configFile = ConfigFile.parse(raw);
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
      }
    }
  }

  void _parseBranch(Section section) {
    var branch = Branch();
    branch.name = section.name;

    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'remote':
          branch.remote = entry.value;
          break;
        case 'merge':
          branch.merge = ReferenceName(entry.value);
          break;
      }
    }

    branches[branch.name] = branch;
  }

  void _parseRemote(Section section) {
    var remote = Remote();
    remote.name = section.name;

    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'url':
          remote.url = entry.value;
          break;
        case 'fetch':
          remote.fetch = entry.value;
          break;
      }
    }

    remotes.add(remote);
  }

  void _parseUser(Section section) {
    user = Author();
    for (var entry in section.options.entries) {
      switch (entry.key) {
        case 'name':
          user.name = entry.value;
          break;
        case 'email':
          user.email = entry.value;
          break;
      }
    }
  }
}

class Section {
  String name;
  Map<String, String> options = {};
  List<Section> sections = [];

  Section(this.name);
}

class ConfigFile {
  List<Section> sections = [];

  static final RegExp _blankLinePattern = RegExp(r'^\s*$');
  static final RegExp _commentPattern = RegExp(r'^\s*[;#]');
  static final RegExp _sectionPattern = RegExp(r'^\s*\[([^\]]+)]\s*$');
  static final RegExp _entryPattern = RegExp(r'^([^=]+)=(.*?)$');

  static ConfigFile parse(String content) {
    var config = ConfigFile();
    Section currentSection;

    for (var line in LineSplitter.split(content)) {
      RegExpMatch match;
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
        currentSection = null;
        var name = match.group(1);
        var sectionNames = name.split(' ');

        assert(sectionNames.length <= 2);
        for (var i = 0; i < sectionNames.length; i++) {
          var sectionName = sectionNames[i];
          if (i != 0) {
            assert(sectionName.startsWith('"'), 'Section name: $sectionName');
            assert(sectionName.endsWith('"'), 'Section name: $sectionName');
            sectionName = sectionName.substring(1, sectionName.length - 1);
          }

          var section = config.sections.firstWhere(
            (s) => s.name == sectionName,
            orElse: () => null,
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

        var key = match[1].trim();
        var value = match[2].trim();
        currentSection.options[key] = value;
        continue;
      }
    }

    return config;
  }

  String serialize() {
    var buffer = StringBuffer();
    for (var section in sections) {
      var name = section.name;
      if (section.sections.isEmpty) {
        buffer.write('[$name]\n');
        _writeSectionProps(buffer, section);
        buffer.write('\n');
        continue;
      }

      if (name != 'branch' && name != 'remote') {
        throw Exception('Unknown field $name');
      }

      for (var subSec in section.sections) {
        assert(subSec.sections.isEmpty);
        buffer.write('[$name "${subSec.name}"]\n');
        _writeSectionProps(buffer, subSec);
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }

  void _writeSectionProps(StringBuffer buffer, Section section) {
    section.options.forEach((key, val) {
      buffer.write('\t');
      buffer.write('$key = $val\n');
    });
  }
}
