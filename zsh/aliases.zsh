alias crypto='curl rate.sx' # Get crypto prices

# wget sucks with certificates. Let's keep it simple.
alias wget="curl -O"

alias tf="terraform"

alias g="git"
alias gs="git status -sb"

#alias k="kubectl"
alias vi="vim"
alias kx="kubectx"
alias kn="kubens"

alias r="source ~/.zshrc"

alias myip='curl http://ipecho.net/plain; echo'

# Alias Screensaver on macOS High Sierra as afk. My Mac locks when it starts.
if [[ -f "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine" ]]; then
    alias afk="open -a ScreenSaverEngine"
fi

if hash exa 2>/dev/null; then
  alias ls='exa'                                                          # ls
  alias l='exa -lbF --git'                                                # list, size, type, git
  alias ll='exa -lbGF --git'                                             # long list
  alias llm='exa -lbGd --git --sort=modified'                            # long list, modified date sort
  alias la='exa -lbhHigUmuSa --time-style=long-iso --git --color-scale'  # all list
  alias lx='exa -lbhHigUmuSa@ --time-style=long-iso --git --color-scale' # all + extended list
  alias lS='exa -1'                                                              # one column, just names
  alias lt='exa --tree --level=2'                                         # tree
fi
