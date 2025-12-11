#disable-next-line no-unused-params
param busUnit string
#disable-next-line no-unused-params
param reg string
param loc string
param env string
param project string
param appTags object

var addAppTags = {'Custom Tag': 'Insert custom data here'}
var appTagsComb = union(appTags, addAppTags)

param secGrpId string

@secure()
param sqlCs string



resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${project}-${env}'
  location: loc
  tags: appTagsComb
  properties: {
    tenantId: '73c91d15-be0a-4139-9ecd-25e09d601ee3'
    enablePurgeProtection: true
    accessPolicies: [
      {
        tenantId: '73c91d15-be0a-4139-9ecd-25e09d601ee3'
        objectId: secGrpId

        permissions: {
          secrets: [
            'all'
          ]
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
          storage: [
            'all'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }

  resource secSQLCs 'secrets' = {
    name: 'DbConnectionString'
    properties: {
      value: sqlCs
    }
  }
}


output secSQLCs string = keyVault::secSQLCs.properties.secretUri
