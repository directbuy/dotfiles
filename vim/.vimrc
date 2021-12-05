set runtimepath+=~/.vim
set number
set t_u7=
colorscheme japanesque
syntax on
"Turn off the stupid bell in zsh/centos
set vb t_vb=
set noeb
"put in some pep8 compliance help
"set textwidth=79
set shiftwidth=4 "operation >> and << move 4 spaces
set tabstop=4 "hard tab is 4 spaces
set expandtab "insert spaces when hitting TABs
set softtabstop=4 "insert/delete 4 spaces with TAB/BACKSPACE
" set shiftround "round indect to multiple of shiftwidth
set autoindent "align new line to indent with previous lin
set wildmode=longest,list,full
set wildmenu
set encoding=utf-8
filetype plugin on
