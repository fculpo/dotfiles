abbr -a cask "brew cask"

abbr -a dig "dig +nocmd any +multiline +noall +answer"

# wget sucks with certificates. Let's keep it simple.
abbr -a wget "curl -O"

# File size
abbr -a fs "stat -f \"%z bytes\""

abbr -a k kubectl
abbr -a kg kubectl get
abbr -a kga kubectl get all
abbr -a vi vim

abbr -a which which -a

# git
abbr -a g git
abbr -a gs  git status -sb
abbr -a ga  git add
abbr -a gc  git commit
abbr -a gcm git commit -m
abbr -a gca git commit --amend
abbr -a gcl git clone
abbr -a gco git checkout
abbr -a gp  git push
abbr -a gpl git pull
abbr -a gl  git l
abbr -a gd  git diff
abbr -a gds git diff --staged
abbr -a gr  git rebase -i HEAD~15
abbr -a gf  git fetch
abbr -a gfc git findcommit
abbr -a gfm git findmessage
abbr -a gco git checkout
