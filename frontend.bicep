
param busUnit string
param reg string
param loc string
param env string
param project string
param appTags object

param certName string

var addAppTags = {
  'Custom Tag': 'Insert custom data here'
}


@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The name of the App Service application to create. This must be globally unique.')
param appName string = 'app-${project}-${env}'

@description('The name of the SKU to use when creating the App Service plan.')
param appServicePlanSkuName string = 'S1'

@description('The number of worker instances of your App Service plan that should be provisioned.')
param appServicePlanCapacity int = 1

@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorEndpointName string = 'afd-${project}-${env}'

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Standard_AzureFrontDoor'

var appServicePlanName = 'asp-${project}-api-${env}'
var frontDoorProfileName = 'afd-${project}-${env}'
var frontDoorOriginGroupName = 'fdg-${project}-${env}'
var frontDoorOriginName = 'fdo-${project}-${env}'
var frontDoorRouteName = 'fdr-${project}-${env}'

//storageSite
resource staticStorageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: 'st${project}static${env}'
  location: loc
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
    }
  }
  sku: {
    name: 'Standard_RAGRS'
  }
  kind: 'StorageV2'
  dependsOn: []
}


var staticWebsiteHostName string = replace(replace(staticStorageAccount.properties.primaryEndpoints.web, 'https://', ''), '/', '')

resource appServicePlan 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
    capacity: appServicePlanCapacity
  }
  kind: 'app'
}


//cdn
resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: staticWebsiteHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: staticWebsiteHostName
    priority: 1
    weight: 1000
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin 
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

output appServiceHostName string = staticStorageAccount.properties.primaryEndpoints.web
output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
