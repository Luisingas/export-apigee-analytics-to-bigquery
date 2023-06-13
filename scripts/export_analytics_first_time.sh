#!/bin/bash

# Constants
ROLE_1="roles/bigquery.dataEditor"
ROLE_2="roles/bigquery.jobUser"

# MODIFY THESE VARIABLES
# ------------------------------------------------
# GCP variables
PROJECT_ID="luisalcantara-joonix" 
DATASET_NAME="dataset_test_apigee_to_bigquery"

# Apigee variables
APIGEE_ORG="luisalcantara-joonix"
APIGEE_ENV="test-env"
START="2023-06-07"
END="2023-06-08"
# ------------------------------------------------

gcloud config set project $PROJECT_ID

if ! PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --quiet --format="value(projectNumber)"); then
    echo -e "\nPlease provide a valid project id..."
    exit 1
fi
APIGEE_SERVICE_AGENT_SA="service-$PROJECT_NUMBER@gcp-sa-apigee.iam.gserviceaccount.com"
echo -e "\nApigee Service Agent Account: $APIGEE_SERVICE_AGENT_SA"

echo -e "\nValidating Bigquery dataset existence: $DATASET_NAME"

if ! bq ls $DATASET_NAME; then
    echo -e "\nBigquery dataset does not exist. Creating new one..."
    if ! bq --location=US mk -d --description "This is my dataset." $DATASET_NAME; then
        echo -e "\nCould not create Bigquery dataset"
        exit 1
    fi
    echo -e "\nBigquery dataset created"
fi
echo -e "\nBigquery dataset does exist"

echo -e "\nValidating if Apigee service agent has required roles..."
OUTPUT=$(gcloud asset search-all-iam-policies --scope="projects/${PROJECT_ID}" --query="policy:${APIGEE_SERVICE_AGENT_SA}" --format=json)

if ! command -v jq &> /dev/null
then
    echo "jq command could not be found"
    exit
fi

ROLE_COUNT=$(echo $OUTPUT | jq . |  grep "roles/bigquery.dataEditor\|roles/bigquery.jobUser" | wc -l)

if ! [[ ${ROLE_COUNT} -eq 2 ]] ; then 
    echo -e "Apigee Service Agent service account does not have required permissions. Be sure to add BigQuery Job User and BigQuery Data Editor roles to Apigee Service Agent"
    echo -e "\ncommand 1: gcloud projects add-iam-policy-binding $PROJECT_ID --member='serviceAccount:$APIGEE_SERVICE_AGENT_SA' --role='roles/bigquery.dataEditor'"
    echo -e "\ncommand 2: gcloud projects add-iam-policy-binding $PROJECT_ID --member='serviceAccount:$APIGEE_SERVICE_AGENT_SA' --role='roles/bigquery.jobUser'"
    exit 1
fi
echo -e "\nApigee Service Agent has necessary roles to continue"
echo -e "\nObtaining token..."
TOKEN=$(gcloud auth print-access-token)

# 1 CREATE DATASTORE
echo -e "\n1 - Creating Apigee Datastore..."
curl "https://apigee.googleapis.com/v1/organizations/$APIGEE_ORG/analytics/datastores" \
  -X POST \
  -H "Content-type:application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d \
  '{
    "displayName": "'"$DATASET_NAME"'",
    "targetType": "bigquery",
    "datastoreConfig": {
      "projectId": "'"$PROJECT_ID"'",
      "datasetName": "'"$DATASET_NAME"'",
      "tablePrefix": "bqprefix"
    }
  }'

# 2 SHOW APIGEE DATASTORES
echo -e "\n2 - Showing Apigee Datastores..."
curl "https://apigee.googleapis.com/v1/organizations/$APIGEE_ORG/analytics/datastores" \
-X GET \
-H "Authorization: Bearer $TOKEN"

# 3 EXPORT APIGEE ANALYTICS TO BIGQUERY
sleep 3
echo -e "\n3 - Exporting Apigee Datastore to Bigquery..."
curl "https://apigee.googleapis.com/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/analytics/exports" \
    -X POST \
    -H "Content-type:application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d \
    '{
        "name": "Export query results to BigQuery",
        "description": "One-time export to BigQuery",
        "dateRange": {
            "start": "'"$START"'", 
            "end": "'"$END"'"
    },
    "outputFormat": "csv",
    "csvDelimiter": ",", 
    "datastoreName": "'"$DATASET_NAME"'"
    }'