#!/bin/bash
MMDVMHOST=/etc/mmdvmhost
STATUS_FILE=/var/tmp/mmdvmstatus
LOG=/var/log/mmdvmlog

# GET DMR IP address from the current configuration
IPAddress=$(awk -v TARGET="DMR Network" -F ' *= *' '{ if ($0 ~ /^\[.*\]$/) { gsub(/^\[|\]$/, "", $0); SECTION=$0 } else if (($1 ~ /Address/) && (SECTION==TARGET)) { print $2 }}' $MMDVMHOST)
# Get current status
if [ -f "$STATUS_FILE" ]; then
  Status=$(head -1 $STATUS_FILE &> /dev/null)
else
  Status=START
fi
# Check network condition by pinging the DMR master server
ping -c 1 $IPAddress &> /dev/null
if [ "$?" = 0 ]; then
# Check for current status, if it is in standalone or empty
# Bring it up, else do nothing
  case $Status in
        STANDALONE)
# We're currently running standalone, change DMR Network to enable
        sudo mount -o remount,rw &> /dev/null
        echo $(date -u) "DMR Network $IPAddress is UP - NET MODE" >> $LOG
        sed -i '/^\[DMR Network\]$/,/^\[/ s/^Enable=0/Enable=1/' $MMDVMHOST
        systemctl restart mmdvmhost
        echo "NET" > $STATUS_FILE
# Make sure turn into ro filesystem
        sudo mount -o remount,ro / &> /dev/null       
        ;;
# Check if mmdvmhost is running, start if not
        *)
        systemctl status mmdvmhost &> /dev/null
        if [ "$?" -ne 0 ]; then
          echo $(date -u) "DMR Network $IPAddress is UP - NET RESTART" >> $LOG
          systemctl restart mmdvmhost
        fi
        echo "NET" > $STATUS_FILE
  esac
# Internet is down, go into standalone mode regardless
else
  sudo mount -o remount,rw &> /dev/null
  echo $(date -u) "DMR Network $IPAddress is DOWN - STANDALONE MODE" >> $LOG
  sed -i '/^\[DMR Network\]$/,/^\[/ s/^Enable=1/Enable=0/' $MMDVMHOST
  systemctl restart mmdvmhost
  echo "STANDALONE" > $STATUS_FILE
# Make sure turn into ro filesystem
  sudo mount -o remount,ro / &> /dev/null
fi
