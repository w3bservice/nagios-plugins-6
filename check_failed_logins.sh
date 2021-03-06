#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check Failed Logins Plugin for AIX
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   ./check_failed_logins.sh -w <WLEVEL> -c <CLEVEL>
#
# SETUP (with NRPE, with other plugin should be a similar process):
# 1.- Copy the plugin to the AIX server you want to monitor.
#   /opt/nagios/libexec/check_failed_logins_rh.sh
# 2.- Define an entry in nrpe.cfg:
#   command[check_failed_logins]=/opt/nagios/libexec/check_failed_logins_rh.sh -w 5 -c 10 2>&1
# 3.- Restart NRPE service.
# 4.- Create a service check in nagios using NRPE.
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios return codes
#
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Plugin info
#
AUTHOR="DEMR"
VERSION="1.0"
PROGNAME=$(basename $0)

print_version() {
	echo ""
	echo "Version: $VERSION, Author: $AUTHOR"
	echo ""
}

print_usage() {
	echo ""
	echo "$PROGNAME"
	echo "Version: $VERSION"
	echo ""
	echo "Usage: $PROGNAME [ -w WarnValue -c CritValue ] | [-v | -h]"
	echo ""
	echo "  -h  Show this page"
	echo "  -v  Plugin Version"
	echo "  -w  Warning value for failed login attempts in the last hour"
	echo "  -c  Critical value for failed login attempts in the last hour"
	echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 1 ]; then
	echo "Insufficient arguments"
	print_usage
	exit $STATE_UNKNOWN
fi
# Grab the command line arguments
WVALUE=0
CVALUE=0
while [ $# -gt 0 ]; do
	case "$1" in
		-h)
			print_usage
			exit $STATE_OK
			;;
		-v)
			print_version
			exit $STATE_OK
			;;
		-w)
			shift
			WVALUE=$1
			;;
		-c)
			shift
			CVALUE=$1
			;;
		*)
			echo "Unknown argument: $1"
			print_usage
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done
# Check argument correctness:
if [ $WVALUE -eq 0 ] || [ $CVALUE -eq 0 ]; then
	echo "Invalid arguments"
	print_usage
	exit $STATE_UNKNOWN
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check failed logins
#
HAS_FAILED_LAST_HOUR=`find /etc/security/failedlogin -mmin -60|wc -l`
if [ $HAS_FAILED_LAST_HOUR -eq 0 ]; then
	FINAL_STATUS="OK - No failed logins in last hour|failed=0"
	RETURN_STATUS=$STATE_OK
else
	DATE=`date "+%b %d"`
	HOUR_AGO=`TZ=GMT+4 date "+%H:%M"`
	RECENT_ATTEMPTS=`who /etc/security/failedlogin|tail -r -20|grep "$DATE"|awk -v h="$HOUR_AGO" '{if($5 > h) print $6;}'|uniq -c|head -1`
	N_ATTEMPTS=`echo "$RECENT_ATTEMPTS"|awk '{print $1;}'`
	HOST_ATTEMPTING=`echo "$RECENT_ATTEMPTS"|awk '{print $2;}'|sed "s/[()]//g"`
	if [ $N_ATTEMPTS -ge $CVALUE ]; then
		FINAL_STATUS="CRITICAL - $N_ATTEMPTS failed login attempts from $HOST_ATTEMPTING|failed=$N_ATTEMPTS"
		RETURN_STATUS=$STATE_CRITICAL
	elif [ $N_ATTEMPTS -ge $WVALUE ]; then
		FINAL_STATUS="WARNING - $N_ATTEMPTS failed login attempts from $HOST_ATTEMPTING|failed=$N_ATTEMPTS"
		RETURN_STATUS=$STATE_WARNING
	else
		FINAL_STATUS="OK - $N_ATTEMPTS failed login attempts from $HOST_ATTEMPTING|failed=$N_ATTEMPTS"
		RETURN_STATUS=$STATE_OK
	fi

fi

echo $FINAL_STATUS
exit $RETURN_STATUS

