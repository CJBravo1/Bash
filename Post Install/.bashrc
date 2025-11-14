if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi

# Only run Greetings in interactive Shells
case $- in
        *i*) greetings;;
esac
