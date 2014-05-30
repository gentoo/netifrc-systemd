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

# In Openrc systems this has value /run/openrc
SVCDIR="/run/netifrc"
# OpenRC saves values in $SVCDIR/options/$SVCNAME/$OPTION
# In non OpenRC setting this is saved in /run/netifrc/options/$OPTION
OPTIONSDIR="${SVCDIR}/options"

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

netifrc_init() {
	# Ensure OPTIONSDIR is present and writeable
	mkdir -p $OPTIONSDIR
	if [ ! -w $OPTIONSDIR ]; then
		eerror "${OPTIONSDIR} does not exist or is not writeable"
		exit -1;
	fi
}

netifrc_cleanup() {
	# Delete all the saved values
	rm -f ${OPTIONSDIR}/*
}

case $1 in
	start)
		netifrc_init
		start;;
	stop)
		stop
		netifrc_cleanup;;
	restart)
		stop
		netifrc_cleanup
		netifrc_init
		start;;
	*)
		die "Unrecognised command $1";;
esac

# vi: ts=4 sw=4 noexpandtab
