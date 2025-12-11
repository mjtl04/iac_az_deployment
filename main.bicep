
@description('The type of environment')
@allowed([
  'sbx'
  'dev'
  'ppd'
  'prd'
])
param env string


@description('The business unit')
@allowed([
  'dig'
])
param busUnit string


@description('The deployment region')
@allowed([
  'uks'
  'ukw'
  'euw'
])
param reg string


param project string
param owner string
param costCode string

var locMap = {
  uks: {
    loc: 'uksouth'
  }
  ukw: {
    loc: 'ukwest'
  }
  euw: {
    loc: 'westeurope'
  }
}

var envConfigMap = {
  sbx: {
  
  }
  dev: {
   
  }
  ppd: {

  }
  prd: {
    
  }
}

var configurationMap = {
  dev: {
    dbs: [
      {
        name: project
        addTags: {
          'Custom Db Tag': 'Insert custom db tag here'
        }
      }
    ]
  }
  ppd: {
    dbs: [
      {
        name: project
        addTags: {
          'Custom Db Tag': 'Insert custom db tag here'
        }
      }
    ]
  }
  prd: {
    dbs: [
      {
        name: project
        addTags: {
          'Custom Db Tag': 'Insert custom db tag here'
        }
      }
    ]
  }
}

var appTags = {
  Project: toUpper(project)
  Owner: owner
  Location: locMap[reg].loc
  CostCode: costCode
}

resource infraKv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'KV-${busUnit}-${reg}-${env}-CERT'
  scope: resourceGroup('${busUnit}-${reg}-${env}-INFRA')
}

module keyvault './keyvault.bicep' = {
  name: 'kv-${project}-${env}'
  params: {
    busUnit: busUnit
    reg: reg
    loc: locMap[reg].loc
    project: project
    env: env
    appTags: appTags

    secGrpId: envConfigMap[env].secGrpId

    sqlCs: sql.outputs.sqlCs
  }
}

module sql './sql.bicep' = {
  name: 'deploySQL'
  params: {
    busUnit: busUnit
    reg: reg
    loc: locMap[reg].loc
    project: project
    env: env
    appTags: appTags

    secGrpId: envConfigMap[env].secGrpId

    dbs: configurationMap[env].dbs
    serverAdminPassword: infraKv.getSecret('${toUpper(project)}-SqlAdminPassword')
  }
}

module api './api.bicep' = {
  name: 'deployApi'
  params: {
    busUnit: busUnit
    reg: reg
    loc: locMap[reg].loc
    project: project
    env: env
    appTags: appTags
    role: 'api'
  }
}


module frontend './frontend.bicep' = {
  name: 'deployFrontEnd'
  params: {
    busUnit: busUnit
    reg: reg
    loc: locMap[reg].loc
    project: project
    env: env
    appTags: appTags

    certName: envConfigMap[env].certName
  }
  dependsOn: [
    infraKv
  ]
}
