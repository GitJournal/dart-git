import 'package:dart_git/branch.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:ini/ini.dart' as ini;

class Config {
  bool bare;
  Map<String, Branch> branches = {};
  ini.Config iniConfig;

  Config(String raw) {
    var config = ini.Config.fromString(raw);
    print('${config.sections().toList()}');
    for (var section in config.sections()) {
      print('Section $section');
      if (section.startsWith('branch ')) {
        var branchName = section.substring('branch '.length).substring(1, -1);
        var branch = Branch();
        branch.name = branchName;

        var secValues = config.items(section);
        for (var secValue in secValues) {
          assert(secValue.length == 2);
          var key = secValue.first;
          var value = secValue.last;

          switch (key) {
            case 'remote':
              branch.remote = value;
              break;
            case 'merge':
              branch.merge = ReferenceName(value);
              break;
          }
        }

        branches[branchName] = branch;
      }
    }
  }
}
