// Purpose: an overview of the underlying infrastructure, for reading rather
// than for deploying.
//
// Exported from the resource group and then edited by hand, mainly to strip
// identifiers. Do not treat it as a deployment template and do not assume it
// would apply cleanly: it has not been tested as one, and the hand edits mean
// it is a description of the environment rather than a faithful record of it.
// The portal artefacts it still carries (generated resource names, a disk GUID)
// are from the export and are left alone.
//
// Redactions follow the same convention as the rest of the repo: the public IP,
// the admin source address, and the DNS label / FQDN are replaced with
// <PLACEHOLDER> values. The SSH key below is a public key and is safe to publish
// by design. Private addresses (172.16.0.0/16) are RFC 1918 and are kept, since
// the topology is part of what this file is here to show.
//
// One open discrepancy: this file says Standard_B2as_v2 and shows Spot priority,
// while docs/01 says Standard_B2als_v2 and does not mention Spot. Unresolved,
// and worth settling against the actual resource group if it still exists.


@secure()
param extensions_enablevmAccess_username string

@secure()
param extensions_enablevmAccess_password string

@secure()
param extensions_enablevmAccess_ssh_key string

@secure()
param extensions_enablevmAccess_reset_ssh string

@secure()
param extensions_enablevmAccess_remove_user string

@secure()
param extensions_enablevmAccess_expiration string
param virtualMachines_vm_grafana_lab_name string = 'vm-grafana-lab'
param networkInterfaces_vm_grafana_lab316_name string = 'vm-grafana-lab316'
param publicIPAddresses_vm_grafana_lab_ip_name string = 'vm-grafana-lab-ip'
param virtualNetworks_vnet_swedencentral_1_name string = 'vnet-swedencentral-1'
param networkSecurityGroups_vm_grafana_lab_nsg_name string = 'vm-grafana-lab-nsg'

resource networkSecurityGroups_vm_grafana_lab_nsg_name_resource 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: networkSecurityGroups_vm_grafana_lab_nsg_name
  location: 'swedencentral'
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS'
        id: networkSecurityGroups_vm_grafana_lab_nsg_name_Allow_HTTPS.id
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '172.16.0.4'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'Allow-HTTP'
        id: networkSecurityGroups_vm_grafana_lab_nsg_name_Allow_HTTP.id
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '172.16.0.4'
          access: 'Allow'
          priority: 210
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'Allow-SSH-Admin'
        id: networkSecurityGroups_vm_grafana_lab_nsg_name_Allow_SSH_Admin.id
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '<ADMIN_IP>'
          destinationAddressPrefix: '172.16.0.4'
          access: 'Allow'
          priority: 220
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

resource publicIPAddresses_vm_grafana_lab_ip_name_resource 'Microsoft.Network/publicIPAddresses@2025-07-01' = {
  name: publicIPAddresses_vm_grafana_lab_ip_name
  location: 'swedencentral'
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    ipAddress: '<PUBLIC_IP>'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: '<DNS_LABEL>'
      fqdn: '<DNS_LABEL>.swedencentral.cloudapp.azure.com'
    }
    ipTags: []
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

resource virtualNetworks_vnet_swedencentral_1_name_resource 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: virtualNetworks_vnet_swedencentral_1_name
  location: 'swedencentral'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'snet-swedencentral-1'
        id: virtualNetworks_vnet_swedencentral_1_name_snet_swedencentral_1.id
        properties: {
          addressPrefixes: [
            '172.16.0.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource virtualMachines_vm_grafana_lab_name_resource 'Microsoft.Compute/virtualMachines@2025-11-01' = {
  name: virtualMachines_vm_grafana_lab_name
  location: 'swedencentral'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2as_v2'
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-22_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: '${virtualMachines_vm_grafana_lab_name}_OsDisk_1_f33764740b0a49b39cfdc3f1b065e8f9'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          id: resourceId(
            'Microsoft.Compute/disks',
            '${virtualMachines_vm_grafana_lab_name}_OsDisk_1_f33764740b0a49b39cfdc3f1b065e8f9'
          )
        }
        deleteOption: 'Delete'
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachines_vm_grafana_lab_name
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/azureuser/.ssh/authorized_keys'
              keyData: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBs5Qf1HWm6xi64ZIeRBJpyR4Wq/qwymyV1IRyOgaR+D'
            }
          ]
        }
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
        enableVMAgentPlatformUpdates: true
      }
      secrets: []
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
      adminUsername: 'azureuser'
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: false
      }
      securityType: 'TrustedLaunch'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_vm_grafana_lab316_name_resource.id
          properties: {
            deleteOption: 'Detach'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    priority: 'Spot'
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: json('40')
    }
  }
}

resource virtualMachines_vm_grafana_lab_name_enablevmAccess 'Microsoft.Compute/virtualMachines/extensions@2025-11-01' = {
  parent: virtualMachines_vm_grafana_lab_name_resource
  name: 'enablevmAccess'
  location: 'swedencentral'
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.OSTCExtensions'
    type: 'VMAccessForLinux'
    typeHandlerVersion: '1.5'
    settings: {}
    protectedSettings: {
      username: extensions_enablevmAccess_username
      password: extensions_enablevmAccess_password
      ssh_key: extensions_enablevmAccess_ssh_key
      reset_ssh: extensions_enablevmAccess_reset_ssh
      remove_user: extensions_enablevmAccess_remove_user
      expiration: extensions_enablevmAccess_expiration
    }
  }
}

resource networkSecurityGroups_vm_grafana_lab_nsg_name_Allow_HTTP 'Microsoft.Network/networkSecurityGroups/securityRules@2025-07-01' = {
  name: '${networkSecurityGroups_vm_grafana_lab_nsg_name}/Allow-HTTP'
  properties: {
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '80'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '172.16.0.4'
    access: 'Allow'
    priority: 210
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    networkSecurityGroups_vm_grafana_lab_nsg_name_resource
  ]
}

resource networkSecurityGroups_vm_grafana_lab_nsg_name_Allow_HTTPS 'Microsoft.Network/networkSecurityGroups/securityRules@2025-07-01' = {
  name: '${networkSecurityGroups_vm_grafana_lab_nsg_name}/Allow-HTTPS'
  properties: {
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '172.16.0.4'
    access: 'Allow'
    priority: 200
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    networkSecurityGroups_vm_grafana_lab_nsg_name_resource
  ]
}

resource networkSecurityGroups_vm_grafana_lab_nsg_name_Allow_SSH_Admin 'Microsoft.Network/networkSecurityGroups/securityRules@2025-07-01' = {
  name: '${networkSecurityGroups_vm_grafana_lab_nsg_name}/Allow-SSH-Admin'
  properties: {
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefix: '<ADMIN_IP>'
    destinationAddressPrefix: '172.16.0.4'
    access: 'Allow'
    priority: 220
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    networkSecurityGroups_vm_grafana_lab_nsg_name_resource
  ]
}

resource virtualNetworks_vnet_swedencentral_1_name_snet_swedencentral_1 'Microsoft.Network/virtualNetworks/subnets@2025-07-01' = {
  name: '${virtualNetworks_vnet_swedencentral_1_name}/snet-swedencentral-1'
  properties: {
    addressPrefixes: [
      '172.16.0.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_swedencentral_1_name_resource
  ]
}

resource networkInterfaces_vm_grafana_lab316_name_resource 'Microsoft.Network/networkInterfaces@2025-07-01' = {
  name: networkInterfaces_vm_grafana_lab316_name
  location: 'swedencentral'
  kind: 'Regular'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        id: '${networkInterfaces_vm_grafana_lab316_name_resource.id}/ipConfigurations/ipconfig1'
        properties: {
          privateIPAddress: '172.16.0.4'
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_vm_grafana_lab_ip_name_resource.id
            properties: {
              deleteOption: 'Detach'
            }
          }
          subnet: {
            id: virtualNetworks_vnet_swedencentral_1_name_snet_swedencentral_1.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: networkSecurityGroups_vm_grafana_lab_nsg_name_resource.id
    }
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}
