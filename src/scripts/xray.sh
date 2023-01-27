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

# Use the read command to split the string and assign the resulting words to an array
read -ra words <<< "$string"

connectorId="${IMAGE_CONNECTOR}"
nameSpace="${words[0]}"
tag="${words[2]}"
entity="${words[1]}"
apiDomain="https://platform.slim.dev"


echo Starting X-Ray Scan : "${PARAM_IMAGE}"

jsonData="${XRAY_REQUEST}"
command=xray
jsonDataUpdated=${jsonData//__CONNECTOR_ID__/${connectorId}}
jsonDataUpdated=${jsonDataUpdated//__NAMESPACE__/${nameSpace}}
jsonDataUpdated=${jsonDataUpdated//__REPO__/"${entity}"}
jsonDataUpdated=${jsonDataUpdated//__COMMAND__/${command}}
jsonDataUpdated=${jsonDataUpdated//__TAG__/${tag}}
#Starting Xray Scan
xrayRequest=$(curl -u ":${SAAS_KEY}" -X 'POST' \
  "${apiDomain}/orgs/${ORG_ID}/engine/executions" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "${jsonDataUpdated}")

executionId=$(jq -r '.id' <<< "${xrayRequest}")

#Fetching the status of X-ray scan
echo Starting X-Ray Scan status check : "${PARAM_IMAGE}"



executionStatus="unknown"
while [[ ${executionStatus} != "completed" ]]; do
	executionStatus=$(curl -s -u :"${SAAS_KEY}" "${apiDomain}"/orgs/"${ORG_ID}"/engine/executions/"${executionId}" | jq -r '.state')
    printf 'current NX state: %s '"$executionStatus \n"
    [[ "${executionStatus}" == "failed" || "${executionStatus}" == "null" ]] && { echo "XRAY failed - exiting..."; exit 1; }
    sleep 3
done

printf 'XRAY Completed state= %s '"$executionStatus \n"
#Fetching the X-ray Report
echo Fetching XRAY report : "${PARAM_IMAGE}"

xrayReport=$(curl -L -u ":${SAAS_KEY}" -X 'GET' \
  "${apiDomain}/orgs/${ORG_ID}/engine/executions/${executionId}/result/report" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json')

echo "${xrayReport}" >> /tmp/artifact-xray;#Uploading report to Artifact



#Adding the container to Favourites
curl -u ":${SAAS_KEY}" -X POST "${apiDomain}/orgs/${ORG_ID}/collections/${FAV_COLLECTION_ID}/images//pins" -H  "accept: application/json" -H  "Content-Type: application/json" -d "{\"scope\":\"tag\",\"connector\":\"${connectorId}\",\"entity\":\"${entity}\",\"namespace\":\"${nameSpace}\",\"version\":\"${tag}\",\"digest\":\"\",\"os\":\"linux\",\"arch\":\"amd64\"}"




