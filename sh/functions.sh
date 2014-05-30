# Compatibility layer for netifrc to work with multiple init
# systems.

# First check whether e* commands are present in the environment
if ![[ command -v ebegin >/dev/null 2>&1 ]]; then
	:

# Then check for the presence of functions.sh
elif [[ -f /lib/gentoo/functions.sh ]]; then
	. /lib/gentoo/functions.sh

else
	echo "/lib/gentoo/functions.sh not found. Exiting"
	exit -1
fi

# runscript functions
if [[ -n $(command -v service_set_value >/dev/null 2>&1) ]]; then
	:
else
	service_set_value() {
		:
	}
	service_get_value() {
		:
	}
	mark_service_started() {
		:
	}
	mark_service_inactive() {
		:
	}
	mark_service_stopped() {
		:
	}
	service_started() {
		:
	}
	service_inactive() {
		:
	}
	mark_service_stopped() {
		:
	}
fi

# Extracts the interface for the current invocation
get_interface() {
	case $INIT in
		openrc)
			printf ${RC_SVCNAME#*.};;
		systemd)
			printf ${RC_IFACE};;
		*)
			eerror "Init system not supported. Aborting"
			exit -1;;
	esac
}

# vim: ts=4 sw=4 noexpandtab
