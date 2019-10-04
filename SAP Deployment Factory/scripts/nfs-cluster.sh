
#https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-nfs
#https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker

#############################
#    Create STONITH device  #
#############################
#
#   The STONITH device uses a Service Principal to authorize against Microsoft Azure. Follow these steps to create a Service Principal.
#   Go to https://portal.azure.com
#   Open the Azure Active Directory blade
#   Go to Properties and write down the Directory ID. This is the tenant ID.
#   Click App registrations
#   Click Add
#   Enter a Name, select Application Type "Web app/API", enter a sign-on URL (for example http://localhost) and click Create
#   The sign-on URL is not used and can be any valid URL
#   Select the new App and click Keys in the Settings tab
#   Enter a description for a new key, select "Never expires" and click Save
#   Write down the Value. It is used as the password for the Service Principal
#   Write down the Application ID. It is used as the username (login ID in the steps below) of the Service Principal
#   [1] Create a custom role for the fence agent
#   The Service Principal does not have permissions to access your Azure resources by default. You need to give the Service Principal permissions to start and stop (deallocate) all virtual machines of the cluster. If you did not already create the custom role, you can create it using PowerShell or Azure CLI
#   Use the following content for the input file. You need to adapt the content to your subscriptions that is, replace c276fc76-9cd4-44c9-99a7-4fd71546436e and e91d47c4-76f3-4271-a796-21b4ecfe3624 with the Ids of your subscription. If you only have one subscription, remove the second entry in AssignableScopes
#   <JSON>
 #   {
 #    "Name": "Linux Fence Agent Role",
 #    "Id": null,
 #    "IsCustom": true,
 #    "Description": "Allows to deallocate and start virtual machines",
 #    "Actions": [
 #      "Microsoft.Compute/*/read",
 #      "Microsoft.Compute/virtualMachines/deallocate/action",
 #      "Microsoft.Compute/virtualMachines/start/action"
 #    ],
 #    "NotActions": [
 #    ],
 #    "AssignableScopes": [
 #      "/subscriptions/c276fc76-9cd4-44c9-99a7-4fd71546436e",
 #      "/subscriptions/e91d47c4-76f3-4271-a796-21b4ecfe3624"
 #    ]
 #  }

  #  Assign the custom role to the Service Principal
  # Assign the custom role "Linux Fence Agent Role" that was created in the last chapter to the Service Principal. Do not use the Owner role anymore!
  # Go to https://portal.azure.com
  # Open the All resources blade
  # Select the virtual machine of the first cluster node
  # Click Access control (IAM)
  # Click Add
  # Select the role "Linux Fence Agent Role"
  # Enter the name of the application you created above
  # Click OK
  # Repeat the steps above for the second cluster node.

  
# replace the bold string with your subscription ID, resource group, tenant ID, service principal ID and password
sudo crm configure property stonith-timeout=900

sudo crm configure primitive rsc_st_azure stonith:fence_azure_arm \
params subscriptionId="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" resourceGroup="RGNAME" tenantId="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" login="ServicePrincipal ID" passwd="password"

###############################################
#    Create fence topology for SBD fencing    #
###############################################
sudo crm configure fencing_topology \
  stonith-sbd rsc_st_azure

############################################
#    Enable the use of a STONITH device    #
############################################
sudo crm configure property stonith-enabled=true

##############################
#         SBD fencing        #
##############################
sudo zypper update
sudo zypper remove lio-utils python-rtslib python-configshell targetcli
sudo zypper install targetcli-fb dbus-1-python
sudo systemctl enable targetcli
sudo systemctl start targetcli
# List all data disks with the following command
sudo ls -al /dev/disk/azure/scsi1/

# total 0
# drwxr-xr-x 2 root root  80 Mar 26 14:42 .
# drwxr-xr-x 3 root root 160 Mar 26 14:42 ..
# lrwxrwxrwx 1 root root  12 Mar 26 14:42 lun0 -> ../../../sdc
# lrwxrwxrwx 1 root root  12 Mar 26 14:42 lun1 -> ../../../sdd

# Then use the disk name to list the disk id
sudo ls -l /dev/disk/by-id/scsi-* | grep sdc

# lrwxrwxrwx 1 root root  9 Mar 26 14:42 /dev/disk/by-id/scsi-14d53465420202020a50923c92babda40974bef49ae8828f0 -> ../../sdc
# lrwxrwxrwx 1 root root  9 Mar 26 14:42 /dev/disk/by-id/scsi-360022480a50923c92babef49ae8828f0 -> ../../sdc

# Use the data disk that you attached for this cluster to create a new backstore
sudo targetcli backstores/block create cl1 /dev/disk/by-id/scsi-360022480a50923c92babef49ae8828f0

sudo targetcli iscsi/ create iqn.2006-04.cl1.local:cl1
sudo targetcli iscsi/iqn.2006-04.cl1.local:cl1/tpg1/luns/ create /backstores/block/cl1
sudo targetcli iscsi/iqn.2006-04.cl1.local:cl1/tpg1/acls/ create iqn.2006-04.prod-cl1-0.local:prod-cl1-0
sudo targetcli iscsi/iqn.2006-04.cl1.local:cl1/tpg1/acls/ create iqn.2006-04.prod-cl1-1.local:prod-cl1-1

# save the targetcli changes
sudo targetcli saveconfig


################################
#       Set up SBD device      #
################################
sudo systemctl enable iscsid
sudo systemctl enable iscsi
sudo systemctl enable sbd
sudo vi /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.2006-04.prod-cl1-0.local:prod-cl1-0
sudo vi /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.2006-04.prod-cl1-1.local:prod-cl1-1
sudo systemctl restart iscsid
sudo systemctl restart iscsi
sudo iscsiadm -m discovery --type=st --portal=10.0.0.17:3260

sudo iscsiadm -m node -T iqn.2006-04.cl1.local:cl1 --login --portal=10.0.0.17:3260
sudo iscsiadm -m node -p 10.0.0.17:3260 --op=update --name=node.startup --value=automatic
lsscsi

# [2:0:0:0]    disk    Msft     Virtual Disk     1.0   /dev/sda
# [3:0:1:0]    disk    Msft     Virtual Disk     1.0   /dev/sdb
# [5:0:0:0]    disk    Msft     Virtual Disk     1.0   /dev/sdc
# [5:0:0:1]    disk    Msft     Virtual Disk     1.0   /dev/sdd
# [6:0:0:0]    disk    LIO-ORG  cl1              4.0   /dev/sde
ls -l /dev/disk/by-id/scsi-* | grep sde

# lrwxrwxrwx 1 root root  9 Feb  7 12:39 /dev/disk/by-id/scsi-1LIO-ORG_cl1:3fe4da37-1a5a-4bb6-9a41-9a4df57770e4 -> ../../sde
# lrwxrwxrwx 1 root root  9 Feb  7 12:39 /dev/disk/by-id/scsi-360014053fe4da371a5a4bb69a419a4df -> ../../sde
# lrwxrwxrwx 1 root root  9 Feb  7 12:39 /dev/disk/by-id/scsi-SLIO-ORG_cl1_3fe4da37-1a5a-4bb6-9a41-9a4df57770e4 -> ../../sde

sudo sbd -d /dev/disk/by-id/scsi-360014053fe4da371a5a4bb69a419a4df -1 10 -4 20 create
sudo vi /etc/sysconfig/sbd
[...]
SBD_DEVICE="/dev/disk/by-id/scsi-360014053fe4da371a5a4bb69a419a4df"
[...]
SBD_PACEMAKER="yes"
[...]
SBD_STARTMODE="always"
echo softdog | sudo tee /etc/modules-load.d/softdog.conf
sudo modprobe -v softdog


##############################
#     Cluster installation   #
##############################
sudo zypper update
sudo ssh-keygen

# Enter file in which to save the key (/root/.ssh/id_rsa): -> Press ENTER
# Enter passphrase (empty for no passphrase): -> Press ENTER
# Enter same passphrase again: -> Press ENTER

# copy the public key
sudo cat /root/.ssh/id_rsa.pub
sudo ssh-keygen

# insert the public key you copied in the last step into the authorized keys file on the second server
sudo vi /root/.ssh/authorized_keys

# Enter file in which to save the key (/root/.ssh/id_rsa): -> Press ENTER
# Enter passphrase (empty for no passphrase): -> Press ENTER
# Enter same passphrase again: -> Press ENTER

# copy the public key   
sudo cat /root/.ssh/id_rsa.pub
# insert the public key you copied in the last step into the authorized keys file on the first server
sudo vi /root/.ssh/authorized_keys
sudo zypper install sle-ha-release fence-agents
sudo vi /etc/hosts
# IP address of the first cluster node
10.0.0.6 prod-cl1-0
# IP address of the second cluster node
10.0.0.7 prod-cl1-1

sudo ha-cluster-init

# Do you want to continue anyway? [y/N] -> y
# Network address to bind to (for example: 192.168.1.0) [10.79.227.0] -> Press ENTER
# Multicast address (for example: 239.x.x.x) [239.174.218.125] -> Press ENTER
# Multicast port [5405] -> Press ENTER
# Do you wish to configure an administration IP? [y/N] -> N

sudo ha-cluster-join

# Do you want to continue anyway? [y/N] -> y
# IP address or hostname of existing node (for example: 192.168.1.1) [] -> IP address of node 1 for example 10.0.0.14
# /root/.ssh/id_rsa already exists - overwrite? [y/N] N

sudo passwd hacluster
sudo vi /etc/corosync/corosync.conf
[...]
  token:          5000
  token_retransmits_before_loss_const: 10
  join:           60
  consensus:      6000
  max_messages:   20

  interface { 
     [...] 
  }
  transport:      udpu
} 
nodelist {
  node {
   # IP address of prod-cl1-0
   ring0_addr:10.0.0.6
  }
  node {
   # IP address of prod-cl1-1
   ring0_addr:10.0.0.7
  } 
}
logging {
  [...]
}
quorum {
     # Enable and configure quorum subsystem (default: off)
     # see also corosync.conf.5 and votequorum.5
     provider: corosync_votequorum
     expected_votes: 2
     two_node: 1
}

sudo service corosync restart
sudo crm configure rsc_defaults resource-stickiness="1"


