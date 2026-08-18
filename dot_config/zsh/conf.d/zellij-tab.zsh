# Name the zellij tab after the first command run in it that matches the table below,
# then leave it alone: later commands, unmatched commands, and any rename done by hand
# keep the name they were given.
# Sourced by zephyr's confd plugin.

[[ -n $ZELLIJ ]] || return 0

# glob pattern (matched against the whole command line, extendedglob on) -> tab name.
# First match wins; anything unmatched never renames.
typeset -ga ZELLIJ_TAB_NAMES=(
    'ssh *(100.68.166.71|fabien-mba5.zuul-gopher.ts.net)*'  'HOME MBA'
)

# Name of the focused tab, empty when it has never been named.
_zellij_tab_current() {
    setopt localoptions extendedglob
    local l
    for l in ${(f)"$(command zellij action dump-layout 2>/dev/null)"}; do
        [[ $l == [[:space:]]#tab[[:space:]]* && $l == *focus=true* ]] || continue
        [[ $l == (#b)*name=\"([^\"]#)\"* ]] && print -r -- $match[1]
        return
    done
}

_zellij_tab_match() {
    setopt localoptions extendedglob
    local i
    for (( i = 1; i <= $#ZELLIJ_TAB_NAMES; i += 2 )); do
        [[ $1 == ${~ZELLIJ_TAB_NAMES[i]} ]] || continue
        print -r -- $ZELLIJ_TAB_NAMES[i+1]
        return
    done
}

_zellij_tab_preexec() {
    setopt localoptions extendedglob
    local name=$(_zellij_tab_match "$1")
    [[ -n $name ]] || return
    # dump-layout and rename-tab both act on the *focused* tab, so a shell running a
    # command in a background tab reads (and would rename) someone else's tab. Bail on
    # any name that isn't zellij's default, and stay hooked: this shell's own tab may
    # still be unnamed, waiting for its turn in the foreground.
    local current=$(_zellij_tab_current)
    [[ -z $current || $current == 'Tab #'<-> ]] || return
    command zellij action rename-tab "$name" &>/dev/null
    add-zsh-hook -d preexec _zellij_tab_preexec
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _zellij_tab_preexec
