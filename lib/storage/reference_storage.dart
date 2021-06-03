import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/result.dart';

class ReferenceStorage {
  final String _dotGitDir;
  final FileSystem _fs;

  ReferenceStorage(this._dotGitDir, this._fs);

  Future<Result<Reference>> reference(ReferenceName refName) async {
    var file = _fs.file(p.join(_dotGitDir, refName.value));
    if (file.existsSync()) {
      var contents = await file.readAsString();
      return Result(Reference(refName.value, contents.trimRight()));
    }

    for (var ref in await _packedRefs()) {
      if (ref.name == refName) {
        return Result(ref);
      }
    }

    return Result.fail(GitRefNotFound(refName));
  }

  Future<Result<List<Reference>>> listReferences(String prefix) async {
    assert(prefix.startsWith(refPrefix));

    var refs = <Reference>[];
    var refLocation = p.join(_dotGitDir, prefix);
    var processedRefNames = <ReferenceName>{};

    var dir = _fs.directory(refLocation);
    if (!dir.existsSync()) {
      return Result(refs);
    }

    var stream = dir.list(recursive: true);
    await for (var fsEntity in stream) {
      if (fsEntity.statSync().type != FileSystemEntityType.file) {
        continue;
      }
      if (fsEntity.basename.startsWith('.')) {
        continue;
      }

      var refName =
          ReferenceName(fsEntity.path.substring(_dotGitDir.length + 1));
      var result = await reference(refName);
      if (result.isSuccess) {
        var ref = result.get();
        refs.add(ref);
        processedRefNames.add(refName);
      }
    }

    for (var ref in await _packedRefs()) {
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
  Future<Result<void>> removeReferences(String prefix) async {
    assert(prefix.startsWith(refPrefix));

    var refLocation = p.join(_dotGitDir, prefix);
    var dir = _fs.directory(refLocation);
    if (!dir.existsSync()) {
      return Result(null);
    }

    await dir.delete(recursive: true);
    return Result(null);
  }

  Future<Result<void>> saveRef(Reference ref) async {
    var refFileName = p.join(_dotGitDir, ref.name.value);
    var refFileName2 = refFileName + '_';

    await _fs.directory(p.dirname(refFileName)).create(recursive: true);
    var file = _fs.file(refFileName2);
    if (ref.isHash) {
      await file.writeAsString(ref.hash.toString() + '\n', flush: true);
    } else if (ref.isSymbolic) {
      var val = symbolicRefPrefix + ref.target!.value;
      await file.writeAsString(val + '\n', flush: true);
    }
    await file.rename(refFileName);

    return Result(null);
  }

  // FIXME: Maybe this doesn't need to read each time!
  Future<List<Reference>> _packedRefs() async {
    var packedRefsFile = _fs.file(p.join(_dotGitDir, 'packed-refs'));
    if (!packedRefsFile.existsSync()) {
      return [];
    }

    var contents = await packedRefsFile.readAsString();
    return _loadPackedRefs(contents);
  }

  Future<Result<void>> deleteReference(ReferenceName refName) async {
    var refFileName = p.join(_dotGitDir, refName.value);
    await _fs.file(refFileName).delete();

    return Result(null);
    // FIXME: What if the deleted ref is in the packed-refs?
  }
}

List<Reference> _loadPackedRefs(String raw) {
  var refs = <Reference>[];
  for (var line in LineSplitter.split(raw)) {
    if (line.startsWith('#')) {
      continue;
    }

    var parts = line.split(' ');
    assert(parts.length == 2);
    if (parts.length != 2) {
      continue;
    }
    refs.add(Reference(parts[1], parts[0]));
  }

  return refs;
}
