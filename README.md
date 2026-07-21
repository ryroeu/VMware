# VMware PowerCLI Scripts

This repository contains standalone PowerShell and VMware PowerCLI scripts for
administering vCenter, ESXi hosts, virtual machines, and Windows guest operating
systems. The scripts range from small command examples to larger deployment and
domain-migration utilities.

## Script categories

| Category | Location | What the scripts cover |
| --- | --- | --- |
| PowerCLI setup and connectivity | Repository root | Configure PowerCLI defaults and connect to one or more vCenter servers. |
| VM provisioning and lifecycle | Repository root | Deploy VMs, deploy and configure Windows VMs, create templates and OS customization specifications, move VMs, join guests to a domain, and update VM notes. |
| Inventory and reporting | Repository root | Report on VM, host, and cluster CPU and memory; VM hardware versions, operating systems, power state, deployment events, sessions, disk capacity, partitions, SQL versions, and installed Windows hotfixes. |
| Guest and host operations | Repository root | Copy files to guests, run remote installers, extend disks, inspect mounted ISO images, and clear an ESXi host's system event log. |
| Datastores | [`datastore/`](datastore/) | Report datastore capacity, free space, used space, and VMFS extent information. |
| Networking | [`network/`](network/) | Report IP addresses, FQDNs, APIPA addresses, E1000 adapters, and VM network details; map Windows guest NICs to vSphere adapters and change guest network settings. |
| Snapshots | [`snapshots/`](snapshots/) | Create snapshots, report snapshots older than 30 days, and remove old snapshots. |
| VMware Tools | [`vmware_tools/`](vmware_tools/) | Report VMware Tools status and update status, configure upgrade policy, and update Tools on powered-on VMs. |
| vCenter clusters | [`vCenter/cluster/`](vCenter/cluster/) | Create clusters and configure High Availability (HA), Distributed Resource Scheduler (DRS), and Distributed Power Management (DPM). |
| vCenter inventory | [`vCenter/inventory/`](vCenter/inventory/) | Create datacenters and create, export, or import folder structures and VM folder locations. |
| vCenter permissions and licensing | [`vCenter/permissions/`](vCenter/permissions/), [`vCenter/license/`](vCenter/license/) | Create and assign roles, export or import permissions, and retrieve or assign license keys. |
| vCenter installation and migration helpers | [`vCenter/install/`](vCenter/install/), [`vCenter/vCenterUtility.ps1`](vCenter/vCenterUtility.ps1) | Generate and run VCSA CLI deployments, provide current vSphere Client and Lifecycle Manager guidance, and assist with Windows guest domain migrations. |

## Notable top-level scripts

- [`ConfigPowerCLI.ps1`](ConfigPowerCLI.ps1) and
  [`ConnectVIServer.ps1`](ConnectVIServer.ps1) configure and establish PowerCLI
  sessions.
- [`DeployWindowsVMs.ps1`](DeployWindowsVMs.ps1) deploys Windows Server VMs from
  a template, applies compute, storage, and network settings, and performs guest
  configuration.
- [`GetVMinfo.ps1`](GetVMinfo.ps1) returns consolidated VM inventory information,
  including guest, host, cluster, datastore, network, and VMware Tools details.
- [`GetVIEventPlus.ps1`](GetVIEventPlus.ps1) provides extended vCenter event
  retrieval.
- [`GetViSession.ps1`](GetViSession.ps1) and
  [`GetViIdleSessions.ps1`](GetViIdleSessions.ps1) report sessions and identify or
  disconnect idle sessions.

## Requirements

- Windows PowerShell or PowerShell, depending on the script and target system
- VMware PowerCLI or VCF PowerCLI with the required vSphere cmdlets
- Network access and appropriate permissions for the target vCenter, ESXi host,
  and guest operating systems
- VMware Tools running in guests for scripts that use guest information or
  `Invoke-VMScript`

## Usage and safety

These are standalone administrative scripts rather than a single PowerShell
module. Read the selected script and replace its sample server names, paths,
credentials, networks, datacenters, clusters, and other environment-specific
values before running it.

Some scripts make immediate infrastructure changes, including modifying cluster
settings, guest networking, permissions, licenses, snapshots, and VMware Tools.
A filename beginning with `Get` does not guarantee that a script is read-only.
Test changes in a non-production environment first, use an account with only the
permissions required for the task, and use `-WhatIf` where the script supports
it.

`ISOUnmount.ps1` is currently an empty placeholder. Other short scripts are
examples intended to be customized rather than parameterized tools.
