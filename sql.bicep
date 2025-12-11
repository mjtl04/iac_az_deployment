
param busUnit string
#disable-next-line no-unused-params
param reg string
param loc string
param env string
param project string
param appTags object

param dbs array
param secGrpId string

@secure()
param serverAdminPassword string

var addAppTags = {
  'Custom Tag': 'Insert custom data here'
}
var appTagsComb = union(appTags, addAppTags)

var environmentConfigurationMap = {
  dev: {
    sqlServer: {
      sku: 'S0'
    }
  }
  ppd: {
    sqlServer: {
      sku: 'S0'
    }
  }
  prd: {
    sqlServer: {
      sku: 'S1'
    }
  }
}

var sqlEp = sqlServer.properties.fullyQualifiedDomainName
var envUpp = toUpper(env)
var busUnitUpp = toUpper(busUnit)

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: 'sql-${project}-${env}'
  location: loc
  properties: {
    administratorLogin: 'rplserveradmin'
    administratorLoginPassword: serverAdminPassword
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: '$AZURE-${busUnitUpp}-${envUpp}-Advanced-User'
      sid: secGrpId
      tenantId: '12345678910111213'
      azureADOnlyAuthentication: false
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: appTagsComb
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = [
  for db in dbs: {
    name: 'sqldb-${db.name}-${env}'
    location: loc
    parent: sqlServer
    sku: {
      name: environmentConfigurationMap[env].sqlServer.sku
    }
  }
]

resource sqlServerFirewallRpl 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  name: 'sqlfw-rpl'
  parent: sqlServer
  properties: {
    startIpAddress: '123.123.123.123'
    endIpAddress: '123.123.123.123'
  }
}

resource sqlServerFirewallAzure 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  name: 'sqlfw-azure'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}


output sqlCs string = 'Data Source=${sqlEp};Initial Catalog=sqldb-${project}-${env};Authentication=Active Directory Managed Identity'
