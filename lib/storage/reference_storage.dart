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

    for (var ref in await _packedRefs()) {
      if (ref.name == refName) {
        return ref;
      }
    }

    return null;
  }

  Future<List<ReferenceName>> listReferenceNames(String prefix) async {
    assert(prefix.startsWith(refPrefix));

    var refs = <ReferenceName>[];
    var refLocation = p.join(dotGitDir, prefix);
    var processedRefNames = <ReferenceName>{};

    var stream = fs.directory(refLocation).list(recursive: true);
    await for (var fsEntity in stream) {
      if (fsEntity.statSync().type != FileSystemEntityType.file) {
        continue;
      }
      if (fsEntity.basename.startsWith('.')) {
        continue;
      }

      var refName =
          ReferenceName(fsEntity.path.substring(dotGitDir.length + 1));
      refs.add(refName);
      processedRefNames.add(refName);
    }

    for (var ref in await _packedRefs()) {
      if (processedRefNames.contains(ref.name)) {
        continue;
      }
      if (ref.name.value.startsWith(prefix)) {
        refs.add(ref.name);
      }
    }

    return refs;
  }

  Future<List<Reference>> listReferences(String prefix) async {
    assert(prefix.startsWith(refPrefix));

    var refs = <Reference>[];
    var refLocation = p.join(dotGitDir, prefix);
    var processedRefNames = <ReferenceName>{};

    var stream = fs.directory(refLocation).list(recursive: true);
    await for (var fsEntity in stream) {
      if (fsEntity.statSync().type != FileSystemEntityType.file) {
        continue;
      }
      if (fsEntity.basename.startsWith('.')) {
        continue;
      }

      var refName =
          ReferenceName(fsEntity.path.substring(dotGitDir.length + 1));
      var ref = await reference(refName);
      refs.add(ref);
      processedRefNames.add(refName);
    }

    for (var ref in await _packedRefs()) {
      if (processedRefNames.contains(ref.name)) {
        continue;
      }
      if (ref.name.value.startsWith(prefix)) {
        refs.add(ref);
      }
    }

    return refs;
  }

  Future<void> saveRef(Reference ref) async {
    var refFileName = p.join(dotGitDir, ref.name.value);
    var refFileName2 = refFileName + '_';

    var file = fs.file(refFileName2);
    await file.writeAsString(ref.hash.toString(), flush: true);

    await file.rename(refFileName);
  }

  // FIXME: Maybe this doesn't need to read each time!
  Future<List<Reference>> _packedRefs() async {
    var packedRefsFile = fs.file(p.join(dotGitDir, 'packed-refs'));
    if (!packedRefsFile.existsSync()) {
      return [];
    }

    var contents = await packedRefsFile.readAsString();
    return _loadPackedRefs(contents);
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
