# VMware PowerCLI Scripts

This repository contains standalone PowerShell and VMware PowerCLI scripts for
administering vCenter, ESXi hosts, virtual machines, and Windows guest operating
systems. The scripts range from small command examples to larger deployment and
domain-migration utilities.

## Script categories

| Category | Location | What the scripts cover |
| --- | --- | --- |
| PowerCLI setup and connectivity | [`PowerCLI/`](PowerCLI/) | Configure PowerCLI defaults and connect to one or more vCenter servers. |
| Performance | [`Performance/`](Performance/) | Report historical CPU and memory utilization for clusters, hosts, and VMs. |
| VM provisioning | [`VM/Provisioning/`](VM/Provisioning/) | Deploy VMs, deploy and configure Windows VMs, and create templates and OS customization specifications. |
| VM inventory | [`VM/Inventory/`](VM/Inventory/) | Report VM configuration, guest operating systems, power state, hardware versions, and guest disk capacity. |
| VM guest administration | [`VM/Guest/`](VM/Guest/) | Join guests to a domain, copy files, run remote installers, extend disks, and inspect Windows software and hotfixes. |
| VM operations | [`VM/Operations/`](VM/Operations/) | Move VMs, update notes, and inspect or unmount ISO images. |
| Datastores | [`Datastores/`](Datastores/) | Report datastore capacity, free space, used space, and VMFS extent information. |
| Networking | [`Networking/`](Networking/) | Report IP addresses, FQDNs, APIPA addresses, E1000 adapters, and VM network details; map Windows guest NICs to vSphere adapters and change guest network settings. |
| Snapshots | [`Snapshots/`](Snapshots/) | Create snapshots, report snapshots older than 30 days, and remove old snapshots. |
| VMware Tools | [`VMware_Tools/`](VMware_Tools/) | Report VMware Tools status and update status, configure upgrade policy, and update Tools on powered-on VMs. |
| vCenter events | [`vCenter/Events/`](vCenter/Events/) | Retrieve vSphere events and report VM creation, deployment, and migration history. |
| vCenter sessions | [`vCenter/Sessions/`](vCenter/Sessions/) | Report active or idle vCenter sessions and optionally disconnect idle sessions. |
| ESXi host operations | [`vCenter/Host/`](vCenter/Host/) | Perform host-level maintenance operations through vCenter. |
| vCenter clusters | [`vCenter/Cluster/`](vCenter/Cluster/) | Create clusters and configure High Availability (HA), Distributed Resource Scheduler (DRS), and Distributed Power Management (DPM). |
| vCenter inventory | [`vCenter/Inventory/`](vCenter/Inventory/) | Create datacenters and create, export, or import folder structures and VM folder locations. |
| vCenter permissions and licensing | [`vCenter/Permissions/`](vCenter/Permissions/), [`vCenter/License/`](vCenter/License/) | Create and assign roles, export or import permissions, and retrieve or assign license keys. |
| vCenter installation and migration helpers | [`vCenter/Install/`](vCenter/Install/), [`vCenter/vCenterUtility.ps1`](vCenter/vCenterUtility.ps1) | Generate and run VCSA CLI deployments, provide current vSphere Client and Lifecycle Manager guidance, and assist with Windows guest domain migrations. |

## Notable scripts

- [`ConfigPowerCLI.ps1`](PowerCLI/ConfigPowerCLI.ps1) and
  [`ConnectVIServer.ps1`](PowerCLI/ConnectVIServer.ps1) configure and establish PowerCLI
  sessions.
- [`DeployWindowsVMs.ps1`](VM/Provisioning/DeployWindowsVMs.ps1) deploys Windows Server VMs from
  a template, applies compute, storage, and network settings, and performs guest
  configuration.
- [`GetVMinfo.ps1`](VM/Inventory/GetVMinfo.ps1) returns consolidated VM inventory information,
  including guest, host, cluster, datastore, network, and VMware Tools details.
- [`GetVIEventPlus.ps1`](vCenter/Events/GetVIEventPlus.ps1) provides extended vCenter event
  retrieval.
- [`GetViSession.ps1`](vCenter/Sessions/GetViSession.ps1) and
  [`GetViIdleSessions.ps1`](vCenter/Sessions/GetViIdleSessions.ps1) report sessions and identify or
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

Some short scripts are examples intended to be customized rather than
parameterized tools.
