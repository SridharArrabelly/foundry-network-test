// Foundry account + managed VNet only. The project, model deployments, and
// project connections live in ai-foundry-project.bicep so PE+DNS can be
// created in between (project + capabilityHost provisioning needs the BYO
// resources reachable over the managed VNet via approved PEs).

@description('Azure region for deployment')
param location string

@description('Resource name prefix')
param prefix string

@description('Your public IP address to allow portal/API access (leave empty to block all public access)')
param allowedIpAddress string = ''

var accountName = 'ais-${prefix}'

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: accountName
  location: location
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: empty(allowedIpAddress) ? 'Disabled' : 'Enabled'
    allowProjectManagement: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: empty(allowedIpAddress) ? [] : [
        {
          value: allowedIpAddress
        }
      ]
    }
    // Managed VNet for the Foundry Agent runtime. Microsoft provisions and
    // manages a virtual network behind the scenes; agent + evaluation traffic
    // is isolated to this network. Outbound to BYO resources (Cosmos, Storage,
    // Search) is configured via approved outbound rules created automatically
    // when project connections are added (see ai-foundry-project.bicep).
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: ''
        useMicrosoftManagedNetwork: true
      }
    ]
  }
}

// Managed-network settings. AllowOnlyApprovedOutbound is the strictest mode:
// outbound traffic from the agent runtime is only permitted to explicitly
// approved targets (the project connections).
#disable-next-line BCP081
resource aiFoundryManagedNetwork 'Microsoft.CognitiveServices/accounts/managednetworks@2025-10-01-preview' = {
  parent: aiFoundry
  name: 'default'
  properties: {
    managedNetwork: {
      IsolationMode: 'AllowOnlyApprovedOutbound'
      managedNetworkKind: 'V2'
      provisionNetworkNow: true
    }
  }
}

// Allow the Foundry account MI to auto-approve managed private endpoints
// created in its managed VNet (outbound PEs to BYO Cosmos/Storage/Search).
// Built-in role: 'Azure AI Enterprise Network Connection Approver'.
resource networkConnectionApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(aiFoundry.id, 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea', resourceGroup().id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea')
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output aiFoundryId string = aiFoundry.id
output aiFoundryName string = aiFoundry.name
output aiFoundryEndpoint string = 'https://${accountName}.cognitiveservices.azure.com'
output aiFoundryPrincipalId string = aiFoundry.identity.principalId
