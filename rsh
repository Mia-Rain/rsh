#!/bin/sh
# shellcheck disable=SC2015,SC1091,SC2034,SC2166
# IFS replacements operate differently in different shells
# testing is done in dash
nl="
"
space=' '
bail() {
  unset ERR
  if [ ! "$DEBUG" ]; then
    "${ERR:?$1}" || exit "${3:-1}"
  else
    "${ERR:?$1"${nl}"DEBUG:"${nl}"$2 | @ $PWD}" || exit "${3:-1}"
  fi
}
clearvars() {
  # shellcheck disable=SC2154,SC2046
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
  if [ ! "$confedit_replace" ]; then
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
              conf_out="$conf_out$nl$1";;
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
  else
    ${confedit_replace} "$@"
  fi
}
cl() {
  # conf loop # loads variables from various configs
  if [ ! "$cl_replace" ]; then
    [ "$DEBUG" ] && printf '%s\n' "RUNNING cl()" 
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
    [ ! "$push_path" ] && {
      case "$1" in
        ""|init|i|revision|commit|ver|r|clone|g|grab|h|help) :;;
        *) bail '$push_path MUST BE SET' 'rsh cannot save data if $push_path is unset; please set $push_path to the location where data should be pushed';;
      esac
    }
    # TODO: implement this better lol
    [ ! "$push_remote" ] && push_remote="$push_path"
    [ ! "$hooks_enabled" ] && hooks_enabled="grab,init,revi,push,pull"
    [ ! "$grap_path" ] && grab_path="$push_path"
    [ ! "$config_hidden" ] && config_hidden="true"
    # default to hidden config
    [ ! "$pull_remote" ] && pull_remote="$push_remote"
    # TODO: implement db_findHidden 
    # setup variables based on others
    [ "$config_hidden" = "true" ] && {
      config_hidden="."
    } || unset config_hidden
    [ "$db_ignore" ] && {
      db_ignore="${space}${db_ignore}${space}"
      # this is done for parsing in db() 
    }
  else
    ${cl_replace} "$@"
  fi
}
db_build(){
  for i in ./*; do
    # db should only be run from parent folder
      [ -d "$i" ] && {
        fl="${fl}${i#./}/"
        cd "$i" || bail "FAILED TO MOVE TO ${PWD}/$i" "Please check the premissions on ${PWD}/$i"
        # shellcheck disable=SC2119 
        db_build
        cd ../ || bail "FAILED TO MOVE TO ${PWD}/../" "Please check the premissions on ${PWD}/../"
        unset fl
      } || {
        case "$db_ignore" in
          *" $fl${i#./} "*) :;;
          *) 
          printf '%s' "$fl${i#./}${space}";;
        esac
      }
    # TODO(?): cycles could be saved by detecting if there are no files in $i
    done
}
# this is used because of recursion
db() {
  # generate a database of files 
  if [ ! "$db_replace" ]; then
    [ -e "./${config_hidden}rsh.conf" ] || {
      bail " CANNOT FIND LOCAL rsh.conf" "db() will only operate correctly from the parent folder of a project"
      # see below
    }
    db_out="$(db_build) ${config_hidden}rsh.conf"
    [ "$db_file" ] && {
      printf 'db_items="%s"\n' "$db_out" > "$db_file"
    } || {
      export db_items="$db_out"
      confedit "$(printf 'db_items="%s"\n' "$db_out")" ./"${config_hidden}"rsh.conf
    }
    unset org_path
  else
    ${db_replace} "$@"
  fi
}
# will be called by commit and used by internal grab 
# also used by push & pull
# TODO: update docs for v0.0.0.67 of db()
hook() {
  # hook func
  :
}
help() {
  # help func
  case "$1" in
    "")
      printf 'USAGE: [DEBUG=1] rsh <command> [args]\n\n'
      printf '       [i]init               Initialise a repository.\n'
      printf '       [g]rab/clone          Clone a repository into a new directory.\n'
      printf '       [r]evision/ver/commit Commit the current changes to a new revision.\n'
      printf '       [p]ull/yank           Pull remote changes to the current project.\n'
      printf '       [p]ush/send           Push currently commited changes to remote location.\n'
      printf '       [h]elp [command]      Provide usage; optionally for a subcommand.\n'
      # TODO: a plugin command should be added in the future to interact with plugins
      printf '\n'
      #p '       [i]nit          Create a bare rsh repository.\n\n' # unneeded
      printf "       Writing  'DEBUG=1 rsh' will enable verbose output.\n";;
      # a single p call could be used but that messes with formatting because of shm
  esac
}
init() {
  # init func
  hook init pre
  if [ ! "$init_replace" ]; then
    [ ! -e "${config_hidden}rsh.conf" ] && {
      :> "./${config_hidden}rsh.conf" 
      [ "$DEBUG" ] && printf '%s\n' "created ${config_hidden}rsh.conf"
      [ -e "./${config_hidden}rsh.conf" ] || \
        bail "FAILED TO CREATE ./${config_hidden}rsh.conf" "Please check the premissions on $PWD"
      # init rsh config
      # technically this shouldn't be needed
      # as >> should still create the file
      # and we don't actually write anything here
      :
    } || \
      bail "./${config_hidden}rsh.conf ALREADY EXISTS" "Please delete ./${config_hidden}rsh.conf if you would like to reinit"
  else
    ${init_replace} "$@"
  fi
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
  if [ ! "$revi_replace" ]; then
    [ "$version_local" ] && {
      : 
      # TODO: version incrementing needs to be written here
    } || {
      export conf_write=1; confedit 'version_local="v0.0.0.1"' ./"${config_hidden}"rsh.conf
    }
  else 
    ${revi_replace}
  fi
  hook revi post
}
cl "$@"
# setup configs
case "$1" in
  (clone|g|grab|*"://"*) grab "$@";;
  (i|init) init "$@";;
  (pull|yank|p|y) pull "$@";;
  (push|send|u|s) push "$@";;
  (commit|revision|ver|r) revi "$@";;
  (""|'?'|-[hH]|[hH]|[hH]elp) help "$@";;
  (*) grab "$@";;
esac
