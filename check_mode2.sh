#!/bin/bash

MMDVMHOST=/etc/mmdvmhost
STATUS_FILE=/var/tmp/mmdvmstatus
LOG=/var/log/mmdvmlog

net_up () {
    mount -o remount,rw / &> /dev/null
    echo $(date) "DMR Network $IPAddress is UP - GOING NET MODE" >> $LOG
    sed -i '/^\[DMR Network\]$/,/^\[/ s/^Enable=0/Enable=1/' $MMDVMHOST
    systemctl restart mmdvmhost
    echo "NET" > $STATUS_FILE
    mount -o remount,ro / &> /dev/null
}

net_down () {
    mount -o remount,rw / &> /dev/null
    echo $(date) "DMR Network $IPAddress is DOWN - GOING STANDALONE MODE" >> $LOG
    sed -i '/^\[DMR Network\]$/,/^\[/ s/^Enable=1/Enable=0/' $MMDVMHOST
    systemctl restart mmdvmhost
    echo "STANDALONE" > $STATUS_FILE
    mount -o remount,ro / &> /dev/null
}

# GET DMR IP address from the current configuration
IPAddress=$(awk -v TARGET="DMR Network" -F ' *= *' '{ if ($0 ~ /^\[.*\]$/) { gsub(/^\[|\]$/, "", $0); SECTION=$0 } else if (($1 ~ /Address/) && (SECTION==TARGET)) { print $2 }}' $MMDVMHOST)
# Get current status
if [ -f "$STATUS_FILE" ]; then
  Status=$(head -1 $STATUS_FILE)
fi
# Check network condition by pinging the DMR master server
ping -c 1 $IPAddress &> /dev/null
# Network is up, check if we're already connected
if [ "$?" = 0 ]; then
# Check if mmdvmhost is running, start if not
  if [ "$Status" == "NET" ]; then
    systemctl status mmdvmhost &> /dev/null
    if [ "$?" -ne 0 ]; then
		net_up
    else
      echo $(date) "DMR Network $IPAddress is UP - STILL IN NET MODE" >> $LOG
    fi
# We're currently running standalone or startup, change DMR Network to enable
  else
	net_up
  fi
# Network is down, go into standalone mode
else
  if [ "$Status" != "STANDALONE" ]; then
	net_down
  else
    echo $(date) "DMR Network $IPAddress is DOWN - STILL IN STANDALONE MODE" >> $LOG
  fi
fi
