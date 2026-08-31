#!/bin/bash

set -e

# ============================================================
# Azure Terraform Bootstrap Script
# ============================================================

# -----------------------------
# Configuration
# -----------------------------

RESOURCE_GROUP="alramz-tf-assets-rg"
LOCATION="uaenorth"
STORAGE_ACCOUNT="alramztfstatefiles1994"
SUBSCRIPTION_ID="c65cd71d-a01c-4f33-a04f-3163f61a94c6"

APP_NAME="alramz-github-actions-tf-sp"

CONTAINERS=(
    "sharedplatformtfstate"
    "devtfstate"
    "qatfstate"
    "preprodtfstate"
    "prodtfstate"
)

# These will be populated dynamically
CLIENT_ID=""
CLIENT_SECRET=""
TENANT_ID=""
ACCOUNT_KEY=""

# ============================================================
# Helper Functions
# ============================================================

check_az_cli() {

    if ! command -v az &> /dev/null; then
        echo "ERROR: Azure CLI is not installed."
        echo "Install it using:"
        echo "brew install azure-cli"
        exit 1
    fi

    echo "Azure CLI found."
}

check_login() {

    if ! az account show &> /dev/null; then
        echo ""
        echo "You are not logged in to Azure."
        echo "Starting Azure login..."
        az login
    fi

    echo "Azure login verified."
}

set_subscription() {

    echo ""
    echo "Setting Azure subscription..."

    az account set --subscription "$SUBSCRIPTION_ID"

    TENANT_ID=$(az account show \
        --query tenantId \
        -o tsv)

    echo "Subscription ID : $SUBSCRIPTION_ID"
    echo "Tenant ID       : $TENANT_ID"
}

# ============================================================
# 1. Create Resource Group + Storage Account
# ============================================================

create_storage() {

    echo ""
    echo "============================================================"
    echo "1. Creating Resource Group and Storage Account"
    echo "============================================================"

    set_subscription

    echo ""
    echo "Creating Resource Group: $RESOURCE_GROUP"

    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION"

    echo ""
    echo "Creating Storage Account: $STORAGE_ACCOUNT"

    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2

    echo ""
    echo "Resource Group and Storage Account created successfully."
}

# ============================================================
# 2. Create Storage Containers
# ============================================================

create_containers() {

    echo ""
    echo "============================================================"
    echo "2. Creating Terraform State Containers"
    echo "============================================================"

    set_subscription

    echo ""
    echo "Getting Storage Account Key..."

    ACCOUNT_KEY=$(az storage account keys list \
        --account-name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --query '[0].value' \
        -o tsv)

    if [ -z "$ACCOUNT_KEY" ]; then
        echo "ERROR: Unable to retrieve storage account key."
        exit 1
    fi

    for CONTAINER in "${CONTAINERS[@]}"; do

        echo ""
        echo "Creating container: $CONTAINER"

        az storage container create \
            --name "$CONTAINER" \
            --account-name "$STORAGE_ACCOUNT" \
            --account-key "$ACCOUNT_KEY" \
            --output none

        echo "Created: $CONTAINER"

    done

    echo ""
    echo "All Terraform state containers created successfully."
}

# ============================================================
# 3. Create App Registration + Service Principal
# ============================================================

create_service_principal() {

    echo ""
    echo "============================================================"
    echo "3. Creating Terraform App Registration"
    echo "============================================================"

    set_subscription

    # Check if App Registration already exists
    EXISTING_APP_ID=$(az ad app list \
        --display-name "$APP_NAME" \
        --query '[0].appId' \
        -o tsv)

    if [ -n "$EXISTING_APP_ID" ]; then

        echo ""
        echo "App Registration already exists."

        CLIENT_ID="$EXISTING_APP_ID"

    else

        echo ""
        echo "Creating App Registration: $APP_NAME"

        CLIENT_ID=$(az ad app create \
            --display-name "$APP_NAME" \
            --query appId \
            -o tsv)

        echo "App Registration created."

    fi

    echo ""
    echo "Client ID: $CLIENT_ID"

    # Create client secret
    echo ""
    echo "Creating client secret..."

    CLIENT_SECRET=$(az ad app credential reset \
        --id "$CLIENT_ID" \
        --display-name "terraform-secret" \
        --query password \
        -o tsv)

    echo "Client secret created."

    # Check if Service Principal already exists
    EXISTING_SP=$(az ad sp list \
        --filter "appId eq '$CLIENT_ID'" \
        --query '[0].appId' \
        -o tsv)

    if [ -n "$EXISTING_SP" ]; then

        echo ""
        echo "Service Principal already exists."

    else

        echo ""
        echo "Creating Service Principal..."

        az ad sp create \
            --id "$CLIENT_ID"

        echo "Service Principal created."

    fi

    # --------------------------------------------------------
    # Assign Contributor role to Resource Group
    # --------------------------------------------------------

    echo ""
    echo "Assigning Contributor role..."

    SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

    EXISTING_ROLE=$(az role assignment list \
        --assignee "$CLIENT_ID" \
        --scope "$SCOPE" \
        --role Contributor \
        --query '[0].id' \
        -o tsv)

    if [ -n "$EXISTING_ROLE" ]; then

        echo "Contributor role already assigned."

    else

        az role assignment create \
            --assignee "$CLIENT_ID" \
            --role Contributor \
            --scope "$SCOPE"

        APP_ID=$(az ad app list \
            --display-name "alramz-github-actions-tf-sp" \
            --query "[0].appId" \
            -o tsv)

        az ad app federated-credential create \
        --id "$APP_ID" \
        --parameters '{
            "name": "github-alramz-mw-oss",
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "repo:Gaurav9969351313@21151838/alramz-mw-oss@1301193654:environment:18/merge",
            "description": "GitHub Actions OIDC",
            "audiences": [
            "api://AzureADTokenExchange"
            ]
        }'

        echo "Contributor role assigned."

    fi

    echo ""
    echo "Terraform Service Principal setup completed."
}

# ============================================================
# 4. Display Configuration
# ============================================================

display_details() {

    echo ""
    echo "============================================================"
    echo "Azure Terraform Configuration"
    echo "============================================================"

    set_subscription

    # Get App ID if not already populated
    if [ -z "$CLIENT_ID" ]; then

        CLIENT_ID=$(az ad app list \
            --display-name "$APP_NAME" \
            --query '[0].appId' \
            -o tsv)

    fi

    echo ""
    echo "Resource Group             : $RESOURCE_GROUP"
    echo "Location                   : $LOCATION"
    echo "Storage Account            : $STORAGE_ACCOUNT"
    echo "AZURE_SUBSCRIPTION_ID      : $SUBSCRIPTION_ID"
    echo "AZURE_TENANT_ID            : $TENANT_ID"
    echo "AZURE_CLIENT_ID            : $CLIENT_ID"
    echo "AZURE_CLIENT_SECRET        : $CLIENT_SECRET"

    echo ""
    echo "Terraform Containers:"
    for CONTAINER in "${CONTAINERS[@]}"; do
        echo "  - $CONTAINER"
    done

    echo ""
    echo "============================================================"
}

# ============================================================
# 5. Execute Everything
# ============================================================

execute_all() {

    echo ""
    echo "============================================================"
    echo "Executing Complete Azure Terraform Bootstrap"
    echo "============================================================"

    create_storage

    create_containers

    create_service_principal

    display_details

    echo ""
    echo "============================================================"
    echo "ALL STEPS COMPLETED SUCCESSFULLY"
    echo "============================================================"
}

# ============================================================
# Main Menu
# ============================================================

check_az_cli
check_login

while true; do

    echo ""
    echo "============================================================"
    echo "       Azure Terraform Bootstrap"
    echo "============================================================"
    echo ""
    echo "1. Create Resource Group and Storage Account"
    echo "2. Create Terraform State Containers"
    echo "3. Create App Registration + Service Principal"
    echo "4. Execute All Steps"
    echo "5. Display Azure Configuration"
    echo "6. Exit"
    echo ""
    read -p "Enter your choice [1-6]: " CHOICE

    case $CHOICE in

        1)
            create_storage
            ;;

        2)
            create_containers
            ;;

        3)
            create_service_principal
            ;;

        4)
            execute_all
            ;;

        5)
            display_details
            ;;

        6)
            echo ""
            echo "Exiting..."
            exit 0
            ;;

        *)
            echo ""
            echo "Invalid option. Please select 1-6."
            ;;

    esac

done