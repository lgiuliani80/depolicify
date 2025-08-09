#!/bin/bash

# Deploy Azure Automation Account - Depolicify
# Script di deployment per Linux/macOS con Azure CLI

set -e

# Colori per l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Parametri di default
RESOURCE_GROUP_NAME="rg-depolicify-itn"
LOCATION="Italy North"
APP_NAME="depolicify"
LOCATION_SHORT="itn"

# Funzione di help
show_help() {
    echo -e "${GREEN}Deploy Azure Automation Account - Depolicify${NC}"
    echo ""
    echo "Usage: $0 -s SUBSCRIPTION_ID [OPTIONS]"
    echo ""
    echo "Required parameters:"
    echo "  -s, --subscription-id SUBSCRIPTION_ID   Azure Subscription ID"
    echo ""
    echo "Optional parameters:"
    echo "  -t, --tenant-id TENANT_ID           Azure Tenant ID (if not specified, uses current tenant)"
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

# Parse dei parametri
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tenant-id)
            TENANT_ID="$2"
            shift 2
            ;;
        -s|--subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
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
            echo -e "${RED}Parametro sconosciuto: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Verifica parametri obbligatori
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    echo -e "${RED}❌ Errore: Subscription ID è obbligatorio!${NC}"
    show_help
    exit 1
fi

# Calcola la data di domani alle 07:00 UTC
SCHEDULE_START_TIME=$(date -u -d "tomorrow 07:00" +"%Y-%m-%dT07:00:00.000Z" 2>/dev/null || date -u -v+1d -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) 07:00:00" +"%Y-%m-%dT07:00:00.000Z")

echo -e "${GREEN}🚀 Avvio deployment Azure Automation Account per Depolicify...${NC}"

# Login ad Azure
echo -e "${YELLOW}🔐 Login ad Azure...${NC}"
if [[ -n "$TENANT_ID" ]]; then
    az login --tenant "$TENANT_ID"
else
    az login
fi

# Imposta la subscription
echo -e "${YELLOW}📋 Impostazione subscription: $SUBSCRIPTION_ID${NC}"
az account set --subscription "$SUBSCRIPTION_ID"

# Crea il Resource Group se non esiste
echo -e "${YELLOW}📁 Verifica/Creazione Resource Group: $RESOURCE_GROUP_NAME${NC}"
if ! az group show --name "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    echo -e "${GREEN}✅ Resource Group creato: $RESOURCE_GROUP_NAME${NC}"
else
    echo -e "${GREEN}✅ Resource Group esistente: $RESOURCE_GROUP_NAME${NC}"
fi

# Mostra i parametri
echo -e "${YELLOW}📋 Parametri deployment:${NC}"
echo -e "  ${WHITE}• App Name:         $APP_NAME${NC}"
echo -e "  ${WHITE}• Location:         $LOCATION${NC}"
echo -e "  ${WHITE}• Location Short:   $LOCATION_SHORT${NC}"
echo -e "  ${WHITE}• Tenant ID:        $TENANT_ID${NC}"
echo -e "  ${WHITE}• Schedule Start:   $SCHEDULE_START_TIME${NC}"

# Deploy del template Bicep
echo -e "${YELLOW}🚀 Avvio deployment template Bicep...${NC}"

# Costruisci i parametri dinamicamente
PARAMS="appname=$APP_NAME locationshort=$LOCATION_SHORT location=$LOCATION scheduleStartTime=$SCHEDULE_START_TIME"

# Aggiungi tenantId solo se specificato
if [[ -n "$TENANT_ID" ]]; then
    PARAMS="$PARAMS tenantId=$TENANT_ID"
fi

DEPLOYMENT_RESULT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "main.bicep" \
    --parameters $PARAMS \
    --output json)

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Deployment completato con successo!${NC}"
    
    # Estrai gli output
    AUTOMATION_ACCOUNT_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.automationAccountName.value')
    RUNBOOK_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.runbookName.value')
    SCHEDULE_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.scheduleName.value')
    PRINCIPAL_ID=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.principalId.value')
    
    echo -e "${YELLOW}📋 Risorse create:${NC}"
    echo -e "  ${WHITE}• Automation Account: $AUTOMATION_ACCOUNT_NAME${NC}"
    echo -e "  ${WHITE}• Runbook: $RUNBOOK_NAME${NC}"
    echo -e "  ${WHITE}• Schedule: $SCHEDULE_NAME${NC}"
    echo -e "  ${WHITE}• Principal ID: $PRINCIPAL_ID${NC}"
    
    echo -e "${RED}⚠️  AZIONI MANUALI NECESSARIE:${NC}"
    echo -e "${YELLOW}1. Assegnare i permessi al managed identity:${NC}"
    echo -e "   ${WHITE}az role assignment create --assignee '$PRINCIPAL_ID' --role 'Contributor' --scope '/subscriptions/$SUBSCRIPTION_ID'${NC}"
    
    echo -e "${YELLOW}2. Verificare che il runbook sia pubblicato nel portale Azure${NC}"
    echo -e "${YELLOW}3. Testare manualmente il runbook prima della prima esecuzione programmata${NC}"
    
    echo -e "${YELLOW}🔗 Link utili:${NC}"
    echo -e "   ${CYAN}• Azure Portal: https://portal.azure.com/#@$TENANT_ID/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME${NC}"
    
    # Script per assegnazione ruoli
    echo -e "${YELLOW}📝 Comando per assegnare i permessi:${NC}"
    cat > assign_permissions.sh << EOF
#!/bin/bash
echo "🔐 Assegnazione permessi al managed identity..."
az role assignment create --assignee "$PRINCIPAL_ID" --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID"
echo "✅ Permessi assegnati!"
EOF
    chmod +x assign_permissions.sh
    echo -e "   ${WHITE}Creato script: assign_permissions.sh${NC}"
    
else
    echo -e "${RED}❌ Deployment fallito!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Script completato!${NC}"
