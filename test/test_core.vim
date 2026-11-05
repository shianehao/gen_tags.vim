" Tests for autoload/gen_tags.vim: project detection, caching and paths

function! TearDown() abort
  let g:gen_tags#root_marker = '.root'
  let g:gen_tags#root_path = ''
  let g:gen_tags#use_cache_dir = 1
  let g:gen_tags#cache_dir = g:test_tmp . '/cache/'
  let g:gen_tags#blacklist = []
  let g:gen_tags#blacklist_re = []
endfunction

function! Test_get_db_name_strips_separators() abort
  call assert_equal('homeuserproj', gen_tags#get_db_name('/home/user/proj'))
  call assert_equal('Cmyprojv1', gen_tags#get_db_name('C:\my proj\v1'))
  call assert_equal('ab', gen_tags#get_db_name('a.b'))
endfunction

function! Test_opt_converter() abort
  call assert_equal(['--a', '-b'], gen_tags#opt_converter('--a -b'))
  call assert_equal(['--x=1 2'], gen_tags#opt_converter(['--x=1 2']))
endfunction

function! Test_fix_path_expands() abort
  call assert_equal(expand('$HOME') . '/x', gen_tags#fix_path('$HOME/x'))
endfunction

function! Test_mkdir_is_idempotent() abort
  let l:dir = g:test_tmp . '/a/b/c'
  call gen_tags#mkdir(l:dir)
  call assert_true(isdirectory(l:dir))
  call gen_tags#mkdir(l:dir)
  call assert_true(isdirectory(l:dir))
endfunction

function! Test_scm_git_dir() abort
  let l:root = MakeProject('git', ['.git'])
  call Edit(l:root . '/src/a.c')
  call assert_equal({'type': '.git', 'root': l:root}, gen_tags#get_scm_info())
endfunction

function! Test_scm_git_file() abort
  "worktrees and submodules have a .git file instead of a directory
  let l:root = MakeProject('gitfile', ['.git-file'])
  call Edit(l:root . '/src/a.c')
  call assert_equal({'type': '.git', 'root': l:root}, gen_tags#get_scm_info())
endfunction

function! Test_scm_hg_and_svn() abort
  let l:hg = MakeProject('hg', ['.hg'])
  call Edit(l:hg . '/src/a.c')
  call assert_equal({'type': '.hg', 'root': l:hg}, gen_tags#get_scm_info())

  let l:svn = MakeProject('svn', ['.svn'])
  call Edit(l:svn . '/src/a.c')
  call assert_equal({'type': '.svn', 'root': l:svn}, gen_tags#get_scm_info())
endfunction

function! Test_scm_none() abort
  let l:root = MakeProject('plain')
  call Edit(l:root . '/src/a.c')
  call assert_equal({'type': '', 'root': ''}, gen_tags#get_scm_info())
endfunction

function! Test_root_marker_wins_over_git() abort
  let l:root = MakeProject('marker', ['.git', '.root'])
  call Edit(l:root . '/src/a.c')
  call assert_equal('.root', gen_tags#get_scm_info()['type'])
endfunction

function! Test_custom_root_marker() abort
  let g:gen_tags#root_marker = '.project'
  let l:root = MakeProject('custom', ['.project'])
  call Edit(l:root . '/src/a.c')
  call assert_equal({'type': '.project', 'root': l:root}, gen_tags#get_scm_info())
endfunction

function! Test_nested_repo_uses_nearest() abort
  let l:outer = MakeProject('outer', ['.git'])
  let l:inner = MakeProject('outer/src/inner', ['.git'])
  call Edit(l:inner . '/src/a.c')
  call assert_equal(l:inner, gen_tags#get_scm_info()['root'])
  call Edit(l:outer . '/src/a.c')
  call assert_equal(l:outer, gen_tags#get_scm_info()['root'])
endfunction

function! Test_unnamed_buffer_uses_cwd() abort
  let l:root = MakeProject('cwd', ['.git'])
  enew
  execute 'cd' fnameescape(l:root . '/src')
  call assert_equal(l:root, gen_tags#get_scm_info()['root'])
endfunction

function! Test_cache_and_clear_cache() abort
  let l:root = MakeProject('late')
  call Edit(l:root . '/src/a.c')
  call assert_equal('', gen_tags#get_scm_info()['type'])

  "A repo created later is not seen until the cache is cleared
  call mkdir(l:root . '/.git')
  call assert_equal('', gen_tags#get_scm_info()['type'])
  call gen_tags#clear_cache()
  call assert_equal('.git', gen_tags#get_scm_info()['type'])
endfunction

function! Test_cache_returns_copy() abort
  let l:root = MakeProject('copy', ['.git'])
  call Edit(l:root . '/src/a.c')
  let l:info = gen_tags#get_scm_info()
  let l:info['type'] = 'junk'
  call assert_equal('.git', gen_tags#get_scm_info()['type'])
endfunction

function! Test_find_project_root() abort
  let l:root = MakeProject('findroot', ['.git'])
  call Edit(l:root . '/src/a.c')
  call assert_equal(l:root, gen_tags#find_project_root())
endfunction

function! Test_find_project_root_falls_back_to_cwd() abort
  let l:root = MakeProject('nocwd')
  call Edit(l:root . '/src/a.c')
  execute 'cd' fnameescape(g:test_tmp)
  call assert_equal(gen_tags#fix_path(getcwd()), gen_tags#find_project_root())
endfunction

function! Test_root_path_option() abort
  let l:root = MakeProject('rootpath', ['.git'])
  let l:other = MakeProject('assigned')
  call Edit(l:root . '/src/a.c')

  let g:gen_tags#root_path = l:other
  call assert_equal(l:other, gen_tags#find_project_root())

  "A path that doesn't exist is ignored
  let g:gen_tags#root_path = g:test_tmp . '/does-not-exist'
  call assert_equal(l:root, gen_tags#find_project_root())
endfunction

function! Test_get_db_dir_in_cache_dir() abort
  let l:root = MakeProject('dbdir', ['.git'])
  call Edit(l:root . '/src/a.c')
  let l:expected = g:test_tmp . '/cache/' . gen_tags#get_db_name(l:root)
  call assert_equal(l:expected, gen_tags#get_db_dir())

  "A missing trailing slash on the cache dir is handled
  let g:gen_tags#cache_dir = g:test_tmp . '/cache'
  call assert_equal(l:expected, gen_tags#get_db_dir())
endfunction

function! Test_get_db_dir_without_cache_dir() abort
  let g:gen_tags#use_cache_dir = 0
  let l:root = MakeProject('nocache', ['.git'])
  call Edit(l:root . '/src/a.c')
  call assert_equal(l:root . '/.git/tags_dir', gen_tags#get_db_dir())

  "Outside a repo the cache dir is still used
  let l:plain = MakeProject('nocache-plain')
  call Edit(l:plain . '/src/a.c')
  call assert_match('^' . escape(g:test_tmp, '\.[]~*') . '/cache/', gen_tags#get_db_dir())
endfunction

function! Test_isblacklist() abort
  let l:root = MakeProject('black')
  call assert_false(gen_tags#isblacklist(l:root))

  let g:gen_tags#blacklist = [l:root]
  call assert_true(gen_tags#isblacklist(l:root))
  call assert_false(gen_tags#isblacklist(l:root . '-other'))

  let g:gen_tags#blacklist = []
  let g:gen_tags#blacklist_re = ['black$']
  call assert_true(gen_tags#isblacklist(l:root))
  call assert_false(gen_tags#isblacklist(l:root . '/src'))
endfunction

function! Test_is_file_belongs() abort
  let l:root = MakeProject('belong', ['.git'])
  call Edit(l:root . '/src/a.c')
  call assert_true(gen_tags#is_file_belongs(l:root . '/src/a.c'))
  call assert_true(gen_tags#is_file_belongs(l:root . '/top.c'))
  call assert_true(gen_tags#is_file_belongs(l:root . '/deep/er/x.c'))
  call assert_false(gen_tags#is_file_belongs(g:test_tmp . '/elsewhere/x.c'))
  "A sibling whose name starts with the root's name is not inside it
  call assert_false(gen_tags#is_file_belongs(l:root . '2/x.c'))
endfunction

function! Test_is_file_belongs_regex_chars_in_root() abort
  let l:root = MakeProject('a.b', ['.git'])
  call Edit(l:root . '/src/a.c')
  call assert_true(gen_tags#is_file_belongs(l:root . '/src/a.c'))
  "'.' must not act as a regex wildcard
  call assert_false(gen_tags#is_file_belongs(g:test_tmp . '/aXb/src/a.c'))
endfunction
