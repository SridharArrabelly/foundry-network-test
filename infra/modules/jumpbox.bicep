@description('Azure region for deployment')
param location string

@description('Resource name prefix')
param prefix string

@description('Subnet ID for the VM')
param vmSubnetId string

@description('Subnet ID for Azure Bastion')
param bastionSubnetId string

@description('Admin username for the VM')
param adminUsername string

@secure()
@description('Admin password for the VM')
param adminPassword string

// --- Public IP for Bastion ---

resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: 'pip-${prefix}-bastion'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// --- Azure Bastion ---

resource bastion 'Microsoft.Network/bastionHosts@2024-07-01' = {
  name: 'bas-${prefix}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// --- Network Interface for VM ---

resource vmNic 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: 'nic-${prefix}-vm'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vmSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// --- Windows VM ---

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${prefix}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    osProfile: {
      computerName: 'vm${prefix}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}

output vmName string = vm.name
output bastionName string = bastion.name
