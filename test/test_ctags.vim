" Tests for autoload/gen_tags/ctags.vim (needs ctags)

let g:loaded_events = 0
autocmd User GenTags#CtagsLoaded let g:loaded_events += 1

function! SetUp() abort
  call RequireExecutable(g:gen_tags#ctags_bin)
  let g:loaded_events = 0
  let s:root = MakeProject('proj', ['.git'])
  call Edit(s:root . '/src/a.c')
  let s:db = gen_tags#get_db_dir() . '/prj_tags'
endfunction

function! TearDown() abort
  let g:gen_tags#ctags_prune = 0
  let g:gen_tags#blacklist = []
  silent! call delete(g:test_tmp . '/cache', 'rf')
endfunction

function! s:tag_names() abort
  return map(filter(readfile(s:db), 'v:val !~# "^!"'), 'split(v:val, "\t")[0]')
endfunction

function! Test_gen_ctags() abort
  GenCtags
  call WaitJobs()
  call assert_true(filereadable(s:db), 'tags file not created')
  call assert_notequal(-1, index(TagFiles(), s:db), 'tags option: ' . &tags)
  call assert_equal(1, len(taglist('^foo$')))
  call assert_equal(1, len(taglist('^bar$')))
  call assert_equal(1, g:loaded_events)
endfunction

function! Test_auto_load_on_buffer_enter() abort
  GenCtags
  call WaitJobs()
  set tags&
  silent! %bwipeout!
  call Edit(s:root . '/src/b.c')
  call assert_notequal(-1, index(TagFiles(), s:db), 'tags option: ' . &tags)
endfunction

function! Test_loaded_event_fires_once() abort
  GenCtags
  call WaitJobs()
  let l:tags = &tags
  doautocmd BufWinEnter
  call Edit(s:root . '/src/b.c')
  call Edit(s:root . '/src/a.c')
  call assert_equal(1, g:loaded_events)
  call assert_equal(l:tags, &tags)
endfunction

function! Test_special_buffers_ignored() abort
  GenCtags
  call WaitJobs()
  set tags&
  new
  setlocal buftype=nofile
  doautocmd BufWinEnter
  call assert_equal(-1, index(TagFiles(), s:db))
endfunction

function! Test_update_on_write_full() abort
  GenCtags
  call WaitJobs()
  call setline(1, 'int foo2(void) { return 1; }')
  silent write
  call WaitJobs()
  call assert_equal(['bar', 'foo2'], sort(s:tag_names()))
endfunction

function! Test_update_on_write_prune() abort
  let g:gen_tags#ctags_prune = 1
  GenCtags
  call WaitJobs()
  call setline(1, 'int foo2(void) { return 1; }')
  silent write
  call WaitJobs()
  call assert_equal(['bar', 'foo2'], sort(s:tag_names()))
endfunction

function! Test_no_update_for_file_outside_project() abort
  GenCtags
  call WaitJobs()
  let l:before = readfile(s:db)
  let l:other = g:test_tmp . '/outside/x.c'
  call WriteFile(l:other, ['int outside;'])
  "Write a file elsewhere while the project db dir stays the same
  let g:gen_tags#root_path = s:root
  call Edit(l:other)
  silent write
  call WaitJobs()
  let g:gen_tags#root_path = ''
  call assert_equal(l:before, readfile(s:db))
endfunction

function! Test_blacklisted_project_not_generated() abort
  let g:gen_tags#blacklist = [s:root]
  GenCtags
  call WaitJobs()
  call assert_false(filereadable(s:db))
endfunction

function! Test_clear_ctags() abort
  GenCtags
  call WaitJobs()
  ClearCtags
  call assert_false(filereadable(s:db))
  call assert_true(isdirectory(fnamemodify(s:db, ':h')))
endfunction

function! Test_clear_ctags_bang_removes_dir() abort
  GenCtags
  call WaitJobs()
  ClearCtags!
  call assert_false(isdirectory(fnamemodify(s:db, ':h')))
endfunction

function! Test_extend_database() abort
  let l:lib = MakeProject('lib')
  call WriteFile(l:lib . '/src/lib.c', ['int libfn(void) { return 3; }'])
  let l:ext_db = gen_tags#get_db_dir() . '/' . gen_tags#get_db_name(l:lib)
  GenCtags
  call WaitJobs()

  "Writing ext.conf from :EditExt generates the extension database, even
  "though the cwd (the gen_tags.vim checkout) is not the project root
  call assert_notequal(s:root, getcwd())
  EditExt
  call setline(1, l:lib)
  silent write
  call WaitJobs()
  close
  call assert_true(filereadable(l:ext_db), 'extension tags not created')

  "It is loaded along with the project tags
  set tags&
  silent! %bwipeout!
  call Edit(s:root . '/src/a.c')
  call assert_notequal(-1, index(TagFiles(), l:ext_db), 'tags option: ' . &tags)
  call assert_equal(1, len(taglist('^libfn$')))
endfunction
