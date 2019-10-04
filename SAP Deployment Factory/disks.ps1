
#####################
#    Prep Server    #
#####################
$friendlyName = "SAP-StoragePool"; 
$Canpooldisks = Get-PhysicalDisk |? {$_.CanPool -eq $true};
New-StoragePool `
    -StorageSubSystemFriendlyName "*Storage*" `
    -FriendlyName $friendlyName `
    -PhysicalDisks $Canpooldisks; 


####################
#    Disk Array    #
####################
$Disks = @(
    @{Name="Logs";Size=512GB;Letter="L"} 
    @{Name="SAP";Size=64GB;Letter="S"} 
    @{Name="Data";Size=5120GB;Letter="T"} 
    @{Name="Shared";Size=1024GB;Letter="X"} 
    @{Name="Backup";Size=5120GB;Letter="Z"}
); 


######################
#    Create Disks    #
######################
 foreach ($disk in $disks) {
    $vd = New-VirtualDisk `
        -StoragePoolFriendlyName $friendlyName `
        -FriendlyName $disk.Name `
        -Size $disk.Size `
        -ResiliencySettingName Simple `
        -ProvisioningType Thin `
        | get-disk `
        | Initialize-Disk `
            -PartitionStyle GPT `
            -PassThru `
            | New-Partition `
                -DriveLetter $disk.Letter `
                -UseMaximumSize `
                | Format-Volume `
                    -FileSystem NTFS `
                    -NewFileSystemLabel $disk.Name `
                    -Confirm:$false 
}
