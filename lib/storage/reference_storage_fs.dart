import 'dart:convert';

import 'package:dart_git/exceptions.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/plumbing/reference.dart';

import 'interfaces.dart';

// FIXME: Revisions have a particular format!!
//        https://git-scm.com/docs/git-check-ref-format
//        This seems like a good task to delegate!
class ReferenceStorageFS implements ReferenceStorage {
  final String _dotGitDir;
  final FileSystem _fs;

  ReferenceStorageFS(this._dotGitDir, this._fs);

  @override
  Reference? reference(ReferenceName refName) {
    var file = _fs.file(p.join(_dotGitDir, refName.value));
    if (file.existsSync()) {
      var contents = file.readAsStringSync().trimRight();
      if (contents.isEmpty) return null;

      return Reference.build(refName.value, contents);
    }

    for (var ref in _packedRefs()) {
      if (ref.name == refName) {
        return ref;
      }
    }
    return null;
  }

  @override
  List<Reference> listReferences(String prefix) {
    assert(prefix.startsWith(refPrefix));

    var refs = <Reference>[];
    var refLocation = p.join(_dotGitDir, prefix);
    var processedRefNames = <ReferenceName>{};

    var dir = _fs.directory(refLocation);
    if (!dir.existsSync()) {
      return refs;
    }

    var stream = dir.listSync(recursive: true);
    for (var fsEntity in stream) {
      if (fsEntity.statSync().type != FileSystemEntityType.file) {
        continue;
      }
      if (fsEntity.basename.startsWith('.')) {
        continue;
      }

      var refName = ReferenceName(fsEntity.path.substring(_dotGitDir.length));
      try {
        var ref = reference(refName);
        if (ref == null) {
          throw GitRefStoreCorrupted();
        }
        refs.add(ref);
        processedRefNames.add(refName);
      } catch (ex) {
        // FIXME: Handle the error!
      }
    }

    for (var ref in _packedRefs()) {
      if (processedRefNames.contains(ref.name)) {
        continue;
      }
      if (ref.name.value.startsWith(prefix)) {
        refs.add(ref);
      }
    }

    return refs;
  }

  // FIXME: removeRef should also look into packed-ref files?
  @override
  void removeReferences(String prefix) {
    assert(prefix.startsWith(refPrefix));

    var refLocation = p.join(_dotGitDir, prefix);
    var dir = _fs.directory(refLocation);
    if (!dir.existsSync()) {
      return;
    }

    dir.deleteSync(recursive: true);
    return;
  }

  @override
  void saveRef(Reference ref) {
    var refFileName = p.join(_dotGitDir, ref.name.value);
    var refFileName2 = '${refFileName}_';

    _fs.directory(p.dirname(refFileName)).createSync(recursive: true);

    var file = _fs.file(refFileName2);
    file.writeAsStringSync(ref.serialize(), flush: true);
    file = file.renameSync(refFileName);

    return;
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
  void deleteReference(ReferenceName refName) {
    var refFileName = p.join(_dotGitDir, refName.value);
    _fs.file(refFileName).deleteSync();

    return;
    // FIXME: What if the deleted ref is in the packed-refs?
    //        The file is being locked in the go-git code!
  }

  @override
  void close() {}
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
    refs.add(Reference.build(parts[1], parts[0]));
  }

  return refs;
}
