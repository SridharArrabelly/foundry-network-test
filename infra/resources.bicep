targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string

@description('Resource name prefix (lowercase, no special chars)')
param prefix string

@description('Your public IP to allow portal/API access (leave empty for fully private)')
param allowedIpAddress string = ''

@description('Admin username for the jumpbox VM')
param vmAdminUsername string = 'azureadmin'

@secure()
@description('Admin password for the jumpbox VM')
param vmAdminPassword string

// =====================================================================
// 1. Network (VNet, subnets, NAT Gateway)
// =====================================================================

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    location: location
    prefix: prefix
  }
}

// =====================================================================
// 2. BYO agent dependencies (Cosmos, Storage, Search)
//    All three are required by the project capabilityHost (Standard Agent).
// =====================================================================

module aiSearch 'modules/ai-search.bicep' = {
  name: 'deploy-ai-search'
  params: {
    location: location
    prefix: prefix
    allowedIpAddress: allowedIpAddress
  }
}

module cosmos 'modules/cosmos.bicep' = {
  name: 'deploy-cosmos'
  params: {
    location: location
    prefix: prefix
  }
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    prefix: prefix
  }
}

// =====================================================================
// 3. Foundry account + Managed VNet (project comes later in step 5)
// =====================================================================

module foundryAccount 'modules/ai-foundry-account.bicep' = {
  name: 'deploy-foundry-account'
  params: {
    location: location
    prefix: prefix
    allowedIpAddress: allowedIpAddress
  }
}

// =====================================================================
// 4. Private Endpoints + DNS (Foundry, Search, Cosmos, Storage)
//    Must exist before the project + capabilityHost in step 5/7 so the
//    agent runtime can reach the BYO resources over the managed VNet.
// =====================================================================

module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'deploy-private-endpoints'
  params: {
    location: location
    prefix: prefix
    peSubnetId: network.outputs.peSubnetId
    vnetId: network.outputs.vnetId
    aiFoundryId: foundryAccount.outputs.aiFoundryId
    searchId: aiSearch.outputs.searchId
    cosmosId: cosmos.outputs.cosmosId
    storageId: storage.outputs.storageId
  }
}

// =====================================================================
// 5. Foundry project + model deployments + BYO project connections
// =====================================================================

module foundryProject 'modules/ai-foundry-project.bicep' = {
  name: 'deploy-foundry-project'
  params: {
    location: location
    prefix: prefix
    accountName: foundryAccount.outputs.aiFoundryName
    searchName: aiSearch.outputs.searchName
    searchId: aiSearch.outputs.searchId
    searchLocation: location
    cosmosName: cosmos.outputs.cosmosName
    cosmosId: cosmos.outputs.cosmosId
    cosmosLocation: location
    cosmosDocumentEndpoint: cosmos.outputs.cosmosDocumentEndpoint
    storageName: storage.outputs.storageName
    storageId: storage.outputs.storageId
    storageLocation: location
    storageBlobEndpoint: storage.outputs.storageBlobEndpoint
  }
  dependsOn: [
    privateEndpoints
  ]
}

// =====================================================================
// 6. Pre-caphost RBAC (project MI on Cosmos, Storage, Search)
// =====================================================================

module preCaphostRoles 'modules/byo-role-assignments.bicep' = {
  name: 'deploy-pre-caphost-roles'
  params: {
    projectPrincipalId: foundryProject.outputs.projectPrincipalId
    cosmosName: cosmos.outputs.cosmosName
    storageName: storage.outputs.storageName
    searchName: aiSearch.outputs.searchName
  }
}

// =====================================================================
// 7. Capability host — the binding that makes the agent runtime work
// =====================================================================

module capabilityHost 'modules/capability-host.bicep' = {
  name: 'deploy-capability-host'
  params: {
    accountName: foundryAccount.outputs.aiFoundryName
    projectName: foundryProject.outputs.projectName
    cosmosDBConnection: foundryProject.outputs.cosmosConnectionName
    azureStorageConnection: foundryProject.outputs.storageConnectionName
    aiSearchConnection: foundryProject.outputs.searchConnectionName
  }
  dependsOn: [
    preCaphostRoles
  ]
}

// =====================================================================
// 8. Post-caphost RBAC (Storage Blob Data Owner + Cosmos SQL role)
//    Scoped using the formatted project workspace ID.
// =====================================================================

module formatWorkspaceId 'modules/format-workspace-id.bicep' = {
  name: 'deploy-format-workspace-id'
  params: {
    projectWorkspaceId: foundryProject.outputs.projectWorkspaceId
  }
}

module postCaphostRoles 'modules/post-caphost-role-assignments.bicep' = {
  name: 'deploy-post-caphost-roles'
  params: {
    projectPrincipalId: foundryProject.outputs.projectPrincipalId
    storageName: storage.outputs.storageName
    cosmosName: cosmos.outputs.cosmosName
    projectWorkspaceIdGuid: formatWorkspaceId.outputs.projectWorkspaceIdGuid
  }
  dependsOn: [
    capabilityHost
  ]
}

// =====================================================================
// 9. Existing role assignments (account MI + Jumpbox MI → Search/Foundry)
// =====================================================================

module roleAssignments 'modules/role-assignments.bicep' = {
  name: 'deploy-role-assignments'
  params: {
    aiFoundryPrincipalId: foundryAccount.outputs.aiFoundryPrincipalId
    aiFoundryProjectPrincipalId: foundryProject.outputs.projectPrincipalId
    aiFoundryId: foundryAccount.outputs.aiFoundryId
    searchId: aiSearch.outputs.searchId
    jumpboxPrincipalId: jumpbox.outputs.vmPrincipalId
  }
}

// =====================================================================
// 10. Jumpbox VM + Bastion
// =====================================================================

module jumpbox 'modules/jumpbox.bicep' = {
  name: 'deploy-jumpbox'
  params: {
    location: location
    prefix: prefix
    vmSubnetId: network.outputs.vmSubnetId
    bastionSubnetId: network.outputs.bastionSubnetId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
  }
}

// =====================================================================
// Outputs
// =====================================================================

output vnetId string = network.outputs.vnetId
output aiFoundryName string = foundryAccount.outputs.aiFoundryName
output aiFoundryEndpoint string = foundryAccount.outputs.aiFoundryEndpoint
output aiFoundryProjectName string = foundryProject.outputs.projectName
output aiSearchName string = aiSearch.outputs.searchName
output aiSearchEndpoint string = aiSearch.outputs.searchEndpoint
output cosmosName string = cosmos.outputs.cosmosName
output storageName string = storage.outputs.storageName
output jumpboxVmName string = jumpbox.outputs.vmName
output bastionName string = jumpbox.outputs.bastionName
