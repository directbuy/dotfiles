if exists("b:git_spell")
  finish
endif

let b:git_spell = 1 " Don't load twice in one buffer

setlocal spell
set textwidth=79
