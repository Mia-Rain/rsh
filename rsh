#!/bin/sh
# IFS replacements operate differently in different shells
# testing is done in dash
nl='
'
space=' '
bail() {
  unset ERR
  ${ERR:?$1} || exit 1
}
clearvars() {
  for i in ${unset_list}; do
    unset ${i}
  done
  unset unset_list
}
# unset variables in $unset_list
confedit() {
  while read -r p || [ "$p" ]; do
    for i in $@; do
      unset a_item a_header
      header="${i%%_*}"; item="${i#*_}"; item="${item%=*}"; value="${i#*=}"
      # values from $@
      case "$p" in
        ("["*"]")
          unset a_item
          # at header
          current_header="${p#'['}"; current_header="${current_header%']'}"; a_header=1;;
        (*"="*)
          unset a_header
          # at item
          c_item="${p%=*}"; c_value="${p#*=}"; a_item=1;;
      esac
      [ "$current_header" = "$header" ] && {
        [ "$c_item" = "$item" -a "$c_value" != "$value" -a "$a_item" ] && {
          p="${item}=${value}"
        }
      }
    done
    printf '%s\n' "$p"
  done
}
# reads from STDIN and outputs an updated config based on the data in $@
# usage:
# confedit header_var1=1 header2_var3=3 < CONF > TMP; cat < TMP > CONF
# will change all values from for loop
# NOTE:
# due to how STDIN/STDOUT works, you will first have to write to a temp file
# then into the config
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
  [ ! "$push_path" ] && bail '$push_path MUST BE SET'
  [ ! "$push_remote" ] && push_remote="$push_path"
  [ ! "$hooks_enabled" ] && hooks_enabled="grab,init,revi,push,pull"
  [ ! "$grap_path" ] && grab_path="$push_path"
  [ ! "$init_hidden" ] && init_hidden="true"
  [ ! "$pull_remote" ] && pull_remote="$push_remote"
  
  # setup variables based on others
  [ "$init_hidden" = "true" ] && {
    init_hidden="."
  } || unset init_hidden
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
    :> "./${init_hidden}rsh.conf" 
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
  hook revi pre
  # revision func
  [ ! "$revi_ignore" ] && {
    while read -r p || [ "$p" ]; do
      revi_ignore="${revi_ignore:+${revi_ignore}${space}}$p"
    done < ./ignore.conf
  }
  [ ! "$revi_replace" ] && {
    :
  } || ${revi_replace}
  # should ./ignore.conf be in use 
  hook revi post
}
cl
# setup configs
case "$1" in
  (clone|g|grab|*"://"*) grab "$@";;
  (i|init) init "$@";;
  # finished?
  (pull|yank|p) pull "$@";;
  (push|send|u) push "$@";;
  (commit|revision|ver|r) revi "$@";;
  (""|?|-[hH]|[hH]|[hH]elp) help;;
  (*) grab "$@";;
esac
