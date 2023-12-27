#!/bin/sh
# shellcheck disable=SC2015,SC1091,SC2034,SC2166,SC2120
# IFS replacements operate differently in different shells
# testing is done with dash
if [ "$ZSH_VERSION" ]; then
    setopt sh_word_split
fi
# fix zsh
nl="
"
space=' '
shcat() {
  while IFS= read -r p || [ "$p" ]; do
    printf '%s\n' "$p"
  done
}
ver="v0.0.0.740"
# TODO:
# $ver must be manually edited, this is annoying, fix somehow
# prob with milang...
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
  unset conf_out
  printf '%s' "${DEBUG+!! INSIDE confedit()$nl}"
  [ "$orgfunc" ] || orgfunc="confedit"
  if [ ! "$confedit_replace" ]; then
    # shellcheck disable=SC2046
    printf '%s' "${DEBUG+!! confedit ARGUMENTS: $@$nl}"
    if [ ! "$conf_file" ]; then
      conf_file="$1"
      printf '%s' "${DEBUG+!! CHECKING FOR $conf_file$nl}"
      if [ "$DRY" ]; then
        [ -e "$conf_file" ] || bail "$conf_file IS MISSING" "Please check your perms"
      else
        :>> "$conf_file" || bail "FAILED TO CREATE $conf_file" "Please check your perms"
      fi
    #else
    #  set -- $conf_file "$@"
    # this causes tons of issues
    # TODO
    fi
    shift 1
    # this removes $conf_file from the params

    conf_out=$(shcat < $conf_file)
    printf '%s' "${DEBUG+!! CONTENTS OF $conf_file are $nl$conf_out$nl}"
    IFS="$nl"
    conf_out=$(
      for line in $conf_out; do
        unset IFS
        for arg in "$@"; do
          case "$line" in
            ("$arg") printf '%s\n' "$line" ;; # if parameter given is already present do nothing
            ("${arg%%=*}"*) printf '%s\n' "$arg";; # if name of variable matches, output new var
            (*) printf '%s\n' "$line";; # for all else just output the current line and move on
          esac
        done
      done
    )
    for arg in "$@"; do
      case "$conf_out" in
        (*"$arg"*) : ;; # if present do nothing
        (*) conf_out="$conf_out$nl$arg";; # if not present, add it
      esac
    done
    [ ! "$DRY" ] && {
      [ -w "$conf_file" -a ! "$DRY" ] && {
        printf '%s\n' "$conf_out" > "$conf_file"
        printf '%s' "${DEBUG+!! WROTE CHANGES of $conf_out to $conf_file$nl}"
      } || {
        bail "COULD NOT WRITE CHANGES TO $conf_file" "Please check the permissions on $conf_file"
      }
    } || {
      printf '%s\n' "-- Would add $conf_out to $conf_file"
      # dry run
      IFS="$nl"
      for i in $conf_out; do
        printf '%s' "${DEBUG+!! CHANGING $i to}"
        eval $(printf 'export %s' "$i")
        printf '%s' "${DEBUG+ $i IN LIVE ENV$nl}"
      done
    }
  else
    ${confedit_replace} "$@"
  fi
}
cl() {
  orgfunc=cl
  # conf loop # loads variables from various configs
  if [ ! "$cl_replace" ]; then
    printf '%s' "${DEBUG+!! RUNNING cl()$nl}"
    files="/etc/default/rsh /etc/rsh.conf ${XDG_CONFIG_HOME:-$HOME/.config}/rsh/conf"
    for i in $files; do
      printf '%s' "${DEBUG+!! LOADING $i$nl}" 
      [ -e "$i" ] && . "$i"
    done
    # user based config
    printf '%s' "${DEBUG+!! LOADING LOCAL CONFIG$nl}" 
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
    printf '%s' "${DEBUG+!! SETTING DEFAULT VARS$nl}" 
    # TODO: implement this better lol
    [ ! "$push_remote" ] && push_remote="$push_path"
    [ ! "$hooks_enabled" ] && hooks_enabled="grab,init,revi,push,pull"
    [ ! "$grab_path" ] && grab_path="$push_path"
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
    db_extras="${db_extras} .rsh.conf"
  else
    ${cl_replace} "$@"
  fi
  PROJECT_PATH="$PWD"
  # set current path
  # cannot be disabled as is required for internal functions
}
db_build(){
  for i in ./*; do
    # db should only be run from parent folder
      [ -d "$i" ] && {
        fl="${fl}${i#./}/"
        cd "$i" || bail "FAILED TO MOVE TO ${PWD}/$i" "Please check the permissions on ${PWD}/$i"
        # shellcheck disable=SC2119 
        db_build
        cd ../ || bail "FAILED TO MOVE TO ${PWD}/../" "Please check the permissions on ${PWD}/../"
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
  IFS=" "
  for i in $db_extras; do
    [ -e "$i" ] && {
      printf '%s' "${i#./}${space}"
    }
  done
}
# this is used because of recursion
db() {
  orgfunc="db"
  # generate a database of files 
  if [ ! "$db_replace" ]; then
    [ "$DRY" -o -e "./${config_hidden}rsh.conf" ] || {
      orgfunc=db
      bail "CANNOT FIND LOCAL rsh.conf" "db() will only operate correctly from the parent folder of a project"
      # see below
    }
    printf '%s' "${DEBUG+!! REPO IS $repo_name$nl}"
    [ "$repo_name" ] || confedit "./${config_hidden}rsh.conf" repo_name=${PWD##*/}
    printf '%s' "${DEBUG+!! BUILDING DATABASE$nl}"
    db_out="$(db_build)"; db_out="${db_out%$space}"
    [ "$db_file" ] && {
      printf 'db_items="%s"\n' "$db_out" > "$db_file"
    } || {
      export db_items="$db_out"
      printf '%s' "${DEBUG+!! WRITING DATABASE$nl}"
      confedit "./${config_hidden}rsh.conf" $(printf 'db_items="%s"\n' "$db_out")
    }
  else
    # shellcheck disable=SC2120
    ${db_replace} "$@"
  fi
}
# will be called by commit and used by internal grab 
# also used by push & pull
# TODO: update docs for v0.0.0.67 of db()
##
# it may be possible to remove the need for a database
# by using a parent path variable
# and just copying everything from there
# might be less complex to implement but would make $db_ignore more complex
##
# for clone()/grab() this would require checking if the remote has the expected syntax required for raw grab
hook() {
  # hook func
  :
}
help() {
  # additionally runs status
  ## 
  # help func
  printf '%s' "${DEBUG+!! USAGE FOR ${1:-STATUS}$nl}"
  case "$1" in
    (usage|help)
      shcat << EOF
---------
|  USAGE: 
---------
|  rsh [ops] <command> [args]
------------
|  Commands:
------------
|    status                Show the status of current repo.
|    [i]init               Initialize a repository.
|    [g]rab/clone          Clone a repository into a new directory.
|    [r]evision/ver/commit Commit the current changes to a new revision.
|    [p]ull/yank           Pull remote changes to the current project.
|    p[u]sh/send           Push currently committed changes to remote location.
|    [h]elp [subcommand]   Provide usage; optionally for a subcommand.
|    config                Directly edit config parameters.
-----------
|  Options:
-----------
|    -[-v]ersion            Show versions of rsh(!) and current repo
|    --verbose              Provides DEBUG info.
|    --dry                  Simulate changes.
EOF
    :;;
    (clone|grab)
      shcat << EOF
---------
|  USAGE: 
---------
|  rsh [ops] $1 <URL/PATH> [version:-latest] [output path]
|   
|  URL:                     Project PATH.
|  Version:                 Version to grab.
|                             Defaults to \`latest\`
|  Output path:             Path to save to.
-----------
|  Options:
-----------
|    --tls/--ssl            Use HTTPS as protocol.
|      https://
|    --insecure             Use HTTP  as protocol.
|      http://
|    --sftp                 Use SFTP  as protocol.
|      sftp://
|    --ftp                  Use FTP   as protocol.
|      ftp://
EOF
# TODO:
# we should really state somewhere that support for this requires that curl
# be compiled with them in the first place
##
# ie if rsh was reimplemented to use hget
# this would probably extremely different
##
      :;;
    (push|send) :;;
    (pull|yank) :;;
    (init) :;;
    (config) :;;
    # TODO:
    # implement these
    (status)
      [ "$version" ] && version="|  VERSION  -- $version"
      [ "$push_path" ] && push_path="|  REMOTE   -- $push_path"
      [ "$push_ready" ] && push_ready="|  STATE    -- READY TO PUSH"
      [ "$db_items" ] && db_items="|  DATABASE -- ACTIVE"
      [ "$repo_name" ] && repo_name="|  REPO     -- $repo_name"
      shcat << EOF
----------
|  STATUS:
----------
${version:-"|  VERSION  -- UNLOADED"}
${push_path:-"|  REMOTE   -- UNLOADED"}
${push_ready:-"|  STATE    -- PRE-COMMIT"}
${db_items:-"|  DATABASE -- UNSET"}
${repo_name:-"|  REPO     -- UNSET"}
EOF
      :;;
      # this seems really complex
      # and it is lol
      # this will get better with a compiler layer
      # but for now; we suffer
    (*|"")
      printf '%s' "${DEBUG+!! UNKNOWN COMMAND AS $1$nl}"
      help "usage"
      help "status"
      :;;
  esac
}
init() {
  hook init pre
  # init literally has no purpose here
  # push_path should be set in /etc/rsh.conf
  # and all else should be generated/edited at runtime
  ##
  # it literally only exists to work with git
  # however rsh is designed differently from others
  hook init post
} 
grab() {
  unset db_items repo_name
  # important to unset data otherwise local config
  # will be used
  # grab func # clone
  case "$1" in
    (*"://"*)
      case "$1" in
        ("https://"*) PROTO="https";;
        ("http://"*) PROTO="http";;
        ("sftp://"*) PROTO="sftp";;
        ("ftp://"*) PROTO="ftp";;
        (*"://"*) PROTO="${1%%://*}";;
        (*) : ${PROTO:=https};;
      esac
    :;;
      # DETECT PROTO
    ("/"*) PROTO="path"
    :;;
    (*) : ${PROTO:=https}
    :;;
      # USE DEFAULT
  esac
  url="$1"; url="${url##*://}"
  [ "$(type curl)" ] && {
    printf '%s' "${DEBUG+!! GRABBING $PROTO://$url$nl}"
    if { clone_conf="$(curl -Ls "${PROTO}://${url}/${2:-latest}/.rsh.conf" --fail)"; [ "$clone_conf" ]; }; then
      eval "$clone_conf"
    elif { clone_conf="$(curl -Ls "${PROTO}://${url}/${2:-latest}/rsh.conf" --fail)"; [ "$clone_conf" ]; }; then
      eval "$clone_conf"
    else
      curl -Ls "${PROTO}://${url}/${2:-latest}/.rsh.conf"
      curl -Ls "${PROTO}://${url}/${2:-latest}/rsh.conf"
      bail "COULD NOT LOAD rsh.conf" "Please see above outputs"
    fi
    IFS=" "
    for file in $db_items; do
      curl -Ls --create-dirs "${PROTO}://${url}/${2:-latest}/$file" -o "${repo_name}/${file}"
      printf '%s' "${DEBUG+!! WROTE $file TO ./$repo_name/$file$nl}"
    done
    shcat << EOF
----------
Cloned into ./$repo_name
----------
EOF
  } || bail "CANNOT PROCEED WITHOUT CURL" "Please install CURL"
  # we aren't checking curl for compatibility here
  # in theory [ "$(curl --version | grep " $PROTO " -q)" ]
  # would work but it would likely be stupid hard to reimplement
  ##
  # idea is to curl ${PROTO}://$1/[.]rsh.conf
  # and source it; then curl everything in $db_items
  # into ./${2:-$repo_name}
}
pull() {
  # pull func
  :
}
vfunc() {
  [ "$2" ] && {
    v="$1"
    until [ "${#v}" -ge 12 ]; do
      v="0${v}"
    done
    n=0; cl=""; vs="$v"
    while [ "$vs" ]; do
      next="${vs%?}"
      cl="${vs#"$next"}$cl"
      [ "$n" -eq 3 -o "${#cl}" -eq 3 ] && {
        cl=".$cl"; n=0;
        [ "${#cl}" -eq 15 ] && {
          v="$cl"
          break
        }
      }
      vs="$next"; : $((n+=1))
    done
    v="$cl"
    v="${v#.}"; printf '%s' "$v"
  } || {
    IFS="."; set -- ${1}
    for i in "$@"; do
      until [ "${#i}" -ge 3 ]; do
        i="0$i"
      done
      printf '%s' "$i"
      shift 1
    done
  }
  printf '%s\n' ""
}
push() {
  hook push pre
  IFS=" "
  set -- ${db_items}
  [ "$push_ready" ] && {
    [ -e "$push_path/repos/$repo_name/$version/" -a ! "$DRY" ] && bail "$version IS ALREADY PRESENT AT $push_path/repos/$repo_name/" "Please remove $version if you wish to amend it..."
    while [ "$1" ]; do
      if [ ! "$DRY" ]; then
        curl -Lsk --create-dirs file:///"$PWD"/"$1" -o "$push_path/repos/$repo_name/$version/$1"
      else
        printf '%s\n' "-- Would copy $1 to $push_path/repos/$repo_name/$version/$1"
      fi
      [ ! "$DRY" ] && printf '%s' "${DEBUG+!! WROTE $1 TO $push_path/repos/$repo_name/$version/$1$nl}"
      if [ ! -e "$push_path/repos/$repo_name/$version/$1" -a ! "$DRY" ]; then
        bail "$push_path/repos/$repo_name/$version/$1 IS MISSING..." "Please check the permissions on $push_path/repos/$repo_name/"
      fi
      shift 1
    done
  } || {
    bail "There is nothing to push..." '$push_ready is unset; please commit before push'
    # TODO: add a -c flag to auto commit
    # as commit messages dont exist in rsh 
  }
  unset vcode i latest
  for i in "$push_path/repos/$repo_name"/*; do
    i=${i##*/}
    [ "$i" != "latest" ] && {
      vcode="$i"
      i=$(vfunc "$i")
      until [ "${i#0}" = "$i" ]; do
        i="${i#?}"
      done
      [ "${latest:-0}" -lt "${i#v}" ] && latest="$i"
    }
  done
  printf '%s' "${DEBUG+!! LATEST VERSION IS $latest$nl}"
  [ -e "$push_path/repos/$repo_name/latest" ] && {
    [ "$(type unlink)" ] && unlink "$push_path/repos/$repo_name/latest"
  }
  [ "$(type ln)" -a "$(type unlink)" ] && {
    printf '%s' "${DEBUG+!! LINKING LATEST AS $vcode$nl}"
    cd "$push_path/repos/$repo_name/" && {
      ln -sf "./$vcode" "./latest"
    } ||  bail "CHECK PERMs ON $push_path/repos/$repo_name/" "Cannot enter $push_path/repos/$repo_name/; add +x perms"
  }
  # determine latest version and write to config
  printf '%s\n' "-- Pushed. Version $version is now present at $push_path/repos/$repo_name/$version"
  printf '%s\n' "-- Make sure permissions on $push_path/repos/$repo_name/$version are correct for your usage"
  cd $PROJECT_PATH
  confedit "./${config_hidden}rsh.conf" push_ready=""


  hook push post
  # TODO: implement --dry handling
}
prePush() {
  printf '%s' "${DEBUG+!! PREPARE PUSH$nl}" 
  # shellcheck disable=SC2119
  db
  # prepare the database for upcoming push
  confedit "./${config_hidden}rsh.conf" push_ready=1
}
#!/bin/sh
revi() {
  orgfunc=revi
  printf '%s' "${DEBUG+!! COMMIT w/ \"$@\"$nl}"
  hook revi pre
  # revision func
  if [ ! "$revi_replace" ]; then
    [ ! "$push_ready" ] && {
      [ "$version" -o "$1" ] && {
        printf '%s' "${DEBUG+!! INCREMENT VERSION CODE$nl}"
        # expected syntax is v0.0.0.0
        # however v1, v0.01.0, v0.0.01.0, etc are all still valid
        # force the current version code into the expected syntax, then increment
        version="${version#${version_prefix:-v}}"
        # 000.000.000.000
        case "$1" in
          ("release") incr="1000000000";; # 001.000.000.000
          ("alpha") incr="1000";; # 000.000.001.000
          ("beta") incr="1000000";; # 000.001.000.000
          ("dev") incr="1";; # 000.000.000.001
          (""|"auto") incr="1";; # treat auto as dev unless at dev limit
          ("custom") version="$2"; incr="";;
        esac
        # remove prefix
        ###
        # Design
        # -- this is designed in a simplistic fashion
        # ---- idea is to take advantage version codes
        # ---- v0.0.0.0
        #      Release - Features Fully implemented
        #              -- Major Feature release
        #      Beta    - Mostly Implemented
        #              -- features release candidate features
        #              -- betas can be used as a pre-release
        #              -- useful for minor features or parts of major features
        #      Alpha   - Barely Functioning; possibly with bugs
        #              -- features experimental features
        #              -- likely still under review and maintenance
        #      dev     - extreme dev; simply used for remote saves
        #              -- do not use dev commits in production or personal use
        #              -- they exist only for dev actively working on the code
        #              -- and are not intended to form a working product;
        #              ---- a simpler form of "master"
        ##
        # Basically you can take advantage of this by removing the separators, then
        # treating it like a regular number; after expanding the version code to the full
        # v000.000.000.000
        ###
        printf '%s' "${DEBUG+!! INCREMENT VERSION FROM $version$nl}"
        [ "$incr" ] && {
          version=$(vfunc "$version")
          until [ "${version#0}" = "$version" ]; do
            version="${version#0}"
          done
          version=$((version+incr))
          version=$(vfunc "$version" _)
        }
        printf '%s' "${DEBUG+!! VERSION BECAME $version$nl}"
        confedit "./${config_hidden}rsh.conf" version="v${version#${version_prefix:-v}}"
        printf '%s' "${DEBUG+!! PREPARE FOR PUSH$nl}"
        prePush
      } || {
        printf '%s' "${DEBUG+!! FIRST VERSION$nl}"
        confedit "./${config_hidden}rsh.conf" version="v0.0.0.1"
        printf '%s' "${DEBUG+!! SETUP PUSH$nl}"
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
  printf '%s\n' "-- Commited. New version is $version. Ready for Push."
  hook revi post
}
ops() {
  # handle ops
  while [ "$1" ]; do
    case "$1" in
      (-v|--version)
      # output version
      unset DEBUG
      bail "rsh version $ver${nl}local project version ${version:-UNSET}" "" "0";;
      (--verbose) 
        DEBUG=1;;
      (--dry)
        DRY=1;;
      (--tls|--ssl)
        PROTO=https;;
      (--ftp)
        PROTO=ftp;;
      (--insecure)
        PROTO=http;;
      (--sftp)
        PROTO=sftp;;
      # PROTO will be used by clone()
      # ${PROTO}://$url
      # shorthand for protocol
    esac
    shift 1
  done
}
debug() {
  printf '%s' "${DEBUG+!! DROPPING TO $1 IF PRESENT$nl}"
  type "$1" >/dev/null && {
    op="$1"; shift 1 # shift out $1
    ${op} "$@"
  } # || bail "$1 IS NOT A VALID COMMAND" "Please make sure $1 is actually defined"
}
# debug() runs commands directly with arguments; useful for db() & cl()
ops "$@"
while :; do
  case "$@" in
    (*"--verbose"*)
      true;;
    (*"--dry"*)
      true;;
      # TODO: use a write() func to better handle --dry
    (*)
      break;;
  esac
  shift 1
done
# shift over until options are removed
 printf '%s' "${DEBUG+!! DEBUG IS ENABLED$nl}"
 printf '%s' "${DRY+!! DRY RUN IS ENABLED$nl}"
# setup op variables
cl "$@"
# setup configs
 IFS=""; printf '%s' "${DEBUG+!! COMMAND IS $@$nl}"
case "$1" in
  (clone|g|grab) 
    printf '%s' "${DEBUG+!! DROP TO grab() "$@"$nl}"; shift 1; grab "$@";;
  (i|init) 
    printf '%s' "${DEBUG+!! DROP TO $1() "$@"$nl}"; shift 1; init "$@";;
  (pull|yank|p|y) 
    printf '%s' "${DEBUG+!! DROP TO pull() "$@"$nl}"; shift 1; pull "$@";;
  (push|send|u|s) 
    printf '%s' "${DEBUG+!! DROP TO push() "$@"$nl}"; shift 1; push "$@";;
  (commit|revision|ver|r) 
    printf '%s' "${DEBUG+!! DROP TO revi() "$@"$nl}"; shift 1; revi "$@";;
  (debug)
    DEBUG=1; printf '%s' "${DEBUG+!! DROP TO debug() "$@"$nl}" ; shift 1; debug "$@";;
  (config)
    :;;
  # TODO:
  # provide a direct link to conf_edit
  (status)
    printf '%s' "${DEBUG+!! DROP TO help() "$@"$nl}"; help "$@";;
  (penis)
    printf '8====D\n'
    # happy birthday Hannah :3
    ;;
  (""|help|'?'|*) 
    printf '%s' "${DEBUG+!! DROP TO help() "$@"$nl}"; shift 1; help "$@";;
esac
# TODO:
# there should be support for plugin based subcommands
