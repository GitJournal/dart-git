import 'package:path/path.dart' as p;

void main() {
  print("Hello World");
}

class GitRepository {
  String workTree;
  String gitDir;
  Map<String, dynamic> config;

  GitRepository(String path) {
    workTree = path;
    gitDir = p.join(workTree, ".git");
  }

  static void init(String path) {
    // Check if path has stuff and accordingly return
  }
}

// How to do error handling?
// - I would love to just return an Error obj, but that cannot always be done
//   I guess exceptions is the way to go

class GitException {}

// Show an example of how we can detect the exception type

//
// This is the perfect kind of project where TDD would work so well
// It would be a good idea to reflect 'go-git's directory structure
//
