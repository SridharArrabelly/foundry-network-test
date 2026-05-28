@description('Azure region for deployment')
param location string

@description('Resource name prefix')
param prefix string

@description('Deploy NAT Gateway on the VM subnet. Only needed when a jumpbox lives in the subnet and needs outbound internet (pip install, GitHub).')
param deployNatGateway bool = true

var vnetName = 'vnet-${prefix}'
var peSubnetName = 'snet-${prefix}-pe'

// --- NAT Gateway for the VM subnet ---
// Default outbound access for VMs is being retired by Azure, so VMs without an
// explicit egress path lose internet access. Attach a NAT Gateway to the VM
// subnet so the jumpbox can reach the internet (pip install, GitHub, etc.)
// without exposing the VM via a public IP. Skipped when no jumpbox is deployed.

resource natPip 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (deployNatGateway) {
  name: 'pip-${prefix}-natgw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = if (deployNatGateway) {
  name: 'natgw-${prefix}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIPAddresses: [
      {
        id: natPip.id
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: peSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-${prefix}-vm'
        properties: {
          addressPrefix: '10.0.2.0/24'
          natGateway: deployNatGateway ? {
            id: natGateway.id
          } : null
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.3.0/26'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output peSubnetId string = vnet.properties.subnets[0].id
output vmSubnetId string = vnet.properties.subnets[1].id
output bastionSubnetId string = vnet.properties.subnets[2].id
