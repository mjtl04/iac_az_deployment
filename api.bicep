
#disable-next-line no-unused-params
param busUnit string
#disable-next-line no-unused-params
param reg string
param loc string
param env string
param project string
param appTags object

param role string

var addAppTags = {
  'Custom Tag': 'Insert custom data here'
}

var appTagsComb = union(appTags, addAppTags)

var environmentConfigurationMap = {
  dev: {
    appService: {
      name: 'Y1'
      tier: 'Dynamic'
      size: 'Y1'
      family: 'Y'
      capacity: 0
    }
    functionApp: {
      siteConfig: {
        alwayson: false
      }
    }
  }
  ppd: {
    appService: {
      name: 'Y1'
      tier: 'Dynamic'
      size: 'Y1'
      family: 'Y'
      capacity: 0
    }
    functionApp: {
      siteConfig: {
        alwayson: false
      }
    }
  }
  prd: {
    appService: {
      name: 'S1'
      tier: 'Standard'
      size: 'S1'
      family: 'S'
      capacity: 1
    }
    functionApp: {
      siteconfig: {
        alwayson: true
      }
    }
  }
}


resource funcApiStorage 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: 'st${project}${role}${env}'
  location: loc
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: appTagsComb
}


resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${project}-${role}-${env}'
  location: loc
  kind: 'functionapp'
  sku: {
    name: environmentConfigurationMap[env].appService.name
    tier: environmentConfigurationMap[env].appService.tier
    capacity: environmentConfigurationMap[env].appService.capacity
  }
  properties: {}
  tags: appTagsComb
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-${project}-${role}-${env}'
  location: loc
  tags: appTagsComb
  kind: 'functionapp'
  properties: {
    hostNameSslStates: [
      {
        name: '${'func-${project}-${role}-${env}'}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${'func-${project}-${role}-${env}'}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
    ]
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: environmentConfigurationMap[env].functionApp.siteconfig.alwaysOn
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcApiStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcApiStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcApiStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcApiStorage.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AzureWebJobsDisableHomepage'
          value: 'true'
        }
        {
          name: 'env'
          value: env
        }
      ]
    }
    clientAffinityEnabled: false
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}


output funcIdentity string = functionApp.identity.principalId
