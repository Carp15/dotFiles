" vim-plug
if has('vim_starting')
    if !isdirectory(expand('$HOME') . '/.local/share/nvim')
        call system('curl -fLo ' . expand('$HOME') . '/.local/share/nvim/site/autoload/plug.vim --create-dirs \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
    end
endif
call plug#begin(expand('$HOME') . '/.local/share/nvim/plugged')


if isdirectory('/usr/local/opt/fzf')
    Plug '/usr/local/opt/fzf' | Plug 'junegunn/fzf.vim'
else
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --bin' }
    Plug 'junegunn/fzf.vim'
endif
let g:make = 'gmake'
if exists('make')
    let g:make = 'make'
endif
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }

Plug 'w0rp/ale'


" color
Plug 'nanotech/jellybeans.vim'
Plug 'tomasr/molokai'


" go
"Plug 'faith/vim-go'
Plug 'zchee/nvim-go', { 'do': 'make', 'for': 'go' }
"Plug 'nsf/gocode', { 'for': 'go', 'rtp': 'nvim', 'do': expand('$HOME') . '/.local/share/nvim/plugged/gocode/nvim/symlink.sh'}
Plug 'nsf/gocode', {'for': 'go', 'rtp': 'nvim'}
Plug 'zchee/deoplete-go', {'for': 'go', 'do': 'make'}
"Plug 'zchee/vim-goiferr', {'for': 'go', 'on': 'GoIferr'}
"Plug 'buoto/gotests-vim', {'for': 'go', 'on': 'GoTests'}
"Plug 'tweekmonster/hl-goimport.vim', {'for': 'go'}

call plug#end()

" encoding
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8

" backspace indent
set backspace=indent,eol,start

"tab
set tabstop=4
set softtabstop=0
set shiftwidth=4
set smarttab
set expandtab

" visual
syntax on
set ruler
set number

let no_beffers_menu=1
if !exists('g:not_finish_vimplug')
    "colorscheme jellybeans
    colorscheme molokai
    highlight Normal ctermbg=none
endif

" auto comment off
augroup auto_comment_off
    autocmd!
    autocmd BufEnter * setlocal formatoptions-=r
    autocmd BufEnter * setlocal formatoptions-=o
augroup END

" use deoplete
let g:deoplete#enable_at_startup = 1
let g:deoplete#auto_complete_delay = 0
let g:deoplete#auto_complete_start_length = 1
let g:deoplete#auto_completion_start_length = 1
let g:deoplete#enable_camel_case = 1
let g:deoplete#enable_ignore_case = 1
let g:deoplete#enable_refresh_always = 1
let g:deoplete#enable_smart_case = 1
let g:deoplete#file#enable_buffer_path = 1
let g:deoplete#max_list = 10000

" go
let g:go_fmt_command = "goimports"

