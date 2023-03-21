#!/bin/sh
# shm script for rsh
h() { # help func
  :
}
i() { # init func
  :
}
g() { # grab func
  :
}
p() { # pull func
  :
}
u() { # push func
  :
}
r() { # revision func
  :
}
case "$1" in
  (clone|grab|*://*) g;;
  (i|init) i;;
  (pull|yank|p) p;;
  (push|send|u) u;;
  (commit|revision|ver|r) r;;
  (""|?|-[hH]|[hH]elp) h;;
  (*) g;;
esac
