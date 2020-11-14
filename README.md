<p align="center">
  <img width="400" width="auto" src="https://raw.githubusercontent.com/GitJournal/dart_git/master/assets/logo.png">
  <br/>A Git Implementation in pure Dart
</p>

<p align="center">
  <a href="https://github.com/GitJournal/dart_git/actions"><img alt="Build Status" src="https://github.com/GitJournal/dart_git/workflows/Dart%20CI/badge.svg"/></a>
  <a href="https://www.gnu.org/licenses/agpl-3.0"><img alt="License: AGPL v3" src="https://img.shields.io/badge/License-AGPL%20v3-blue.svg"></a>
  </br>
  <a href="http://paypal.me/visheshhanda"><img alt="Donate Paypal" src="https://img.shields.io/badge/Donate-Paypal-%231999de"></a>
  <a href="https://github.com/sponsors/vHanda"><img alt="Sponsor via GitHub" src="https://img.shields.io/badge/Sponsor-Github-%235a353"></a>
</p>


This is an experimental reimplementation of Git in pure Dart. The GitJournal project is currently using libgit2, but it's a pain using it - the cross compilation, java ndk bindings + ios bindings. Also, it doesn't let us easily control the FS layer. We eventually want to encrypt the git repo.

Therefore, this is an experimental start at reimplementing Git in Dart. Right now the plan is to just implement a subset of features required by GitJournal.


## Comparison with git

*dart-git* aims to be fully compatible with [git](https://github.com/git/git), all the *porcelain* operations will be implemented to work exactly as *git* does.

*Git* is a humongous project with years of development by thousands of contributors, *dart-git* does not aim to implement all its features. It's primarily driven by the needs of the GitJournal project. You can find a comparison of *dart-git* vs *git* in the [compatibility documentation](COMPATIBILITY.md).


## License

This project has been heavily inspired by the [go-git](https://github.com/go-git/go-git/) project and has often adapted code from that project. go-git is licensed under Apache License Version 2.0

dart-git is licensed under Affero General Public License 3.0, see [LICENSE](LICENSE)
