" Tests for g:gen_tags#ctags_auto_gen (read when the plugin loads)

let g:gen_tags#ctags_auto_gen = 1

function! SetUp() abort
  call RequireExecutable(g:gen_tags#ctags_bin)
endfunction

function! Test_auto_gen_in_repo() abort
  let l:root = MakeProject('repo', ['.git'])
  call Edit(l:root . '/src/a.c')
  call WaitJobs()
  call assert_true(filereadable(gen_tags#get_db_dir() . '/prj_tags'))
endfunction

function! Test_no_auto_gen_outside_repo() abort
  let l:root = MakeProject('plain')
  call Edit(l:root . '/src/a.c')
  call WaitJobs()
  call assert_false(filereadable(gen_tags#get_db_dir() . '/prj_tags'))
endfunction
