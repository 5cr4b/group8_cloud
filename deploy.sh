#!/bin/bash

# deploy.sh
# Script to automate build and deployment of FastAPI Full Stack Template on Ubuntu (AWS only, PostgreSQL)

# Exit on error
set -e

# Configuration variables (customize as needed)
AWS_REGION="us-west-2"
S3_BUCKET="fastapi-frontend-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'unknown-account')"
PROJECT_DIR="$(pwd)"
AWS_DIR="$(pwd)/aws"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

##
Input data here
##

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Export AWS credentials if provided
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
fi
export AWS_REGION

# Function to check if a command exists and is functional
check_command() {
  local cmd=$1
  local install_msg=$2
  if command -v "$cmd" >/dev/null 2>&1; then
    if "$cmd" --version >/dev/null 2>&1; then
      echo -e "${GREEN}$cmd is installed and functional (version: $("$cmd" --version)).${NC}"
      return 0
    else
      echo -e "${RED}$cmd is found but not functional.${NC}"
      return 1
    fi
  else
    echo -e "${RED}$cmd is not installed. $install_msg${NC}"
    return 1
  fi
}

# Function to validate AWS credentials
check_credentials() {
  echo "Checking AWS credentials..."
  if [ -n "$AWS_ACCESS_KEY_ID" ] && [ "${#AWS_ACCESS_KEY_ID}" -lt 20 ]; then
    echo -e "${RED}AWS_ACCESS_KEY_ID is invalid (too short, expected 20 characters).${NC}"
    exit 1
  fi
  if [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ "${#AWS_SECRET_ACCESS_KEY}" -lt 40 ]; then
    echo -e "${RED}AWS_SECRET_ACCESS_KEY is invalid (too short, expected 40 characters).${NC}"
    exit 1
  fi
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}AWS credentials are not valid or lack permissions for sts:GetCallerIdentity.${NC}"
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
      echo "Provided AWS_ACCESS_KEY_ID (first 8 chars): ${AWS_ACCESS_KEY_ID:0:8}..."
      echo "Provided AWS_SECRET_ACCESS_KEY (first 8 chars): ${AWS_SECRET_ACCESS_KEY:0:8}..."
    else
      echo "No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY provided in script. Checking ~/.aws/credentials..."
    fi
    echo "Please verify your credentials, ensure permissions for sts:GetCallerIdentity, or run 'aws configure'."
    exit 1
  fi
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  S3_BUCKET="fastapi-frontend-$AWS_ACCOUNT_ID"
  echo -e "${GREEN}AWS credentials verified. Account ID: $AWS_ACCOUNT_ID${NC}"
}

# Function to test PostgreSQL connectivity
test_db_connectivity() {
  echo "Testing PostgreSQL connectivity..."
  if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}psql not found. Installing postgresql-client...${NC}"
    sudo apt-get install -y postgresql-client || { echo -e "${RED}Failed to install postgresql-client.${NC}"; exit 1; }
  fi
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully connected to PostgreSQL database.${NC}"
  else
    echo -e "${RED}Failed to connect to PostgreSQL. Check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, and ensure the database is accessible.${NC}"
    echo "Run: PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
    exit 1
  fi
}

# Function to install dependencies
install_dependencies() {
  echo "Installing required tools..."
  sudo apt-get update -y || { echo -e "${RED}Failed to update package list.${NC}"; exit 1; }
  check_command unzip "Installing unzip..." || sudo apt-get install -y unzip || { echo -e "${RED}Failed to install unzip.${NC}"; exit 1; }
  if check_command aws "Installing AWS CLI..."; then
    echo -e "${GREEN}Skipping AWS CLI installation.${NC}"
  else
    echo "Downloading AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || { echo -e "${RED}Failed to download AWS CLI.${NC}"; exit 1; }
    unzip -o awscliv2.zip || { echo -e "${RED}Failed to unzip AWS CLI.${NC}"; exit 1; }
    sudo ./aws/install --update || { echo -e "${RED}Failed to install AWS CLI.${NC}"; exit 1; }
    rm -rf awscliv2.zip aws
    if ! command -v aws >/dev/null 2>&1 || ! aws --version >/dev/null 2>&1; then
      echo -e "${RED}AWS CLI installation failed. Please install manually or check PATH.${NC}"
      echo "Try adding '/usr/local/bin' to your PATH: export PATH=\$PATH:/usr/local/bin"
      exit 1
    fi
    echo -e "${GREEN}AWS CLI installed successfully (version: $(aws --version)).${NC}"
  fi
  if check_command terraform "Installing Terraform..."; then
    echo -e "${GREEN}Skipping Terraform installation.${NC}"
  else
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg || { echo -e "${RED}Failed to add Terraform GPG key.${NC}"; exit 1; }
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -y
    sudo apt-get install -y terraform || { echo -e "${RED}Failed to install Terraform.${NC}"; exit 1; }
    if ! command -v terraform >/dev/null 2>&1 || ! terraform --version >/dev/null 2>&1; then
      echo -e "${RED}Terraform installation failed. Please install manually.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Terraform installed successfully (version: $(terraform --version)).${NC}"
  fi
  if check_command node "Installing Node.js..."; then
    echo -e "${GREEN}Skipping Node.js installation.${NC}"
  else
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - || { echo -e "${RED}Failed to set up Node.js repository.${NC}"; exit 1; }
    sudo apt-get install -y nodejs || { echo -e "${RED}Failed to install Node.js.${NC}"; exit 1; }
    if ! command -v node >/dev/null 2>&1 || ! node --version >/dev/null 2>&1; then
      echo -e "${RED}Node.js installation failed. Please install manually.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Node.js installed successfully (version: $(node --version)).${NC}"
  fi
  if check_command python3 "Installing Python3..."; then
    echo -e "${GREEN}Skipping Python3 installation.${NC}"
  else
    sudo apt-get install -y python3 python3-pip || { echo -e "${RED}Failed to install Python3 and pip.${NC}"; exit 1; }
    if ! command -v python3 >/dev/null 2>&1 || ! python3 --version >/dev/null 2>&1; then
      echo -e "${RED}Python3 installation failed. Please install manually.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Python3 and pip installed successfully (version: $(python3 --version)).${NC}"
  fi
}

# Function to clone and modify the repository
prepare_project() {
  echo "Preparing project..."
  if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/fastapi/full-stack-fastapi-template.git "$PROJECT_DIR" || { echo -e "${RED}Failed to clone repository.${NC}"; exit 1; }
  else
    echo -e "${GREEN}Repository already cloned.${NC}"
  fi
  cat > "$BACKEND_DIR/requirements.txt" << EOL
fastapi>=0.68.0,<0.69.0
pydantic>=1.8.0,<2.0.0
uvicorn>=0.15.0,<0.16.0
sqlalchemy>=1.4.0,<1.5.0
psycopg2-binary>=2.9.0,<2.10.0
python-jose[cryptography]>=3.3.0,<3.4.0
passlib[bcrypt]>=1.7.0,<1.8.0
python-multipart>=0.0.5,<0.1.0
mangum>=0.17.0,<0.18.0
EOL
  cat > "$BACKEND_DIR/app/db/base.py" << EOL
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

SQLALCHEMY_DATABASE_URL = f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME')}"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
EOL
  cat > "$BACKEND_DIR/main.py" << EOL
from mangum import Mangum
from app.main import app

handler = Mangum(app)
EOL
  cat > "$BACKEND_DIR/app/main.py" << EOL
from fastapi import FastAPI
from .api import api_router
from .db.init_db import init_db

app = FastAPI()
app.include_router(api_router)

@app.on_event("startup")
async def startup_event():
    init_db()
EOL
  echo -e "${GREEN}Project modifications applied successfully.${NC}"
}

# Function to build frontend
build_frontend() {
  echo "Building frontend..."
  if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}Frontend directory not found at $FRONTEND_DIR.${NC}"
    exit 1
  fi
  cd "$FRONTEND_DIR"
  npm install || { echo -e "${RED}Failed to install frontend dependencies.${NC}"; exit 1; }
  npm run build || { echo -e "${RED}Failed to build frontend.${NC}"; exit 1; }
  cd "$PROJECT_DIR"
  echo -e "${GREEN}Frontend built successfully.${NC}"
}

# Function to build backend
build_backend() {
  echo "Building backend..."
  if [ ! -d "$BACKEND_DIR" ]; then
    echo -e "${RED}Backend directory not found at $BACKEND_DIR.${NC}"
    exit 1
  fi
  cd "$BACKEND_DIR"
  pip3 install -r requirements.txt -t . || { echo -e "${RED}Failed to install backend dependencies.${NC}"; exit 1; }
  zip -r "$AWS_DIR/backend.zip" . -x "*.git*" || { echo -e "${RED}Failed to create backend ZIP.${NC}"; exit 1; }
  cd "$PROJECT_DIR"
  echo -e "${GREEN}Backend built successfully.${NC}"
}

# Function to deploy AWS infrastructure
deploy_aws() {
  echo "Deploying AWS infrastructure..."
  if [ ! -d "$AWS_DIR" ]; then
    echo -e "${RED}AWS Terraform directory not found at $AWS_DIR.${NC}"
    exit 1
  fi
  cd "$AWS_DIR"
  terraform init || { echo -e "${RED}Terraform init failed.${NC}"; exit 1; }
  terraform apply -auto-approve \
    -var="db_host=$DB_HOST" \
    -var="db_port=$DB_PORT" \
    -var="db_user=$DB_USER" \
    -var="db_password=$DB_PASSWORD" \
    -var="db_name=$DB_NAME" \
    -var="alert_email=$ALERT_EMAIL" \
    -var="secret_key=$SECRET_KEY" \
    -var="frontend_bucket_name=$S3_BUCKET" || { echo -e "${RED}Terraform apply failed.${NC}"; exit 1; }
  S3_ENDPOINT=$(terraform output -raw s3_website_endpoint 2>/dev/null || echo "unknown")
  API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "unknown")
  cd "$PROJECT_DIR"
  if [ "$S3_ENDPOINT" = "unknown" ] || [ "$API_URL" = "unknown" ]; then
    echo -e "${RED}Failed to retrieve S3 endpoint or API Gateway URL.${NC}"
    exit 1
  fi
  # Remove any trailing '/prod' to avoid redundant segments
  API_URL=$(echo "$API_URL" | sed 's/\/prod$//')
  echo "S3_ENDPOINT: $S3_ENDPOINT"
  echo "API_URL: $API_URL"
}

# Function to upload frontend to S3
upload_frontend() {
  echo "Uploading frontend to S3..."
  if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}Frontend directory not found at $FRONTEND_DIR.${NC}"
    exit 1
  fi
  cd "$FRONTEND_DIR"
  echo "REACT_APP_API_URL=$API_URL" > .env
  echo "Using API_URL: $API_URL"
  npm run build || { echo -e "${RED}Failed to rebuild frontend with API URL.${NC}"; exit 1; }
  aws s3 sync dist/ s3://$S3_BUCKET --delete || { echo -e "${RED}Failed to upload frontend to S3.${NC}"; exit 1; }
  cd "$PROJECT_DIR"
  echo -e "${GREEN}Frontend uploaded to S3 successfully.${NC}"
}

# Main function
main() {
  echo -e "${GREEN}Starting deployment of FastAPI Full Stack Template...${NC}"
  install_dependencies
  check_credentials
  test_db_connectivity
  prepare_project
  build_frontend
  build_backend
  deploy_aws
  upload_frontend
  echo -e "${GREEN}Deployment successful!${NC}"
  echo "Access the application at: http://$S3_ENDPOINT"
  echo "API_URL: $API_URL"
}

# Run main with error handling
main || { echo -e "${RED}Deployment failed. Check the error messages above.${NC}"; exit 1; }

# Cleanup instructions
echo -e "${GREEN}To clean up resources after use:${NC}"
echo "cd $AWS_DIR && terraform destroy -auto-approve -var=\"db_host=$DB_HOST\" -var=\"db_port=$DB_PORT\" -var=\"db_user=$DB_USER\" -var=\"db_password=$DB_PASSWORD\" -var=\"db_name=$DB_NAME\" -var=\"alert_email=$ALERT_EMAIL\" -var=\"secret_key=$SECRET_KEY\" -var=\"frontend_bucket_name=$S3_BUCKET\""