import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

// FIXME: Revisions have a particular format!!
//        https://git-scm.com/docs/git-check-ref-format
//        This seems like a good task to delegate!
class ReferenceStorageFS implements ReferenceStorage {
  final String _dotGitDir;
  final FileSystem _fs;

  ReferenceStorageFS(this._dotGitDir, this._fs);

  @override
  Result<Reference> reference(ReferenceName refName) {
    var file = _fs.file(p.join(_dotGitDir, refName.value));
    if (file.existsSync()) {
      var contents = file.readAsStringSync();
      return Result(Reference(refName.value, contents.trimRight()));
    }

    for (var ref in _packedRefs()) {
      if (ref.name == refName) {
        return Result(ref);
      }
    }

    return Result.fail(GitRefNotFound(refName));
  }

  @override
  Result<List<Reference>> listReferences(String prefix) {
    assert(prefix.startsWith(refPrefix));

    var refs = <Reference>[];
    var refLocation = p.join(_dotGitDir, prefix);
    var processedRefNames = <ReferenceName>{};

    var dir = _fs.directory(refLocation);
    if (!dir.existsSync()) {
      return Result(refs);
    }

    var stream = dir.listSync(recursive: true);
    for (var fsEntity in stream) {
      if (fsEntity.statSync().type != FileSystemEntityType.file) {
        continue;
      }
      if (fsEntity.basename.startsWith('.')) {
        continue;
      }

      var refName =
          ReferenceName(fsEntity.path.substring(_dotGitDir.length + 1));
      var result = reference(refName);
      if (result.isSuccess) {
        var ref = result.getOrThrow();
        refs.add(ref);
        var _ = processedRefNames.add(refName);
      }
      // FIXME: Handle the error!
    }

    for (var ref in _packedRefs()) {
      if (processedRefNames.contains(ref.name)) {
        continue;
      }
      if (ref.name.value.startsWith(prefix)) {
        refs.add(ref);
      }
    }

    return Result(refs);
  }

  // FIXME: removeRef should also look into packed-ref files?
  @override
  Result<void> removeReferences(String prefix) {
    assert(prefix.startsWith(refPrefix));

    var refLocation = p.join(_dotGitDir, prefix);
    var dir = _fs.directory(refLocation);
    if (!dir.existsSync()) {
      return Result(null);
    }

    dir.deleteSync(recursive: true);
    return Result(null);
  }

  @override
  Result<void> saveRef(Reference ref) {
    var refFileName = p.join(_dotGitDir, ref.name.value);
    var refFileName2 = refFileName + '_';

    var _ = _fs.directory(p.dirname(refFileName)).createSync(recursive: true);
    var file = _fs.file(refFileName2);
    if (ref.isHash) {
      file.writeAsStringSync(ref.hash.toString() + '\n', flush: true);
    } else if (ref.isSymbolic) {
      var val = symbolicRefPrefix + ref.target!.value;
      file.writeAsStringSync(val + '\n', flush: true);
    }
    file = file.renameSync(refFileName);

    return Result(null);
  }

  // FIXME: Maybe this doesn't need to read each time!
  List<Reference> _packedRefs() {
    var packedRefsFile = _fs.file(p.join(_dotGitDir, 'packed-refs'));
    if (!packedRefsFile.existsSync()) {
      return [];
    }

    var contents = packedRefsFile.readAsStringSync();
    return _loadPackedRefs(contents);
  }

  @override
  Result<void> deleteReference(ReferenceName refName) {
    var refFileName = p.join(_dotGitDir, refName.value);
    var _ = _fs.file(refFileName).deleteSync();

    return Result(null);
    // FIXME: What if the deleted ref is in the packed-refs?
    //        The file is being locked in the go-git code!
  }
}

List<Reference> _loadPackedRefs(String raw) {
  var refs = <Reference>[];
  for (var line in LineSplitter.split(raw)) {
    if (line.startsWith('#') || line.startsWith('^')) {
      continue;
    }

    var parts = line.split(' ');
    assert(parts.length == 2, 'Got $line');
    if (parts.length != 2) {
      continue;
    }
    refs.add(Reference(parts[1], parts[0]));
  }

  return refs;
}
