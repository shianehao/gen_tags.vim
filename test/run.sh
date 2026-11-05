#!/bin/sh
# Run the gen_tags.vim test suite.
#
# Usage: test/run.sh [vim|nvim] [test/test_foo.vim ...]
#   The editor defaults to $VIM_BIN or "vim". Without test files, every
#   test/test_*.vim file is run. Each file runs in its own editor process.
set -u

cd "$(dirname "$0")/.." || exit 1

editor="${VIM_BIN:-vim}"
case "${1:-}" in
  vim|nvim|*/vim|*/nvim) editor="$1"; shift ;;
esac

if ! command -v "$editor" >/dev/null 2>&1; then
  echo "error: $editor not found" >&2
  exit 1
fi

case "$editor" in
  *nvim) set -- --headless -u NONE -i NONE -n "$@" ;;
  *)     set -- -N -u NONE -i NONE -n -es "$@" ;;
esac
# "$@" now holds the editor flags followed by any test files given.

files=""
flags=""
for arg in "$@"; do
  case "$arg" in
    *.vim) files="$files $arg" ;;
    *)     flags="$flags $arg" ;;
  esac
done
[ -n "$files" ] || files=$(ls test/test_*.vim)

# Guard against a hung editor where timeout(1) is available
limit=""
command -v timeout >/dev/null 2>&1 && limit="timeout 120"

out=$(mktemp)
trap 'rm -f "$out"' EXIT
failed=0

echo "Running tests with $("$editor" --version | head -n 1)"
for file in $files; do
  echo "== $file"
  rm -f "$out"
  # shellcheck disable=SC2086
  $limit "$editor" $flags \
    --cmd "let g:test_file = '$file'" \
    --cmd "let g:test_out = '$out'" \
    -S test/runner.vim </dev/null >/dev/null 2>&1
  status=$?

  if [ -f "$out" ]; then
    sed '/^DONE$/d' "$out"
  fi
  if [ $status -ne 0 ] || ! grep -qx DONE "$out" 2>/dev/null; then
    [ -f "$out" ] && grep -qx DONE "$out" || echo "FAIL $file did not finish (exit $status)"
    failed=1
  fi
done

if [ $failed -ne 0 ]; then
  echo "Some tests FAILED"
  exit 1
fi
echo "All tests passed"
