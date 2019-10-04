#Requires -Version 3.0

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'AzureSAP',
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts',
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
    [string] $DSCSourceFolder = 'DSC',
    [switch] $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        $JsonParameters = $JsonParameters.parameters
    }
    $ArtifactsLocationName = '_artifactsLocation'
    $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    $OptionalParameters[$ArtifactsLocationName] = $JsonParameters | Select -Expand $ArtifactsLocationName -ErrorAction Ignore | Select -Expand 'value' -ErrorAction Ignore
    $OptionalParameters[$ArtifactsLocationSasTokenName] = $JsonParameters | Select -Expand $ArtifactsLocationSasTokenName -ErrorAction Ignore | Select -Expand 'value' -ErrorAction Ignore

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }

    # Create a storage account name if none was provided
    if ($StorageAccountName -eq '') {
        $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
    }

    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if ($StorageAccount -eq $null) {
        $StorageResourceGroupName = 'ARM_Deploy_Staging'
        New-AzureRmResourceGroup -Location "$ResourceGroupLocation" -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
    }

    # Generate the value for artifacts location if it is not provided in the parameter file
    if ($OptionalParameters[$ArtifactsLocationName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationName] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

    $ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) `
            -Container $StorageContainerName -Context $StorageAccount.Context -Force
    }

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
    if ($OptionalParameters[$ArtifactsLocationSasTokenName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force `
            (New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
    }
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

$Deploy = ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm'))
if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment `
			-ResourceGroupName $ResourceGroupName `
			-TemplateFile $TemplateFile `
			-TemplateParameterFile $TemplateParametersFile `
			@OptionalParameters
	)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
    New-AzureRmResourceGroupDeployment `
		-Name $Deploy `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile `
        @OptionalParameters `
        -Force -Verbose `
        -ErrorVariable ErrorMessages
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}


Wait-Event -Timeout 10
<#""
""
""
Write-Output "Configure NSG Flow Logs"
""
""
""
#################################
#    Configure NSG Flow Logs    #
#################################
$NetworkWatcherName = "NetworkWatcher_$ResourceGroupLocation"
$RGName = $ResourceGroupName.ToLower()
$StorageAccountName = $RGName.Substring(0,3)+"nsgflowlogs"
if((Get-AzureRmNetworkWatcher -Name $NetworkWatcherName -ResourceGroupName 'NetworkWatcherRG' -ErrorAction SilentlyContinue) -eq $null) {
    Write-Output "Creating Network Watcher"
    $NetWatcher = New-AzureRmNetworkWatcher `
        -Name $NetworkWatcherName `
        -ResourceGroupName $ResourceGroupName `
        -Location $ResourceGroupLocation
}
Else {
    Write-Output "Network Watcher Already Exists"
    $NetWatcher = Get-AzureRmNetworkWatcher `
        -Name $NetworkWatcherName `
        -ResourceGroupName 'NetworkWatcherRG'
}
if((Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) -eq $null) {
    Write-Output "Creating Storage Account for NSG Flow Logs"
    $StorageAccount = New-AzureRmStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -SkuName Standard_LRS `
        -Location $ResourceGroupLocation `
        -Kind StorageV2

}
Else {
    Write-Output "Storage Account for NSG Flow Logs Already Exists"
    $StorageAccount = Get-AzureRmStorageAccount `
        -Name $StorageAccountName `
        -ResourceGroupName $ResourceGroupName 
}
$vnets = Get-AzureRmVirtualNetwork
foreach ($vnet in $vnets) {
    foreach ($subnet in $vnet.subnets) {
		$nsgId = $null
        $nsgId = $subnet.NetworkSecurityGroup.Id
        If ($nsgId) {
			Set-AzureRmNetworkWatcherConfigFlowLog `
                -NetworkWatcher $NetWatcher `
				-TargetResourceId $nsgId `
                -StorageAccountId $storageAccount.Id `
				-EnableFlowLog $true `
                -EnableRetention $true `
                -RetentionInDays 90
        }
    }
}
""
""
""

Write-Output "Set VMs Dynamicly allocated IP addresses as Static"
""
""
""
#>
##############################################
#    Set All IPs on VMs and ILB to Static    #
##############################################
$VMNic = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName).Name
foreach ($Nic_name in $VMNic) {	
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName | ? -Property name -Match 'EWM'
    foreach ($N in $nic) {
        $N.IpConfigurations[0].PrivateIpAllocationMethod = 'Static'
        Set-AzureRmNetworkInterface -NetworkInterface $N 
        $IP = $N.IpConfigurations[0].PrivateIpAddress
        Write-Host `
            "The allocation method is now set to"`
            $N.IpConfigurations[0].PrivateIpAllocationMethod`
            "for the IP address" $IP"." `
            -NoNewline
    }
}
""
""
""
Write-Output "Install Azure SAP Enhanced Monitoring Agent"
""
""
""
Wait-Event -Timeout 10
#############################################
#    Azure SAP Enhanced Monitoring Agent    #
#############################################
$VMs = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
foreach ($VM in $VMs) {
	Set-AzureRmVMAEMExtension `
		-ResourceGroupName $ResourceGroupName `
		-VMName $VM.Name
}
""
""
""
###############################################################
#    Enable Write Accelerator on M-Series Database Servers    #
###############################################################
$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName `
    | Where-Object -Property Name -Match 'DB'
if(($VM.HardwareProfile.VmSize) -eq 'Standard_M128ms') {
	#new Write Accelerator status ($true for enabled, $false for disabled) 
	""
    Write-Host `
        -BackgroundColor Black `
        -ForegroundColor Cyan `
        "InstallingWrite Accelerator to M-Series VM" 
    ""
    $newstatus = $true
	$datadiskname = ($VM.StorageProfile.DataDisks | Where-Object -Property DiskSizeGB -Match 512).name

	foreach ($Disk in $datadiskname) {
		Set-AzureRmVMDataDisk `
			-VM $VM `
			-Name $Disk `
			-Caching None `
			-WriteAccelerator:$newstatus
	}
	Update-AzureRmVM `
		-ResourceGroupName $ResourceGroupName `
		-VM $VM
}
else {
	 Write-Host `
        -BackgroundColor Black `
        -ForegroundColor Cyan `
		"No M-Series VMs in this deployment"
}
""
""
""

