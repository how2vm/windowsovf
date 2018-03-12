#############################################################################
# Script Purpose: vApp settings												#
# Author: Aram Avetisyan 					#
# Version: 2											     				#
# Release Date: 27.02.2018													#
# Dependency: getvmenv.bat and unattend_no.xml								#
#############################################################################

#File Paths
$firstbootstate = 'C:\Program Files\vmenv\firstboot.state'
$vmlog = 'C:\Program Files\vmenv\vmenv.log'
$getenvbat = 'C:\Program` Files\vmenv\getvmenv.bat'
$vmenvxml = 'C:\Program Files\vmenv\vmenv.xml'
$sysprepnofile = 'C:\Program Files\vmenv\unattend_no.xml'
$sysprepokfile = 'C:\Program Files\vmenv\unattend_ok.xml'
$sysprepexe = "C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /reboot /unattend:'$sysprepokfile'"

# Check Execution state
($vmenvstate = Get-ChildItem $firstbootstate) 2>&1 | out-null 

If ($vmenvstate.Exists) {
    # If state file exists, nothing will happen.
    Write-Output "State file exists. Nothing to do....."
}
Else {
    # Generate Timestamp, Write to Log file and export XML config file
    $vmdate = Get-Date -Format "MMddyyyy-hh:mm"
    Write-Output $vmdate": Fetching config XMLs" >> $vmlog
    Invoke-Expression -Command $getenvbat

    # Import XMLs save those as variables.
    [xml]$vmenv = Get-Content $vmenvxml
    [xml]$vmsysprepenv = Get-Content $sysprepnofile
    # Collect Variables from vmenv XML
    $vmIP = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*_IP*' } | select -expand value
    $vmNetmask = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*Netmask*' } | select -expand value
    $vmGW = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*Gateway*' } | select -expand value
    $vmHostname = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*Hostname*' } | select -expand value
    $vmDNS = $vmenv.Environment.PropertySection.Property | ?{ $_.key -like '*DNS*' } | select -expand value

    # Replace Hostname in Sysprep file and write it to disk
    # If you ahve added nodes to sysprep, make sure array element number is fixed.
    $vmsysprepenv.unattend.settings.Component[2].Computername = "$vmHostname"
    $vmsysprepenv.Save($sysprepokfile)


    # Fetch Network interface name
    $ifname = Get-NetAdapter | Select -expand Name
    #Configure network
    $vmdate = Get-Date -Format "MMddyyyy-hh:mm"
    Write-Output $vmdate": Configuring Network settings" >> $vmlog
    New-NetIPAddress –InterfaceAlias $ifname –IPAddress $vmIP –PrefixLength $vmNetmask -DefaultGateway $vmGW
    Set-DnsClientServerAddress -InterfaceAlias $ifname -ServerAddresses $vmDNS

    # Execute sysprep to change SID and set hostname
    $vmdate = Get-Date -Format "MMddyyyy-hh:mm"
    Write-Output $vmdate": Setting a 10 Seconds timer before rebooting" >> $vmlog
    Write-Output "Sysprep will be executed in 20 seconds. A reboot will follow."
    Start-Sleep -s 20
    $vmdate = Get-Date -Format "MMddyyyy-hh:mm"
    Write-Output $vmdate":FirstBoot Complete" >> $firstbootstate
    Invoke-Expression -Command $sysprepexe
}