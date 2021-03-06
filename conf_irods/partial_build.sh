#!/usr/bin/env bash

source env-files/use-local-irods.env

echo "INFO: Create Linux user ${HS_USER_ZONE_PROXY_USER} on ${HS_USER_ZONE_HOST}"
docker exec ${HS_USER_ZONE_HOST} sh -c "useradd -m -p ${HS_USER_ZONE_PROXY_USER_PWD} -s /bin/bash ${HS_USER_ZONE_PROXY_USER}"
# TODO why does the container/image contain a /home/hsuserproxy bad file that should be a directory? and hsuserproxy user already exists
docker exec ${HS_USER_ZONE_HOST} rm -rf /home/hsuserproxy
docker exec ${HS_USER_ZONE_HOST} mkdir -p /home/hsuserproxy/.irods
docker cp create_user.sh ${HS_USER_ZONE_HOST}:/home/${HS_USER_ZONE_PROXY_USER}/create_user.sh
docker cp delete_user.sh ${HS_USER_ZONE_HOST}:/home/${HS_USER_ZONE_PROXY_USER}/delete_user.sh
docker exec ${HS_USER_ZONE_HOST} chown -R ${HS_USER_ZONE_PROXY_USER}:${HS_USER_ZONE_PROXY_USER} /home/${HS_USER_ZONE_PROXY_USER}
docker exec ${HS_USER_ZONE_HOST} sh -c "echo "${HS_USER_ZONE_PROXY_USER}":"${HS_USER_ZONE_PROXY_USER}" | chpasswd"

docker exec ${HS_USER_ZONE_HOST} useradd rods -s /bin/bash

# Store IPs for data.local.org and users.local.org for use in scripts
ICAT1IP=$(docker exec ${IRODS_HOST} /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)
ICAT2IP=$(docker exec ${HS_USER_ZONE_HOST} /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)

echo "echo rods | iinit" | $RUN_ON_DATA
echo "echo rods | iinit" | $RUN_ON_USER

echo "INFO: Federate ${IRODS_ZONE} with ${HS_USER_IRODS_ZONE}"

echo "INFO: federation configuration for ${IRODS_HOST} - modify /etc/irods/server_config.json"
docker exec ${IRODS_HOST} sh -c "jq '.federation[0].icat_host=\"${HS_USER_ZONE_HOST}\" | .federation[0].zone_name=\"${HS_USER_IRODS_ZONE}\" | .federation[0].zone_key=\"${HS_USER_IRODS_ZONE}_KEY\" | .federation[0].negotiation_key=\"${SHARED_NEG_KEY}\"' /etc/irods/server_config.json > /tmp/tmp.json"
docker exec ${IRODS_HOST} sh -c "cat /tmp/tmp.json | jq '.' > /etc/irods/server_config.json && chown irods:irods /etc/irods/server_config.json && rm -f /tmp/tmp.json"
docker exec ${IRODS_HOST} sh -c "cat /etc/irods/server_config.json | jq '.federation'"

echo "INFO: federation configuration for ${HS_USER_ZONE_HOST}"
docker exec ${HS_USER_ZONE_HOST} sh -c "jq '.federation[0].icat_host=\"${IRODS_HOST}\" | .federation[0].zone_name=\"${IRODS_ZONE}\" | .federation[0].zone_key=\"${IRODS_ZONE}_KEY\" | .federation[0].negotiation_key=\"${SHARED_NEG_KEY}\"' /etc/irods/server_config.json > /tmp/tmp.json"
docker exec ${HS_USER_ZONE_HOST} sh -c "cat /tmp/tmp.json | jq '.' > /etc/irods/server_config.json && chown irods:irods /etc/irods/server_config.json && rm -f /tmp/tmp.json"
docker exec ${HS_USER_ZONE_HOST} sh -c "cat /etc/irods/server_config.json | jq '.federation'"

echo "INFO: make resource ${IRODS_DEFAULT_RESOURCE} in ${IRODS_ZONE}"
echo "iadmin mkresc ${IRODS_DEFAULT_RESOURCE} unixfilesystem ${IRODS_HOST}:/var/lib/irods/iRODS/Vault" | $RUN_ON_DATA

echo "INFO: make user ${IRODS_USERNAME} in ${IRODS_ZONE}"
echo "iadmin mkuser $IRODS_USERNAME rodsuser" | $RUN_ON_DATA
echo "iadmin moduser $IRODS_USERNAME password $IRODS_AUTH" | $RUN_ON_DATA

echo "INFO: make ${HS_LOCAL_PROXY_USER_IN_FED_ZONE} and ${HS_USER_ZONE_PROXY_USER} in ${HS_USER_ZONE_HOST}"
echo "iadmin mkuser ${HS_LOCAL_PROXY_USER_IN_FED_ZONE} rodsuser" | $RUN_ON_USER
echo "iadmin moduser ${HS_LOCAL_PROXY_USER_IN_FED_ZONE} password ${HS_WWW_IRODS_PROXY_USER_PWD}" | $RUN_ON_USER

echo "INFO: create and configure rodsadmin"
echo "iadmin mkuser ${HS_USER_ZONE_PROXY_USER} rodsadmin" | $RUN_ON_USER
echo "iadmin moduser ${HS_USER_ZONE_PROXY_USER} password ${HS_USER_ZONE_PROXY_USER_PWD}" | $RUN_ON_USER

echo "INFO: make resource ${HS_IRODS_LOCAL_ZONE_DEF_RES} in ${HS_USER_ZONE_HOST}"
echo "iadmin mkresc ${HS_IRODS_LOCAL_ZONE_DEF_RES} unixfilesystem ${HS_USER_ZONE_HOST}:/var/lib/irods/iRODS/Vault" | $RUN_ON_USER


# Tips for piping strings to docker exec container terminal https://gist.github.com/ElijahLynn/72cb111c7caf32a73d6f#file-pipe_to_docker_examples
echo "iadmin mkzone ${HS_USER_IRODS_ZONE} remote ${ICAT2IP}:1247" | $RUN_ON_DATA
sleep 1s
echo "iadmin mkzone ${IRODS_ZONE} remote ${ICAT1IP}:1247" | $RUN_ON_USER
sleep 1s

echo "INFO: copy iRODS config"
docker exec --user rods ${HS_USER_ZONE_HOST} whoami
docker exec ${HS_USER_ZONE_HOST} mkdir -p /home/${HS_USER_ZONE_PROXY_USER}/.irods
docker cp env-files/rods@${HS_USER_ZONE_HOST}.json ${HS_USER_ZONE_HOST}:/home/${HS_USER_ZONE_PROXY_USER}/.irods/irods_environment.json
docker exec ${HS_USER_ZONE_HOST} chown -R ${HS_USER_ZONE_PROXY_USER}:${HS_USER_ZONE_PROXY_USER} /home/${HS_USER_ZONE_PROXY_USER}

echo "INFO: iint the ${HS_USER_ZONE_PROXY_USER} in ${HS_USER_ZONE_HOST}"
#TODO this throws error but succeeds research as low priority work
echo "echo ${HS_USER_ZONE_PROXY_USER_PWD} | iinit" | docker exec -i -u hsuserproxy users.local.org /bin/bash

echo "INFO: give ${IRODS_USERNAME} own rights over ${HS_USER_IRODS_ZONE}/home"
echo "iadmin mkuser "${IRODS_USERNAME}"#"${IRODS_ZONE}" rodsuser" | $RUN_ON_USER

echo "INFO: update permissions"
echo "ichmod -r -M own "${IRODS_USERNAME}"#"${IRODS_ZONE}" /${HS_USER_IRODS_ZONE}/home" | $RUN_ON_USER

echo "INFO: edit permissions in /home"
echo "ichmod -r -M own "${HS_LOCAL_PROXY_USER_IN_FED_ZONE}" /${HS_USER_IRODS_ZONE}/home" | $RUN_ON_USER

echo "INFO: set ${HS_USER_IRODS_ZONE}/home to inherit"
echo "ichmod -r -M inherit /"${HS_USER_IRODS_ZONE}"/home" | $RUN_ON_USER
