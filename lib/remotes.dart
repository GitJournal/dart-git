import 'package:dart_git/config.dart';
import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/reference.dart';

import 'package:collection/collection.dart';

extension Remotes on GitRepository {
  Future<List<Reference>> remoteBranches(String remoteName) async {
    if (config.remote(remoteName) == null) {
      throw Exception('remote $remoteName does not exist');
    }

    var remoteRefsPrefix = '$refRemotePrefix$remoteName/';
    var result = await refStorage.listReferences(remoteRefsPrefix);
    return result.get();
  }

  Future<Reference?> remoteBranch(String remoteName, String branchName) async {
    if (config.remote(remoteName) == null) {
      throw Exception('remote $remoteName does not exist');
    }

    var remoteRef = ReferenceName.remote(remoteName, branchName);
    var result = await refStorage.reference(remoteRef);
    return result.data;
  }

  Future<GitRemoteConfig> addRemote(String name, String url) async {
    var existingRemote = config.remotes.firstWhereOrNull(
      (r) => r.name == name,
    );
    if (existingRemote != null) {
      throw Exception('fatal: remote "$name" already exists.');
    }

    var remote = GitRemoteConfig.create(name: name, url: url);
    config.remotes.add(remote);

    await saveConfig();

    return remote;
  }

  Future<GitRemoteConfig> addOrUpdateRemote(String name, String url) async {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      return addRemote(name, url);
    }

    config.remotes[i] = GitRemoteConfig(
      name: config.remotes[i].name,
      fetch: config.remotes[i].fetch,
      url: url,
    );
    await saveConfig();

    return config.remotes[i];
  }

  Future<GitRemoteConfig?> removeRemote(String name) async {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      return null;
    }

    var remote = config.remotes[i];
    config.remotes.removeAt(i);
    await saveConfig();

    await refStorage.removeReferences(refRemotePrefix + name);
    // TODO: Remote the objects from that remote?

    return remote;
  }

  Future<Reference?> guessRemoteHead(String remoteName) async {
    // See: https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/25430727#25430727
    //      https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/8841024#8841024
    //
    // The ideal way is to use https://libgit2.org/libgit2/#HEAD/group/remote/git_remote_default_branch
    //
    var branches = await remoteBranches(remoteName);
    if (branches.isEmpty) {
      return null;
    }

    var i = branches.indexWhere((b) => b.name.branchName() == 'HEAD');
    if (i != -1) {
      var remoteHead = branches[i];
      assert(remoteHead.isSymbolic);

      return resolveReference(remoteHead).get();
    } else {
      branches = branches.where((b) => b.name.branchName() != 'HEAD').toList();
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
