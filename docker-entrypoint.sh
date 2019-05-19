#!/bin/bash

# Check if CONFLUENCE_HOME and CONFLUENCE INSTALL variable are found in ENV.
if [ -z "${CONFLUENCE_HOME}" ] || [ -z "${CONFLUENCE_INSTALL}" ]; then
  echo "One of CONFLUENCE_HOME or CONFLUENCE_INSTALL variables - or both! - are empty."
  echo "Please ensure that they are set in Dockerfile, or passed as ENV variable."
  echo "Abnormal exit..."
  exit 1
else
  echo "Found \${CONFLUENCE_HOME}: ${CONFLUENCE_HOME}"
  echo "Found \${CONFLUENCE_INSTALL}: ${CONFLUENCE_INSTALL}"
fi

# Add additional information for system logs, by displaying the version file:
cat ${CONFLUENCE_INSTALL}/atlassian-version.txt
echo

if [ -n "${TZ_FILE}" ]; then
  # There is a time zone file mentioned. Lets see if it actually exists.
  if [ -r ${TZ_FILE} ]; then
    # Set the symbolic link from the timezone file to /home/OS_USERNAME/localtime, which is owned by OS_USERNAME.
    # The link from /home/OS_USERNAME/localtime is already setup as /etc/localtime as user root, in Dockerfile.
    echo "Found  \${TZ_FILE}: ${TZ_FILE} , for timezone."
    HOME_DIR=$(grep ${OS_USERNAME} /etc/passwd | cut -d ':' -f 6)
    ln -sf ${TZ_FILE} ${HOME_DIR}/localtime
  else
    echo "Specified TZ_FILE ($TZ_FILE) was not found on the file system. Default timezone will be used instead."
    echo "Timezone related files are in /usr/share/zoneinfo/*"
  fi
else
  echo "TZ_FILE was not specified, the defaut TimeZone (${TZ_FILE}) will be used."

fi

# Is proxy name set for confluence, e.g. confluence.example.com
if [ -n "${X_PROXY_NAME}" ]; then

  # Remove all single and double quotes from the ENV variable
  X_PROXY_NAME=$(echo ${X_PROXY_NAME} | tr -d \' | tr -d \")

  if [ ! -f ${CONFLUENCE_INSTALL}/.modified.proxyname ]; then
    echo "Modifying server.xml to use ${X_PROXY_NAME} as a value for 'proxyName'"

    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' \
      --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${CONFLUENCE_INSTALL}/conf/server.xml"

    touch ${CONFLUENCE_INSTALL}/.modified.proxyname
  else
    echo "server.xml is already modified, and the 'proxyName' attribute is already inserted in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_PROXY_NAME not defined as ENV variable. Not modifying server.xml."
fi

# Is proxy port set for confluence: e.g. 443
if [ -n "${X_PROXY_PORT}" ]; then

  # Remove all single and double quotes from the ENV variable
  X_PROXY_PORT=$(echo ${X_PROXY_PORT} | tr -d \' | tr -d \")

  if [ ! -f ${CONFLUENCE_INSTALL}/.modified.proxyport ]; then
    echo "Modifying server.xml to use '${X_PROXY_PORT}' as a value for 'proxyPort'"

    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' \
      --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${CONFLUENCE_INSTALL}/conf/server.xml"

    touch ${CONFLUENCE_INSTALL}/.modified.proxyport
  else
    echo "server.xml is already modified, and the 'proxyPort' attribute is already inserted in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_PROXY_PORT not defined as ENV variable. Not modifying server.xml."
fi

# Is proxy scheme defined? e.g. http or https
if [ -n "${X_PROXY_SCHEME}" ]; then

  # Remove all single and double quotes from the ENV variable
  X_PROXY_SCHEME=$(echo ${X_PROXY_SCHEME} | tr -d \' | tr -d \")

  if [ ! -f ${CONFLUENCE_INSTALL}/.modified.scheme ]; then
    echo "Modifying server.xml to use '${X_PROXY_SCHEME}' as a value for 'scheme'"

    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' \
      --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${CONFLUENCE_INSTALL}/conf/server.xml"

    touch ${CONFLUENCE_INSTALL}/.modified.scheme

    if [ "${X_PROXY_SCHEME}" == "https" ] && [ ! -f ${CONFLUENCE_INSTALL}/.modified.secure ]; then
      echo "Modifying server.xml to use 'true' as a value for 'secure'"

      xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' \
        --type "attr" --name "secure" --value "true" "${CONFLUENCE_INSTALL}/conf/server.xml"

      touch ${CONFLUENCE_INSTALL}/.modified.secure

      echo "Modifying server.xml to set redirectPort to ${X_PROXY_PORT} instead of default port 8443"

      xmlstarlet ed --inplace --pf --ps --update '//Connector[@port="8090"]/@redirectPort' \
        --value "${X_PROXY_PORT}" "${CONFLUENCE_INSTALL}/conf/server.xml"

      touch ${CONFLUENCE_INSTALL}/.modified.redirectPort
    fi
  else
    echo "server.xml is already modified, and the 'scheme' attribute is already inserted in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_PROXY_SCHEME not defined as ENV variable. Not modifying server.xml."
fi

# Is there a context path set for confluence? Normally set to null
if [ -n "${X_CONTEXT_PATH}" ]; then
  # Remove all single and double quotes from the ENV variable
  X_CONTEXT_PATH=$(echo ${X_CONTEXT_PATH} | tr -d \' | tr -d \")

  if [ ! -f ${CONFLUENCE_INSTALL}/.modified.path ]; then
    echo "Modifying server.xml to use context path: '${X_CONTEXT_PATH}' instead of the default '' "

    xmlstarlet ed --inplace --pf --ps --update '//Context/@path' \
      --value "${X_CONTEXT_PATH}" "${CONFLUENCE_INSTALL}/conf/server.xml"

    touch ${CONFLUENCE_INSTALL}/.modified.path
  else
    echo "server.xml is already modified, and the context 'path' attribute is already updated in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_CONTEXT_PATH not defined as ENV variable. Not modifying server.xml."
fi
echo

# DATACENTER mode:
# ----------------
# Check if DATACENTER_MODE is set to true and CONFLUENCE_DATACENTER_SHARE is configured
if [ "$DATACENTER_MODE" == "true" ] && [ -n "${CONFLUENCE_DATACENTER_SHARE}" ]; then
  echo "DATACENTER_MODE is set to 'true' and CONFLUENCE_DATACENTER_SHARE is found set to: ${CONFLUENCE_DATACENTER_SHARE}"
  echo "Proceeding to setup Confluence in DataCenter mode..."
  # Note: The DataCenter logic for Confluence differs from Confluence.
  # Setting cluster node name in catalina opts:
  #  sed -i "/export CATALINA_OPTS/c\CATALINA_OPTS=\"-Dconfluence.cluster.node.name=$(hostname) \${CATALINA_OPTS}\"\nexport CATALINA_OPTS" "${CONFLUENCE_INSTALL}/bin/setenv.sh"
  export CATALINA_OPTS="${CATALINA_OPTS} -Dconfluence.cluster.node.name=$(hostname)"

  # Get ips of cluster nodes from confluence service
  if [ -f ${CONFLUENCE_HOME}/confluence.cfg.xml ]; then
    if [ -z "${CLUSTER_PEER_IPS}" ]; then
      # This is a special case, where confluence is running in kubernetes, not on plain docker host.
      KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
      # Note: In the command below, "this node" will not show up in the service endpoints, 
      #       because it is still "booting up" and "not ready".
      CLUSTER_PEER_IPS=$(curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/${CONFLUENCE_NAMESPACE}/endpoints/${CONFLUENCE_SERVICE_NAME} | jq -r .subsets[].addresses[].ip | paste -sd "," -)

    else
      # This is a special case, which caters for confluence running on plain docker host instead of Kubernetes.
      echo "Using CLUSTER_PEER_IPS = ${CLUSTER_PEER_IPS} , as received by ENV variable."

    fi

    # Lets manage POD_IP first, as it will be used later.
    # So, POD_IP is being obtained through the helm chart.
    # But, if the container is being run without Kubernetes, such as on plain docker host, then POD_IP will be empty.
    # In that case, we need to find the IP of this pod/container ourselves, using 'ip addr'
    if [ -z "${POD_IP}" ]; then
      POD_IP=$(ip addr | egrep -w inet | egrep -e "eth|ens" | awk '{print $2}' | cut -d '/' -f1)
    fi

    if [ -z "${CLUSTER_PEER_IPS}" ]; then
      # if there are no peer IPs found, then we need to add at least the IP of this node in the cluster.peers file.
      CLUSTER_PEER_IPS=${POD_IP}
    else
      # append our IP to the peers list:
      CLUSTER_PEER_IPS="${POD_IP},${CLUSTER_PEER_IPS}"
    fi

    echo "Updating ${CONFLUENCE_HOME}/confluence.cfg.xml with PEER IPS: ${CLUSTER_PEER_IPS} ..."
    xmlstarlet edit -L -u "//properties/property[@name='confluence.cluster.peers']" \
      --value "${CLUSTER_PEER_IPS}" ${CONFLUENCE_HOME}/confluence.cfg.xml
  else
    echo "The file ${CONFLUENCE_HOME}/confluence.cfg.xml was not found; because, this may be the first node - still booting up."
  fi
else
  echo "Either DATACENTER_MODE is false or CONFLUENCE_DATACENTER_SHARE is empty. Refusing to setup Confluence in data-center mode."
  echo "If you were trying to run Confluence in DataCenter mode, then both DATACENTER_MODE and CONFLUENCE_DATACENTER_SHARE need to be set to appropriate values."
fi

# Import SSL Certificates
# ------------------------------------------------------------------------------

echo "\${SSL_CERTS_PATH} is found as: ${SSL_CERTS_PATH}"
echo "\${CERTIFICATE} is found as: ${CERTIFICATE}"
echo "\${ENABLE_CERT_IMPORT} is found as: ${ENABLE_CERT_IMPORT}"

# CERTIFICATE variable existed for importing a single certificate.
# If SSL_CERTS_PATH is empty and CERTIFICATE file is mentioned, extract
#   directory path from CERTIFICATE file as SSL_CERTS_PATH.

if [ -z "${SSL_CERTS_PATH}" ] && [ -n "${CERTIFICATE}" ]; then
  echo "CERTIFICATE found without SSL_CERTS_PATH in ENV variables."
  echo "Extract dirname from CERTIFICATE variable and use it as SSL_CERTS_PATH."
  SSL_CERTS_PATH=$(dirname ${CERTIFICATE})
fi

if [ -z "${JAVA_KEYSTORE_PASSWORD}" ]; then
  echo 'The ENV variable JAVA_KEYSTORE_PASSWORD is empty.'
  echo 'Please provide JAVA_KEYSTORE_PASSWORD as an ENV variable.  Using the default value for now.'
  JAVA_KEYSTORE_PASSWORD='changeit'
fi

# If SSL_CERTS_PATH exists, then we can import certificates.
# Whitelisted certificates: *.crt, *.pem
# It does not matter if the directory is empty.
#   In that case, no certificates will be imported.
# The keystore is by default stored in a file named .keystore in the
#   user's home directory.

if [ ${ENABLE_CERT_IMPORT} = true ] && [ ! -z "${SSL_CERTS_PATH}" ]; then
  JAVA_KEYSTORE_FILE=${CONFLUENCE_INSTALL}/jre/lib/security/cacerts
  # Loop through all certificates in this directory and import them.
  for CERT in ${SSL_CERTS_PATH}/*.crt ${SSL_CERTS_PATH}/*.pem; do
    echo "Importing certificate: ${CERT} ..."
    ${CONFLUENCE_INSTALL}/jre/bin/keytool \
      -noprompt \
      -storepass ${JAVA_KEYSTORE_PASSWORD} \
      -keystore ${JAVA_KEYSTORE_FILE} \
      -import \
      -file ${CERT} \
      -alias $(basename ${CERT})
  done
  echo "Imported certificates:"
  ${CONFLUENCE_INSTALL}/jre/bin/keytool \
    -list -keystore ${JAVA_KEYSTORE_FILE} \
    -storepass ${JAVA_KEYSTORE_PASSWORD} \
    -v \
    | grep "crt\|pem"
fi


# Download / plugins provided by user - if any:
# -------------------------------------
echo
if [ -r ${PLUGINS_FILE} ]; then
  echo "Found plugins file: ${PLUGINS_FILE} ... Processing ..."
  PLUGIN_IDS_LIST=$(cat ${PLUGINS_FILE} |  sed -e '/\#/d' -e '/^$/d'|  awk '{print $1}')
  if [ -z "${PLUGIN_IDS_LIST}" ] ; then 
    echo "The plugins file - ${PLUGINS_FILE} is empty, skipping plugins download ..."
  else

    for PLUGIN_ID in ${PLUGIN_IDS_LIST}; do 
    echo
      PLUGIN_URL="https://marketplace.atlassian.com/download/plugins/${PLUGIN_ID}"
      echo "Searching Atlassian marketplace for plugin file related to plugin ID: ${PLUGIN_ID} ..."
      PLUGIN_FILE_URL=$(curl -s -I -L  $PLUGIN_URL | grep  -e "location.*http" | cut -d ' ' -f2 | tr -d '\r\n')
      if [ -z "${PLUGIN_FILE_URL}" ]; then
        echo "Could not find a plugin with plugin ID: ${PLUGIN_ID}. Skipping ..."
      else
        PLUGIN_FILENAME=$(basename ${PLUGIN_FILE_URL})
        echo "The plugin file for the plugin ID: ${PLUGIN_ID}, is found to be: ${PLUGIN_FILENAME} ... Downloading ..."
        echo "Saving plugin file as ${CONFLUENCE_INSTALL}/confluence/WEB-INF/atlassian-bundled-plugins/${PLUGIN_FILENAME} ..."
        curl -s $PLUGIN_FILE_URL -o ${CONFLUENCE_INSTALL}/confluence/WEB-INF/atlassian-bundled-plugins/${PLUGIN_FILENAME}
      fi
    done
    echo
  fi

else
  echo "Plugins file not found. Skipping plugin installation."
fi
echo


# Show additional information for system logs (again):
echo
echo "Confluence version and related platform information:"
echo "==================================================="
cat ${CONFLUENCE_INSTALL}/atlassian-version.txt
echo

echo
echo "Finished running entrypoint script(s). Now executing: $@  ..."
echo

# Execute the CMD from the Dockerfile:
exec "$@"
