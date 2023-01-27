#!/bin/bash

#regex="^[a-zA-Z0-9]+\/[a-zA-Z0-9]+:[a-zA-Z0-9]+$"

# if echo "${PARAM_IMAGE}" | grep -Eq "$regex"; then
#     echo "The string is valid"
# else
#     echo "Invalid Image,Image name must be in library/node:latest format"
#     exit 1;
# fi
# Set the IFS variable to "/:", which will be used to split the string
IFS='/:'

# Assign the string to a variable
string="${PARAM_IMAGE}"
echo "${string}"
match=$(echo "${string}" | grep -oP '^(?:([^/]+)/)?(?:([^/]+)/)?([^@:/]+)(?:[@:](.+))?$')
echo "${match}"
IFS='/' 
read -r -a parts <<< "$match"
echo "${parts[2]}"
registry=${parts[0]}
namespace=${parts[1]}
repository=${parts[2]}
#tag=${parts[3]}
# echo "${tag}"
# if [ -z "$tag" ]; then
#   tag="latest"
# fi


if echo "$repository" | grep -q ":"; then
  IFS=':' read -ra arr <<< "$repository"
  tag=${arr[1]}
  repository=${arr[0]}
else
  repository=${arr[0]}
  tag="latest"
fi
echo "${tag}"

if echo "$registry" | grep -q ":"; then
  namespace=$registry
  registry=""
fi

if [ -z "$namespace" ]; then
  namespace="library"
fi

# Use the read command to split the string and assign the resulting words to an array
#read -ra words <<< "$string"

connectorId="${IMAGE_CONNECTOR}"
nameSpace="${namespace}"
#tag="${tag}"
entity="${repository}"
apiDomain="https://platform.slim.dev"

IFS='.'
read -ra array <<< "${connectorId}"
connectorPlatform=${array[0]}
echo "${connectorPlatform}"

echo Starting Vulnerability Scan : "${PARAM_IMAGE}"

jsonData="${VSCAN_REQUEST}"
command=vscan
jsonDataUpdated=${jsonData//__CONNECTOR_ID__/${connectorId}}
jsonDataUpdated=${jsonDataUpdated//__NAMESPACE__/${nameSpace}}
jsonDataUpdated=${jsonDataUpdated//__REPO__/${entity}}
jsonDataUpdated=${jsonDataUpdated//__COMMAND__/${command}}
jsonDataUpdated=${jsonDataUpdated//__TAG__/${tag}}


#Starting Vulnarability Scan
vscanRequest=$(curl -u ":${SAAS_KEY}" -X 'POST' \
  "${apiDomain}/orgs/${ORG_ID}/engine/executions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "${jsonDataUpdated}")






executionId=$(jq -r '.id' <<< "${vscanRequest}")

#Starting Vulnarability Scan Status Check
echo Starting Vulnerability Scan status check : "${PARAM_IMAGE}"



executionStatus="unknown"
while [[ ${executionStatus} != "completed" ]]; do
	executionStatus=$(curl -s -u :"${SAAS_KEY}" "${apiDomain}"/orgs/"${ORG_ID}"/engine/executions/"${executionId}" | jq -r '.state')
    printf 'current NX state: %s '"$executionStatus \n"
    [[ "${executionStatus}" == "failed" || "${executionStatus}" == "null" ]] && { echo "Vulnerability scan failed - exiting..."; exit 1; }
    sleep 3
done

printf 'Vulnerability scan Completed state= %s '"$executionStatus \n"
#Fetching the report of Vulnarability Scan
echo Fetching Vulnerability scan report : "${PARAM_IMAGE}"

vscanReport=$(curl -L -u ":${SAAS_KEY}" -X 'GET' \
  "${apiDomain}/orgs/${ORG_ID}/engine/executions/${executionId}/result/report" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json')

shaId=$(jq -r '.image.digest' <<< "${vscanReport}")
echo "${shaId}"
echo "${vscanReport}" >> /tmp/artifact-vscan;#Report will be added to Artifact
readmeData="${README}"
readmeDataUpdated=${readmeData//__COLLECTION__/${FAV_COLLECTION_ID}}
echo "${readmeDataUpdated}" >> /tmp/artifact-readme;





