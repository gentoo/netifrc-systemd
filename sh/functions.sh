# Compatibility layer for netifrc to work with multiple init
# systems.

# First check whether e* commands are present in the environment
if ![[ command -v ebegin >/dev/null 2>&1 ]]; then
	:

# Then check for the presence of functions.sh
elif [[ -f /lib/gentoo/functions.sh ]]; then
	. /lib/gentoo/functions.sh

# For completeness sake, provide the functions for a non Gentoo
# non OpenRC environment
else
	# Adapted from sys-apps/gentoo-functions
	
	#    hard set the indent used for e-commands.
	#    num defaults to 0
	# This is a private function.
	_esetdent()
	{
		local i="$1"
		[ -z "$i" ] || [ "$i" -lt 0 ] && i=0
		RC_INDENTATION=$(printf "%${i}s" '')
	}
	
	#    increase the indent used for e-commands.
	eindent()
	{
		local i="$1"
		[ -n "$i" ] && [ "$i" -gt 0 ] || i=$RC_DEFAULT_INDENT
		_esetdent $(( ${#RC_INDENTATION} + i ))
	}
	
	#    decrease the indent used for e-commands.
	eoutdent()
	{
		local i="$1"
		[ -n "$i" ] && [ "$i" -gt 0 ] || i=$RC_DEFAULT_INDENT
		_esetdent $(( ${#RC_INDENTATION} - i ))
	}
	
	# this function was lifted from OpenRC. It returns 0 if the argument  or
	# the value of the argument is "yes", "true", "on", or "1" or 1
	# otherwise.
	yesno()
	{
		[ -z "$1" ] && return 1
	
		case "$1" in
			[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1) return 0;;
			[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0) return 1;;
		esac
	
		local value=
		eval value=\$${1}
		case "$value" in
			[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1) return 0;;
			[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0) return 1;;
			*) vewarn "\$$1 is not set properly"; return 1;;
		esac
	}
	
	#    show an informative message (without a newline)
	einfon()
	{
		if yesno "${EINFO_QUIET}"; then
			return 0
		fi
		if ! yesno "${RC_ENDCOL}" && [ "${LAST_E_CMD}" = "ebegin" ]; then
			printf "\n"
		fi
		printf " ${GOOD}*${NORMAL} ${RC_INDENTATION}$*"
		LAST_E_CMD="einfon"
		return 0
	}
	
	#    show an informative message (with a newline)
	einfo()
	{
		einfon "$*\n"
		LAST_E_CMD="einfo"
		return 0
	}
	
	#    show a warning message (without a newline) and log it
	ewarnn()
	{
		if yesno "${EINFO_QUIET}"; then
			printf " $*"
			else
			if ! yesno "${RC_ENDCOL}" && [ ${LAST_E_CMD} = "ebegin" ]; then
				printf "\n"
			fi
			printf " ${WARN}*${NORMAL} ${RC_INDENTATION}$*"
		fi
	
		local name="${0##*/}"
		# Log warnings to system log
		esyslog "daemon.warning" "${name}" "$*"
	
		LAST_E_CMD="ewarnn"
		return 0
	}
	
	#    show a warning message (with a newline) and log it
	ewarn()
	{
		if yesno "${EINFO_QUIET}"; then
			printf " $*\n"
			else
			if ! yesno "${RC_ENDCOL}" && [ ${LAST_E_CMD} = "ebegin" ]; then
				printf "\n"
			fi
			printf " ${WARN}*${NORMAL} ${RC_INDENTATION}$*\n"
		fi
	
		local name="${0##*/}"
		# Log warnings to system log
		esyslog "daemon.warning" "${name}" "$*"
	
		LAST_E_CMD="ewarn"
		return 0
	}
	
	#    show an error message (without a newline) and log it
	eerrorn()
	{
		if yesno "${EINFO_QUIET}"; then
			printf " $*" >/dev/stderr
		else
			if ! yesno "${RC_ENDCOL}" && [ "${LAST_E_CMD}" = "ebegin" ]; then
				printf "\n"
			fi
			printf " ${BAD}*${NORMAL} ${RC_INDENTATION}$*"
		fi
	
		local name="${0##*/}"
		# Log errors to system log
		esyslog "daemon.err" "rc-scripts" "$*"
	
		LAST_E_CMD="eerrorn"
		return 0
	}
	
	#    show an error message (with a newline) and log it
	eerror()
	{
		if yesno "${EINFO_QUIET}"; then
			printf " $*\n" >/dev/stderr
		else
			if ! yesno "${RC_ENDCOL}" && [ "${LAST_E_CMD}" = "ebegin" ]; then
				printf "\n"
			fi
			printf " ${BAD}*${NORMAL} ${RC_INDENTATION}$*\n"
		fi
	
		local name="${0##*/}"
		# Log errors to system log
		esyslog "daemon.err" "rc-scripts" "$*"
	
		LAST_E_CMD="eerror"
		return 0
	}
	
	#    show a message indicating the start of a process
	ebegin()
	{
		local msg="$*"
		if yesno "${EINFO_QUIET}"; then
			return 0
		fi
	
		msg="${msg} ..."
		einfon "${msg}"
		if yesno "${RC_ENDCOL}"; then
			printf "\n"
		fi
	
		LAST_E_LEN="$(( 3 + ${#RC_INDENTATION} + ${#msg} ))"
		LAST_E_CMD="ebegin"
		return 0
	}
	
	#    indicate the completion of process, called from eend/ewend
	#    if error, show errstr via efunc
	_eend()
	{
		local retval="${1:-0}" efunc="${2:-eerror}" msg
		shift 2
	
		if [ "${retval}" = "0" ]; then
			yesno "${EINFO_QUIET}" && return 0
			msg="${BRACKET}[ ${GOOD}ok${BRACKET} ]${NORMAL}"
		else
			if [ -c /dev/null ] ; then
				rc_splash "stop" >/dev/null 2>&1 &
			else
				rc_splash "stop" &
			fi
			if [ -n "$*" ] ; then
				${efunc} "$*"
			fi
			msg="${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL}"
		fi
	
		if yesno "${RC_ENDCOL}"; then
			printf "${ENDCOL}  ${msg}\n"
		else
			[ "${LAST_E_CMD}" = ebegin ] || LAST_E_LEN=0
			printf "%$(( COLS - LAST_E_LEN - 6 ))s%b\n" '' "${msg}"
		fi
	
		return ${retval}
	}
	
	#    indicate the completion of process
	#    if error, show errstr via eerror
	eend()
	{
		local retval="${1:-0}"
		shift
	
		_eend "${retval}" eerror "$*"
	
		LAST_E_CMD="eend"
		return ${retval}
	}
	
	#    indicate the completion of process
	#    if error, show errstr via ewarn
	ewend()
	{
		local retval="${1:-0}"
		shift
	
		_eend "${retval}" ewarn "$*"
	
		LAST_E_CMD="ewend"
		return ${retval}
	}
	
	# v-e-commands honor EINFO_VERBOSE which defaults to no.
	# The condition is negated so the return value will be zero.
	veinfo()
	{
		yesno "${EINFO_VERBOSE}" && einfo "$@"
	}
	
	veinfon()
	{
		yesno "${EINFO_VERBOSE}" && einfon "$@"
	}
	
	vewarn()
	{
		yesno "${EINFO_VERBOSE}" && ewarn "$@"
	}
	
	veerror()
	{
		yesno "${EINFO_VERBOSE}" && eerror "$@"
	}
	
	vebegin()
	{
		yesno "${EINFO_VERBOSE}" && ebegin "$@"
	}
	
	veend()
	{
		yesno "${EINFO_VERBOSE}" && { eend "$@"; return $?; }
		return ${1:-0}
	}
	
	vewend()
	{
		yesno "${EINFO_VERBOSE}" && { ewend "$@"; return $?; }
		return ${1:-0}
	}
	
	veindent()
	{
		yesno "${EINFO_VERBOSE}" && eindent
	}
	
	veoutdent()
	{
		yesno "${EINFO_VERBOSE}" && eoutdent
	}
	
	
	# This is the main script, please add all functions above this point!
	
	# Dont output to stdout?
	EINFO_QUIET="${EINFO_QUIET:-no}"
	EINFO_VERBOSE="${EINFO_VERBOSE:-no}"
	
	# Should we use color?
	RC_NOCOLOR="${RC_NOCOLOR:-no}"
	# Can the terminal handle endcols?
	RC_ENDCOL="yes"
	
	# Default values for e-message indentation and dots
	RC_INDENTATION=''
	RC_DEFAULT_INDENT=2
	RC_DOT_PATTERN=''
	
	# Cache the CONSOLETYPE - this is important as backgrounded shells don't
	# have a TTY. rc unsets it at the end of running so it shouldn't hang
	# around
	if [ -z "${CONSOLETYPE}" ] ; then
		CONSOLETYPE="$(consoletype 2>/dev/null )"; export CONSOLETYPE
	fi
	if [ "${CONSOLETYPE}" = "serial" ] ; then
		RC_NOCOLOR="yes"
		RC_ENDCOL="no"
	fi
	
	# Setup COLS and ENDCOL so eend can line up the [ ok ]
	COLS="${COLUMNS:-0}"		# bash's internal COLUMNS variable
	[ "$COLS" -eq 0 ] && \
		COLS="$(set -- $(stty size 2>/dev/null) ; printf "$2\n")"
	[ "$COLS" -gt 0 ] || COLS=80	# width of [ ok ] == 7
	
	if yesno "${RC_ENDCOL}"; then
		ENDCOL='\033[A\033['$(( COLS - 8 ))'C'
	else
		ENDCOL=''
	fi
	
	# Setup the colors so our messages all look pretty
	if yesno "${RC_NOCOLOR}"; then
		unset GOOD WARN BAD NORMAL HILITE BRACKET
	elif (type tput && tput colors) >/dev/null 2>&1; then
		GOOD="$(tput sgr0)$(tput bold)$(tput setaf 2)"
		WARN="$(tput sgr0)$(tput bold)$(tput setaf 3)"
		BAD="$(tput sgr0)$(tput bold)$(tput setaf 1)"
		HILITE="$(tput sgr0)$(tput bold)$(tput setaf 6)"
		BRACKET="$(tput sgr0)$(tput bold)$(tput setaf 4)"
		NORMAL="$(tput sgr0)"
	else
		GOOD=$(printf '\033[32;01m')
		WARN=$(printf '\033[33;01m')
		BAD=$(printf '\033[31;01m')
		HILITE=$(printf '\033[36;01m')
		BRACKET=$(printf '\033[34;01m')
		NORMAL=$(printf '\033[0m')
	fi
fi


# Extracts the interface for the current invocation
get_interface() {
	case $INIT in
		openrc)
			printf ${RC_SVCNAME#.};;
		systemd)
			printf "${RC_IFACE}";;
		*)
			eerror "Init system not supported. Aborting"
			exit -1;;
	esac
}

# vim: ts=4 sw=4 noexpandtab
