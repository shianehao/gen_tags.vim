" Tests for autoload/gen_tags/job.vim and statusline.vim

function! SetUp() abort
  if !has('nvim') && !has('job')
    call Skip('no job support')
  endif
  call RequireExecutable('sleep')
  let g:done = 0
endfunction

function! TearDown() abort
  let g:gen_tags#statusline = 0
endfunction

function! OnDone(...) abort
  let g:done += 1
endfunction

function! Test_async_job_runs_callback() abort
  call gen_tags#job#system_async(['sleep', '0'], function('OnDone'))
  call assert_true(WaitFor('g:done == 1'), 'callback not called')
  call assert_false(gen_tags#job#is_running())
endfunction

function! Test_is_running() abort
  call assert_false(gen_tags#job#is_running())
  call gen_tags#job#system_async(['sleep', '0.5'])
  call assert_true(gen_tags#job#is_running())
  call WaitJobs()
  call assert_false(gen_tags#job#is_running())
endfunction

function! Test_same_job_not_started_twice() abort
  call gen_tags#job#system_async(['sleep', '0.5'], function('OnDone'))
  call gen_tags#job#system_async(['sleep', '0.5'], function('OnDone'))
  call assert_true(WaitFor('g:done >= 1'))
  sleep 200m
  call assert_equal(1, g:done)

  "Once finished, the same command can run again
  call gen_tags#job#system_async(['sleep', '0'], function('OnDone'))
  call gen_tags#job#system_async(['sleep', '0.5'], function('OnDone'))
  call assert_true(WaitFor('g:done == 3'))
endfunction

function! Test_statusline_set_and_clear() abort
  let g:gen_tags#statusline = 1
  set statusline=original
  call gen_tags#statusline#set('working')
  call assert_match('gen_tags.vim', &l:statusline)
  call assert_equal('working', b:msg)
  call gen_tags#statusline#clear()
  call assert_equal('original', &statusline)
  set statusline&
endfunction

function! Test_statusline_disabled_by_default() abort
  set statusline=original
  call gen_tags#statusline#set('working')
  call assert_equal('original', &statusline)
  set statusline&
endfunction
