
#!/bin/bash
MMDVMHOST=/etc/mmdvmhost
STATUS_FILE=/var/tmp/mmdvmstatus

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
  echo "DMR Network $IPAddress is UP"
# Check for current status, if it is in standalone or empty
# Bring it up, else do nothing
  case $Status in
        STANDALONE)
# We're currently running standalone, change DMR Network to enable
        sed -i '/^\[DMR Network\]$/,/^\[/ s/^Enable=0/Enable=1/' $MMDVMHOST
        systemctl restart mmdvmhost
        echo "NET" > $STATUS_FILE
        ;;        
        *)
# Do nothing, we're online
        echo "NET" > $STATUS_FILE
        ;;        
  esac
# Internet is down, go into standalone mode regardless
else
  echo "DMR Network $IPAddress is DOWN"
  sed -i '/^\[DMR Network\]$/,/^\[/ s/^Enable=1/Enable=0/' $MMDVMHOST
  systemctl restart mmdvmhost
  echo "STANDALONE" > $STATUS_FILE
fi
