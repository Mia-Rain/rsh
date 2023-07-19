#!/bin/sh
# shellcheck disable=SC2015,SC1091,SC2034
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
argshift() {
  while [ "$1" ]; do
    [ "${p%=*}" = "${1%=*}" ] && p="$1"
    shift 1
  done
  printf '%s\n' "$p"
}
confedit() {
  [ "$conf_file" ] || eval $(printf 'conf_file=$%s\n' "$#")
  conf_out=$(
  while read -r p || [ "$p" ]; do
    argshift "$@"
  done < "$conf_file")
  while [ "$1" ]; do
    case "$1" in 
      *"_"*"="*)
        case "$conf_out" in
          *"$1"*) : ;;
          *)
            conf_out="$conf_out
$1";;
        esac;;
      *)
        [ ! "$2" ] && {
          :
          # simply move on should the current item not match the expected syntax if it is the last item
        } || {
          bail "AN ARGUMENT PASSED TO confedit() HAS INVALID SYNTAX" "It is likely you passed a file to confedit() incorrectly; see docs/confedit"
        };;
    esac
    shift 1
  done
  [ -w "$conf_file" ] && {
    printf '%s\n' "$conf_out" > "$conf_file"
  } || {
    bail "COULD NOT WRITE CHANGES TO $conf_file" "Please check the permissions on $conf_file"
  }
}

cl() {
  # conf loop # loads variables from various configs
  [ "$cl_replace" ] && {
    [ -e "/etc/default/rsh" ] && . /etc/default/rsh
    # default config provided by distro
    [ -e "/etc/rsh/system" ] && . /etc/rsh/system
    # global system config
    [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/rsh/conf" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}"/rsh/conf
    # user based config
    [ -e "./rsh.conf" -o -e "./.rsh.conf" ] && {
      [ -e "./rsh.conf" ] && . ./rsh.conf
      [ -e "./.rsh.conf" ] && . ./.rsh.conf 
    }
    # project config 
    # defaults
    # shellcheck disable=SC2016
    [ ! "$push_path" ] && bail '$push_path MUST BE SET' 'rsh cannot save data if $push_path is unset; please set $push_path to the location where data should be pushed'
    # TODO: some functions should not depend on $push_path being set; such as clone/grab 
    [ ! "$push_remote" ] && push_remote="$push_path"
    [ ! "$hooks_enabled" ] && hooks_enabled="grab,init,revi,push,pull"
    [ ! "$grap_path" ] && grab_path="$push_path"
    [ ! "$init_hidden" ] && init_hidden="true"
    [ ! "$pull_remote" ] && pull_remote="$push_remote"
  
    # setup variables based on others
    [ "$config_hidden" = "true" ] && {
      config_hidden="."
    } || unset config_hidden
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
    [ "$version_local" ] && {
      :  
    } || {
      export conf_write=1; confedit 'version_local="v0.0.0.1"' ./"${init_hidden}"rsh.conf
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
