#Functions
greetings () {
	echo "Welcome to $(hostname)" | toilet -f term -F border --gay
	uptime -p | lolcat
	fortune -s | lolcat
}


###Daemon Reload###
daemonReload()
{
	sudo systemctl daemon-reload
}