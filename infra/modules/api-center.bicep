// ============================================================
// Azure API Center — MCP Server Registry
// ============================================================

@description('API Center インスタンス名')
param name string

@description('デプロイリージョン')
param location string

resource apiCenter 'Microsoft.ApiCenter/services@2024-03-01' = {
  name: name
  location: location
  properties: {}
}

output name string = apiCenter.name
output id string = apiCenter.id
