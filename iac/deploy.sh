#!/bin/bash

# Deploy Azure Automation Account - Depolicify
# Deployment script for Linux/macOS with Azure CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Default parameters
RESOURCE_GROUP_NAME="rg-depolicify-itn"
LOCATION="Italy North"
APP_NAME="depolicify"
LOCATION_SHORT="itn"

# Help function
show_help() {
    echo -e "${GREEN}Deploy Azure Automation Account - Depolicify${NC}"
    echo ""
    echo "Usage: $0 -s SUBSCRIPTION_ID [OPTIONS]"
    echo ""
    echo "Optional parameters:"
    echo "  -g, --resource-group RG_NAME        Resource Group name (default: rg-depolicify-itn)"
    echo "  -l, --location LOCATION             Azure region (default: Italy North)"
    echo "  -a, --app-name APP_NAME             Application name (default: depolicify)"
    echo "  -c, --location-short LOCATION_SHORT Location abbreviation (default: itn)"
    echo "  -h, --help                          Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -s 87654321-4321-4321-4321-210987654321"
    echo "  $0 -t 12345678-1234-1234-1234-123456789012 -s 87654321-4321-4321-4321-210987654321"
    echo ""
}

# Parse parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -a|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -c|--location-short)
            LOCATION_SHORT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown parameter: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${GREEN}🚀 Starting Azure Automation Account deployment for Depolicify...${NC}"

# Create Resource Group if it doesn't exist
echo -e "${YELLOW}📁 Checking/Creating Resource Group: $RESOURCE_GROUP_NAME${NC}"
if ! az group show --name "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    echo -e "${GREEN}✅ Resource Group created: $RESOURCE_GROUP_NAME${NC}"
else
    echo -e "${GREEN}✅ Existing Resource Group: $RESOURCE_GROUP_NAME${NC}"
fi

# Show parameters
echo -e "${YELLOW}📋 Deployment parameters:${NC}"
echo -e "  ${WHITE}• App Name:         $APP_NAME${NC}"
echo -e "  ${WHITE}• Location:         $LOCATION${NC}"
echo -e "  ${WHITE}• Location Short:   $LOCATION_SHORT${NC}"

# Deploy Bicep template
echo -e "${YELLOW}🚀 Starting Bicep template deployment...${NC}"

# Build parameters dynamically
PARAMS="appname=$APP_NAME locationshort=$LOCATION_SHORT location=$LOCATION"

# Add tenantId only if specified
if [[ -n "$TENANT_ID" ]]; then
    PARAMS="$PARAMS tenantId=$TENANT_ID"
fi

DEPLOYMENT_RESULT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "main.bicep" \
    --parameters $PARAMS \
    --output json)

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
    
    # Extract outputs
    AUTOMATION_ACCOUNT_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.automationAccountName.value')
    RUNBOOK_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.runbookName.value')
    SCHEDULE_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.scheduleName.value')
    PRINCIPAL_ID=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.principalId.value')
    
    echo -e "${YELLOW}📋 Resources created:${NC}"
    echo -e "  ${WHITE}• Automation Account: $AUTOMATION_ACCOUNT_NAME${NC}"
    echo -e "  ${WHITE}• Runbook: $RUNBOOK_NAME${NC}"
    echo -e "  ${WHITE}• Schedule: $SCHEDULE_NAME${NC}"
    echo -e "  ${WHITE}• Principal ID: $PRINCIPAL_ID${NC}"
    
    echo -e "${RED}⚠️  MANUAL ACTIONS REQUIRED:${NC}"
    echo -e "${YELLOW}1. Assign permissions to managed identity:${NC}"
    TENANT_ID=$(az account show --query "tenantId" --output tsv)
    for S in $(az account list --query "[?tenantId=='$TENANT_ID'].id" --output tsv); do
        echo -e "   ${WHITE}az role assignment create --assignee '$PRINCIPAL_ID' --role 'Contributor' --scope '/subscriptions/$S'${NC}"
    done

    echo -e "${YELLOW}2. Verify that the runbook is published in the Azure portal${NC}"
    echo -e "${YELLOW}3. Test the runbook manually before the first scheduled execution${NC}"
    
    echo -e "${YELLOW}🔗 Useful links:${NC}"
    echo -e "   ${CYAN}• Azure Portal: https://portal.azure.com/#@$TENANT_ID/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME${NC}"
    
    # Script for role assignment
    echo -e "${YELLOW}📝 Command to assign permissions:${NC}"
    cat > assign_permissions.sh << EOF
#!/bin/bash
echo "🔐 Assigning permissions to managed identity..."
az role assignment create --assignee "$PRINCIPAL_ID" --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID"
echo "✅ Permissions assigned!"
EOF
    chmod +x assign_permissions.sh
    echo -e "   ${WHITE}Created script: assign_permissions.sh${NC}"
    
else
    echo -e "${RED}❌ Deployment failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Script completed!${NC}"
