// ============================================================
// Azure Container Registry
// ============================================================

@description('リソース名ベース（例: mcp-user01）')
param nameBase string

@description('デプロイリージョン')
param location string

// ACR 名はグローバル一意 & 英数字のみ（ハイフン除去 + RG スコープのユニーク5文字サフィックス）
var acrName = '${replace(nameBase, '-', '')}${take(uniqueString(resourceGroup().id), 5)}'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
