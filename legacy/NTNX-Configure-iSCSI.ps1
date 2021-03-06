#region Helper Functions
function Get-BroadcastAddress {
    param (
        [IpAddress]$ip,
        [IpAddress]$Mask
    )
 
    $IpAddressBytes = $ip.GetAddressBytes()
    $SubnetMaskBytes = $Mask.GetAddressBytes()
 
    if ($IpAddressBytes.Length -ne $SubnetMaskBytes.Length) {
        throw "Lengths of IP address and subnet mask do not match."
        exit 0
    }
 
    $BroadcastAddress = @()
 
    for ($i=0;$i -le 3;$i++) {
        $a = $subnetMaskBytes[$i] -bxor 255
        if ($a -eq 0) {
            $BroadcastAddress += $ipAddressBytes[$i]
        }
        else {
            $BroadcastAddress += $a
        }
    }
 
    $BroadcastAddressString = $BroadcastAddress -Join "."
    return [IpAddress]$BroadcastAddressString
}

function Get-NetwotkAddress {
    param (
        [IpAddress]$ip,
        [IpAddress]$Mask
    )
 
    $IpAddressBytes = $ip.GetAddressBytes()
    $SubnetMaskBytes = $Mask.GetAddressBytes()
 
    if ($IpAddressBytes.Length -ne $SubnetMaskBytes.Length) {
        throw "Lengths of IP address and subnet mask do not match."
        exit 0
    }
 
    $BroadcastAddress = @()
 
    for ($i=0;$i -le 3;$i++) {
        $BroadcastAddress += $ipAddressBytes[$i]-band $subnetMaskBytes[$i]
 
    }
 
    $BroadcastAddressString = $BroadcastAddress -Join "."
    return [IpAddress]$BroadcastAddressString
}

function Test-IsInSameSubnet {
    param (
        [IpAddress]$ip1,
        [IpAddress]$ip2,
        [IpAddress]$mask
    )
 
    $Network1 = Get-NetwotkAddress -ip $ip1 -mask $mask
    $Network2 = Get-NetwotkAddress -ip $ip2 -mask $mask
 
    return $Network1.Equals($Network2)
}

function NTNX-Build-Menu {
<#
.NAME
	NTNX-Build-Menu
.SYNOPSIS
	Builds and menu and return the users selection
.DESCRIPTION
  Build a menu passing an array of values and retun the user's selection
.NOTES
	Authors:  VMware Dude
.LINK
	www.nutanix.com
.PARAMETER Title
  Menu title
.PARAMETER Data
  Array data used for menu options
.EXAMPLE
  NTNX-Build-Menu -Title "My Menu" -Data $MyArray
#>
   
Param(
	[parameter(Mandatory=$true)][string]$Title,
    [parameter(Mandatory=$true)][array]$Data,
    [parameter(Mandatory=$false)]$filter,
    [parameter(Mandatory=$false)][string]$EndObj
)
	$Increment = 0
	$filteredData = $Data | select $filter
	write-host ""
	write-host $Title
	$filteredData | %{
		$Increment +=1
		write-host "$Increment." $_
	}
  
	if ([string]::IsNullOrEmpty($EndObj)) {
  		$EndObj = "DONE"
	}
	
	$Increment +=1
  	write-host "$Increment. " $EndObj
	
	$index = (read-host "Please select an option [Example: 1]")-1
  
	# Selection is valid
	if ($Data[$index]) {
		$selection = $Data[$index]
		write-host "You selected: $($selection | select $filter) at index $index"
	} else { # Assuming last index was selected
		$selection = $EndObj
		Write-Host 	"You selected $EndObj"
	}

	return $selection
}

function NTNX-Map-Object {
<#
.NAME
	NTNX-Map-Object
.SYNOPSIS
	Maps objects from provided arrays
.DESCRIPTION
	Maps objects from provided arrays
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Map-Object -mappingType "NETWORK" -sourceData $vmNetworks -targetData $availNetworks -Filter name,VlanId
#> 
	Param(
		[parameter(Mandatory=$true)][array]$mappingType,
		
		[parameter(Mandatory=$true)][array]$sourceData,
		
		[parameter(Mandatory=$true)][array]$targetData,
		
		[parameter(Mandatory=$true)]$filter
	)
	
	begin {

		# Get source
		$sourceObj = NTNX-Build-Menu -Title "Please select a source:" -Data $sourceData -Filter $filter
		
		if ($sourceObj -eq "DONE") {
			Write-Host "Mapping cancelled or completed by user!"
			break
		}
		
		# Get target
		$targetObj = NTNX-Build-Menu -Title "Please select a target:" -Data $targetData -Filter $filter
		
		if ($targetObj -eq "DONE") {
			Write-Host "Mapping cancelled or completed by user!"
			break
		}

		Write-Host "Created the mapping of $sourceObj to $targetObj"
	}
	process {
		$mapping = New-Object PSCustomObject -Property @{
			mappingType = $mappingType
			sourceObj = $sourceObj
			targetObj = $targetObj
		}
	}
	end {
		return $mapping
	}
}

function Unzip-File {
<#
.NAME
	Unzip-File
.SYNOPSIS
	blah
.DESCRIPTION
	blah
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    blah
#> 
	param (
		[parameter(mandatory=$false)]$file,
		
		[parameter(mandatory=$false)]$destination
	)
	
	begin {
	
	}
	
	process {
		$shell = new-object -com shell.application
		$zip = $shell.NameSpace($file)
		
		foreach($item in $zip.items()) {
			$shell.Namespace($destination).copyhere($item)
		}
	}
	
	end {
	
	}
}

#endregion

#region Connection Functions

############################################################
##
## Function: NTNX-Connect-HYP
## Author: Steven Poitras
## Description: Connect to Hypervisor manager function
## Language: PowerShell
##
############################################################
function NTNX-Connect-HYP {
<#
.NAME
	NTNX-Connect-HYP
.SYNOPSIS
	Connect to Hypervisor manager function
.DESCRIPTION
	Connect to Hypervisor manager function
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Connect-HYP -IP "99.99.99.99.99" -User "BlahUser" -Type VC
#> 
	Param(
	    [parameter(mandatory=$true)][AllowNull()]$IP,
		
		[parameter(mandatory=$false)][AllowNull()]$Type,
		
		[parameter(mandatory=$false)][AllowNull()]$credential
	)

	begin{
		$hypType = "VC","SCVMM"
	
		# Make sure requried snappins are installed / loaded
		$loadedSnappins = Get-PSSnapin
		
		# If no IP passed prompt for IP
		if ([string]::IsNullOrEmpty($IP)) {
			$IP = Read-Host "Please enter a IP or hostname for the management Server: "
		}
		
		# If no type passed prompt for type
		if ([string]::IsNullOrEmpty($Type)) {
			$Type = NTNX-Build-Menu -Title "Please select a management server type:" -Data $hypType
		}
		
		# If values not set use defaults
		if ([string]::IsNullOrEmpty($credential)) {
			Write-Host "No admin credential passed, prompting for input..."
			$credential = (Get-Credential -Message "Please enter the vCenter Server credentials <admin/*******>")
		}

	}
	process {
		if ($Type -eq $hypType[0]) {
			# Make sure snappin is loaded
			if ($loadedSnappins.name -notcontains "VMware.VimAutomation.Core") {
				Write-Host "PowerCLI snappin not installed or loaded, exiting..."
				break
			}	
			
			# Check if connection already exists
			if ($($global:DefaultVIServers | where {$_.Name -Match $IP}).IsConnected -ne "True") {
				# Connect to vCenter Server
				Write-Host "Connecting to vCenter Server ${IP} as $$credential.UserName}..."
				$connObj = Connect-VIServer $IP -User $($credential.UserName.Trim("\")) `
					-Password $(([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))) -AcceptInvalidSSLCerts
			} else {  #Already connected to server
				Write-Host "Already connected to server ${IP}, continuing..."
			}
		} elseif ($Type -eq $hypType[1]) {
			# To be input
		}
		
	}
	end {
		$hypServerObj = New-Object PSCustomObject -Property @{
			IP = $IP
			Type = $Type
			Credential = $credential
			connObj = $connObj
		}
		
		return $hypServerObj
	}
}

############################################################
##
## Function: NTNX-Connect-NTNX
## Author: Steven Poitras
## Description: Connect to NTNX function
## Language: PowerShell
##
############################################################
function NTNX-Connect-NTNX {
<#
.NAME
	NTNX-Connect-NTNX
.SYNOPSIS
	Connect to NTNX function
.DESCRIPTION
	Connect to NTNX function
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Connect-NTNX -IP "99.99.99.99.99" -User "BlahUser"
#> 
	Param(
	    [parameter(mandatory=$true)][AllowNull()]$ip,
		
		[parameter(mandatory=$false)][AllowNull()]$credential
	)

	begin{
		# Make sure requried snappins are installed / loaded
		$loadedSnappins = Get-PSSnapin
		
		if ($loadedSnappins.name -notcontains "NutanixCmdletsPSSnapin") {
			Write-Host "Nutanix snappin not installed or loaded, trying to load..."
			
			# Try to load snappin
			Add-PSSnapin NutanixCmdletsPSSnapin
			
			if ($loadedSnappins.name -notcontains "NutanixCmdletsPSSnapin") {
				Write-Host "Nutanix snappin not installed or loaded, exiting..."
				break
			}
		}
		
		# If values not set use defaults
		if ([string]::IsNullOrEmpty($credential)) {
			Write-Host "No Nutanix user passed, using default..."
			$credential = (Get-Credential -Message "Please enter the Nutanix Prism credentials <admin/*******>")
		}

	}
	process {
		# Check for connection and if not connected try to connect to Nutanix Cluster
		if ([string]::IsNullOrEmpty($IP)) { # Nutanix IP not passed, gather interactively
			$IP = Read-Host "Please enter a IP or hostname for the Nutanix cluter: "
		}
		
		# If not connected, try connecting
		if ($(Get-NutanixCluster -Servers $IP -ErrorAction SilentlyContinue).IsConnected -ne "True") {  # Not connected
			Write-Host "Connecting to Nutanix cluster ${IP} as ${credential.UserName}..."
			$connObj = Connect-NutanixCluster -Server $IP -UserName $($credential.UserName.Trim("\")) `
				-Password $(([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))) -AcceptInvalidSSLCerts -F
		} else {  # Already connected to server
			Write-Host "Already connected to server ${IP}, continuing..."
		}
	}
	end {
		$nxServerObj = New-Object PSCustomObject -Property @{
			IP = $IP
			Credential = $credential
			connObj = $connObj
		}
		
		return $nxServerObj
	}
}

############################################################
##
## Function: NTNX-Connect-SSH
## Author: Steven Poitras
## Description: Connect to SSH function
## Language: PowerShell
##
############################################################
function NTNX-Connect-SSH {
<#
.NAME
	NTNX-Connect-SSH
.SYNOPSIS
	Connect to SSH function
.DESCRIPTION
	Connect to SSH function
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
	
	posh-ssh link: http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Connect-SSH -IP "99.99.99.99.99" -Credential $mycred
#> 
	Param(
	    [parameter(mandatory=$false)][AllowNull()]$ip,
		
		[parameter(mandatory=$false)][AllowNull()]$credential

	)

	begin{
		# Make sure requried snappins are installed / loaded
		$loadedModule = Get-Module

		if ($loadedModule.name -notcontains "posh-ssh") {
			Write-host 	"posh-ssh module not found or loading, attempting to install..."
			iex (New-Object Net.WebClient).DownloadString("https://gist.github.com/darkoperator/6152630/raw/c67de4f7cd780ba367cccbc2593f38d18ce6df89/instposhsshdev")
		} else {
			Write-Host "posh-ssh module installed already, continuing..."
		}
	
	}
	
	process {
		if ([string]::IsNullOrEmpty($ip)) { # SSH IP not passed, gather interactively
			$IP = Read-Host "Please enter a IP or hostname for the SSH target: "
		}
		
		if ([string]::IsNullOrEmpty($credential)) { # SSH creds not passed, gather interactively
			$credential = Get-Credential
		}
		
		$session = New-SshSession -ComputerName $ip -Credential $credential -AcceptKey
		
	}
	
	end {
		return $session
	}
	
}

#endregion

#region Core Functions
############################################################
##
## Function: NTNX-Install-iSCSI
## Author: Steven Poitras
## Description: Install Windows iSCSI
## Language: PowerShell
##
############################################################
function NTNX-Install-iSCSI {
<#
.NAME
	NTNX-Install-iSCSI
.SYNOPSIS
	Install Windows iSCSI and MPIO
.DESCRIPTION
	Install Windows iSCSI and MPIO and ensure firewall
	and service is set to automatically start
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Install-iSCSI -MPIOPolicy Foo
#> 
	param (
		[parameter(mandatory=$false)][ValidateSet('FOO', 'RR', 'LQD')]$MPIOPolicy

	)
	
	begin {
		# Defaults
		$diskTimeout = 60
		
		#Available options: FOO - Failover Only, RR - Round Robin, LQD - Least Queue Depth
		if ([string]::IsNullOrEmpty($MPIOPolicy)) {
			$usedLBPolicy = 'FOO'	
		} else {
			$usedLBPolicy = $MPIOPolicy
		}
	}
	
	process {
		# Make sure it's set to automatic startup
		Write-Host "Setting iSCSI service type to Automatic..."
		Set-Service -Name msiscsi -StartupType Automatic
		
		# Make sure iSCSI service is started
		if ($(Get-Service -Name msiscsi).Status -ne "Running") {
			# Service not running, start it...
			Start-Service -Name msiscsi
		}
		
		# Install MPIO
		Write-Host "Installing MPIO..."
		Install-WindowsFeature -Name multipath-io
		
		# Enable automatic claiming of iSCSI devices
		Write-Host "Enabling automatic claiming of iscsi devices..."
		Enable-MSDSMAutomaticClaim -BusType iscsi
		
		# Get current MPIO policy
		$currLBPolicy = Get-MSDSMGlobalDefaultLoadBalancePolicy
		Write-Host "Current load balancing policy is $currLBPolicy..."
		
		# Set default policy
		Write-Host "Setting default load balancing policy to $usedLBPolicy..."
		Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy $usedLBPolicy
		
		$lbCommand = 'mpclaim.exe -L -M 1'
		Invoke-Expression -Command:$lbCommand
		
		# Set disk timeout
		Write-Host "Setting disk timeout to $diskTimeout..."
		Set-MPIOSetting -NewDiskTimeout $diskTimeout
		
		# Check and set firewalla settings to allow iSCSI
		$iscsiFWRules = Get-NetFirewallServiceFilter -Service msiscsi |`
			Get-NetFirewallRule | Select DisplayGroup,DisplayName,Enabled
		
		if ($iscsiFWRules.Enabled -eq 'True') {
			Write-Host "You must allow the following firewall rules:"
			$iscsiFWRules | where {$_.Enabled -match 'True'}
			
			Write-Host "Attempting to set firewall rules automatically..."
			Set-NetFirewallRule -DisplayGroup 'iSCSI Service' -Enabled False
			
			if ($($iscsiFWRules | where {$_.Enabled -match 'True'}).length -eq 0) {
				Write-Host "Setting rules was successful..."
			} else {
				Write-Host "Setting rules was not successful, exiting ..."
				break
			}
			
		} else {
			# Firewall rules not enabled
			Write-Host "iSCSI service firewall rules not enabled, continuing..."
		}
		
	}
	
	end {
		# Validate iSCSI is running and mpio is enabled
		$iScsiStatus = $(Get-Service -Name msiscsi).status
		
		if ($iScsiStatus -ne "Running") {
			# Service not running
			Write-Host "Error, iSCSI service is $iScsiStatus"
		} else {
			# Service is running
			Write-Host "Success, iSCSI service is $iScsiStatus"
		}
		
		# Get OS IQN
		$initiatorIQN = (Get-InitiatorPort).NodeAddress
		
		Write-Host "IQN is: $initiatorIQN"
		
		return $initiatorIQN
	}
}

############################################################
##
## Function: NTNX-Create-Volume
## Author: Steven Poitras
## Description: Create NTNX vdisks for iSCSI initiators
## Language: PowerShell
##
############################################################
function NTNX-Create-Volume {
<#
.NAME
	NTNX-Create-Volumes
.SYNOPSIS
	Create NTNX volumes and attach to a specified IQN
.DESCRIPTION
	Create NTNX volumes and attach to a specified IQN
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Create-Volume -volumeName "myvm_vol1" -diskQty 6 -initiatorIQN "iqn.924...."
		-sshSessionID 1
#> 
	param (
		[parameter(mandatory=$true)]$volumeName,
		
		[parameter(mandatory=$true)][int]$diskQty,
		
		[parameter(mandatory=$true)]$diskSize,
		
		[parameter(mandatory=$true)]$container,
		
		[parameter(mandatory=$true)]$initiatorIQN,
		
		[parameter(mandatory=$true)]$sshSessionID

	)
	
	begin {
		# Defaults
		[int]$diskPerVol = 1

	}
	
	process {

		$volumeQty = [Math]::Ceiling($diskQty / $diskPerVol)
		
		# Add disks to volume
		1..$volumeQty | %{
			$int = $_
			
			$l_volumeName = "$volumeName-$int"
			
			$response = Invoke-SshCommand -SessionId 0 -Command "source /etc/profile > /dev/null 2>&1; `
				acli vg.get $l_volumeName" | Out-Null
				
			if ($response.output -notmatch "Unknown") {
				# VG already exists
				Write-Host "Volume already exists, continuing..."
				Return
			}
		
			# Create volume
			Write-Host "Creating volume $l_volumeName"
			Invoke-SshCommand -SessionId $sshSessionID -Command "source /etc/profile > /dev/null 2>&1; `
				acli vg.create $l_volumeName" | Out-Null
				
			1..$diskPerVol | %{
				# Create disk
				Write-Host "Creating disk $_ of $diskPerVol for volume $l_volumeName"
				Invoke-SshCommand -SessionId $sshSessionID -Command "source /etc/profile > /dev/null 2>&1; `
					acli vg.disk_create $l_volumeName create_size=$diskSize container=$container"  | Out-Null
			}
			
			# Attach initiator to volume, there may be multiple IQNs in the shared case
			$initiatorIQN | %{
				Invoke-SshCommand -SessionId $sshSessionID -Command "source /etc/profile > /dev/null 2>&1; `
					acli vg.attach_external $l_volumeName $_"
			}
			
		}

	}
	
	end {
		return $volumeQty
	
	}
}

############################################################
##
## Function: NTNX-Conf-iSCSI
## Author: Steven Poitras
## Description: Configure iSCSI targets
## Language: PowerShell
##
############################################################
function NTNX-Conf-iSCSI {
<#
.NAME
	NTNX-Conf-iSCSI
.SYNOPSIS
	Configure iSCSI function
.DESCRIPTION
	Configure iSCSI function
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Conf-iSCSI -activePath "99.99.99.99" -standbyPath "10.10.10.1","10.10.10.2"
		-fileSystem 'NTFS' -blockSizeKB 64
#> 
	param (
		[parameter(mandatory=$true)]$activePath,
		
		[parameter(mandatory=$true)]$standbyPath,
		
		[parameter(mandatory=$true)]$initiatorIP,
		
		[parameter(mandatory=$true)]$expVolQty,
		
		[parameter(mandatory=$true)]$expDiskQty,
		
		[parameter(mandatory=$false)][ValidateSet('NTFS','ReFS','exFAT','FAT32','FAT')]$fileSystem,
		
		[parameter(mandatory=$false)]$blockSizeKB
	)
	
	begin {
		# Defaults
		if ([string]::IsNullOrEmpty($fileSystem)) {
			$fsType = 'NTFS'
		} else {
			$fsType = $fileSystem
		}
		
		if ([string]::IsNullOrEmpty($blockSizeKB)) {
			$blockSize = 8
		} else {
			$blockSize = $blockSizeKB
		}
		
		$partStyle = 'MBR'
		[int]$maxRetry = 3
		[int]$sleepSecs = 30
	}
	
	process {
	
		# Find connected adapters
		$localAdapter = Get-NetAdapter | where Status -eq up | Get-NetIPAddress -AddressFamily IPv4 -ea 0
		
		# If multiple adapters, prompt user for selection
		if ($localAdapter.Length -gt 1) {
			$adapter = $localAdapter | where {$_.IPAddress -match $initiatorIP}
			
			if (!$adapter) {
				Write-Host "Initiator IP not found in available adapters, exiting..."
				break
			}
			
		} else { # Single adapter
			$adapter = $localAdapter
		}
		
		# Add active CVM
		New-IscsiTargetPortal -TargetPortalAddress $activePath
		
		# Perform discovery
		$discoveredTargets = Get-IscsiTarget
		Write-Host "Found $($discoveredTargets.length) iSCSI targets"
		
		if ($discoveredTargets.length -le 0) {
			# No targets found
			Write-Host "No iSCSI targets found, exiting..."
			return
		}
		
		# Add and test standby CVM
		$standbyPath | %{
			$currPath = $_
			
			# Add portal
			New-IscsiTargetPortal -TargetPortalAddress $currPath
			
			# Test discovery
			$l_discoveredTargets = Get-IscsiTarget
			Write-Host "Found $($l_discoveredTargets.length) iSCSI targets on path $currPath"
			
			if ($l_discoveredTargets -eq $discoveredTargets) {
				# CVM all good
				Write-Host "Standby CVM can see all expected targets..."
			} else {
				# Don't use this CVM
			}
		}
		
		# Connect to all discovered targets
		$discoveredTargets | %{
			$currTarget = $_
			
			# Add active path
			Connect-IscsiTarget -NodeAddress $currTarget.NodeAddress `
				-InitiatorPortalAddress $adapter.IPAddress `
				-IsMultipathEnabled $true -IsPersistent $true `
				-TargetPortalAddress $activePath			
			
			# Add standby paths
			$standbyPath | %{
				$currPortalIP = $_
				
				Connect-IscsiTarget -NodeAddress $currTarget.NodeAddress `
					-InitiatorPortalAddress $adapter.IPAddress `
					-IsMultipathEnabled $true -IsPersistent $true `
					-TargetPortalAddress $currPortalIP
			}
		}
		
		# Get iscsi disks
		$iscsiDisk = Get-Disk | where {$_.BusType -eq 'iSCSI'}
		$i = 1
		while ($iscsiDisk.length -lt $discoveredTargets.length -and $i -le $maxRetry) {
			Write-Host "Sleeping for $sleepSecs seconds to allow device discovery..."
			Start-Sleep -Seconds $sleepSecs
			
			# Increment int
			$i+=1
			
			# Refresh disk object
			$iscsiDisk = Get-Disk | where {$_.BusType -eq 'iSCSI'}
		}

		Write-Host "Found $($iscsiDisk.length) iSCSI disks!"
		Write-Host "Proceeding to initialize and format devices..."
		
		$iscsiDisk | %{
			$currDisk = $_
			Write-Host "Starting work on disk $($currDisk.Number) ..."
			
			Set-disk -Number $currDisk.Number -IsReadOnly $false
			
			if ($currDisk.OperationalStatus -ne 'Online') {
				# Initialize and format disk(s)
				Write-Host "Attempting to initialize disk..."
				Initialize-Disk -Number ($currDisk.Number) -PartitionStyle MBR -ErrorAction SilentlyContinue
			}
			
			# Reset counter
			$i = 1
			while (!($currDisk | Get-Partition) -and $i -le $maxRetry) {
				Write-Host "Attempting to create partition, try $i of  $maxRetry ..."
				# Create partition
				New-Partition -DiskNumber ($currDisk.Number) -AssignDriveLetter -UseMaximumSize
				
				if (!($currDisk | Get-Partition)) {
					$i+=1
					Write-Host "Partitioning failed, sleeping for $sleepSecs seconds..."
					Start-Sleep -Seconds $sleepSecs
				}
			}
			
			# Get partition object
			$partition = $currDisk | Get-Partition
			
			# Set partition as read / write
			Set-Partition -diskNumber ($currDisk.Number) `
				-PartitionNumber ($partition.PartitionNumber) -IsReadOnly $false
			
			# Reset counter
			$i = 1
			while (($partition | Get-Volume).FileSystem -ne $fsType -and $i -le $maxRetry) {
				Write-Host "Attempting to format volume, try $i of  $maxRetry ..."
				# Format volume
				Format-Volume -Partition $partition -FileSystem $fsType `
					-AllocationUnitSize $($blockSize*1024) -Confirm:$false
				
				if (!($partition | Get-Volume)) {
					$i+=1
					Write-Host "Format failed, sleeping for $sleepSecs seconds..."
					Start-Sleep -Seconds $sleepSecs
				}
			}
		}

	}
	
	end {
		# Validate iSCSI session
	}
}

############################################################
##
## Function: NTNX-Execute-iSCSI
## Author: Steven Poitras
## Description: Configure iSCSI targets
## Language: PowerShell
##
############################################################
function NTNX-Execute-iSCSI {
<#
.NAME
	NTNX-Conf-iSCSI
.SYNOPSIS
	Connect to VC function
.DESCRIPTION
	Connect to VC function
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
	
	This should be run from a domain joined computer and have administrative 
	right to install and configure services on the desired hosts
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Execute-iSCSI -vm "blah","blah2" -nutanixIP 99.99.99.99 -diskQty 6 `
		-diskSize 2048G -numPaths 3
#> 
	param (
		[parameter(mandatory=$false)]$vm,
		
		[parameter(mandatory=$false)]$nutanixIP,
		
		[parameter(mandatory=$false)]$diskQty,
		
		[parameter(mandatory=$false)]$diskSize,
		
		[parameter(mandatory=$false)]$numPaths
		
	)
	
	begin {
		<#
		Workflow steps
			0.	Get VMs (name(s)) and vDisk inputs (Qty., size and naming convention)
			1.	Install Win iSCSI / MPIO - X
			2.	Create vdisks / assign VM IQN
			3.	Attach iSCSI Targets
			4.	Format and partition devices
			5.	Validate & exit
		#>
		
		# Pre-req message
		Write-host "NOTE: the following pre-requisites MUST be performed / valid before script execution:"
		Write-Host "	+ Nutanix CMDlets must be installed on computer running script"
		Write-Host "	+ Nutanix CMDlets snappin must be loaded"
		Write-Host "	+ Execution policy must be set to un-restricted"
		Write-Host "	+ Remote powershell must be enabled"
		Write-Host "	+ Target machine(s) must be joined to a Windows domain"
		Write-Host "	+ The hostname must be able to be resolved via DNS"
		Write-Host "	+ VM name must match the Windows hostname (non-fqdn)"
		Write-Host "	+ Must be running NOS version 4.1.3 or higher"
		
		$input = Read-Host "Do you want to continue? [Y/N]:"
		
		if ($input -ne 'y') {
			break
		}
		
		# Import modules and add snappins
		Import-Module DnsClient
		Add-PSSnapin NutanixCmdletsPSSnapin
		
		if ($(Get-ExecutionPolicy) -ne 'Unrestricted') {
			Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force -Confirm:$false
		}
		
		# Defaults
		if ([string]::IsNullOrEmpty($vm)) {
			[array]$vm = Read-Host "Please enter a comma separated list of Nutanix VM name(s) to configure: "
		}
		
		if ([string]::IsNullOrEmpty($nutanixIP)) {
			$nutanixIP = Read-Host Read-Host "Please enter the IP of a Nutanix CVM: "
		}
		
		if ([string]::IsNullOrEmpty($diskQty)) {
			$diskQty = 8
		}
		
		if ([string]::IsNullOrEmpty($diskSize)) {
			$diskSize = "2048G"
		}
		
		if ([string]::IsNullOrEmpty($numPaths)) {
			$numPaths = 3
		}
		
		# Retry var
		$maxRetry = 3
		
		# Connect to Nutanix cluster via SSH
		Write-Host "Connecting to Nutanix SSH..."
		NTNX-Connect-SSH -ip $nutanixIP -credential $(Get-Credential -Message "Please enter the Nutanix CVM SSH credentials <nutanix/*******>")
		
		# Connect to Prism for Nutanix CMDlets
		Write-Host "Connecting to Nutanix Prism..."
		NTNX-Connect-NTNX -ip $nutanixIP -credential $(Get-Credential -Message "Please enter the Nutanix Prism credentials <admin/*******>")
			
		# Get admin credential to connect to hosts with
		$osCred = Get-Credential -Message "Please input the Windows credentials which has administrative access to the VMs to be configured"
		
		# Perform string formatting for VM names
		$vm = $vm.Split(',').Trim()
		
		Write-Host "Found $($vm.length) VM input(s)..."
		
		# Get Nutanix VM objects for searching
		$ntnxVM = Get-NTNXVM
		
		# Get host objects
		$hosts = Get-NTNXHost
		
		# Get container objects
		$availCtr = Get-NTNXContainer
		
		if ($availCtr.length -gt 1) {
			$selectedCtr = NTNX-Build-Menu -Title "Please select a container:" -Data $availCtr.name
		} else {
			$selectedCtr = $availCtr.name
		}
	}
	
	process {
		
		# For each VM install and configure iSCSI
		$vm | %{
			$currVM = $_
			Write-Host "Current VM is: $_"
		
			# Try to find VM object
			$vmObj = $ntnxVM |? {$currVM -contains $_.vmName -or $_.ipAddresses -contains $currVM}
			
			if (!$vmObj) {
				Write-Host "Nutanix VM object not found, please verify VM name or IP..."
				return
			}
			
			Write-Host "Found matching input VM $($vmObj.vmName) ..."
			
			Write-Progress -Activity "Configuring VM $($vmObj.vmName)" -PercentComplete 10
			
			# Test DNS vm resolution
			if (Resolve-DnsName -name $vmObj.vmName -QuickTimeout -ErrorAction SilentlyContinue) {
				# Resolution successful, using hostname to connect
				Write-Host "Resolution successful, using hostname to connect..."
				$sessionObj = New-PSSession -ComputerName $vmObj.vmName -Credential $osCred
			} else {
				Write-Host "Resolution un-successful, trying IP address..."
				
				$vmObj.IPAddresses | %{
					[int]$i = 1
					
					# Check for ipv6
					if ($_.IndexOf(':') -gt 0) {
						Write-Host "Found IPv6 address, skipping..."
						return
					}
					
					# Format IP string if vSphere
					$currIP = $_.Split('/')[0]
					
					while ($sessionObj.Availability -ne "Available" -and $i -le $maxRetry) {
						# Try to connect via IP
						Write-Host "Trying IP address $currIP , attempt $i of $maxRetry"
						$sessionObj = New-PSSession -ComputerName $currIP -Credential $osCred
						
						$i+=1
						Write-Host "Sleeping for 5 seconds..."
						Start-Sleep -Seconds 5
					}
				}
			}
			
			if ($sessionObj.Availability -ne "Available") {
				Write-Host "Unable to create session with Windows VM..."
				return
			}
			
			# If there are multiple IP addresses, prompt for selection
			if ($vmObj.IPAddresses.count -gt 1) {
				Write-Host "Multiple IP addresses found, prompting for input..."
				$initiatorIP = NTNX-Build-Menu -Title "Please select a IP address to use for iSCSI:" -Data $vmObj.IPAddresses
				
			} else {
				Write-Host "Single IP address found, using that..."
				$initiatorIP = $vmObj.IPAddresses
			}
			
			# Format IP string if vSphere
			$initiatorIP = $initiatorIP.Split('/')[0]
		
			# Install iSCSI on target VM
			Write-Progress -Activity "Configuring VM ${vmObj.vmName}" -Status "Installing iSCSI and MPIO on target..." -PercentComplete 25
			Invoke-Command -session $sessionObj -ScriptBlock ${function:NTNX-Install-iSCSI}
			
			# Get VM IQN for mapping
			$vmIQN = Invoke-Command -session $sessionObj -ScriptBlock {(Get-InitiatorPort).NodeAddress}
			
			# Create and map volumes
			Write-Progress -Activity "Configuring VM ${currVM.vmName}" -Status "Creating volumes and performing mapping..." -PercentComplete 50
			
			# Format name to all lower
			$vmNameLower = $vmObj.vmName.toLower()
			
			# Create volume group and disks
			NTNX-Create-Volume -volumeName "$vmNameLower-vol" -diskQty $diskQty `
				-diskSize "$diskSize" -container $selectedCtr -initiatorIQN $vmIQN `
				-sshSessionID $((Get-SshSession | where {$_.Host -match $nutanixIP}).SessionId | Select-Object -first 1) | Out-Null
			
			# Configure iSCSI and format devices
			
			# Find host for VM
			$vmHost = $hosts | where {$vmObj.hostName -match $_.name}
			Write-Host "VM host is $($vmHost.name)"
			
			# Find local CVM
			$activePath = $vmHost.serviceVMExternalIP
			Write-Host "Local path IP: is $activePath"
			
			# Choose random standby CVM
			$standbyPath = Get-Random ($hosts.serviceVMExternalIP -ne $vmCVMIP) -Count $($numPaths-1)
			Write-Host "Standby Path IP(s): $standbyPath"
			
			# Configure iSCSI on host
			Write-Host "Configuring iSCSI on VM with active Path: $activePath and standby Path: $standbyPath"
			Write-Progress -Activity "Configuring VM ${currVM.vmName}" -Status "Configuring iSCSI targets on VM..." -PercentComplete 75
			Invoke-Command -session $sessionObj -ScriptBlock `
				${function:NTNX-Conf-iSCSI} -ArgumentList $activePath, $standbyPath, $initiatorIP
				
			Write-Progress -Activity "Configuring VM ${currVM.vmName}" -Status "Configuration of VM ${currVM.vmName} complete..." -PercentComplete 100
			
			# Clean up session
			$sessionObj = $null
		}
	
	}
	
	end {
		Write-Host "Configuration complete, clearing up sessions..."
	
		# Cleanup sessions and disconnect
		Disconnect-NutanixCluster -NutanixClusters $(Get-NutanixCluster)
		
		# Close SSH sessions
		Get-SshSession | Remove-SshSession | Out-Null
	}
	
}

#endregion

# Execute driver function
NTNX-Execute-iSCSI
