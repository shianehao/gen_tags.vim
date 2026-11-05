" ============================================================================
" File: ctags.vim
" Arthur: Jia Sui <jsfaint@gmail.com>
" Description:  1. Generate ctags under the given folder.
"               2. Add db when vim is open.
"               3. support generate third-party project ctags
" Required: This script requires ctags.
" Usage:
"   1. Generate ctags db:
"       :GenCtags
"   2. Edit Extend project list
"       :EditExt
"   3. Clear ctags file
"       :ClearCtags
" ============================================================================

function! s:ctags_get_extend_list(...) abort
  let l:file = (a:0 ? a:1 : gen_tags#get_db_dir()) . '/' . s:ext

  if filereadable(l:file)
    let l:list = readfile(l:file)
    return l:list
  endif

  return []
endfunction

function! s:ctags_get_extend_name(item, ...) abort
  let l:file = (a:0 ? a:1 : gen_tags#get_db_dir()) . '/' . gen_tags#get_db_name(a:item)

  return l:file
endfunction

"Add a tags file to 'tags'. Returns 1 if 'tags' changed.
function! s:ctags_add(file) abort
  let l:old = &tags
  let l:file = escape(a:file, ' ')
  exec 'set tags' . '+=' . expand(l:file)

  "Vim ignores duplicate 'tags' entries; only notify when something changed
  if &tags ==# l:old
    return 0
  endif

  silent! doautocmd User GenTags#CtagsLoaded
  return 1
endfunction

"Only add ctags db as extension database
function! s:ctags_add_ext(dir) abort
  for l:item in s:ctags_get_extend_list(a:dir)
    call s:ctags_add(s:ctags_get_extend_name(l:item, a:dir))
  endfor
endfunction

function! s:is_universal_ctags() abort
  if exists('s:ctags_version')
    return s:ctags_version
  endif

  let s:ctags_version = system(g:gen_tags#ctags_bin . ' --version') =~? '\<\%(Universal\) Ctags\>' ? 1 : 0

  return s:ctags_version
endfunction

"Generate ctags tags and set tags option
"Optional a:1 is the project's db dir, for callers whose current buffer is
"not in the project (e.g. ext.conf).
function! s:ctags_gen(filename, dir, ...) abort
  "Explicit generation re-detects the project (repo may be new)
  call gen_tags#clear_cache()

  "Check if current path in the blacklist
  if gen_tags#isblacklist(gen_tags#find_project_root())
    return
  endif

  "Generate tags directory
  let l:dir = a:0 ? a:1 : gen_tags#get_db_dir()
  call gen_tags#mkdir(l:dir)

  call gen_tags#echo('Generating ctags in background')
  let l:file = s:ctags_update_all(a:filename, a:dir, l:dir)

  "Search for existence tags string.
  let l:ret = stridx(&tags, l:dir)
  if l:ret == -1
    call s:ctags_add(l:file)
  endif
endfunction

function! s:ctags_auto_load() abort
  "Special buffers (help, quickfix, terminal, ...) never have project tags
  if !empty(&buftype)
    return
  endif

  let l:dir = gen_tags#get_db_dir()
  let l:file = l:dir . '/' . s:ctags_db
  if filereadable(l:file)
    call s:ctags_add(l:file)
    call s:ctags_add_ext(l:dir)
  endif
endfunction

"Edit extend conf file
function! s:ctags_ext_edit() abort
  augroup gen_ctags
    autocmd BufWritePost ext.conf call s:ctags_ext_gen()
  augroup END

  let l:dir = gen_tags#get_db_dir()
  call gen_tags#mkdir(l:dir)
  let l:file = l:dir . '/' . s:ext
  exec 'split' fnameescape(l:file)

  "ext.conf lives in the db dir, outside the project: remember which project
  "it belongs to so writing it doesn't depend on the current directory.
  let b:gen_tags_db_dir = l:dir
endfunction

"Geterate extend ctags
function! s:ctags_ext_gen() abort
  let l:dir = get(b:, 'gen_tags_db_dir', gen_tags#get_db_dir())
  for l:item in s:ctags_get_extend_list(l:dir)
    let l:file = s:ctags_get_extend_name(l:item, l:dir)
    call s:ctags_gen(l:file, l:item, l:dir)
  endfor

  augroup gen_ctags
    autocmd! BufWritePost ext.conf
  augroup END
endfunction

function! s:ctags_remove_file(file) abort
  if filereadable(a:file)
    call delete(a:file)
  endif
endfunction

"Delete exist tags file
function! s:ctags_clear(bang) abort
  if empty(a:bang) || !has('patch-7.4.1107')
    let l:dir = gen_tags#get_db_dir()

    "Remove project ctags
    let l:file = l:dir . '/' . s:ctags_db
    call s:ctags_remove_file(l:file)

    "Remove extend ctags
    for l:item in s:ctags_get_extend_list(l:dir)
      let l:file = s:ctags_get_extend_name(l:item, l:dir)
      call s:ctags_remove_file(l:file)
    endfor
  else
    "Remove all files include tag folder
    let l:dir = gen_tags#get_db_dir()
    call delete(l:dir, 'rf')
  endif
endfunction

function! s:ctags_auto_update() abort
  if !empty(&buftype)
    return
  endif

  let l:tagfile = gen_tags#get_db_dir() . '/' . s:ctags_db

  if !filereadable(l:tagfile)
    return
  endif

  let l:srcfile = fnamemodify(gen_tags#fix_path('<afile>'), ':p')
  if !gen_tags#is_file_belongs(l:srcfile)
    return
  endif

  "Prune tags content for saved file
  if g:gen_tags#ctags_prune
    call s:ctags_prune(l:tagfile, l:srcfile)
    call s:ctags_update_single(l:srcfile, l:tagfile)
  else
    call s:ctags_update_all('', '')
  endif
endfunction

function! s:ctags_auto_gen() abort
  " If not in scm, return
  let l:scm = gen_tags#get_scm_info()
  if empty(l:scm['type'])
    return
  endif

  " If tags exist, return
  let l:file = gen_tags#get_db_dir() . '/' . s:ctags_db
  if filereadable(l:file)
    return
  endif

  call s:ctags_gen('', '')
endfunction

function! gen_tags#ctags#init() abort
  if exists('g:loaded_gentags#ctags') && g:loaded_gentags#ctags == 1
    return
  endif

  let s:ctags_db = 'prj_tags'
  let s:ext = 'ext.conf'

  if !exists('g:gen_tags#ctags_auto_gen')
    let g:gen_tags#ctags_auto_gen = 0
  endif

  if !exists('g:gen_tags#ctags_auto_update')
    let g:gen_tags#ctags_auto_update = 1
  endif


  "Prune tags file before incremental update
  if !exists('g:gen_tags#ctags_prune')
    let g:gen_tags#ctags_prune = 0
  endif

  "Command list
  command! -nargs=0 GenCtags call s:ctags_gen('', '')
  command! -nargs=0 EditExt call s:ctags_ext_edit()
  command! -nargs=0 -bang ClearCtags call s:ctags_clear('<bang>')

  augroup gen_ctags
    autocmd!
    if g:gen_tags#ctags_auto_update
      autocmd BufWritePost * call s:ctags_auto_update()
    endif
    autocmd BufWinEnter * call s:ctags_auto_load()

    if g:gen_tags#ctags_auto_gen
      autocmd BufReadPost * call s:ctags_auto_gen()
    endif
  augroup END

  let g:loaded_gentags#ctags = 1
endfunction

"Prune tagfile
function! s:ctags_prune(tagfile, file) abort
  if !filereadable(a:tagfile)
    return
  endif

  "ctags escapes backslashes in file names on windows
  let l:needle = "\t" . (has('win32') ? escape(a:file, '\') : a:file) . "\t"

  "Literal match: file names may contain regex characters
  let l:tags = readfile(a:tagfile, 'b')
  let l:count = len(l:tags)
  call filter(l:tags, 'stridx(v:val, l:needle) < 0')

  "Skip rewriting the (possibly large) tags file when nothing was pruned
  if len(l:tags) != l:count
    call writefile(l:tags, a:tagfile, 'b')
  endif
endfunction

"s:ctags_update_single update tags file single file
"NOTE: ctags append mode is buggy.
"So if your project is not very large, just disable
function! s:ctags_update_single(file, tagfile) abort
  let l:cmd = s:ctags_cmd_pre()

  let l:file = expand(a:tagfile)

  let l:cmd += ['-f', l:file, '-a', expand(a:file)]

  call gen_tags#job#system_async(l:cmd)
endfunction

"s:ctags_update_all generate tags for all the file and the tags name
function! s:ctags_update_all(filename, dir, ...) abort
  let l:dir = a:0 ? a:1 : gen_tags#get_db_dir()

  let l:cmd = s:ctags_cmd_pre()

  if empty(a:filename)
    let l:file = l:dir . '/' . s:ctags_db
    let l:cmd += ['-f', l:file, '-R', expand(gen_tags#find_project_root())]
  else
    let l:file = a:filename
    let l:cmd += ['-f', l:file, '-R', expand(a:dir)]
  endif

  call gen_tags#job#system_async(l:cmd)

  return l:file
endfunction

function! s:ctags_cmd_pre() abort
  let l:cmd = [g:gen_tags#ctags_bin]

  "Extra flag in universal ctags, enable reference tags
  if s:is_universal_ctags()
    let l:cmd += ['--extras=+r']
  endif

  if !exists('g:gen_tags#ctags_opts')
    return l:cmd
  endif

  let l:cmd += gen_tags#opt_converter(g:gen_tags#ctags_opts)

  return l:cmd
endfunction
