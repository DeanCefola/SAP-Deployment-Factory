

**Deployment Prerequisites**
============================
- 1 Virtual Network
- 1 or more subnets
- 1 monitoring storage account
- 1 Azure Backup Recovery Services Vault
    



**Prepare Templates for your YOURSUBSCRIPTION **
===========================================
-  Update PARAMETER: with your subscription name(s)

-  "Subscription": {
      "type": "string",
      "allowedValues": [
        "YOURSUBSCRIPTION"       
      ],
      "defaultValue": "YOURSUBSCRIPTION"
    },

-  Update VARIABLES: (YOURSUBSCRIPTION)
SUBSCRIPTION_ENV:
    - YOURSUBSCRIPTION       - Title: Must match Parameter:(subscitpion)
    - ID:                    - Enter Subscription ID
    - timeZone:              - Enter Time Zone for your Azure SAP Environment 
    - SapBitsURI:            - Provide the URL to the installation media (https://ENTER_YOUR_URI_TO_SAP_FILES.blob.core.windows.net/  MUST HAVE '/' at the end)
    - SAP_RGName:            - Azure Resource Group this deployment will target 
    - Backup_RGName:         - Azure Resource Group where the Azure Backup Recovery Services Vault is located 
    - Backup_VaultName:      - Name of the Azure Backup Recovery Services Vault
    - ASR_RGName:            - Azure Resource Group where the Azure Site Recovery Vault is located 
    - vNET_ID:               - ID of the Virtual Network for this deployment 
    - vNET_Subnets_Web:      - ID of the Subnet within the VNET_ID Virtual Network for the Web Dispatcher VMs
    - vNET_Subnets_ASCS:     - ID of the Subnet within the VNET_ID Virtual Network for the  ASCS VMs
    - vNET_Subnets_App:      - ID of the Subnet within the VNET_ID Virtual Network for the  App Servers
    - vNET_Subnets_Database: - ID of the Subnet within the VNET_ID Virtual Network for the  Database Servers
    - vNET_Subnets_Mgmt:     - ID of the Subnet within the VNET_ID Virtual Network for the  management network
    - vNET_Subnets_Fiori:    - ID of the Subnet within the VNET_ID Virtual Network for the  Fiori servers
    - vNET_Subnets_SolMan:   - ID of the Subnet within the VNET_ID Virtual Network for the  SolMan servers





**Azure SAP Offering Overview**
================================
- *Microsoft documentation for SAP running in Azure:*
-----------------------------------------------------
- https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/deployment-guide?toc=%2Fazure%2Fvirtual-machines%2Fwindows%2Ftoc.json
- § SAP Note 1928533, which has:
-    □ List of Azure VM sizes that are supported for the deployment of SAP software
-    □ Important capacity information for Azure VM sizes
-    □ Supported SAP software, and operating system (OS) and database combinations
-    □ Required SAP kernel version for Windows and Linux on Microsoft Azure
- § SAP Note 2015553 lists prerequisites for SAP-supported SAP software deployments in Azure.
- § SAP Note 2178632 has detailed information about all monitoring metrics reported for SAP in Azure.
- § SAP Note 1409604 has the required SAP Host Agent version for Windows in Azure.
- § SAP Note 2191498 has the required SAP Host Agent version for Linux in Azure.
- § SAP Note 2243692 has information about SAP licensing on Linux in Azure.
- § SAP Note 1984787 has general information about SUSE Linux Enterprise Server 12.
- § SAP Note 2002167 has general information about Red Hat Enterprise Linux 7.x.
- § SAP Note 1999351 has additional troubleshooting information for the Azure Enhanced Monitoring Extension for SAP.
- § SAP Note 1597355 has general information about swap-space for Linux.



*High availability for SAP NetWeaver on Azure VMs on SUSE Linux Enterprise Server for SAP applications:*
-------------------------------------------------------------------------------------------------------
- https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse



**Deployment Perameters**   
=========================
- adminPassword:      - local admin password
- Subscription:       - Name of your Subscription
- SAPSystemId:        - ID Of your SAP deployment (3 Charectors long)
- Environment:        - SAP Environment Name (Sandbox, Dev, QA, Perf, Prod)
- hanaNumber:         - SAP Hana Database Number
- Compliance:         - Backup Policy Compliance (SOX, HIPPA, PCI, Prod Basic, Non-Prod Basic)
- OperatingSystem:    - Windows Server 2016, SLES 12 SP3, RHEL 7.4 
- Authentication:     - Password or SSH (Windows only supports passwords)
- DataBaseSize:       - See section below on SAP VMs (Demo, Small, Medium, Large, XLarge, HLI)
- AppServerCount:     - number of App Servers desired in deployment (Up to 100)
- WebDispatcherCount: - number of Web Dispatchers desired in deployment (Up to 4)
- FIORICount:         - number of Fiori Servers desired in deployment (Up to 2)
- SolManCount:        - number of SolMan Servers desired in deployment (Up to 2)
- NfsServerCount:     - number of NFS Servers desired in deployment (Up to 8)



**Deployment Variables**
========================

- SUBSCRIPTION_ENV:
    - YOURSUBSCRIPTION       - Title:
    - ID:                    - Enter Subscription ID
    - timeZone:              - Enter Time Zone for your Azure SAP Environment 
    - SapBitsURI:            - Installation media for SAP HANA should be downloaded and place in the SapBits folder, Provide the URL to the installation media
    - SAP_RGName:            - Azure Resource Group this deployment will target 
    - Backup_RGName:         - Azure Resource Group where the Azure Backup Recovery Services Vault is located 
    - Backup_VaultName:      - Name of the Azure Backup Recovery Services Vault
    - ASR_RGName:            - Azure Resource Group where the Azure Site Recovery Vault is located 
    - vNET_ID:               - ID of the Virtual Network for this deployment 
    - vNET_Subnets_Web:      - ID of the Subnet within the VNET_ID Virtual Network for the Web Dispatcher VMs
    - vNET_Subnets_ASCS:     - ID of the Subnet within the VNET_ID Virtual Network for the  ASCS VMs
    - vNET_Subnets_App:      - ID of the Subnet within the VNET_ID Virtual Network for the  App Servers
    - vNET_Subnets_Database: - ID of the Subnet within the VNET_ID Virtual Network for the  Database Servers
    - vNET_Subnets_Mgmt:     - ID of the Subnet within the VNET_ID Virtual Network for the  management network
    - vNET_Subnets_Fiori:    - ID of the Subnet within the VNET_ID Virtual Network for the  Fiori servers
    - vNET_Subnets_SolMan:   - ID of the Subnet within the VNET_ID Virtual Network for the  SolMan servers

- SAP_ENV: 
    - Environment Title:
    - Name:          - Name of the SAP Environment (Sandbox, Dev, QA, Perf, Prod)
    - DR:			   - Enable Azure Site Recovery (no, yes)
    - Database:      - number of Database VMs (1, 2)
    - ASCS:          - number of ASCS (0, 1, 2)
    - WebDispatcher: - number of servers pulled from parameter input
    - AppServer:     - number of servers pulled from parameter input
    - Fiori:         - number of servers pulled from parameter input
    - SolMan:        - number of servers pulled from parameter input
    - NFS:           - number of servers pulled from parameter input

- ILB_INFO:
    - ILB Title: 
    - Name:                     - Name of load balancer
    - frontendIPConfigurations: - 1 Internal IP Address per ILB
    - backendAddressPools:      - 1 pool per ILB
    - loadBalancingRules:       - Standard Internal Load Balancer HA PORTS        
    - probes:                   - 59999 default probe port
    - inboundNatRules:		  - N/A
    - inboundNatPools:		  - N/A        

- SSH: 
    - sshKeyPath: - Path to Key file
    - sshKeyData: - ssh key    

- TAGS:
    - SAP_Application: - SAP System ID from Parameters Input
    - SAP_Environment: - SAP Environment from Parameters Input
    - Organization:    - Name of the Resource Group you deployed to
    - UserName:		   - User Name (Static Value)
    - Email:		   - Email address of User
    - Application:	   - SAP
    - GLAccount:	   - Account for chargeback / showback    

- TEMPLATES: 
    - Database:		 - Link to Nested Templates
    - AppServer:	 - Link to Nested Templates
    - ASCS:			 - Link to Nested Templates
    - Fiori:		 - Link to Nested Templates
    - WebDispatcher: - Link to Nested Templates
    - SolMan:		 - Link to Nested Templates
    - NFSServer:	 - Link to Nested Templates
    - Backup:		 - Link to Nested Templates
    - ASR:			 - Link to Nested Templates

- VM_IMAGES:
    - Windows: - Windows Server 2016 DataCenter
    - SLES:    - SUSE 12 Sp3 
    - RHEL:    - RHEL 7.4

- VM_SIZES: (All sizes require Accellerated Networking and Certification for use with SAP)
    - Demo: 
    - Small: 
    - Medium: 
    - Large: 
    - X-Large: 
    - HLI: ( when HLI is selected, no Database server will be deployed.  You must provision the HLI Database server first)

- VM_EXTENSIONS: 
    - Windows: - (Extension to configure the Disks inside the OS)
    - Linux:   - (Extension to configure the Disks inside the OS)
    - SAP:     - (Extension to configure installation of SAP Hana)

- adminUserName:       - local admin user name

- sidlower:            - force SAP System ID to be in all lowercase letters 

- Monitor_Storage_url: - http link to storage account for VM Monitoring i.e - 'eccmonitord47kfby.blob.core.windows.net'



**Deployment Sizing Charts**
============================
- SAP VMs  (https://launchpad.support.sap.com/#/notes/1928533)
- SAP Systems are deployed based on T-Shirt sizing 
- The following table outlines the deployment topology characteristics for each supported t-shirt size:
-----------------------------------------------------------------------------------
| T-Shirt Size |   DB VM Size     | Cores | Memory  | Data Disks  |  SAPS Score  |
| ------------ | ---------------- | ----- | ------- | ----------- | ------------ |
| Demo	       | Standard_F4s_v2  |   4   |  8 GB   | 8x  1023 GB |   2,000 SAPS |
| Small	       | Standard_E16_v3  |  16   | 128 GB  | 8x  1023 GB |  25,000 SAPS |
| Medium       | Standard_E32s_v3 |  32   | 256 GB  | 16x 1023 GB |  48,750 SAPS |
| Large        | Standard_E64s_v3 |  64   | 432 GB  | 16x 1023 GB |  78,620 SAPS |
| X-Large      | Standard_M128ms  | 128   | 3.8 TB  | 32x 1023 GB | 137,520 SAPS |
| HLI          | HLI              | HLI   | HLI     | HLI         | HLI          |
-----------------------------------------------------------------------------------

HANA Systems Info:
------------------
- The template current deploys HANA on a one of the machines listed in the table below with the noted disk configuration. 
- The deployment takes advantage of Managed Disks, 
- for more information on Managed Disks or the sizes of the noted disks can be found on this page.
------------------------------------------------------------------------------------------------------------------------------------
| Machine Size |  RAM    | /root          |   Data           | Log Disks       | /hana/shared    | /usr/sap      | hana/backup     |
| ------------ | ------- | -------------- | ---------------- |---------------- | --------------- | ------------- | ----------------|
| Demo         |   8 GB  |  1 x P4 (32GB) |  1 x P15 (256GB) | 1 x P10 (128GB) | 1 x P10 (128GB) | 1 x P6 (64GB) | 1 x P15 (256GB) |
| Small        | 128 GB  |  1 x P4 (32GB) |  2 x P15 (256GB) | 1 x P20 (512GB) | 1 x P20 (512GB) | 1 x P6 (64GB) | 1 x P15 (256GB) |
| Medium       | 256 GB  |  1 x P4 (32GB) |  2 x P30 (1TB)   | 2 x P20 (512GB) | 1 x P30 (1TB)   | 1 x P6 (64GB) | 2 x P30 (1TB)   |
| Large        | 432 GB  |  1 x P4 (32GB) |  3 x P30 (1TB)   | 2 x P20 (512GB) | 1 x P30 (1TB)   | 1 x P6 (64GB) | 2 x P30 (1TB)   |
| X-Large      | 3.8 TB  |  1 x P4 (32GB) |  5 x P30 (1TB)   | 2 x P20 (512GB) | 1 x P30 (1TB)   | 1 x P6 (64GB) | 2 x P40 (2TB)   |
| HLI          | HLI     |  HLI           |  HLI             | HLI             | HLI             | HLI           | HLI             |
------------------------------------------------------------------------------------------------------------------------------------
