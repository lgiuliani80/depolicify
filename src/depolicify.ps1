$ErrorActionPreference = "Stop"

$TenantId = Get-AutomationVariable -Name 'TenantId'

Connect-AzAccount -Identity -TenantId $TenantId

Write-Host "Script started"

Get-AzSubscription -TenantId $TenantId | ForEach-Object {
    Set-AzContext $_

    Write-Output "- STORAGE ACCOUNTS"
    Write-Output "  ================"
    Write-Output ""
    Get-AzStorageAccount | Where-Object { -not $_.AllowSharedKeyAccess -or -not ($_.PublicNetworkAccess -eq 'Enabled') } | ForEach-Object {
        Write-Output "  * $($_.StorageAccountName): allowing key access and public network access"
        $_ | Set-AzStorageAccount -AllowSharedKeyAccess $true -PublicNetworkAccess Enabled
    }

    Write-Output "- KEY VAULTS"
    Write-Output "  =========="
    Write-Output ""
    Get-AzKeyVault | ForEach-Object {
        Write-Output "  * $($_.VaultName): allowing public network access"
        #$_ | Update-AzKeyVault -PublicNetworkAccess Enabled

        Update-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName -PublicNetworkAccess Enabled
    }

}

Write-Host "Script completed"
