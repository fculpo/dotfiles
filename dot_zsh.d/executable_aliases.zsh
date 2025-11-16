alias crypto='curl rate.sx' # Get crypto prices

# wget sucks with certificates. Let's keep it simple.
alias wget="curl -O"

# [[ "$(command -v colordiff)" ]] && alias diff='colordiff'

alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'
alias ports='netstat -tulanp'

# confirmation before overwriting files
alias mv='mv -i'
alias cp='cp -i'
alias ln='ln -i'

# Progress bar on file copy. Useful evenlocal.
alias cpProgress="rsync --progress -ravz"

alias tf="terraform"
alias tg="terragrunt"

alias g="git"
alias gs="git status -sb"

alias k="kubectl"
alias vi="vim"
alias kx="kubectx"
alias kn="kubens"

alias r="exec zsh"

alias myip='curl http://ipecho.net/plain; echo'

# Alias Screensaver on macOS High Sierra as afk. My Mac locks when it starts.
if [[ -f "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine" ]]; then
    alias afk="open -a ScreenSaverEngine"
fi

[[ "$(command -v prettyping)" ]] && alias ping="prettyping --nolegend"
[[ "$(command -v prettyping)" ]] && alias ping6="prettyping --nolegend --ipv6"
[[ "$(command -v htop)" ]] && alias top="htop"

mcd() {
    # DESC: Create a directory and enter it
    # USAGE: mcd [dirname]
    mkdir -pv "$1"
    cd "$1" || exit
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

    # Clean up LaunchServices to remove duplicates in the "Open With" menu
    alias cleanupLS="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder" 
    
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
