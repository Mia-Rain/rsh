#!/bin/sh
# IFS replacements operate differently in different shells
# testing is done in dash
nl='
'
space=' '
conf() { # conf func
  while read -r p || [ "$p" ]; do
    case "$p" in
      ("["*"]") prefix="${p#[}"; prefix="${prefix%]}" ;;
      (*)       eval $(IFS='='; set -- $p; printf '%s_%s="%s"' "$prefix" "$1" "$2") 
                # this falls apart with zsh ...
    esac
  done
  # defaults
  [ ! "$hooks_enabled" ] && hooks_enabled="grab,init,revi,push,pull"
  [ ! "$grap_path" ] && grab_path="$push_path"
} # a raw config file is less complicated but harder to read ...
cl() { # conf loop # loads variables from various configs
  [ -f "/etc/rsh/default.conf" ] && conf < /etc/rsh/default.conf # default config provided by rsh
  [ -f "/etc/default/rsh" ] && conf < /etc/default/rsh # default config provided by distro
  [ -f "/etc/rsh/system" ] && conf < /etc/rsh/system # global system config
  [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rsh/conf" ] && conf < "${XDG_CONFIG_HOME:-$HOME/.config}"/rsh/conf
  # user based config
}
hook() { # hook func
  :
}
help() { # help func
  :
}
init() { # init func
:
}
grab() { # grab func
  :
}
pull() { # pull func
  :
}
push() { # push func
  :
}
revi() { # revision func
  :
}
case "$1" in
  (clone|grab|*"://"*) grab "$@";;
  (i|init) init;;
  (pull|yank|p) pull "$@";;
  (push|send|u) push "$@";;
  (commit|revision|ver|r) revi "$@";;
  (""|?|-[hH]|[hH]elp) help;;
  (*) grab "$@";;
esac
