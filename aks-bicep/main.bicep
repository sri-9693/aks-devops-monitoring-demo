param location string = 'centralus'

param adminUsername string = 'azureuser'
param adminPassword string = 'Password@123'
param aksName string = 'my-aks-cluster'
param dnsPrefix string = 'myaksdns'

// Public IP (Standard SKU)
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: 'vm-public-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'aks-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

// Subnet (clean parent syntax)
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: 'subnet1'
  parent: vnet
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: 'aks-subnet'
  parent: vnet
  properties: {
    addressPrefix: '10.0.2.0/24'
  }
}

// Network Security Group (allow SSH)
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'vm-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'vm-nic'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'devops-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'devops-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-05-01' = {
  name: aksName
  location: location

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    dnsPrefix: dnsPrefix

    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 1
        vmSize: 'Standard_D2s_v3'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'System'

        vnetSubnetID: aksSubnet.id
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '10.100.0.0/16'
      dnsServiceIP: '10.100.0.10'
    }
  }
}
