alias crypto='curl rate.sx' # Get crypto prices

# wget sucks with certificates. Let's keep it simple.
alias wget="curl -O"

[[ "$(command -v colordiff)" ]] && alias diff='colordiff'

alias mount='mount |column -t'

alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'
alias ports='netstat -tulanp'

# confirmation #
alias mv='mv -i'
alias cp='cp -i'
alias ln='ln -i'

#progress bar on file copy. Useful evenlocal.
alias cpProgress="rsync --progress -ravz"

alias tf="terraform"

alias g="git"
alias gs="git status -sb"

alias k="kubectl"
alias vi="vim"
alias kx="kubectx"
alias kn="kubens"

alias r="source ~/.zshrc"

alias myip='curl http://ipecho.net/plain; echo'

# Alias Screensaver on macOS High Sierra as afk. My Mac locks when it starts.
if [[ -f "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine" ]]; then
    alias afk="open -a ScreenSaverEngine"
fi

[[ "$(command -v prettyping)" ]] && alias ping="prettyping --nolegend"

[[ "$(command -v bat)" ]] && alias cat="bat"

[[ "$(command -v htop)" ]] && alias top="htop"

if hash eza 2>/dev/null; then
  alias ls='eza'                                                          # ls
  alias l='eza -lbF --git'                                                # list, size, type, git
  alias ll='eza -lbGF --git'                                             # long list
  alias llm='eza -lbGd --git --sort=modified'                            # long list, modified date sort
  alias la='eza -lbhHigUmuSa --time-style=long-iso --git --color-scale'  # all list
  alias lx='eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale' # all + extended list
  alias lS='eza -1'                                                              # one column, just names
  alias lt='eza --tree --level=2'                                         # tree
fi

if exa --icons &>/dev/null; then
    alias ls='exa --git --icons'                             # system: List filenames on one line
    alias l='exa --git --icons -lF'                          # system: List filenames with long format
    alias ll='exa -lahF --git'                               # system: List all files
    alias lll="exa -1F --git --icons"                        # system: List files with one line per file
    alias llm='ll --sort=modified'                           # system: List files by last modified date
    alias la='exa -lbhHigUmuSa --color-scale --git --icons'  # system: List files with attributes
    alias lx='exa -lbhHigUmuSa@ --color-scale --git --icons' # system: List files with extended attributes
    alias lt='exa --tree --level=2'                          # system: List files in a tree view
    alias llt='exa -lahF --tree --level=2'                   # system: List files in a tree view with long format
    alias ltt='exa -lahF | grep "$(date +"%d %b")"'          # system: List files modified today
elif command -v exa &>/dev/null; then
    alias ls='exa --git'
    alias l='exa --git -lF'
    alias ll='exa -lahF --git'
    alias lll="exa -1F --git"
    alias llm='ll --sort=modified'
    alias la='exa -lbhHigUmuSa --color-scale --git'
    alias lx='exa -lbhHigUmuSa@ --color-scale --git'
    alias lt='exa --tree --level=2'
    alias llt='exa -lahF --tree --level=2'
    alias ltt='exa -lahF | grep "$(date +"%d %b")"'
elif command -v colorls &>/dev/null; then
    alias ll="colorls -1A --git-status"
    alias ls="colorls -A"
    alias ltt='colorls -A | grep "$(date +"%d %b")"'
elif [[ $(command -v ls) =~ gnubin || $OSTYPE =~ linux ]]; then
    alias ls="ls --color=auto"
    alias ll='ls -FlAhpv --color=auto'
    alias ltt='ls -FlAhpv| grep "$(date +"%d %b")"'
else
    alias ls="ls -G"
    alias ll='ls -FGlAhpv'
    alias ltt='ls -FlAhpv| grep "$(date +"%d %b")"'
fi

mcd() {
    # DESC: Create a directory and enter it
    # USAGE: mcd [dirname]
    mkdir -pv "$1"
    cd "$1" || exit
}

extract() {
    # DESC:  Extracts a compressed file from multiple formats
    # USAGE: extract -v <file>

    local opt
    local OPTIND=1

    while getopts "hv" opt; do
        case "$opt" in
            h)
                cat <<EOF
  $ ${FUNCNAME[0]} [option] <archives>
  options:
    -h  show this message and exit
    -v  verbosely list files processed
EOF
                return
                ;;
            v)
                local -r verbose='v'
                ;;
            ?)
                extract -h >&2
                return 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    [ $# -eq 0 ] && extract -h && return 1
    while [ $# -gt 0 ]; do
        if [ -f "$1" ]; then
            case "$1" in
                *.tar.bz2 | *.tbz | *.tbz2) tar "x${verbose}jf" "$1" ;;
                *.tar.gz | *.tgz) tar "x${verbose}zf" "$1" ;;
                *.tar.xz)
                    xz --decompress "$1"
                    set -- "$@" "${1:0:-3}"
                    ;;
                *.tar.Z)
                    uncompress "$1"
                    set -- "$@" "${1:0:-2}"
                    ;;
                *.bz2) bunzip2 "$1" ;;
                *.deb) dpkg-deb -x${verbose} "$1" "${1:0:-4}" ;;
                *.pax.gz)
                    gunzip "$1"
                    set -- "$@" "${1:0:-3}"
                    ;;
                *.gz) gunzip "$1" ;;
                *.pax) pax -r -f "$1" ;;
                *.pkg) pkgutil --expand "$1" "${1:0:-4}" ;;
                *.rar) unrar x "$1" ;;
                *.rpm) rpm2cpio "$1" | cpio -idm${verbose} ;;
                *.tar) tar "x${verbose}f" "$1" ;;
                *.txz)
                    mv "$1" "${1:0:-4}.tar.xz"
                    set -- "$@" "${1:0:-4}.tar.xz"
                    ;;
                *.xz) xz --decompress "$1" ;;
                *.zip | *.war | *.jar) unzip "$1" ;;
                *.Z) uncompress "$1" ;;
                *.7z) 7za x "$1" ;;
                *) echo "'$1' cannot be extracted via extract" >&2 ;;
            esac
        else
            echo "extract: '$1' is not a valid file" >&2
        fi
        shift
    done
}

j2y() {
    # convert json files to yaml using python and PyYAML
    python -c 'import sys, yaml, json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' <"$1"
}

y2j() {
    # convert yaml files to json using python and PyYAML
    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' <"$1"
}

if [[ ${OSTYPE} == "darwin"* ]]; then # Only load these on a MacOS computer

    ## ALIASES ##
    alias cpwd='pwd | tr -d "\n" | pbcopy'                        # Copy the working path to clipboard
    alias cl="fc -e -|pbcopy"                                     # Copy output of last command to clipboard
    alias caff="caffeinate -ism"                                  # Run command without letting mac sleep
    alias cleanDS="find . -type f -name '*.DS_Store' -ls -delete" # Delete .DS_Store files on Macs
    alias showHidden='defaults write com.apple.finder AppleShowAllFiles TRUE'
    alias hideHidden='defaults write com.apple.finder AppleShowAllFiles FALSE'
    alias capc="screencapture -c"
    alias capic="screencapture -i -c"
    alias capiwc="screencapture -i -w -c"

    CAPTURE_FOLDER="${HOME}/Desktop"

    function cap() {
        # DESC: Capture the screen to the desktop
        screencapture "${CAPTURE_FOLDER}/capture-$(date +%Y%m%d_%H%M%S).png"
    }

    function capi() {
        # DESC: Capture the selected screen area to the desktop
        screencapture -i "${CAPTURE_FOLDER}/capture-$(date +%Y%m%d_%H%M%S).png"
    }

    function capiw() {
        # DESC: Capture the selected window to the desktop
        screencapture -i -w "${CAPTURE_FOLDER}/capture-$(date +%Y%m%d_%H%M%S).png"
    }

    # Open the finder to a specified path or to current directory.
    f() {
        # DESC:  Opens the Finder to specified directory. (Default is current oath)
        # ARGS:  $1 (optional): Path to open in finder
        # REQS:  MacOS
        # USAGE: f [path]
        open -a "Finder" "${1:-.}"
    }

    ql() {
        # DESC:  Opens files in MacOS Quicklook
        # ARGS:  $1 (optional): File to open in Quicklook
        # USAGE: ql [file1] [file2]
        qlmanage -p "${*}" &>/dev/null
    }

    alias cleanupLS="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder" # Clean up LaunchServices to remove duplicates in the "Open With" menu

    unquarantine() {
        # DESC:  Manually remove a downloaded app or file from the MacOS quarantine
        # ARGS:  $1 (required): Path to file or app
        # USAGE: unquarantine [file]

        local attribute
        for attribute in com.apple.metadata:kMDItemDownloadedDate com.apple.metadata:kMDItemWhereFroms com.apple.quarantine; do
            xattr -r -d "${attribute}" "$@"
        done
    }

    browser() {
        # DESC:  Pipe HTML to a Safari browser window
        # USAGE: echo "<h1>hi mom!</h1>" | browser'

        local FILE
        FILE=$(mktemp -t browser.XXXXXX.html)
        cat /dev/stdin >|"${FILE}"
        open -a Safari "${FILE}"
    }

    finderpath() {
        # DESC:  Echoes the path of the frontmost window in the finder
        # ARGS:  None
        # OUTS:  None
        # USAGE: cd $(finderpath)
        # credit: https://github.com/herrbischoff/awesome-osx-command-line/blob/master/functions.md

        local FINDER_PATH

        FINDER_PATH=$(
            osascript -e 'tell application "Finder"' \
                -e "if (${1-1} <= (count Finder windows)) then" \
                -e "get POSIX path of (target of window ${1-1} as alias)" \
                -e 'else' \
                -e 'get POSIX path of (desktop as alias)' \
                -e 'end if' \
                -e 'end tell' 2>/dev/null
        )

        echo "${FINDER_PATH}"
    }

    ## SPOTLIGHT MAINTENANCE ##
    alias spot-off="sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist"
    alias spot-on="sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist"

    # If the 'mds' process is eating tons of memory it is likely getting hung on a file.
    # This will tell you which file that is.
    alias spot-file="lsof -c '/mds$/'"

    # Search for a file using MacOS Spotlight's metadata
    spotlight() { mdfind "kMDItemDisplayName == '${1}'wc"; }
fi
