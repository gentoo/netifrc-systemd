#!/bin/sh

CONFDIR="@SYSCONFDIR@"
LIBEXECDIR="@LIBEXECDIR@/sh"
INIT=systemd

usage() {
  # TODO Update with options and better description
  echo "netifrc systemd wrapper"
}

die() {
  echo "$@"
  exit -1
}

while getopts ":s:i:p:" opt; do
  case $opt in
	s)
		RC_SVCNAME=$OPTARG;;
	i)
		RC_IFACE=$OPTARG;;
	p)
		RC_SVCPREFIX=$OPTARG;;
  esac
done

[ -z "$RC_IFACE" ] && die "Missing Parameter Interface"

: ${RC_SVCPREFIX:="net"}
RC_SVCNAME="$RC_SVCPREFIX"."$RC_IFACE"
RC_UNAME=$(uname)

# Source the config file
if [ -f "$CONFDIR/$RC_SVCPREFIX" ]; then
	. "$CONFDIR/$RC_SVCPREFIX"
fi

# Source the actual runscript
if [ -f "$LIBEXECDIR/$RC_SVCPREFIX" ]; then
	. "$LIBEXECDIR/$RC_SVCPREFIX"
else
	echo "$INITDIR/$RC_SVCPREFIX : Init file missing or invalid path"
	exit -1
fi

case $1 in
	start)
		start;;
	stop)
		stop;;
	restart)
		stop
		start;;
	*)
		die "Unrecognised command $1";;
esac

# vi: ts=4 sw=4 noexpandtab
