// ============================================================
// Azure Container Registry
// ============================================================

@description('リソース名プレフィックス（ハイフン不可）')
param prefix string

@description('デプロイリージョン')
param location string

// ACR 名はグローバル一意 & 英数字のみ（ハイフン除去）
var acrName = replace(prefix, '-', '')

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
