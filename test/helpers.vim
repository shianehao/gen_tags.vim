" ============================================================================
" File: helpers.vim
" Description: Shared helpers for gen_tags.vim tests (sourced by runner.vim)
" ============================================================================

function! Skip(reason) abort
  throw 'SKIP: ' . a:reason
endfunction

function! RequireExecutable(...) abort
  for l:bin in a:000
    if !executable(l:bin)
      call Skip(l:bin . ' not found')
    endif
  endfor
endfunction

"Write a:lines to a:path, creating parent directories
function! WriteFile(path, lines) abort
  call mkdir(fnamemodify(a:path, ':h'), 'p')
  call writefile(a:lines, a:path)
endfunction

"Create a project under the sandbox and return its absolute path.
"Optional list of markers: directory names ('.git', '.hg', ...) or
"'.git-file' for a git worktree/submodule style '.git' file.
"The project contains src/a.c (defines foo) and src/b.c (defines bar).
function! MakeProject(name, ...) abort
  let l:dir = g:test_tmp . '/' . a:name
  call WriteFile(l:dir . '/src/a.c', ['int foo(void) { return 1; }'])
  call WriteFile(l:dir . '/src/b.c', ['int bar(void) { return 2; }'])
  for l:marker in get(a:000, 0, [])
    if l:marker ==# '.git-file'
      call writefile(['gitdir: /nonexistent'], l:dir . '/.git')
    else
      call mkdir(l:dir . '/' . l:marker, 'p')
    endif
  endfor
  return fnamemodify(l:dir, ':p:h')
endfunction

function! Edit(path) abort
  execute 'edit' fnameescape(a:path)
endfunction

"Poll until a:expr (a string expression) is true or a:timeout ms passed
function! WaitFor(expr, ...) abort
  let l:timeout = get(a:000, 0, 5000)
  let l:start = reltime()
  while !eval(a:expr)
    if reltimefloat(reltime(l:start)) * 1000 > l:timeout
      return 0
    endif
    sleep 10m
  endwhile
  return 1
endfunction

"Wait for background tag jobs to finish
function! WaitJobs() abort
  if !exists('*gen_tags#job#is_running') && empty(globpath(&rtp, 'autoload/gen_tags/job.vim'))
    return
  endif
  call assert_true(WaitFor('!gen_tags#job#is_running()', 10000), 'background jobs did not finish')
  "Give exit callbacks a chance to run
  sleep 50m
endfunction

"Entries of the 'tags' option
function! TagFiles() abort
  return split(&tags, ',')
endfunction
