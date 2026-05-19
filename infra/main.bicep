targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string

@description('Resource name prefix (lowercase, no special chars)')
param prefix string

// --- Network ---

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    location: location
    prefix: prefix
  }
}

// --- AI Foundry ---

module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'deploy-ai-foundry'
  params: {
    location: location
    prefix: prefix
  }
}

// --- AI Search ---

module aiSearch 'modules/ai-search.bicep' = {
  name: 'deploy-ai-search'
  params: {
    location: location
    prefix: prefix
  }
}

// --- Role Assignments (Foundry system MI → Search) ---

module roleAssignments 'modules/role-assignments.bicep' = {
  name: 'deploy-role-assignments'
  params: {
    aiFoundryPrincipalId: aiFoundry.outputs.aiFoundryPrincipalId
    searchId: aiSearch.outputs.searchId
  }
}

// --- Private Endpoints + DNS ---

module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'deploy-private-endpoints'
  params: {
    location: location
    prefix: prefix
    peSubnetId: network.outputs.peSubnetId
    vnetId: network.outputs.vnetId
    aiFoundryId: aiFoundry.outputs.aiFoundryId
    searchId: aiSearch.outputs.searchId
  }
}

// --- Outputs ---

output vnetId string = network.outputs.vnetId
output aiFoundryName string = aiFoundry.outputs.aiFoundryName
output aiSearchName string = aiSearch.outputs.searchName
