# Name the zellij tab after what the shell is doing: the running command while one
# is running, the current directory (fish-abbreviated) back at the prompt.
# Sourced by zephyr's confd plugin.

[[ -n $ZELLIJ ]] || return 0

# ~/.config/zellij -> ~/.c/zellij. Every component but the last is cut to its first
# character; dotdirs keep the dot (.config -> .c), same as fish's prompt_pwd.
_zellij_tab_cwd() {
    local dir=${(%):-%~} part
    local -a parts out
    parts=(${(s:/:)dir})
    (( $#parts )) || { print -r -- / ; return }
    for part in ${parts[1,-2]}; do
        [[ $part == .* ]] && out+=${part[1,2]} || out+=${part[1,1]}
    done
    # ${dir[1]/#[^\/]/} is "/" for absolute paths outside $HOME, empty for ~ ones.
    print -r -- "${dir[1]/#[^\/]/}${(j:/:)out}${out:+/}${parts[-1]}"
}

# `uv run ansible-playbook -i inventories/prod gitlab.yaml -e ... --diff`
# -> `ansible-playbook gitlab.yaml`: drop the runner, keep the command and its first
# positional argument (basename only).
_zellij_tab_cmd() {
    local -a words=(${(z)1})
    local w
    while (( $#words > 1 )); do
        case ${words[1]:t} in
        sudo | doas | env | command | nohup | time | nice) shift 1 words ;;
        uv | uvx | poetry | pdm | rye | hatch | pipenv | npx | bunx)
            shift 1 words
            [[ ${words[1]} == run ]] && shift 1 words
            ;;
        *=*) shift 1 words ;;  # leading VAR=value assignments
        *) break ;;
        esac
    done
    (( $#words )) || return
    local cmd=${words[1]:t} arg=
    words=(${words[2,-1]})
    while (( $#words )); do
        w=$words[1]
        shift 1 words
        [[ $w == ('|' | '||' | '&&' | ';' | '&' | '>'* | '<'*) ]] && break
        if [[ $w == -?* ]]; then
            # ponytail: assume only a lone short flag (-i) takes a separate value;
            # long flags are treated as booleans or --opt=value. Wrong for
            # `--limit foo`-style flags, but those are rarely the first positional.
            [[ $w == -[^-] && $words[1] != -* ]] && shift 1 words
            continue
        fi
        arg=$w
        break
    done
    print -r -- "${cmd}${arg:+ ${arg:t}}"
}

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

# Synchronous on purpose: backgrounding the rename lets a fast command's preexec and
# precmd calls land out of order and leave the tab stuck on the command name.
_zellij_tab_set() {
    setopt localoptions extendedglob
    local name=$1
    [[ -n $name ]] || return
    (( ${#name} > 30 )) && name="${name[1,29]}…"
    [[ $name == $_zellij_tab_last ]] && return

    # Hands off any tab this shell doesn't own: one someone renamed by hand (or in a
    # layout), or one already driven by a second shell in the same tab. Costs a
    # dump-layout, but only when the name is about to change anyway.
    #
    # Re-checked every time rather than latched: dump-layout and rename-tab both act on
    # the *focused* tab, so a shell whose tab is in the background reads a foreign name.
    # Latching that would strand the tab on the command name after any command you
    # switched away from. ponytail: costs a dump-layout per prompt in a hand-named tab.
    local current=$(_zellij_tab_current)
    if [[ -n $_zellij_tab_last ]]; then
        [[ $current == $_zellij_tab_last ]] || return
    else
        [[ -z $current || $current == 'Tab #'<-> ]] || return
    fi

    _zellij_tab_last=$name
    command zellij action rename-tab "$name" &>/dev/null
}

_zellij_tab_preexec() { _zellij_tab_set "$(_zellij_tab_cmd "$1")" }
_zellij_tab_precmd() { _zellij_tab_set "$(_zellij_tab_cwd)" }

autoload -Uz add-zsh-hook
add-zsh-hook preexec _zellij_tab_preexec
add-zsh-hook precmd _zellij_tab_precmd
