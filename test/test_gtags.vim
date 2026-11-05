" Tests for autoload/gen_tags/gtags.vim (needs cscope support and GNU Global)

let g:loaded_events = 0
autocmd User GenTags#GtagsLoaded let g:loaded_events += 1

function! SetUp() abort
  if !has('cscope')
    call Skip('no cscope support')
  endif
  call RequireExecutable(g:gen_tags#gtags_bin, g:gen_tags#global_bin, 'gtags-cscope')
  let g:loaded_events = 0
  let s:root = MakeProject('proj', ['.git'])
  call Edit(s:root . '/src/a.c')
  let s:db_dir = gen_tags#get_db_dir()
endfunction

function! TearDown() abort
  silent! call delete(g:test_tmp . '/cache', 'rf')
endfunction

function! s:gen() abort
  GenGTAGS
  call WaitJobs()
  call assert_true(WaitFor('cscope_connection()'), 'cscope db not added')
endfunction

"Symbols GNU Global knows the definition of
function! s:global(symbol) abort
  let l:cwd = getcwd()
  execute 'lcd' fnameescape(s:root)
  let l:out = systemlist(g:gen_tags#global_bin . ' -x ' . a:symbol)
  execute 'lcd' fnameescape(l:cwd)
  return l:out
endfunction

function! Test_env_follows_buffer() abort
  call assert_equal(s:root, $GTAGSROOT)
  call assert_equal(s:db_dir, $GTAGSDBPATH)

  let l:other = MakeProject('other', ['.git'])
  call Edit(l:other . '/src/a.c')
  call assert_equal(l:other, $GTAGSROOT)
  call assert_equal(gen_tags#get_db_dir(), $GTAGSDBPATH)
endfunction

function! Test_gen_gtags() abort
  call s:gen()
  call assert_true(filereadable(s:db_dir . '/GTAGS'))
  call assert_equal(1, g:loaded_events)

  silent! cscope find g bar
  call assert_equal('b.c', expand('%:t'))
endfunction

function! Test_loaded_event_fires_once() abort
  call s:gen()
  doautocmd BufWinEnter
  call Edit(s:root . '/src/b.c')
  call Edit(s:root . '/src/a.c')
  call assert_equal(1, g:loaded_events)
endfunction

function! Test_update_on_write() abort
  call s:gen()
  call setline(1, 'int foo2(void) { return 1; }')
  silent write
  call WaitJobs()
  call assert_equal(1, len(s:global('foo2')))
  call assert_equal(0, len(s:global('foo')))
endfunction

function! Test_regenerate_runs_update() abort
  call s:gen()
  call WriteFile(s:root . '/src/c.c', ['int baz(void) { return 3; }'])
  GenGTAGS
  call WaitJobs()
  call assert_equal(1, len(s:global('baz')))
endfunction

function! Test_clear_gtags() abort
  call s:gen()
  ClearGTAGS
  call assert_false(filereadable(s:db_dir . '/GTAGS'))
  call assert_equal(0, cscope_connection())
  call assert_true(isdirectory(s:db_dir))

  "Can be loaded again afterwards
  call s:gen()
  call assert_equal(2, g:loaded_events)
endfunction

function! Test_clear_gtags_bang_removes_dir() abort
  call s:gen()
  ClearGTAGS!
  call assert_false(isdirectory(s:db_dir))
endfunction
