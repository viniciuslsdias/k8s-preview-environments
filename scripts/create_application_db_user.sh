#!/bin/bash

CURRENT_DIR=$(dirname $(realpath $0))
TERRAFORM_DIR="${CURRENT_DIR%/scripts}/terraform"

HOST=$(terraform -chdir="$TERRAFORM_DIR" output -raw db_instance_address)
PORT=$(terraform -chdir="$TERRAFORM_DIR" output db_instance_port)
DB_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw db_instance_name)
DB_ADMIN_CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id $(terraform -chdir="$TERRAFORM_DIR" output -raw db_instance_master_user_secret_arn) --query SecretString --output text)
DB_ADMIN_USER=$(echo $DB_ADMIN_CREDENTIALS | jq -r '.username')
DB_ADMIN_PASSWORD=$(echo $DB_ADMIN_CREDENTIALS | jq -r '.password')

NEW_USER="supportportal"
NEW_PASSWORD="CHANGE_ME"

kubectl run psql-client \
  --rm -it \
  --image=postgres:14 \
  --env PGPASSWORD="$DB_ADMIN_PASSWORD" \
  --restart=Never -- \
  psql -h $HOST -p $PORT -U $DB_ADMIN_USER -d $DB_NAME \
  -c "CREATE USER $NEW_USER WITH PASSWORD '$NEW_PASSWORD'; GRANT ALL PRIVILEGES ON DATABASE $DB_NAME to $NEW_USER;"