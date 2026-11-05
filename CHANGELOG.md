# Changelog

All notable changes to gen_tags.vim are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `gen_tags#clear_cache()` refreshes the cached project root. Call it after creating a new repository or `.root` folder for a file that is already open. `:GenCtags` and `:GenGTAGS` also refresh the cache. ([#1], [#2])
- A test suite in `test/`, run with `test/run.sh [vim|nvim]`. It uses Vim's built-in `assert_*()` functions and needs no extra plugins. ([#3])
- GitHub Actions runs the tests with Vim and Neovim on every push and pull request, and the README shows a CI badge. ([#3], [#4])

### Changed

- Switching buffers and saving files is much faster. The project root is now detected once per directory and cached, instead of being searched for several times on every `BufEnter`, `BufWinEnter` and `BufWritePost`. ([#1])
- The `GenTags#CtagsLoaded` and `GenTags#GtagsLoaded` events fire only when a tag database is newly added, not on every buffer switch. ([#1])
- Special buffers such as help, quickfix and terminal buffers are skipped when tags are loaded or updated. ([#1])
- With `g:gen_tags#ctags_prune`, the tags file is rewritten on save only if entries were actually removed. ([#1])

### Fixed

- Files in a sibling directory whose name starts with the project's name (for example `/src/proj2` for project `/src/proj`) were treated as part of the project. Paths containing regex characters such as `.` or `[` could also be matched wrongly. ([#1])
- With `g:gen_tags#ctags_prune`, file names containing regex characters could prune tags for the wrong file. ([#1])
- `:EditExt` extension databases were read from and written to the wrong place when Vim's current directory was not the project root. ([#3])
- After a manual `:cscope kill`, the gtags database was never added back when entering a buffer. ([#3])

[Unreleased]: https://github.com/shianehao/gen_tags.vim/compare/ce01c16...HEAD
[#1]: https://github.com/shianehao/gen_tags.vim/pull/1
[#2]: https://github.com/shianehao/gen_tags.vim/pull/2
[#3]: https://github.com/shianehao/gen_tags.vim/pull/3
[#4]: https://github.com/shianehao/gen_tags.vim/pull/4
