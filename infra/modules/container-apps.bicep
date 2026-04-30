// ============================================================
// Azure Container Apps — バックエンド API / MCP Server ホスト
// ============================================================

@description('リソース名プレフィックス')
param prefix string

@description('デプロイリージョン')
param location string

@description('knowledge-api コンテナイメージ')
param knowledgeApiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('incident-mcp-server コンテナイメージ')
param incidentMcpImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('oncall-api コンテナイメージ')
param oncallApiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// Container Apps Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${prefix}'
  location: location
  properties: {
    zoneRedundant: false
  }
}

// Knowledge Search API (REST)
resource knowledgeApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-knowledge-api'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'knowledge-api'
          image: knowledgeApiImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// Incident MCP Server (Streamable HTTP)
resource incidentMcp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-incident-mcp'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3001
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'incident-mcp'
          image: incidentMcpImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// On-call Schedule API (REST)
resource oncallApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-oncall-api'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3002
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'oncall-api'
          image: oncallApiImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output knowledgeApiUrl string = knowledgeApi.properties.configuration.ingress.fqdn
output incidentMcpUrl string = incidentMcp.properties.configuration.ingress.fqdn
output oncallApiUrl string = oncallApi.properties.configuration.ingress.fqdn
