<#Author       : Dean Cefola
# Creation Date: 08-08-2018
# Usage        : HanaStudio Installation

#********************************************************************************
# Date                         Version      Changes
#------------------------------------------------------------------------
# 08/08/2018                     1.0        Intial Version
#
#*********************************************************************************
#
#>

param (    
    [string]$baseUri
)
    


################################
#    DataDisk Configuration    #
################################
$friendlyName = "StoragePool"; 
$Canpooldisks = Get-PhysicalDisk |? {$_.CanPool -eq $true};
New-StoragePool `
    -StorageSubSystemFriendlyName "*Storage*" `
    -FriendlyName $friendlyName `
    -PhysicalDisks $Canpooldisks; 


####################
#    Disk Array    #
####################
$Disks = @(
    @{Name="Data";Size=32GB;Letter="Z"} 
    
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



###################
#    Variables    #
###################
#NOTE:  Get the bits for the HANA installation and copy them to C:\SAPbits\SAP_HANA_STUDIO\
$hanadest    =  "C:\SapBits"
$hanapath    =  "C:\SapBits\SAP_HANA_STUDIO\"
$jrepath     =  "C:\Program Files\"  
$jredest     =  $jrepath +"serverjre.tar.gz" 
$ProcessLog  =  $hanadest +"\HanaStudio_Install.log"

########################################
#    Create Folders for HANA Studio    #
########################################
if((test-path $hanadest) -eq $false) {
    Write-Host -ForegroundColor Magenta -BackgroundColor Black "Creating C:\SapBits folders"    
    New-Item -Path $hanadest -ItemType directory
    New-item -Path $hanapath -itemtype directory
    New-Item -Path $ProcessLog -ItemType file
}
else {
    Write-Host -ForegroundColor Magenta -BackgroundColor Black "C:\SapBits already exists" 
    $logmessage = "C:\SapBits already exists"
    add-content $ProcessLog $logmessage
}
if ((Test-Path 'C:\Users\testuser') -eq $false) {
    Write-Host -ForegroundColor Magenta -BackgroundColor Black "Creating test user folders"
    $logmessage = "Creating test user folders"
    add-content $ProcessLog $logmessage
    New-item -Path 'C:\Users\testuser' -itemtype directory -Force -ErrorAction SilentlyContinue
    New-item -Path 'C:\Users\testuser\Documents' -itemtype directory -ErrorAction SilentlyContinue
    New-item -Path 'C:\Users\testuser\Documents\hbinst.log' -itemtype file -ErrorAction SilentlyContinue
}
else {
    Write-Host -ForegroundColor Magenta -BackgroundColor Black "C:\Users\testuser already exists" 
    $logmessage = "C:\Users\testuser already exists" 
    add-content $ProcessLog $logmessage
}
""
""
Wait-Event -Timeout 2

###########################
#    Download Software    #
###########################
$Date = Get-Date
Write-Host -ForegroundColor Magenta -BackgroundColor Black "Begin File Downloads"
$logmessage = "Begin File Downloads"
$logmessage = "$logmessage --  $Date"
add-content $ProcessLog $logmessage
$installers = @{    
    "sapcar.exe"       = $baseUri + "sapcar.exe";
    "putty.msi"        = $baseUri + "putty.msi";
    "sapcar_linux.exe" = $baseUri + "sapcar_linux.exe" 
    "HANA_STUDIO.SAR"  = $baseUri + "HANA_STUDIO.SAR" 
    "serverjre.tar.gz" = $baseUri + "serverjre.tar.gz"
    "7z.msi"           = $baseUri + "7z.msi"
}
foreach ($i in $installers.GetEnumerator()) {
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "Downloading" $i.name
    $logmessage = $i.name
    $logmessage = "Downloading  --  $logmessage"
    add-content $ProcessLog $logmessage    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $value=$i.Value
    $Downloadpath="$hanapath$($i.Name)"
    $i.name.Split('.')[0]
    Start-Job -Name $i.name.Split('.')[0] -ScriptBlock {
        param($value,$Downloadpath)`
        Invoke-WebRequest $value `
            -Method Get `
            -OutFile $Downloadpath
        } -ArgumentList $value,$Downloadpath
}


#######################
#    Install 7.Zip    #
#######################
Do {
    $DownloadCheck = (Get-Job -Name 7z).State
    if($DownloadCheck -eq "Completed") {
        Write-Host -ForegroundColor Green -BackgroundColor Black "7zip Download Complete"; 
        Wait-Event -Timeout 2
    }
    else {
        $DownloadCheck = (Get-Job -Name 7z).State
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "7zip still downloading...pause 5 seconds"
        $logmessage = "7zip still downloading...pause 5 seconds"
        add-content $ProcessLog $logmessage        
        Wait-Event -Timeout 5
    }       
} 
Until ($DownloadCheck -eq "Completed")
Write-Host -ForegroundColor Cyan -BackgroundColor Black "####    7zip Download Complete    ####"
$logmessage = "###############################
####    7zip Download Complete    ####
###############################
 
"
add-content $ProcessLog $logmessage
""
""
$Date = Get-Date
$logmessage = "Installing 7zip"
$logmessage = "$logmessage  --  $Date"
add-content $ProcessLog $logmessage
cd $hanapath
& .\7z.msi /quiet
Wait-Event -Timeout 10


###########################
#    Install serverjre    #
###########################
Do {
    $DownloadCheck = (Get-Job -Name serverjre).State
    if($DownloadCheck -eq "Completed") {
        Write-Host -ForegroundColor Green -BackgroundColor Black "serverjre Download Complete"; 
        Wait-Event -Timeout 2
    }
    else {
        $DownloadCheck = (Get-Job -Name serverjre).State
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "serverjre still downloading...pause 5 seconds"
        $logmessage = "serverjre still downloading...pause 5 seconds"
        add-content $ProcessLog $logmessage        
        Wait-Event -Timeout 5
    }       
} 
Until ($DownloadCheck -eq "Completed")
Write-Host -ForegroundColor Cyan -BackgroundColor Black "####    serverjre Download Complete    ####"
$logmessage = "##################################
####    serverjre Download Complete    ####
##################################
 
"
add-content $ProcessLog $logmessage
$logmessage = "Installing serverjre"
$logmessage = "$logmessage  --  $Date"
add-content $ProcessLog $logmessage
""
""
cd "$jrepath\7-Zip"
& .\7z.exe e "$hanapath\serverjre.tar.gz" "-oC:\Program Files"
& .\7z.exe x -y "$jrepath\serverjre.tar" "-oC:\Program Files"


#######################
#    Install Putty    #
#######################
Do {
    $DownloadCheck = (Get-Job -Name PuTTY).State
    if($DownloadCheck -eq "Completed") {
        Write-Host -ForegroundColor Green -BackgroundColor Black "PuTTY Download Complete"; 
        Wait-Event -Timeout 2
    }
    else {
        $DownloadCheck = (Get-Job -Name PuTTY).State
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "PuTTY still downloading...pause 5 seconds"
        $logmessage = "PuTTY still downloading...pause 5 seconds"
        add-content $ProcessLog $logmessage        
        Wait-Event -Timeout 5
    }       
} 
Until ($DownloadCheck -eq "Completed")
Write-Host -ForegroundColor Cyan -BackgroundColor Black "####    PuTTY Download Complete    ####"
$logmessage = "################################
####    PuTTY Download Complete    ####
################################
 
"
add-content $ProcessLog $logmessage
Write-Host -ForegroundColor Cyan -BackgroundColor Black "Installing PuTTY"
$Date = Get-Date
$logmessage = "Installing PuTTY"
$logmessage = "$logmessage  --  $Date"
add-content $ProcessLog $logmessage
""
""
cd $hanapath
& .\putty.msi /quiet


##############################
#    Set System Variables    #
##############################
Write-Host -ForegroundColor Cyan -BackgroundColor Black "Set System Path Variable for Java"
$logmessage = " 
 
####    Set System Path Variable for Java    #### 
 
"
add-content $ProcessLog $logmessage    
$oldPath = (Get-ItemProperty `
    -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ `
    -Name PATH).path
$newpath = “$oldpath;C:\Program Files\jdk-10.0.2\bin"
Set-ItemProperty `
    -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ `
    -Name PATH `
    -Value $newPath
set 'HDB_INSTALLER_TRACE_FILE=C:\Users\testuser\Documents\hdbinst.log'


#############################
#    Install Hana Studio    #
#############################
Do {
    $DownloadCheck = (Get-Job -Name HANA_STUDIO).State
    if($DownloadCheck -eq "Completed") {
        Write-Host -ForegroundColor Green -BackgroundColor Black "Hana Studio Download Complete"; 
        Wait-Event -Timeout 2
    }
    else {
        $DownloadCheck = (Get-Job -Name HANA_STUDIO).State
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Hana Studio still downloading...pause 5 seconds"
        $logmessage = "Hana Studio still downloading...pause 5 seconds"
        add-content $ProcessLog $logmessage        
        Wait-Event -Timeout 5
    }       
} 
Until ($DownloadCheck -eq "Completed")
Write-Host -ForegroundColor Cyan -BackgroundColor Black "####    Hana Studio Download Complete    ####"
$logmessage = "#####################################
####    Hana Studio Download Complete    ####
#####################################
 
"
add-content $ProcessLog $logmessage
Write-Host -ForegroundColor Cyan -BackgroundColor Black "Extracting Hana Studio Files"
$Date = Get-Date
$logmessage = "Extracting Hana Studio Files"
$logmessage = "$logmessage  --  $Date"
add-content $ProcessLog $logmessage
""
""
cd "$hanapath"; 
.\sapcar.exe -xfv HANA_STUDIO.SAR
""
""
cd "$hanapath\SAP_HANA_STUDIO\"; 
.\hdbinst.exe `
    -a $hanapath"SAP_HANA_STUDIO\studio" `
    -b --path="C:\Program Files\sap\hdbstudio"
Write-Host -ForegroundColor Cyan -BackgroundColor Black "####    Hana Studio Installation Complete    ####"
$logmessage = "#####################################
####    Hana Studio Installation Complete    ####
#####################################
 
"
add-content $ProcessLog $logmessage


##################
#    Clean Up    #
##################
Get-Job |Remove-Job -Force 
""
""
Write-Host -ForegroundColor Cyan -BackgroundColor Black "####    Script Complete    ####"
$Date = Get-Date
$logmessage = " 
 
  
   
########################
########################
####    Script Complete    ####
########################
########################
 $Date
"
add-content $ProcessLog $logmessage
