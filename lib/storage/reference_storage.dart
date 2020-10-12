import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/plumbing/reference.dart';

class ReferenceStorage {
  String dotGitDir;
  FileSystem fs;

  ReferenceStorage(this.dotGitDir, this.fs);

  Future<Reference> reference(ReferenceName refName) async {
    var file = fs.file(p.join(dotGitDir, refName.value));
    if (file.existsSync()) {
      var contents = await file.readAsString();
      return Reference(refName.value, contents.trimRight());
    }

    var packedRefsFile = fs.file(p.join(dotGitDir, 'packed-refs'));
    if (!packedRefsFile.existsSync()) {
      return null;
    }

    var contents = await packedRefsFile.readAsString();
    for (var ref in _loadPackedRefs(contents)) {
      if (ref.name == refName) {
        return ref;
      }
    }

    return null;
  }

  Future<List<ReferenceName>> listReferences(String prefix) async {
    var refs = <ReferenceName>[];
    var stream = fs.directory(refHeadPrefix).list();
    await for (var fsEntity in stream) {
      assert(fsEntity.statSync().type == FileSystemEntityType.file);

      var fileName = p.basename(fsEntity.path);
      refs.add(ReferenceName.head(fileName));
    }

    return refs;
  }

  Future<void> saveRef(Reference ref) async {
    // FIXME: Make this operation atomic
    //        Never overwrite a file, just move the file
    var file = fs.file(p.join(dotGitDir, ref.name.value));
    await file.writeAsString(ref.hash.toString(), flush: true);
  }
}

Iterable<Reference> _loadPackedRefs(String raw) sync* {
  for (var line in LineSplitter.split(raw)) {
    if (line.startsWith('#')) {
      continue;
    }

    var parts = line.split(' ');
    assert(parts.length == 2);
    if (parts.length != 2) {
      continue;
    }
    yield Reference(parts[1], parts[0]);
  }
}
