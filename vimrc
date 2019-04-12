" Theme and Styling
set t_Co=256
set background=light
colorscheme solarized

set history=200        " keep 200 lines of command line history
set ruler              " show the cursor position all the time
set showcmd            " display incomplete commands
set wildmenu           " display completion matches in a status line
set autoindent
set expandtab          "Insert spaces instead of tabs in insert mode. Use spaces for indents"
set showmatch
set mouse=a
set backspace=indent,eol,start

" Set Proper Tabs
set tabstop=4
set shiftwidth=4
set smarttab
set expandtab

" Do not show default status line as we got a plugin for that
set noshowmode


" shows trailing whitespaces
highlight ExtraWhitespace ctermbg=darkgreen guibg=lightgreen
autocmd BufEnter * match ExtraWhitespace /\s\+$/

"remove trailing whitespaces
:command Rs %s/\s\+$//g

" make -> perl -c
":w -> make
"autocmd FileType perl set makeprg=perl\ -c\ %\ $*
"autocmd FileType perl set errorformat=%f:%l:%m
"autocmd BufWritePost *.pl,*.pm make

" allow autofolding with SPACE
nnoremap <silent> <Space> @=(foldlevel('.')?"za\|zd":"zfa}")<CR>
nnoremap <F5> :GundoToggle<CR>

set relativenumber
set cursorline " highlight current line
set wildmenu " visual autocomplete for command menu

" toggle between number and relativenumber
function! ToggleNumber()
  if(&relativenumber == 1)
    set norelativenumber
    set number
  else
    set relativenumber
  endif
endfunc

" remove numbers
function! RemoveNumber()
  set norelativenumber
  set nonumber
endfunc

nnoremap <F6> :call ToggleNumber()<CR>
nnoremap <leader><F6> :call RemoveNumber()<CR>

" Tagbar
nmap <F4> :TagbarToggle<CR>

" NERDTree
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
map <C-n> :NERDTreeToggle<CR>

" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Make sure you use single quotes

Plug 'tpope/vim-sensible'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'scrooloose/syntastic'
Plug 'altercation/vim-colors-solarized'
Plug 'majutsushi/tagbar'
Plug 'scrooloose/nerdcommenter'
Plug 'valloric/youcompleteme'
Plug 'godlygeek/tabular'
Plug 'honza/vim-snippets'
Plug 'ervandew/supertab'
Plug 'junegunn/fzf'
Plug 'itchyny/lightline'
Plug 'w0rp/ale'
Plug 'airblade/vim-gitgutter'

" On-demand loading
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }

" Initialize plugin system
call plug#end()
