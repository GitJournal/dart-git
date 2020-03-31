import 'dart:convert';

import 'package:dart_git/branch.dart';
import 'package:dart_git/plumbing/reference.dart';

class Config {
  bool bare;
  Map<String, Branch> branches = {};

  Config(String raw) {
    var configFile = ConfigFile.parse(raw);
    for (var section in configFile.sections) {
      if (section.name == 'branch') {
        section.sections.forEach(_parseBranch);
        continue;
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
    return '';
  }
}
