import 'package:collection/collection.dart';

import 'package:dart_git/config.dart';
import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/reference.dart';

extension Remotes on GitRepository {
  List<Reference> remoteBranches(String remoteName) {
    if (config.remote(remoteName) == null) {
      throw GitRemoteNotFound(remoteName);
    }

    var remoteRefsPrefix = '$refRemotePrefix$remoteName/';
    return refStorage.listReferences(remoteRefsPrefix);
  }

  HashReference remoteBranch(
    String remoteName,
    String branchName,
  ) {
    if (config.remote(remoteName) == null) {
      throw GitRemoteNotFound(remoteName);
    }

    var remoteRef = ReferenceName.remote(remoteName, branchName);
    var ref = refStorage.reference(remoteRef);
    if (ref == null) throw GitRefNotFound(remoteRef);
    switch (ref) {
      case HashReference():
        return ref;
      case SymbolicReference():
        throw GitRefNotHash(remoteRef);
    }
  }

  GitRemoteConfig addRemote(String name, String url) {
    var existingRemote = config.remotes.firstWhereOrNull((r) => r.name == name);
    if (existingRemote != null) {
      throw GitRemoteAlreadyExists(name);
    }

    var remote = GitRemoteConfig.create(name: name, url: url);
    config.remotes.add(remote);

    saveConfig();
    return remote;
  }

  GitRemoteConfig updateRemote(
    String name,
    String url,
  ) {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      throw GitRemoteNotFound(name);
    }

    config.remotes[i] = GitRemoteConfig(
      name: config.remotes[i].name,
      fetch: config.remotes[i].fetch,
      url: url,
    );
    saveConfig();

    return config.remotes[i];
  }

  GitRemoteConfig addOrUpdateRemote(
    String name,
    String url,
  ) {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      return addRemote(name, url);
    }

    config.remotes[i] = GitRemoteConfig(
      name: config.remotes[i].name,
      fetch: config.remotes[i].fetch,
      url: url,
    );
    saveConfig();

    return config.remotes[i];
  }

  GitRemoteConfig removeRemote(String name) {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      throw GitRemoteNotFound(name);
    }

    var remote = config.remotes.removeAt(i);
    saveConfig();

    refStorage.removeReferences(refRemotePrefix + name);
    // TODO: Remote the objects from that remote?

    return remote;
  }

  Reference? guessRemoteHead(String remoteName) {
    // See: https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/25430727#25430727
    //      https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/8841024#8841024
    //
    // The ideal way is to use https://libgit2.org/libgit2/#HEAD/group/remote/git_remote_default_branch
    //
    var branches = remoteBranches(remoteName);
    if (branches.isEmpty) {
      return null;
    }

    var i = branches.indexWhere((b) => b.name.branchName() == refHead);
    if (i != -1) {
      var remoteHead = branches[i];
      assert(remoteHead is SymbolicReference);

      return resolveReference(remoteHead);
    } else {
      branches = branches.where((b) => b.name.branchName() != refHead).toList();
    }

    if (branches.length == 1) {
      return branches[0];
    }

    var mi = branches.indexWhere((e) => e.name.branchName() == 'master');
    if (mi != -1) {
      return branches[mi];
    }

    mi = branches.indexWhere((e) => e.name.branchName() == 'main');
    if (mi != -1) {
      return branches[mi];
    }

    // Return the first alphabetical one
    branches
        .sort((a, b) => a.name.branchName()!.compareTo(b.name.branchName()!));
    return branches[0];
  }
}
