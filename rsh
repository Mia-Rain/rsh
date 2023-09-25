#!/bin/sh
# shellcheck disable=SC2015,SC1091,SC2034,SC2166,SC2120
# IFS replacements operate differently in different shells
# testing is done in dash
nl="
"
space=' '
ver="v0.0.0.68"
# current version
bail() {
  unset ERR
  if [ ! "$DEBUG" ]; then
    "${ERR:?$1}" || exit "${3:-1}"
  else
    "${ERR:?$1"${nl}"DEBUG:"${nl}"$2 | @ $PWD | Failed in $orgfunc}" || exit "${3:-1}"
  fi
}
clearvars() {
  # shellcheck disable=SC2154,SC2046
  for i in ${unset_list}; do
    # shellcheck disable=SC2086
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
  [ "$orgfunc" ] || orgfunc="confedit"
  if [ ! "$confedit_replace" ]; then
    [ "$conf_write" ] || conf_write=1
    # shellcheck disable=SC2046
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
    [ "$conf_write" ] && {
      [ -w "$conf_file" ] && {
        printf '%s\n' "$conf_out" > "$conf_file"
      } || {
        bail "COULD NOT WRITE CHANGES TO $conf_file" "Please check the permissions on $conf_file"
      }
    } || {
      printf 'Add %s to %s\n' "$conf_out" "$conf_file"
      # dry run 
    }
  else
    ${confedit_replace} "$@"
  fi
}
cl() {
  orgfunc=cl
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
  [ "$orgfunc" ] || orgfunc="db"
  # generate a database of files 
  if [ ! "$db_replace" ]; then
    [ -e "./${config_hidden}rsh.conf" ] || {
      orgfunc=db
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
  else
    # shellcheck disable=SC2120
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
      printf 'USAGE: rsh [ops] <command> [args]\n\n'
      printf '    Commands:                                        \n'
      printf '       [i]init               Initialise a repository.\n'
      printf '       [g]rab/clone          Clone a repository into a new directory.\n'
      printf '       [r]evision/ver/commit Commit the current changes to a new revision.\n'
      printf '       [p]ull/yank           Pull remote changes to the current project.\n'
      printf '       [p]ush/send           Push currently commited changes to remote location.\n'
      printf '       [h]elp [subcommand]   Provide usage; optionally for a subcommand.\n'
      # TODO: a plugin command should be added in the future to interact with plugins
      printf '    Options:                                         \n'
      printf '      -[v]/--verbose         Provides DEBUG info.\n'
      printf '      -[d]/--dry             Simulate changes.\n'
#!/bin/sh
  esac
}
init() {
  orgfunc=init
  # init func
  hook init pre
  if [ ! "$init_replace" ]; then
    [ ! -e "${config_hidden}rsh.conf" ] && {
      [ "$DRY" ] || :> "./${config_hidden}rsh.conf" 
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
prePush() {
  # shellcheck disable=SC2119
  db
  # prepare the database for upcoming push
  confedit 'push_ready="1"' ./"${config_hidden}"rsh.conf
}
revi() {
  hook revi pre
  # revision func
  if [ ! "$revi_replace" ]; then
    [ ! "$push_ready" ] && {
      [ "$version" ] && {
        # expected syntax is v0.0.0.0
        # however v1, v0.01.0, v0.0.01.0, etc are all still valid
        # force the current version code into the expected syntax, then increment
        version="${version#v}"
        # remove prefix
        # TODO: implement this lol
        # -- use a secondary func with $@ instead of a counter loop
        # func is more complex per say but counter loop is far slower
#!/bin/sh
        # TODO: provide increment flags, for release, beta, alpha, dev, etc
        # as well as a single flag to set $version
      } || {
        confedit 'version="v0.0.0.1"' ./"${config_hidden}"rsh.conf
        # this is equal to v0.0.0.001 & v000.000.000.001
        prePush
      }
    } || {
      # shellcheck disable=SC2016
      bail '$push_ready IS SET; UNSET TO CONTINUE' "revi() will not operate unless you unset push_ready"
    }
    # revi should not operate if push_ready is set
  else 
    ${revi_replace}
  fi
  hook revi post
}
ops() {
  # handle ops
  while [ "$1" ]; do
    case "$1" in
      (-v)
      # output version
      unset DEBUG
      bail "$ver";;
      (--verbose) 
        DEBUG=1;;
      (--dry)
        DRY=1
        unset conf_write
        unset write;;
    esac
    shift 1
  done
}
ops "$@"
while :; do
  case "$@" in
    (*"--verbose"*)
      true;;
    (*"--dry"*)
      true;;
    (*)
      break;;
  esac
  shift 1
done
# shift over until options are removed
[ "$DEBUG" ] && {
  printf '%s\n' "DEBUG IS ${DEBUG+ENABLED}"
  printf '%s\n' "DRY RUN IS ${conf_write:-ENABLED}"
} 
# setup op variables
cl "$@"
# setup configs
[ "$DEBUG" ] && printf '%s\n' "COMMAND IS $1"
case "$1" in
  (clone|g|grab|*"://"*) grab "$@";;
  (i|init) init "$@";;
  (pull|yank|p|y) pull "$@";;
  (push|send|u|s) push "$@";;
  (commit|revision|ver|r) revi "$@";;
  ("help"|""|'?'|-[hH]|[hH]|[hH]elp) help "$@";;
  (*) grab "$@";;
esac
# dry run is handled directly within confedit() using $conf_write
# $write should be used by pull/push
