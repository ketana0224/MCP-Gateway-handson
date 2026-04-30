// ============================================================
// Azure API Management × API Center × MCP ハンズオン
// メインデプロイテンプレート
// ============================================================

targetScope = 'resourceGroup'

@description('リソース名のプレフィックス')
param prefix string = 'mcp-workshop'

@description('デプロイリージョン')
param location string = resourceGroup().location

@description('APIM 管理者メールアドレス')
param apimPublisherEmail string

@description('APIM 発行者名')
param apimPublisherName string = 'MCP Workshop'

// ============================================================
// API Management (MCP Gateway)
// ============================================================
module apim 'modules/apim.bicep' = {
  name: 'deploy-apim'
  params: {
    name: 'apim-${prefix}'
    location: location
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

// ============================================================
// API Center (MCP Server Registry)
// ============================================================
module apiCenter 'modules/api-center.bicep' = {
  name: 'deploy-api-center'
  params: {
    name: 'apic-${prefix}'
    location: location
  }
}

// ============================================================
// Container Apps Environment + Apps (バックエンドAPI / MCP Server)
// ============================================================
module containerApps 'modules/container-apps.bicep' = {
  name: 'deploy-container-apps'
  params: {
    prefix: prefix
    location: location
  }
}

// ============================================================
// Application Insights + Log Analytics (監査・監視)
// ============================================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${prefix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinsights-${prefix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ============================================================
// Key Vault (シークレット管理)
// ============================================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${prefix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
  }
}

// ============================================================
// Outputs
// ============================================================
output apimGatewayUrl string = apim.outputs.gatewayUrl
output apimName string = apim.outputs.name
output apiCenterName string = apiCenter.outputs.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output logAnalyticsWorkspaceId string = logAnalytics.id
output keyVaultName string = keyVault.name
output knowledgeApiUrl string = containerApps.outputs.knowledgeApiUrl
output incidentMcpUrl string = containerApps.outputs.incidentMcpUrl
output oncallApiUrl string = containerApps.outputs.oncallApiUrl
