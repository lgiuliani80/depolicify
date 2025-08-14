@description('Name of the application')
param appname string = 'depolicify'

@description('Short name for the location (e.g., eastus -> eus, westeurope -> weu)')
param locationshort string = 'itn'

@description('Azure region for deployment')
param location string = 'Italy North'

@description('Tenant ID for the Azure Active Directory')
param tenantId string = tenant().tenantId

@description('Start time for the schedule (UTC)')
param scheduleStartTime string = dateTimeAdd(utcNow(), 'P1H')

@description('Local time zone')
param timeZone string = 'Europe/Rome'

@description('Expiration for SAS token created to access .ps1 script in the storage account. Defaults to 1H')
param expiry string = dateTimeAdd(utcNow(), 'PT1H')

// Variables for resource naming
var automationAccountName = 'aa-${appname}-${locationshort}'
var storageAccountName = 'st${appname}${locationshort}${substring(uniqueString(resourceGroup().id), 0, 5)}'
var runbookName = 'depolicify'
var scheduleName = 'Hourly-Schedule'
var jobScheduleName = guid(resourceGroup().id, automationAccountName, runbookName, scheduleName)
var variableName = 'TenantId'
var deploymentScriptName = 'upload-runbook-script'

// PowerShell script content from depolicify.ps1
var runbookContent = loadTextContent('../src/depolicify.ps1')

// Storage Account for hosting the runbook script
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
  tags: {
    Application: appname
    Environment: 'Production'
    Purpose: 'RunbookStorage'
  }
}

// Deployment Script to upload the PowerShell file and generate SAS URL
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: deploymentScriptName
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.50.0'
    retentionInterval: 'PT1H'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    storageAccountSettings: {
      storageAccountName: storageAccountName
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
    #disable-next-line prefer-interpolation
    scriptContent: concat('''
# Runbook content
cat << "EOF" > depolicify.ps1
''', runbookContent, '''
EOF
      
      # Create container
      echo "1. Creating container ..."
      az storage container create --name runbooks --account-name $STORAGE_ACCOUNT_NAME --account-key $STORAGE_ACCOUNT_KEY
      echo ""

      # Upload the PowerShell script content to blob
      echo "2. Uploading PowerShell script ..."
      az storage blob upload \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $STORAGE_ACCOUNT_KEY \
        --container-name runbooks \
        --name depolicify.ps1 \
        --file depolicify.ps1 \
        --overwrite
      echo ""

      # Generate SAS URL with read permission valid for 1 hour
      echo "3. Generating SAS for blob ..."
      SAS_URL=$(az storage blob generate-sas \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key "$STORAGE_ACCOUNT_KEY" \
        --container-name runbooks \
        --name depolicify.ps1 \
        --permissions r \
        --expiry $EXPIRY \
        --https-only \
        --output tsv)
      
      FULL_URL="${STORAGE_ACCOUNT_ENDPOINT}runbooks/depolicify.ps1?${SAS_URL}"

      echo -ne "\r\n\r\n"
      echo -ne "Full URL: $FULL_URL \r\n"
      echo -ne "\r\n"
      
      echo "{\"runbookUrl\": \"$FULL_URL\"}" > $AZ_SCRIPTS_OUTPUT_PATH
    ''')
    environmentVariables: [
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: storageAccount.name
      }
      {
        name: 'STORAGE_ACCOUNT_ENDPOINT'
        value: storageAccount.properties.primaryEndpoints.blob
      }
      {
        name: 'STORAGE_ACCOUNT_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
      {
        name: 'EXPIRY'
        value: expiry
      }
    ]
  }
}

// Azure Automation Account
resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  tags: {
    Application: appname
    Environment: 'Production'
  }
}

// Automation Variable for TenantId
resource automationVariable 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = {
  parent: automationAccount
  name: variableName
  properties: {
    description: 'Tenant ID for Azure Active Directory authentication'
    isEncrypted: false
    value: '"${tenantId}"'
  }
}

// PowerShell 7.2 Runbook
resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2018-06-30' = {
  parent: automationAccount
  name: runbookName
  location: location
  properties: {
    runbookType: 'PowerShell72'
    description: 'Runbook to remove restrictive policies from Storage Accounts and Key Vaults'
    logProgress: true
    logVerbose: false
    publishContentLink: {
      uri: deploymentScript.properties.outputs.runbookUrl
      version: '1.0.0.0'
    }
  }
  dependsOn: [
    automationVariable
  ]
}

// Schedule for hourly execution
resource schedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: scheduleName
  properties: {
    description: 'Hourly schedule'
    frequency: 'Hour'
    interval: 1
    startTime: scheduleStartTime
    timeZone: timeZone
  }
}

// Job Schedule to link the runbook with the schedule
resource jobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  name: jobScheduleName
  properties: {
    runbook: {
      name: runbook.name
    }
    schedule: {
      name: schedule.name
    }
  }
}

// Outputs
output automationAccountName string = automationAccount.name
output automationAccountId string = automationAccount.id
output storageAccountName string = storageAccount.name
output runbookName string = runbook.name
output runbookUrl string = deploymentScript.properties.outputs.runbookUrl
output scheduleName string = schedule.name
output principalId string = automationAccount.identity.principalId
