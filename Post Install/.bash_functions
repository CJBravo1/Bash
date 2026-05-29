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

