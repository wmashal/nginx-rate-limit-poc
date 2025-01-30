#!/bin/sh
read_vcap(){
  if [ -n "$VCAP_SERVICES"  ] ; then
    DT_API_TOKEN=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.apitoken')
    export DT_API_TOKEN
    DT_API_URL=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.apiurl')
    export DT_API_URL
    DT_TENANT=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.environmentid')
    export DT_TENANT
    DT_APPLICATIONID=$(echo "$VCAP_APPLICATION" | jq -r '."application_name"')
    export DT_APPLICATIONID
    DT_HOST_ID=$(echo "$VCAP_APPLICATION" | jq -r '."application_name"')_$CF_INSTANCE_INDEX
    export DT_HOST_ID
  fi
}

write_ld_preload(){
  agentPath=$(cat /opt/dynatrace/oneagent/manifest.json | jq -r '[."technologies"."process"."linux-x86-64"[] | select(.binarytype == "primary")]' | jq -r '.[0].path')
  if [ -z "$agentPath" ] ; then
   echo "Dynatrace agentPath could not be determined"
   return
  fi
  export LD_PRELOAD="/opt/dynatrace/oneagent/${agentPath}"
  echo "LD_PRELOAD used: ${LD_PRELOAD}"
  echo "$LD_PRELOAD" >> /etc/ld.so.preload
}

download_and_install_agent(){
   cd /tmp
   download_url="$DT_API_URL/v1/deployment/installer/agent/unix/paas-sh/latest?flavor=musl&include=nginx&bitness=64&arch=x86&Api-Token=${DT_API_TOKEN}"
   echo "Downloading agent..."
   wget --no-check-certificate --quiet --tries=5 --timeout=60 -O dynatrace-install.sh "${download_url}"
   if [ $? -ne 0 ] ; then
     echo "Agent download failed"
     return
   fi
   chmod +x dynatrace-install.sh
   ./dynatrace-install.sh
   write_ld_preload
   cd -
}

if [ -z "$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace")')" ] ; then
  echo "No dynatrace service bound"
else
  echo "Dynatrace service bound. Preparing OneAgent"
  if [ "$ONEAGENT_ENABLED" = "false" ]; then
    echo "OneAgent is disabled"
  else
    read_vcap
    if [ -z "$DT_API_TOKEN" ] || [ -z "$DT_API_URL" ]; then
      echo "Missing Dynatrace credentials"
    else
      download_and_install_agent
      # Verify installation
      if [ -f "/opt/dynatrace/oneagent/agent/conf/ruxitagentproc.conf" ]; then
        echo "Agent configuration exists"
        echo "Process config:"
        cat /opt/dynatrace/oneagent/agent/conf/ruxitagentproc.conf
      fi
    fi
  fi
fi

exec /usr/local/openresty/nginx/sbin/nginx -g "daemon off;"