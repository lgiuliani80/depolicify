# Azure Automation Account - Depolicify

This Bicep project creates an Azure Automation Account with a PowerShell 7.2 runbook called "depolicify" that runs daily at 07:00 AM.

## Quick Deploy

### Deploy with default parameters

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Flgiuliani80%2Fdepolicify%2Fmain%2Fiac%2Fmain.bicep)

**Command for Azure CLI:**

```bash
az deployment group create \
  --resource-group "rg-TestBicepAutom" \
  --template-uri "https://raw.githubusercontent.com/lgiuliani80/depolicify/main/iac/main.bicep" \
  --parameters scheduleStartTime="$(date -u -d 'tomorrow 07:00' '+%Y-%m-%dT07:00:00.000Z')"
```

> **Note:** The "Deploy to Azure" buttons work only if:
>
> 1. The repository is public on GitHub
> 2. The Bicep template is accessible via HTTPS raw URL
> 3. You have the necessary permissions in the target Azure subscription

## Resources Created

- **Azure Automation Account** (`aa-depolicify-itn`) - Automation account with managed identity
- **PowerShell Runbook** (`depolicify`) - Script to remove restrictions from Storage Accounts and Key Vaults
- **Schedule** (`Daily-0700-Schedule`) - Daily schedule at 07:00 AM UTC
- **Job Schedule** - Link between runbook and schedule
- **Automation Variable** (`TenantId`) - Variable containing the Tenant ID

## Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `appname` | Application name | `depolicify` | No |
| `locationshort` | Location abbreviation | `itn` | No |
| `location` | Azure region | `Italy North` | No |
| `tenantId` | Azure AD tenant ID | `tenant().tenantId` (current) | No |
| `timeZone` | Schedule time zone | `Europe/Rome` | No |

## Naming Convention

All resources follow the required naming convention:

- `<resource-abbreviation>-<appname>-<locationshort>`

Example: `aa-depolicify-itn` for the Automation Account

## Deployment

### 1. Update parameters

Edit the `main.parameters.json` file by entering the correct values:

```json
{
  "scheduleStartTime": {
    "value": "2025-08-10T07:00:00.000Z"
  }
}
```

**Note**: The `tenantId` is no longer required in the parameters as it is automatically detected from the current resource group.

### 2. Deploy with Azure CLI

```bash
# Login to Azure
az login

# Set the correct subscription
az account set --subscription "your-subscription-id"

# Create the resource group (if it doesn't exist)
az group create --name "rg-depolicify-itn" --location "Italy North"

# Deploy the template
az deployment group create \
  --resource-group "rg-depolicify-itn" \
  --template-file "main.bicep" \
  --parameters "@main.parameters.json"
```

### 3. Deploy with PowerShell

```powershell
# Login to Azure (tenantId detected automatically)
Connect-AzAccount

# Set the correct subscription
Set-AzContext -SubscriptionId "your-subscription-id"

# Create the resource group (if it doesn't exist)
New-AzResourceGroup -Name "rg-depolicify-itn" -Location "Italy North"

# Deploy the template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-depolicify-itn" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "main.parameters.json"
```

## Runbook Functionality

The `depolicify` runbook performs the following operations:

1. **Authenticates** using the Automation Account's managed identity
2. **Iterates** through all subscriptions in the tenant
3. **Storage Accounts**: Enables shared key access and public network access
4. **Key Vaults**: Enables public network access

## Required Permissions

The Automation Account's managed identity must have the following permissions:

- **Storage Accounts**: `Storage Account Contributor` or `Owner`
- **Key Vaults**: `Key Vault Contributor` or `Owner`
- **Subscriptions**: `Reader` to enumerate resources

### Assign permissions via PowerShell

```powershell
# Get the managed identity principal ID
$automationAccount = Get-AzAutomationAccount -ResourceGroupName "rg-depolicify-itn" -Name "aa-depolicify-itn"
$principalId = $automationAccount.Identity.PrincipalId

# Assign the Contributor role at subscription level
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Contributor" -Scope "/subscriptions/your-subscription-id"
```

## Schedule

- **Frequency**: Daily
- **Time**: 07:00 AM

## Outputs

The template returns the following outputs:

- `automationAccountName`: Automation Account name
- `automationAccountId`: Automation Account resource ID
- `runbookName`: Runbook name
- `scheduleName`: Schedule name
- `principalId`: Managed identity principal ID

## Troubleshooting

### Check runbook status

```bash
az automation runbook show \
  --resource-group "rg-depolicify-itn" \
  --automation-account-name "aa-depolicify-itn" \
  --name "depolicify"
```

### Check schedule

```bash
az automation schedule show \
  --resource-group "rg-depolicify-itn" \
  --automation-account-name "aa-depolicify-itn" \
  --name "Daily-0700-Schedule"
```

### Execution logs

Execution logs are available in the Azure portal under:
`Automation Account > Jobs > [Job ID] > Output`
