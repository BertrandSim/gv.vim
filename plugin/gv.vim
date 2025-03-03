" The MIT License (MIT)
"
" Copyright (c) 2016 Junegunn Choi
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.

function! s:warn(message)
  echohl WarningMsg | echom a:message | echohl None
endfunction

function! s:shrug()
  call s:warn('¯\_(ツ)_/¯')
endfunction

let s:begin = '^[^0-9]*[0-9]\{4}-[0-9]\{2}-[0-9]\{2}\s\+'

function! gv#sha(...)
  return matchstr(get(a:000, 0, getline('.')), s:begin.'\zs[a-f0-9]\+')
endfunction

function! s:move(flag)
  let [l, c] = searchpos(s:begin, a:flag)
  return l ? printf('%dG%d|', l, c) : ''
endfunction

function! s:browse(url)
  call netrw#BrowseX(b:git_origin.a:url, 0)
endfunction

function! s:tabnew()
  execute (tabpagenr()-1).'tabnew'
endfunction

function! s:gbrowse()
  let sha = gv#sha()
  if empty(sha)
    return s:shrug()
  endif
  execute 'GBrowse' sha
endfunction

function! s:type(visual)
  if a:visual
    let shas = filter(map(getline("'<", "'>"), 'gv#sha(v:val)'), '!empty(v:val)')
    if len(shas) < 2
      return [0, 0]
    endif
    return ['diff', FugitiveShellCommand(['diff', shas[-1], shas[0]])]
  endif

  if exists('b:git_origin')
    let syn = synIDattr(synID(line('.'), col('.'), 0), 'name')
    if syn == 'gvGitHub'
      return ['link', '/issues/'.expand('<cword>')[1:]]
    elseif syn == 'gvTag'
      let tag = matchstr(getline('.'), '(tag: \zs[^ ,)]\+')
      return ['link', '/releases/'.tag]
    endif
  endif

  let sha = gv#sha()
  if !empty(sha)
    return ['commit', FugitiveFind(sha)]
  endif
  return [0, 0]
endfunction

function! s:split(tab)
  if a:tab
    call s:tabnew()
  elseif getwinvar(winnr('$'), 'gv')
    $wincmd w
    enew
  else
    vertical botright new
  endif
  let w:gv = 1
endfunction

function! s:open(visual, ...)
  let [type, target] = s:type(a:visual)

  if empty(type)
    return s:shrug()
  elseif type == 'link'
    return s:browse(target)
  endif

  call s:split(a:0)
  call s:scratch()
  if type == 'commit'
    execute 'e' escape(target, ' ')
    nnoremap <silent> <buffer> gb :GBrowse<cr>
  elseif type == 'diff'
    call s:fill(target)
    setf diff
  endif
  nnoremap <silent> <buffer> q :close<cr>
  let bang = a:0 ? '!' : ''
  if exists('#User#GV'.bang)
    execute 'doautocmd <nomodeline> User GV'.bang
  endif
  wincmd p
  echo
endfunction

function! s:dot()
  let sha = gv#sha()
  return empty(sha) ? '' : ':Git  '.sha."\<s-left>\<left>"
endfunction

function! s:maps()
  nnoremap <silent> <buffer> q    :$wincmd w <bar> close<cr>
  nnoremap <silent> <buffer> <nowait> gq :$wincmd w <bar> close<cr>
  nnoremap <silent> <buffer> r    :call <sid>refresh()<cr>
  nnoremap <silent> <buffer> gb   :call <sid>gbrowse()<cr>
  nnoremap <silent> <buffer> <cr> :call <sid>open(0)<cr>
  nnoremap <silent> <buffer> o    :call <sid>open(0)<cr>
  nnoremap <silent> <buffer> O    :call <sid>open(0, 1)<cr>
  xnoremap <silent> <buffer> <cr> :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <buffer> o    :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <buffer> O    :<c-u>call <sid>open(1, 1)<cr>
  nnoremap          <buffer> <expr> .  <sid>dot()
  nnoremap <silent> <buffer> <expr> ]] <sid>move('')
  nnoremap <silent> <buffer> <expr> ][ <sid>move('')
  nnoremap <silent> <buffer> <expr> [[ <sid>move('b')
  nnoremap <silent> <buffer> <expr> [] <sid>move('b')
  xnoremap <silent> <buffer> <expr> ]] <sid>move('')
  xnoremap <silent> <buffer> <expr> ][ <sid>move('')
  xnoremap <silent> <buffer> <expr> [[ <sid>move('b')
  xnoremap <silent> <buffer> <expr> [] <sid>move('b')

  nmap              <buffer> <C-n> ]]o
  nmap              <buffer> <C-p> [[o
  xmap              <buffer> <C-n> ]]ogv
  xmap              <buffer> <C-p> [[ogv
endfunction

function! s:setup(git_origin)
  call s:tabnew()
  call s:scratch()

  if exists('g:fugitive_github_domains')
    let domain = join(map(extend(['github.com'], g:fugitive_github_domains),
          \ 'escape(substitute(split(v:val, "://")[-1], "/*$", "", ""), ".")'), '\|')
  else
    let domain = '.*github.\+'
  endif
  " https://  github.com  /  junegunn/gv.vim  .git
  " git@      github.com  :  junegunn/gv.vim  .git
  let pat = '^\(https\?://\|git@\)\('.domain.'\)[:/]\([^@:/]\+/[^@:/]\{-}\)\%(.git\)\?$'
  let origin = matchlist(a:git_origin, pat)
  if !empty(origin)
    let scheme = origin[1] =~ '^http' ? origin[1] : 'https://'
    let b:git_origin = printf('%s%s/%s', scheme, origin[2], origin[3])
  endif
endfunction

function! s:scratch()
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
endfunction

function! s:fill(cmd)
  setlocal modifiable
  %delete _
  silent execute 'read' escape('!'.a:cmd, '%')
  normal! gg"_dd
  setlocal nomodifiable
endfunction

function! s:tracked(file)
  call system(FugitiveShellCommand(['ls-files', '--error-unmatch', a:file]))
  return !v:shell_error
endfunction

function! s:check_buffer(current)
  if empty(a:current)
    throw 'untracked buffer'
  elseif !s:tracked(a:current)
    throw a:current.' is untracked'
  endif
endfunction

function! s:log_opts(bang, visual, line1, line2)
  if a:visual || a:bang
    let current = expand('%')
    call s:check_buffer(current)
    return a:visual ? [[printf('-L%d,%d:%s', a:line1, a:line2, current)], []] : [['--follow'], ['--', current]]
  endif
  return [['--graph'], []]
endfunction

function! s:list(log_opts)
  let repo_short_name = fnamemodify(substitute(FugitiveGitDir(), '[\\/]\.git[\\/]\?$', '', ''), ':t')
  let bufname = repo_short_name.' '.join(a:log_opts)
  silent exe (bufexists(bufname) ? 'buffer' : 'file') fnameescape(bufname)

  let default_opts = ['--color=never', '--date=short', '--format=%ad %h%d %s (%an)']
  let git_args = ['log'] + default_opts + a:log_opts
  let b:git_log_cmd = FugitiveShellCommand(git_args)

  call s:fill(b:git_log_cmd)
  setlocal nowrap tabstop=8 cursorline iskeyword+=#

  if !exists(':GBrowse')
    doautocmd <nomodeline> User Fugitive
  endif
  call s:maps()
  setf GV
  redraw
  echo 'o: open split / O: open tab / gb: GBrowse / r: refresh / q: quit'
endfunction

function! s:refresh()
  " refresh current GV buffer
  setlocal modifiable
  normal! gg"_dG
  setlocal nomodifiable
  call s:fill(b:git_log_cmd)
endfunction

function! s:trim(arg)
  let arg = substitute(a:arg, '\s*$', '', '')
  return arg =~ "^'.*'$" ? substitute(arg[1:-2], "''", '', 'g')
     \ : arg =~ '^".*"$' ? substitute(substitute(arg[1:-2], '""', '', 'g'), '\\"', '"', 'g')
     \ : substitute(substitute(arg, '""\|''''', '', 'g'), '\\ ', ' ', 'g')
endfunction

function! gv#shellwords(arg)
  let words = []
  let contd = 0
  for token in split(a:arg, '\%(\%(''\%([^'']\|''''\)\+''\)\|\%("\%(\\"\|[^"]\)\+"\)\|\%(\%(\\ \|\S\)\+\)\)\s*\zs')
    let trimmed = s:trim(token)
    if contd
      let words[-1] .= trimmed
    else
      call add(words, trimmed)
    endif
    let contd = token !~ '\s\+$'
  endfor
  return words
endfunction

function! s:split_pathspec(args)
  let split = index(a:args, '--')
  if split < 0
    return [a:args, []]
  elseif split == 0
    return [[], a:args]
  endif
  return [a:args[0:split-1], a:args[split:]]
endfunction

function! s:gl(buf, visual)
  if !exists(':Gllog')
    return
  endif
  tab split
  silent execute a:visual ? "'<,'>" : "" 'Gllog'
  call setloclist(0, insert(getloclist(0), {'bufnr': a:buf}, 0))
  noautocmd b #
  lopen
  xnoremap <buffer> o :call <sid>gld()<cr>
  nnoremap <buffer> o <cr><c-w><c-w>
  nnoremap <buffer> O :call <sid>gld()<cr>
  nnoremap <buffer> q :tabclose<cr>
  nnoremap <buffer> gq :tabclose<cr>
  call matchadd('Conceal', '^fugitive://.\{-}\.git//')
  call matchadd('Conceal', '^fugitive://.\{-}\.git//\x\{7}\zs.\{-}||')
  setlocal concealcursor=nv conceallevel=3 nowrap
  let w:quickfix_title = 'o: open / o (in visual): diff / O: open (tab) / q: quit'
endfunction

function! s:gld() range
  let [to, from] = map([a:firstline, a:lastline], 'split(getline(v:val), "|")[0]')
  execute (tabpagenr()-1).'tabedit' escape(to, ' ')
  if from !=# to
    execute 'vsplit' escape(from, ' ')
    windo diffthis
  endif
endfunction

function! s:gv(bang, visual, line1, line2, args) abort
  if !exists('g:loaded_fugitive')
    return s:warn('fugitive not found')
  endif

  if empty(FugitiveGitDir())
    return s:warn('not in git repo')
  endif

  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  let root = FugitiveFind(':/')
  try
    if cwd !=# root
      execute cd escape(root, ' ')
    endif
    if a:args =~ '?$'
      if len(a:args) > 1
        return s:warn('invalid arguments')
      endif
      call s:check_buffer(expand('%'))
      call s:gl(bufnr(''), a:visual)
    else
      let [opts1, paths1] = s:log_opts(a:bang, a:visual, a:line1, a:line2)
      let [opts2, paths2] = s:split_pathspec(gv#shellwords(a:args))
      let log_opts = opts1 + opts2 + paths1 + paths2
      call s:setup(FugitiveRemoteUrl())
      call s:list(log_opts)
      call FugitiveDetect(@#)
    endif
  catch
    return s:warn(v:exception)
  finally
    if getcwd() !=# cwd
      cd -
    endif
  endtry
endfunction

command! -bang -nargs=* -range=0 -complete=customlist,fugitive#CompleteObject GV call s:gv(<bang>0, <count>, <line1>, <line2>, <q-args>)
