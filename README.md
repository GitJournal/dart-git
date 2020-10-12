# Dart Git

[![Build Status](https://github.com/GitJournal/dart_git/workflows/Dart%20CI/badge.svg)](https://github.com/GitJournal/dart_git/actions)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

This is an experimental reimplementation of Git in pure Dart. The GitJournal project is currently using libgit2, but it's a pain using it - the cross compilation, java ndk bindings + ios bindings. Also, it doesn't let us easily control the FS layer. We eventually want to encrypt the git repo.

Therefore, this is an experimental start at reimplementing Git in Dart. Right now the plan is to just implement a subset of features required by GitJournal.


## License

Affero General Public License 3.0, see [LICENSE](LICENSE)
