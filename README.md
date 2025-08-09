# Azure Automation Account - Depolicify

Questo progetto Bicep crea un Azure Automation Account con un runbook PowerShell 7.2 chiamato "depolicify" che viene eseguito quotidianamente alle 07:00 AM UTC.

## Risorse create

- **Azure Automation Account** (`aa-depolicify-itn`) - Account di automazione con managed identity
- **Runbook PowerShell** (`depolicify`) - Script per rimuovere restrizioni da Storage Account e Key Vault
- **Schedule** (`Daily-0700-Schedule`) - Programmazione giornaliera alle 07:00 AM UTC
- **Job Schedule** - Collegamento tra runbook e schedule
- **Automation Variable** (`TenantId`) - Variabile contenente il Tenant ID

## Parametri

| Parametro | Descrizione | Valore di default | Obbligatorio |
|-----------|-------------|-------------------|--------------|
| `appname` | Nome dell'applicazione | `depolicify` | No |
| `locationshort` | Abbreviazione della location | `itn` | No |
| `location` | Regione Azure | `Italy North` | No |
| `tenantId` | ID del tenant Azure AD | `tenant().tenantId` (corrente) | No |
| `scheduleStartTime` | Data/ora di inizio schedule | - | **Sì** |

## Naming Convention

Tutte le risorse seguono la naming convention richiesta:
- `<abbreviazione-risorsa>-<appname>-<locationshort>`

Esempio: `aa-depolicify-itn` per l'Automation Account

## Deployment

### 1. Aggiornare i parametri

Modifica il file `main.parameters.json` inserendo i valori corretti:

```json
{
  "scheduleStartTime": {
    "value": "2025-08-10T07:00:00.000Z"
  }
}
```

**Nota**: Il `tenantId` non è più richiesto nei parametri in quanto viene automaticamente rilevato dal resource group corrente.

### 2. Deploy con Azure CLI

```bash
# Login ad Azure
az login

# Imposta la subscription corretta
az account set --subscription "your-subscription-id"

# Crea il resource group (se non esiste)
az group create --name "rg-depolicify-itn" --location "Italy North"

# Deploy del template
az deployment group create \
  --resource-group "rg-depolicify-itn" \
  --template-file "main.bicep" \
  --parameters "@main.parameters.json"
```

### 3. Deploy con PowerShell

```powershell
# Login ad Azure (tenantId rilevato automaticamente)
Connect-AzAccount

# Imposta la subscription corretta
Set-AzContext -SubscriptionId "your-subscription-id"

# Crea il resource group (se non esiste)
New-AzResourceGroup -Name "rg-depolicify-itn" -Location "Italy North"

# Deploy del template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-depolicify-itn" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "main.parameters.json"
```

## Funzionalità del Runbook

Il runbook `depolicify` esegue le seguenti operazioni:

1. **Autentica** usando il managed identity dell'Automation Account
2. **Itera** su tutte le subscription del tenant
3. **Storage Account**: Abilita l'accesso con shared key e l'accesso dalla rete pubblica
4. **Key Vault**: Abilita l'accesso dalla rete pubblica

## Permessi necessari

Il managed identity dell'Automation Account deve avere i seguenti permessi:

- **Storage Account**: `Storage Account Contributor` o `Owner`
- **Key Vault**: `Key Vault Contributor` o `Owner`
- **Subscription**: `Reader` per enumerare le risorse

### Assegnazione permessi via PowerShell

```powershell
# Ottieni il principal ID del managed identity
$automationAccount = Get-AzAutomationAccount -ResourceGroupName "rg-depolicify-itn" -Name "aa-depolicify-itn"
$principalId = $automationAccount.Identity.PrincipalId

# Assegna il ruolo Contributor a livello di subscription
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Contributor" -Scope "/subscriptions/your-subscription-id"
```

## Schedule

- **Frequenza**: Giornaliera
- **Orario**: 07:00 AM UTC
- **Fuso orario**: UTC

## Output

Il template restituisce i seguenti output:

- `automationAccountName`: Nome dell'Automation Account
- `automationAccountId`: ID risorsa dell'Automation Account  
- `runbookName`: Nome del runbook
- `scheduleName`: Nome della schedule
- `principalId`: Principal ID del managed identity

## Troubleshooting

### Verificare lo stato del runbook
```bash
az automation runbook show \
  --resource-group "rg-depolicify-itn" \
  --automation-account-name "aa-depolicify-itn" \
  --name "depolicify"
```

### Verificare la schedule
```bash
az automation schedule show \
  --resource-group "rg-depolicify-itn" \
  --automation-account-name "aa-depolicify-itn" \
  --name "Daily-0700-Schedule"
```

### Log di esecuzione
I log di esecuzione sono disponibili nel portale Azure sotto:
`Automation Account > Jobs > [Job ID] > Output`
