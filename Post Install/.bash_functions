#Functions
wakeupdeepthought () {
	echo -e "\e[32m Deepthought....Arrise!\e[0m"
	sudo etherwake -i eth0 50:EB:F6:52:A7:10
	sleep 5
	ping -c 4 deepthought.lan
}

greetings () {
	echo "Welcome to $(hostname)" | toilet -f term -F border --gay
	uptime -p | lolcat
	fortune -s | lolcat
}

function updateSystem {
        echo -e "\e[32mUpdating System\e[0m"

    if command -v dnf &> /dev/null; then
        echo "dnf is installed, running updates..."
        sudo dnf update -y
    elif command -v apt $> /dev/null; then
        sudo apt update
        sudo apt upgrade -y
    fi

    #Flatpak Updates
    if command -v flatpak &> /dev/null; then
        echo "flatpak is installed, running updates..."
        flatpak upgrade -y
    fi

	#Config Backup
	
	# Check if Dropbox is running
	if ! pgrep -x "dropbox" > /dev/null; then
		echo -e "\e[31mDropbox is not running. Unable to backup config files.\e[0m"
		return 1
	fi

	backupDirectory="$HOME/Dropbox/Linux Config/$HOSTNAME"
	# Create backup directory if it does not exist
	if [ ! -d "$backupDirectory" ]; then
		echo "Backup directory does not exist. Creating it..."
		mkdir -p "$backupDirectory"
	fi
		mkdir -p "$backupDirectory/bashfiles"
		mkdir -p "$backupDirectory/sshConfig"
		echo -e "\e[32mBacking up Bash Config Files\e[0m"
		for file in "$HOME"/.bash*; do
			[ -e "$file" ] && cp -R "$file" "$backupDirectory/bashfiles"
		done
		echo -e "\e[32mBacking up SSH Config Files\e[0m"
		cp -R "$HOME/.ssh" "$backupDirectory/sshConfig"
		
}



###Daemon Reload###
daemonReload()
{
	sudo systemctl daemon-reload
}


ghcs() {
	TARGET="shell"
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-EOF
	Wrapper around \`gh copilot suggest\` to suggest a command based on a natural language description of the desired output effort.
	Supports executing suggested commands if applicable.

	USAGE
	  $FUNCNAME [flags] <prompt>

	FLAGS
	  -d, --debug              Enable debugging
	  -h, --help               Display help usage
	      --hostname           The GitHub host to use for authentication
	  -t, --target target      Target for suggestion; must be shell, gh, git
	                           default: "$TARGET"

	EXAMPLES

	- Guided experience
	  $ $FUNCNAME

	- Git use cases
	  $ $FUNCNAME -t git "Undo the most recent local commits"
	  $ $FUNCNAME -t git "Clean up local branches"
	  $ $FUNCNAME -t git "Setup LFS for images"

	- Working with the GitHub CLI in the terminal
	  $ $FUNCNAME -t gh "Create pull request"
	  $ $FUNCNAME -t gh "List pull requests waiting for my review"
	  $ $FUNCNAME -t gh "Summarize work I have done in issues and pull requests for promotion"

	- General use cases
	  $ $FUNCNAME "Kill processes holding onto deleted files"
	  $ $FUNCNAME "Test whether there are SSL/TLS issues with github.com"
	  $ $FUNCNAME "Convert SVG to PNG and resize"
	  $ $FUNCNAME "Convert MOV to animated PNG"
	EOF

	local OPT OPTARG OPTIND
	while getopts "dht:-:" OPT; do
		if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
			OPT="${OPTARG%%=*}"       # extract long option name
			OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
			OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
		fi

		case "$OPT" in
			debug | d)
				GH_DEBUG=api
				;;

			help | h)
				echo "$__USAGE"
				return 0
				;;

			hostname)
				GH_HOST="$OPTARG"
				;;

			target | t)
				TARGET="$OPTARG"
				;;
		esac
	done

	# shift so that $@, $1, etc. refer to the non-option arguments
	shift "$((OPTIND-1))"

	TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
	trap 'rm -f "$TMPFILE"' EXIT
	if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
		if [ -s "$TMPFILE" ]; then
			FIXED_CMD="$(cat $TMPFILE)"
			history -s $(history 1 | cut -d' ' -f4-); history -s "$FIXED_CMD"
			echo
			eval "$FIXED_CMD"
		fi
	else
		return 1
	fi
}

ghce() {
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-EOF
	Wrapper around \`gh copilot explain\` to explain a given input command in natural language.

	USAGE
	  $FUNCNAME [flags] <command>

	FLAGS
	  -d, --debug      Enable debugging
	  -h, --help       Display help usage
	      --hostname   The GitHub host to use for authentication

	EXAMPLES

	# View disk usage, sorted by size
	$ $FUNCNAME 'du -sh | sort -h'

	# View git repository history as text graphical representation
	$ $FUNCNAME 'git log --oneline --graph --decorate --all'

	# Remove binary objects larger than 50 megabytes from git history
	$ $FUNCNAME 'bfg --strip-blobs-bigger-than 50M'
	EOF

	local OPT OPTARG OPTIND
	while getopts "dh-:" OPT; do
		if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
			OPT="${OPTARG%%=*}"       # extract long option name
			OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
			OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
		fi

		case "$OPT" in
			debug | d)
				GH_DEBUG=api
				;;

			help | h)
				echo "$__USAGE"
				return 0
				;;

			hostname)
				GH_HOST="$OPTARG"
				;;
		esac
	done

	# shift so that $@, $1, etc. refer to the non-option arguments
	shift "$((OPTIND-1))"

	GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain "$@"
}
