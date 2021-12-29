import 'package:collection/collection.dart';

import 'package:dart_git/config.dart';
import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/reference.dart';

extension Remotes on GitRepository {
  Result<List<Reference>> remoteBranches(String remoteName) {
    if (config.remote(remoteName) == null) {
      var ex = GitRemoteNotFound(remoteName);
      return Result.fail(ex);
    }

    var remoteRefsPrefix = '$refRemotePrefix$remoteName/';
    return refStorage.listReferences(remoteRefsPrefix);
  }

  Result<Reference> remoteBranch(
    String remoteName,
    String branchName,
  ) {
    if (config.remote(remoteName) == null) {
      var ex = GitRemoteNotFound(remoteName);
      return Result.fail(ex);
    }

    var remoteRef = ReferenceName.remote(remoteName, branchName);
    return refStorage.reference(remoteRef);
  }

  Result<GitRemoteConfig> addRemote(String name, String url) {
    var existingRemote = config.remotes.firstWhereOrNull((r) => r.name == name);
    if (existingRemote != null) {
      var ex = GitRemoteAlreadyExists(name);
      return Result.fail(ex);
    }

    var remote = GitRemoteConfig.create(name: name, url: url);
    config.remotes.add(remote);

    var result = saveConfig();
    if (result.isFailure) {
      return fail(result);
    }

    return Result(remote);
  }

  Result<GitRemoteConfig> addOrUpdateRemote(
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
    var result = saveConfig();
    if (result.isFailure) {
      return fail(result);
    }

    return Result(config.remotes[i]);
  }

  Result<GitRemoteConfig> removeRemote(String name) {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      var ex = GitRemoteNotFound(name);
      return Result.fail(ex);
    }

    var remote = config.remotes.removeAt(i);
    var cfgResult = saveConfig();
    if (cfgResult.isFailure) {
      return fail(cfgResult);
    }

    var result = refStorage.removeReferences(refRemotePrefix + name);
    if (result.isFailure) {
      return fail(result);
    }
    // TODO: Remote the objects from that remote?

    return Result(remote);
  }

  Reference? guessRemoteHead(String remoteName) {
    // See: https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/25430727#25430727
    //      https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/8841024#8841024
    //
    // The ideal way is to use https://libgit2.org/libgit2/#HEAD/group/remote/git_remote_default_branch
    //
    var branches = remoteBranches(remoteName).getOrThrow();
    if (branches.isEmpty) {
      return null;
    }

    var i = branches.indexWhere((b) => b.name.branchName() == refHead);
    if (i != -1) {
      var remoteHead = branches[i];
      assert(remoteHead.isSymbolic);

      return resolveReference(remoteHead).getOrThrow();
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
