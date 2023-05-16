#!/bin/sh
# IFS replacements operate differently in different shells
# testing is done in dash
nl='
'
space=' '
conf() {
  # conf func
  while read -r p || [ "$p" ]; do
    case "$p" in
      ("["*"]") prefix="${p#[}"; prefix="${prefix%]}" ;;
      (*)       eval $(IFS='='; set -- $p; printf '%s_%s="%s"' "$prefix" "$1" "$2") 
                # this falls apart with zsh ...
    esac
  done
}
# a raw config file is less complicated but harder to read ...
# in the future a plugin could be used to have a raw config
# less code, more configuration
cl() {
  # conf loop # loads variables from various configs
  [ -e "/etc/rsh/default.conf" ] && conf < /etc/rsh/default.conf
  # default config provided by rsh
  [ -e "/etc/default/rsh" ] && conf < /etc/default/rsh
  # default config provided by distro
  [ -e "/etc/rsh/system" ] && conf < /etc/rsh/system
  # global system config
  [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/rsh/conf" ] && conf < "${XDG_CONFIG_HOME:-$HOME/.config}"/rsh/conf
  # user based config
  [ -e "./rsh.conf" -o -e "./.rsh.conf" ] && {
    [ -e "./rsh.conf" ] && conf < ./rsh.conf
    [ -e "./.rsh.conf" ] && conf < ./.rsh.conf 
  }
  # project config 
  # defaults
  [ ! "$hooks_enabled" ] && hooks_enabled="grab,init,revi,push,pull"
  [ ! "$grap_path" ] && grab_path="$push_path"
  [ ! "$init_hidden" ] && init_hidden="true"
  [ ! "$pull_remote" ] && pull_remote="$push_remote"
}
db() {
  # generate a database of files 
  for i in ./*; do
  # db should only be run from parent folder
    [ -d "$i" ] && {
      fl="${fl}${i#./}/"; echo "$fl"
      cd $i
      # should handle permission errors here.. TODO
      db
      cd ../; unset fl
    } || echo "$fl${i#./}"
  done
}
# will be called by commit and used by internal grab 
hook() {
  # hook func
  :
}
help() {
  # help func
  :
}
init() {
  # init func
  hook init pre
  [ ! "$init_replace" ] && {
    [ "$init_hidden" = "true" ] && init_pre="."
    init_config="${init_pre}rsh.conf"
    :> "$init_config" 
    # init rsh config
    # technically this shouldn't be needed
    # as >> should still create the file
    # and we don't actually write anything here
    :
  } || ${init_replace} "$@"
  hook init post
} 
grab() {
  # grab func
  :
}
pull() {
  # pull func
  :
}
push() {
  # push func
  :
}
revi() {
  # revision func
  :
}
cl
# setup configs
case "$1" in
  (clone|g|grab|*"://"*) grab "$@";;
  (i|init) init;;
  # finished?
  (pull|yank|p) pull "$@";;
  (push|send|u) push "$@";;
  (commit|revision|ver|r) revi "$@";;
  (""|?|-[hH]|[hH]|[hH]elp) help;;
  (*) grab "$@";;
esac
