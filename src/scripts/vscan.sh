#!/bin/bash



connectorId="${IMAGE_CONNECTOR}"
nameSpace="${IMAGE_NAMESPACE}"
tag="${IMAGE_TAG}"
entity="${PARAM_IMAGE}"
apiDomain="https://platform.slim.dev"

echo Starting Vulnerability Scan : "${PARAM_IMAGE}"

jsonData="${VSCAN_REQUEST}"
command=vscan
jsonDataUpdated=${jsonData//__CONNECTOR_ID__/${connectorId}}
jsonDataUpdated=${jsonDataUpdated//__NAMESPACE__/${nameSpace}}
jsonDataUpdated=${jsonDataUpdated//__REPO__/${PARAM_IMAGE}}
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

echo "${vscanReport}" >> /tmp/artifact-vscan;#Report will be added to Artifact

Fetching image details
echo "Fetching Details for" : "${PARAM_IMAGE}"

imageDetails=$(curl -u ":${SAAS_KEY}" -X "GET" \
  "${API_DOMAIN}/orgs/${ORG_ID}/collection/images?limit=10&entity=${PARAM_IMAGE}&connector=${connectorId}&namespace=${nameSpace}" \
  -H "accept: application/json")
 

imageDetail=$(jq -r '.data[0]' <<< "${imageDetails}")


imageId=$(jq -r '.id' <<< "${imageDetail}")


echo "${imageId}"


#Adding the container to Favourites
curl -u ":${SAAS_KEY}" -X POST "${apiDomain}/orgs/${ORG_ID}/collections/${FAV_COLLECTION_ID}/images/${imageId}/pins" -H  "accept: application/json" -H  "Content-Type: application/json" -d "{\"scope\":\"tag\",\"connector\":\"${connectorId}\",\"entity\":\"${entity}\",\"namespace\":\"${nameSpace}\",\"version\":\"${tag}\",\"digest\":\"\",\"os\":\"linux\",\"arch\":\"amd64\"}"





