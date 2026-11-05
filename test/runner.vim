" ============================================================================
" File: runner.vim
" Description: Minimal test runner for gen_tags.vim, based on Vim's built-in
"              assert_*() functions. Run through test/run.sh, which starts a
"              fresh editor for every test file:
"                vim -N -u NONE -i NONE -n -es
"                  --cmd "let g:test_file = 'test/test_foo.vim'"
"                  --cmd "let g:test_out = 'out.txt'" -S test/runner.vim
"
"  - Every function named Test_*() in g:test_file is run, in sorted order.
"  - Top-level code in the test file runs before the plugin is loaded, so it
"    can set options that are only read at init time.
"  - SetUp()/TearDown(), if defined, run around every test.
"  - A test is skipped by throwing 'SKIP: reason' (see Skip()).
" ============================================================================

set nocompatible
let s:test_dir = expand('<sfile>:p:h')
let s:repo = fnamemodify(s:test_dir, ':h')
let &runtimepath = s:repo . ',' . &runtimepath

"Sandbox: fixtures and tag databases live in a throwaway directory
let g:test_tmp = fnamemodify(tempname(), ':p')
call mkdir(g:test_tmp, 'p')
let g:gen_tags#cache_dir = g:test_tmp . '/cache/'
let s:cwd = getcwd()

execute 'source' fnameescape(s:test_dir . '/helpers.vim')
execute 'source' fnameescape(g:test_file)
runtime plugin/gen_tags.vim

function! s:reset() abort
  call WaitJobs()
  silent! %bwipeout!
  execute 'cd' fnameescape(s:cwd)
  set tags&
  if exists(':cscope') == 2 && has('cscope')
    silent! cscope kill -1
  endif
  if exists('*gen_tags#clear_cache')
    call gen_tags#clear_cache()
  endif
endfunction

let s:names = sort(map(split(execute('function /^Test_'), "\n"),
      \ {_, v -> matchstr(v, '^function \zs\w\+')}))

let s:lines = []
let s:failed = 0
for s:name in s:names
  let v:errors = []
  let s:status = 'PASS'
  let s:note = ''
  try
    if exists('*SetUp')
      call SetUp()
    endif
    call call(s:name, [])
  catch /^SKIP:/
    let s:status = 'SKIP'
    let s:note = substitute(v:exception, '^SKIP:\s*', '', '')
  catch
    call add(v:errors, v:exception . ' (' . v:throwpoint . ')')
  finally
    try
      if exists('*TearDown')
        call TearDown()
      endif
      call s:reset()
    catch
      call add(v:errors, 'teardown: ' . v:exception . ' (' . v:throwpoint . ')')
    endtry
  endtry

  if s:status !=# 'SKIP' && !empty(v:errors)
    let s:status = 'FAIL'
    let s:failed += 1
  endif

  call add(s:lines, s:status . ' ' . s:name . (empty(s:note) ? '' : ' (' . s:note . ')'))
  if s:status ==# 'FAIL'
    call extend(s:lines, map(copy(v:errors), '"    " . v:val'))
  endif
endfor

if empty(s:names)
  call add(s:lines, 'FAIL no Test_* functions found')
  let s:failed += 1
endif

call add(s:lines, 'DONE')
call writefile(s:lines, g:test_out)
call delete(g:test_tmp, 'rf')

if s:failed
  cquit
endif
qall!
