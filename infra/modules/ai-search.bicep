@description('Azure region for deployment')
param location string

@description('Resource name prefix')
param prefix string

@description('Your public IP address to allow portal/API access (leave empty to block all public access)')
param allowedIpAddress string = ''

var searchName = 'srch-${prefix}'

resource aiSearch 'Microsoft.Search/searchServices@2025-05-01' = {
  name: searchName
  location: location
  sku: {
    name: 'basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hostingMode: 'Default'
    publicNetworkAccess: empty(allowedIpAddress) ? 'disabled' : 'enabled'
    partitionCount: 1
    replicaCount: 1
    networkRuleSet: {
      ipRules: empty(allowedIpAddress) ? [] : [
        {
          value: allowedIpAddress
        }
      ]
      bypass: 'AzureServices'
    }
  }
}

output searchId string = aiSearch.id
output searchName string = aiSearch.name
