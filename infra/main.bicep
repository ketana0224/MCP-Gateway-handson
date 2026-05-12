// ============================================================
// Azure API Management × API Center × MCP ハンズオン
// メインデプロイテンプレート
// ============================================================

targetScope = 'resourceGroup'

@description('リソース名のベースプレフィックス（通常は固定）')
param prefix string = 'mcp'

@description('参加者ID（例: user01, user02）。同一サブスクリプションで複数人がハンズオンを実施する場合、衝突を防ぐためリソース名に付与される。')
@minLength(2)
@maxLength(10)
param userId string

@description('デプロイリージョン')
param location string = resourceGroup().location

@description('APIM 管理者メールアドレス')
param apimPublisherEmail string

@description('APIM 発行者名')
param apimPublisherName string = 'MCP Workshop'

@description('バックエンド（Container Apps Environment + 3 つの Container Apps + ACR）をデプロイするか。サブスクリプションの Container App Environment 数上限（既定 1 個）を回避するため、複数人ハンズオンでは「講師が 1 セット作成 → 参加者は false 指定で共有」する。')
param deployBackend bool = true

// 参加者ごとに一意なベース名（例: mcp-user01）
var nameBase = '${prefix}-${userId}'

// グローバル一意な DNS 名を要求するリソース用の安定 suffix（5 文字）
var uniqueSuffix = take(uniqueString(resourceGroup().id, userId), 5)

// ============================================================
// API Management (MCP Gateway)
// ============================================================
module apim 'modules/apim.bicep' = {
  name: 'deploy-apim'
  params: {
    name: 'apim-${nameBase}-${uniqueSuffix}'
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
    name: 'apic-${nameBase}-${uniqueSuffix}'
    location: location
  }
}

// ============================================================
// Azure Container Registry (コンテナイメージ格納)
// deployBackend=true の場合のみ作成
// ============================================================
module acr 'modules/acr.bicep' = if (deployBackend) {
  name: 'deploy-acr'
  params: {
    nameBase: nameBase
    location: location
  }
}

// ============================================================
// Container Apps Environment + Apps (バックエンドAPI / MCP Server)
// deployBackend=true の場合のみ作成
// ============================================================
@description('knowledge-api コンテナイメージ（省略時はプレースホルダ）')
param knowledgeApiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('incident-mcp-server コンテナイメージ（省略時はプレースホルダ）')
param incidentMcpImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('oncall-api コンテナイメージ（省略時はプレースホルダ）')
param oncallApiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

module containerApps 'modules/container-apps.bicep' = if (deployBackend) {
  name: 'deploy-container-apps'
  params: {
    nameBase: nameBase
    location: location
    knowledgeApiImage: knowledgeApiImage
    incidentMcpImage: incidentMcpImage
    oncallApiImage: oncallApiImage
  }
}

// ============================================================
// Application Insights + Log Analytics (監査・監視)
// ============================================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${nameBase}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinsights-${nameBase}'
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
  // 命名長: kv- (3) + mcp- (4) + userId (max 10) + - (1) + suffix (5) = 最大 23 文字（24 文字制限内）
  name: 'kv-${nameBase}-${uniqueSuffix}'
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
output logAnalyticsName string = logAnalytics.name
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output logAnalyticsWorkspaceId string = logAnalytics.id
output keyVaultName string = keyVault.name
// Backend outputs（deployBackend=false の場合は空文字）
output knowledgeApiUrl string = deployBackend ? containerApps!.outputs.knowledgeApiUrl : ''
output incidentMcpUrl string = deployBackend ? containerApps!.outputs.incidentMcpUrl : ''
output oncallApiUrl string = deployBackend ? containerApps!.outputs.oncallApiUrl : ''
output knowledgeApiContainerAppName string = deployBackend ? containerApps!.outputs.knowledgeApiContainerAppName : ''
output incidentMcpContainerAppName string = deployBackend ? containerApps!.outputs.incidentMcpContainerAppName : ''
output oncallApiContainerAppName string = deployBackend ? containerApps!.outputs.oncallApiContainerAppName : ''
output acrLoginServer string = deployBackend ? acr!.outputs.acrLoginServer : ''
output acrName string = deployBackend ? acr!.outputs.acrName : ''
output deployBackend bool = deployBackend
