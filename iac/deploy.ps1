# Deploy Azure Automation Account - Depolicify

# Script di deployment PowerShell per Windows

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-depolicify-itn",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "Italy North",
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "depolicify",
    
    [Parameter(Mandatory=$false)]
    [string]$LocationShort = "itn"
)

# Calcola la data di inizio per domani alle 07:00 UTC
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-ddT07:00:00.000Z")

Write-Host "🚀 Avvio deployment Azure Automation Account per Depolicify..." -ForegroundColor Green

# Login ad Azure
Write-Host "🔐 Login ad Azure..." -ForegroundColor Yellow
if ($TenantId) {
    Connect-AzAccount -TenantId $TenantId
} else {
    Connect-AzAccount
}

# Imposta la subscription
Write-Host "📋 Impostazione subscription: $SubscriptionId" -ForegroundColor Yellow
Set-AzContext -SubscriptionId $SubscriptionId

# Crea il Resource Group se non esiste
Write-Host "📁 Verifica/Creazione Resource Group: $ResourceGroupName" -ForegroundColor Yellow
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-Host "✅ Resource Group creato: $ResourceGroupName" -ForegroundColor Green
} else {
    Write-Host "✅ Resource Group esistente: $ResourceGroupName" -ForegroundColor Green
}

# Parametri per il deployment
$parameters = @{
    appname = $AppName
    locationshort = $LocationShort
    location = $Location
    scheduleStartTime = $tomorrow
}

# Aggiungi tenantId solo se specificato
if ($TenantId) {
    $parameters.tenantId = $TenantId
}

Write-Host "📋 Parametri deployment:" -ForegroundColor Yellow
$parameters | Format-Table -AutoSize

# Deploy del template Bicep
Write-Host "🚀 Avvio deployment template Bicep..." -ForegroundColor Yellow
try {
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "main.bicep" `
        -TemplateParameterObject $parameters `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "✅ Deployment completato con successo!" -ForegroundColor Green
        
        Write-Host "`n📋 Risorse create:" -ForegroundColor Yellow
        Write-Host "  • Automation Account: $($deployment.Outputs.automationAccountName.Value)" -ForegroundColor White
        Write-Host "  • Runbook: $($deployment.Outputs.runbookName.Value)" -ForegroundColor White
        Write-Host "  • Schedule: $($deployment.Outputs.scheduleName.Value)" -ForegroundColor White
        Write-Host "  • Principal ID: $($deployment.Outputs.principalId.Value)" -ForegroundColor White
        
        Write-Host "`n⚠️  AZIONI MANUALI NECESSARIE:" -ForegroundColor Red
        Write-Host "1. Assegnare i permessi al managed identity:" -ForegroundColor Yellow
        Write-Host "   New-AzRoleAssignment -ObjectId '$($deployment.Outputs.principalId.Value)' -RoleDefinitionName 'Contributor' -Scope '/subscriptions/$SubscriptionId'" -ForegroundColor White
        
        Write-Host "`n2. Verificare che il runbook sia pubblicato nel portale Azure" -ForegroundColor Yellow
        Write-Host "`n3. Testare manualmente il runbook prima della prima esecuzione programmata" -ForegroundColor Yellow
        
        Write-Host "`n🔗 Link utili:" -ForegroundColor Yellow
        Write-Host "   • Azure Portal: https://portal.azure.com/#@$TenantId/resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$($deployment.Outputs.automationAccountName.Value)" -ForegroundColor Cyan
        
    } else {
        Write-Host "❌ Deployment fallito!" -ForegroundColor Red
        Write-Host $deployment.ProvisioningState -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Errore durante il deployment:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "`n✅ Script completato!" -ForegroundColor Green
