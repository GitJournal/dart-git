import 'package:dart_git/branch.dart';
import 'package:ini/ini.dart' as ini;

class GitConfig {
  bool bare;
  Map<String, Branch> branches = {};
  ini.Config iniConfig;
}
