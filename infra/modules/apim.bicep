// ============================================================
// Azure API Management — MCP Gateway
// ============================================================

@description('APIM インスタンス名')
param name string

@description('デプロイリージョン')
param location string

@description('管理者メールアドレス')
param publisherEmail string

@description('発行者名')
param publisherName string

resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

output gatewayUrl string = apim.properties.gatewayUrl
output name string = apim.name
output principalId string = apim.identity.principalId
