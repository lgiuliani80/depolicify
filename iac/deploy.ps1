# Deploy Azure Automation Account - Depolicify

# PowerShell deployment script for Windows

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-depolicify-itn",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "Italy North",
    
    [Parameter(Mandatory=$false)]
    [string]$LocationShort = "itn"

    [Parameter(Mandatory=$false)]
    [string]$AppName = "depolicify",
    
)

Write-Host "🚀 Starting Azure Automation Account deployment for Depolicify..." -ForegroundColor Green

# Create Resource Group if it doesn't exist
Write-Host "📁 Checking/Creating Resource Group: $ResourceGroupName" -ForegroundColor Yellow
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-Host "✅ Resource Group created: $ResourceGroupName" -ForegroundColor Green
} else {
    Write-Host "✅ Existing Resource Group: $ResourceGroupName" -ForegroundColor Green
}

# Parameters for deployment
$parameters = @{
    appname = $AppName
    locationshort = $LocationShort
    location = $Location
}

Write-Host "📋 Deployment parameters:" -ForegroundColor Yellow
$parameters | Format-Table -AutoSize

# Deploy Bicep template
Write-Host "🚀 Starting Bicep template deployment..." -ForegroundColor Yellow
try {
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "main.bicep" `
        -TemplateParameterObject $parameters `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
        
        Write-Host "`n📋 Resources created:" -ForegroundColor Yellow
        Write-Host "  • Automation Account: $($deployment.Outputs.automationAccountName.Value)" -ForegroundColor White
        Write-Host "  • Runbook: $($deployment.Outputs.runbookName.Value)" -ForegroundColor White
        Write-Host "  • Schedule: $($deployment.Outputs.scheduleName.Value)" -ForegroundColor White
        Write-Host "  • Principal ID: $($deployment.Outputs.principalId.Value)" -ForegroundColor White
        
        Write-Host "`n⚠️  MANUAL ACTIONS REQUIRED:" -ForegroundColor Red
        Write-Host "1. Assign permissions to managed identity:" -ForegroundColor Yellow
        $TENANT_ID = (Get-AzContext).Tenant.Id
        Get-AzSubscription -TenantId $TENANT_ID | ForEach-Object {
            Write-Host "   New-AzRoleAssignment -ObjectId '$($deployment.Outputs.principalId.Value)' -RoleDefinitionName 'Contributor' -Scope '/subscriptions/$($_.Id)'" -ForegroundColor White
        }

        Write-Host "`n2. Verify that the runbook is published in the Azure portal" -ForegroundColor Yellow
        Write-Host "`n3. Test the runbook manually before the first scheduled execution" -ForegroundColor Yellow
        
        Write-Host "`n🔗 Useful links:" -ForegroundColor Yellow
        Write-Host "   • Azure Portal: https://portal.azure.com/#@$TenantId/resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$($deployment.Outputs.automationAccountName.Value)" -ForegroundColor Cyan
        
    } else {
        Write-Host "❌ Deployment failed!" -ForegroundColor Red
        Write-Host $deployment.ProvisioningState -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error during deployment:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "`n✅ Script completed!" -ForegroundColor Green
