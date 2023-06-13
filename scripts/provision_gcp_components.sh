#!/bin/bash
FUNCTION_NAME=export-analytics-functions
JOB_NAME=export-to-bigquery-job
REGION="us-central1"
PROJECT_ID="luisalcantara-joonix"

APIGEE_ORG="luisalcantara-joonix"
APIGEE_ENV="test-env"
APIGEE_DATASTORE_NAME="Test Datastore"

gcloud functions deploy $FUNCTION_NAME \
  --runtime=python310 \
  --region=$REGION \
  --source=../functions/. \
  --entry-point=export_function \
  --trigger-http \
  --allow-unauthenticated

gcloud scheduler jobs create http $JOB_NAME \
  --schedule="0 0 * * *" \
  --uri="https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME" \
  --http-method=POST \
  --headers="{ \"Content-Type\": \"application/json; charset=utf-8\" }" \
  --message-body="{\"apigee_organization\":\"$APIGEE_ORG\",\"apigee_env\":\"$APIGEE_ENV\", \"apigee_datastore_name\":\"$APIGEE_DATASTORE_NAME\"}}" \
  --location $REGION