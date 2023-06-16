#!/bin/sh
# shellcheck disable=SC2015
# IFS replacements operate differently in different shells
# testing is done in dash
nl='
'
space=' '
bail() {
  unset ERR
  if [ ! "$DEBUG" ]; then
    ${ERR:?$1} || exit 1
  else
    ${ERR:?$1
DEBUG:
$2
} || exit 1
  fi
  # if is needed here
}
clearvars() {
  for i in ${unset_list}; do
    unset ${i}
  done
  unset unset_list
}
# unset variables in $unset_list
confedit() {
  in=$(
    while IFS= read -r p || [ "$p" ]; do
      printf '%s\n' "$p"
    done < "$2")
    while IFS= read -r p || [ "$p" ]; do
      : $((lines+=1))
    done << EOF
$in
EOF
  out=$(
  todo="$1"
  n=1; while IFS= read -r p || [ "$p" ]; do
    for i in $1; do
      unset a_item a_header
      header="${i%%_*}"; item="${i#*_}"; item="${item%=*}"; value="${i#*=}"
      # values from $@
      case "$p" in
        ("["*"]")
          unset a_item
          # at header
          c_header="${p#'['}"; c_header="${c_header%']'}"; a_header=1;;
        (*"="*)
          unset a_header
          # at item
          c_item="${p%=*}"; c_value="${p#*=}"; a_item=1;;
      esac
      [ "$c_header" = "$header" ] && {
        [ "$c_item" = "$item" -a "$c_value" != "$value" -a "$a_item" ] && {
          p="${item}=${value}"
        }
        todo="${todo%%${header}_${item}=${value}*}${todo##*${header}_${item}=${value}}"
      }
    done
    # if on last line
    printf '%s\n' "$p"
    [ "$n" -eq "$lines" -a "$todo" = "$1" ] && {
      printf '%s\n' "[$header]
$item=$value"
    }
    : $((n+=1))
  done << EOF
$in
EOF
) || bail 'an error occurred in confedit()...; set $DEBUG for additional info' 'additional ERRORS should be present above'
  [ "$conf_write" ] && {
    printf '%s\n' "$out" > "$2" || bail "Failed to write to $2"
  } || printf '%s\n' "$out"
  unset_list="in out todo lines"
  clearvars
}
# reads from STDIN and outputs an updated config based on the data in $@
# usage:
# confedit 'header_var1=1 header2_var3=3' ./CONF > TMP
# will change all values from for loop
# NOTE:
# due to how STDIN/STDOUT works, you will first have to write to a temp file
# then into the config
# setting conf_write causes confedit() to auto update $2
conf() {
  # conf func
  [ "$conf_replace" ] && {
    while read -r p || [ "$p" ]; do
      case "$p" in
        ("["*"]") prefix="${p#[}"; prefix="${prefix%]}" ;;
        (*)       eval $(IFS='='; set -- $p; printf '%s_%s="%s"' "$prefix" "$1" "$2") 
                  # this falls apart with zsh ...
      esac
    done
  } || ${conf_replace} "$@"
}
# a raw config file is less complicated but harder to read ...
# in the future a plugin could be used to have a raw config
# less code, more configuration
cl() {
  # conf loop # loads variables from various configs
  [ "$cl_replace" ] && {
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
    # shellcheck disable=SC2016
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
  } || ${cl_replace} "$@"
}
db() {
  # generate a database of files 
  [ ! "$db_replace" ] && {
    for i in ./*; do
    # db should only be run from parent folder
      [ -d "$i" ] && {
        fl="${fl}${i#./}/"
        cd "$i" || bail "Something went wrong trying to enter $i ... check perms and try again"
        # shellcheck disable=SC2119 
        db
        cd ../; unset fl
      } || printf '%s' "$fl${i#./}${space}"
    # cycles could be saved by detecting if there are no files in $i
    done
  } || ${db_replace} "$@"
}
# will be called by commit and used by internal grab 
# also used by push & pull
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
  [ ! "$revi_replace" ] && {
    [ "$revi_self" ] && {
      :  
    } || {
      export conf_write=1; confedit 'revi_self="v0.0.0.1"' ./"${init_hidden}"rsh.conf
    }

  } || ${revi_replace}
  hook revi post
}
cl "$@"
# setup configs
case "$1" in
  (clone|g|grab|*"://"*) grab "$@";;
  (i|init) init "$@";;
  # finished?
  (pull|yank|p) pull "$@";;
  (push|send|u) push "$@";;
  (commit|revision|ver|r) revi "$@";;
  (""|'?'|-[hH]|[hH]|[hH]elp) help;;
  (*) grab "$@";;
esac
