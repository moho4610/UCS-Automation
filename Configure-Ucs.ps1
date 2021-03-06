<#
.SYNOPSIS
Configure-Ucs, Configure UCS from Excel Spreadsheet
.DESCRIPTION
Configure-Ucs, Configure UCS from Excel Spreadsheet.NOTES

.PARAMETER Ucs
The UCS hostame or IP address
.PARAMETER UcsUser
A UCS user name 
.PARAMETER UcsPass
The user's password
.PARAMETER ConfigFile
Excel file with UCS configuration information
.PARAMETER Equipment
Switch to process Equipment sheet
.PARAMETER Servers
Switch to process Servers sheet
.PARAMETER LAN
Switch to process LAN sheet
.PARAMETER SAN
Switch to process SAN sheet
.PARAMETER VM
Switch to process VM sheet
.PARAMETER Admin
Switch to process Admin sheet
.PARAMETER Clean
Remove Orgs, Vlans, VSans, Dns, Ntp, Mgmt IP Pool, Port channels, Uplinks, Server links
.EXAMPLE
Configure-Ucs.ps1 -Ucs 10.10.20.30 -UcsUser admin -UcsPass admin123 -ConfigFile F:\UCS-Configs\UCS-Pod1-Ucs1-Settings.xslx -Equipment -Servers -LAN -SAN -VM -Admin
  Configures the UCS 10.10.20.30 based on the Settings in the ConfigFile on the sheets Equipment, Servers, LAN, SAN, VM, and Admin
#>

param(
    [Parameter(Mandatory=$true,HelpMessage="Enter a UCS hostname or IP address")]
      [string] $Ucs,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter UCS user")]
      [string] $UcsUser,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter UCS user's Password")]
      [string] $UcsPass,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter a Configuration File")]
      [string] $ConfigFile,
            
    [switch] $Equipment,
    [switch] $Servers,
    [switch] $LAN,
    [switch] $SAN,
    [switch] $VM,
    [switch] $Admin,
    [switch] $Clean
);

# Read in configurations
$Excel = New-Object -comobject Excel.Application
$Excel.Visible = $False
$Excel.displayalerts=$False
$Workbook = $Excel.Workbooks.Open($ConfigFile)

  if ($Equipment) {
    $ucsEquipmentSettingsFile = "C:\UCS-EquipmentSettings.csv"
    $Sheet = $Workbook.Worksheets.Item("Equipment")
    $Sheet.SaveAs($ucsEquipmentSettingsFile,6)
    $ucsEquipmentSettings = Import-Csv -Delimiter ',' -Path $ucsEquipmentSettingsFile
    #$ucsEquipmentSettings
  }

  if ($Servers) {  
    $ucsServersSettingsFile = "C:\UCS-ServersSettings.csv"
    $Sheet = $Workbook.Worksheets.Item("Servers")
    $Sheet.SaveAs($ucsServersSettingsFile,6)
    $ucsServersSettings = Import-Csv -Delimiter ',' -Path $ucsServersSettingsFile
    #$ucsServersSettings
  }

  if ($LAN) {  
    $ucsLANSettingsFile = "C:\UCS-LANSettings.csv"  
    $Sheet = $Workbook.Worksheets.Item("LAN")
    $Sheet.SaveAs($ucsLANSettingsFile,6)
    $ucsLANSettings = Import-Csv -Delimiter ',' -Path $ucsLANSettingsFile
    #$ucsLANSettings
  }

  if ($SAN) {  
    $ucsSANSettingsFile = "C:\UCS-SANSettings.csv"  
    $Sheet = $Workbook.Worksheets.Item("SAN")
    $Sheet.SaveAs($ucsSANSettingsFile,6)
    $ucsSANSettings = Import-Csv -Delimiter ',' -Path $ucsSANSettingsFile
    #$ucsSANSettings
  }

  if ($VM) {
    $ucsVMSettingsFile = "C:\UCS-VMSettings.csv"  
    $Sheet = $Workbook.Worksheets.Item("VM")
    $Sheet.SaveAs($ucsVMSettingsFile,6)
    $ucsVMSettingsFile = Import-Csv -Delimiter ',' -Path $ucsVMSettingsFile
    #$ucsVMSettingsFile
  }
  
  if ($Admin) {
    $ucsAdminSettingsFile = "C:\UCS-AdminSettings.csv"  
    $Sheet = $Workbook.Worksheets.Item("Admin")
    $Sheet.SaveAs($ucsAdminSettingsFile,6)
    $ucsAdminSettings = Import-Csv -Delimiter ',' -Path $ucsAdminSettingsFile
    #$ucsAdminSettings
  }
  
$Excel.Quit()

If(ps excel){kill -name excel}

# Connect to UCS
  $password = convertto-securestring -Force -AsPlainText $UcsPass
  $credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $UcsUser,$password;
  $ucsConn =  Connect-Ucs $Ucs -Credential $credentials -NotDefault;

# Process Admin Settings
if ($Admin) {
  foreach ($ucsAdminSetting in $ucsAdminSettings) { 

    # Time Zone
    # *actual time cannot be set via PowerShell
    if ($ucsAdminSetting.Component -eq "TimeZone") {
      Get-UcsSvcEp -Ucs $ucsConn | Set-UcsTimezone -Ucs $ucsConn -Timezone $ucsAdminSetting.Setting_01 -Force
    }  

    # DNS
    # Only IP Addresses are accepted
    if ($ucsAdminSetting.Component -eq "DNS") {
     Get-Ucsdns -Ucs $ucsConn | Add-UcsDnsServer -Ucs $ucsConn -Name $ucsAdminSetting.Setting_01 -ModifyPresent
    }

    # NTP Servers
    if ($ucsAdminSetting.Component -eq "NTP") {
     Get-UcsTimeZone -Ucs $ucsConn | Add-UcsNtpServer -Ucs $ucsConn -Name $ucsAdminSetting.Setting_01 -ModifyPresent
    }

    # Management IP Pool Blocks
    if ($ucsAdminSetting.Component -eq "MgmtIPPool") {
      Get-UcsIpPool -Ucs $ucsConn -Name ext-mgmt | Add-UcsIpPoolBlock -Ucs $ucsConn -From $ucsAdminSetting.Setting_01 -To $ucsAdminSetting.Setting_02 -DefGw $ucsAdminSetting.Setting_03 -Subnet $ucsAdminSetting.Setting_04 -ModifyPresent
    }
    
    # Organizations
    if ($ucsAdminSetting.Component -eq "Org") {
      Add-UcsOrg -Ucs $ucsConn -Name $ucsAdminSetting.Setting_01 -Descr $ucsAdminSetting.Setting_02 -ModifyPresent
    }
  }
}

# Process Equipment Settings
if ($Equipment) {
  foreach ($ucsEquipmentSetting in $ucsEquipmentSettings) { 

    # Chassis Discovery Policy
    # -Action - "1-link,2-link,4-link,8-link,immediate,platform-max,user-acknowledged"
    # -LinkAggregationPref - "none,port-channel"
    if ($ucsEquipmentSetting.Component -eq "ChassisDiscovery") {
      Get-UcsChassisDiscoveryPolicy -Ucs $ucsConn | Set-UcsChassisDiscoveryPolicy -Ucs $ucsConn -Action $ucsEquipmentSetting.Setting_01 -LinkAggregationPref $ucsEquipmentSetting.Setting_02 -Force
    }
  
    # Power Supply Policy
    # -Redundancy - "grid,n+1,non-redundant"
    if ($ucsEquipmentSetting.Component -eq "PowerControl") {
      Get-UcsPowerControlPolicy -Ucs $ucsConn | Set-UcsPowerControlPolicy -Ucs $ucsConn -Redundancy $ucsEquipmentSetting.Setting_01 -Force
    }
    
    if ($ucsEquipmentSetting.Component -eq "ServerPort") {
      Get-UcsFabricServerCloud -Ucs $ucsConn -Id $ucsEquipmentSetting.Setting_01 | Add-UcsServerPort -Ucs $ucsConn -PortId $ucsEquipmentSetting.Setting_02 -SlotId $ucsEquipmentSetting.Setting_03 -UsrLbl $ucsEquipmentSetting.Setting_04
    }

    if ($ucsEquipmentSetting.Component -eq "UplinkPort") {
      Get-UcsFiLanCloud -Ucs $ucsConn -Id $ucsEquipmentSetting.Setting_01 | Add-UcsUplinkPort -Ucs $ucsConn -PortId $ucsEquipmentSetting.Setting_02 -SlotId $ucsEquipmentSetting.Setting_03 -UsrLbl $ucsEquipmentSetting.Setting_04
    }
  }
}

# Process LAN Settings
if ($LAN) {
  foreach ($ucsLANSetting in $ucsLANSettings) {
  
    # PortChannels
    if ($ucsLANSetting.Component -eq "PortChannel") {
      Get-UcsFiLanCloud -Ucs $ucsConn -Id $ucsLANSetting.Setting_01 | Add-UcsUplinkPortChannel -Ucs $ucsConn -Name $ucsLANSetting.Setting_02 -PortId $ucsLANSetting.Setting_03 -AdminState $ucsLANSetting.Setting_04 -ModifyPresent
    }

    # Port Channel Members
    if ($ucsLANSetting.Component -eq "PortChannelMember") {
      Get-UcsUplinkPortChannel -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 | Add-UcsUplinkPortChannelMember -Ucs $ucsConn -PortId $ucsLANSetting.Setting_02 -SlotId $ucsLANSetting.Setting_03 -ModifyPresent
    }
    
    # VLANs
    if ($ucsLANSetting.Component -eq "VLAN") {
      Get-UcsLanCloud -Ucs $ucsConn | Add-UcsVlan -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 -Id $ucsLANSetting.Setting_02 -ModifyPresent
    }
	
	# VLAN Groups
    if ($ucsLANSetting.Component -eq "VLANGroup") {
      Get-UcsLanCloud -Ucs $ucsConn | Add-UcsFabricNetGroup -Ucs $ucsConn -Name $ucsLANSetting.Setting_01
    }
	
	# VLAN Group Port-Channel
    if ($ucsLANSetting.Component -eq "VLANGroup-PC") {
      Get-UcsLanCloud -Ucs $ucsConn | Get-UcsFabricNetGroup -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 | Add-UcsVlanMemberPortChannel -Ucs $ucsConn -PortId $ucsLANSetting.Setting_02 -SwitchId $ucsLANSetting.Setting_03 -AdminState "enabled" -ModifyPresent
    }
	
	# VLAN Group Vlans
    if ($ucsLANSetting.Component -eq "VLANGroup-VLAN") {
      Get-UcsLanCloud -Ucs $ucsConn | Get-UcsFabricNetGroup -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 | Add-UcsFabricPooledVlan -Name $ucsLANSetting.Setting_02
    }
    
	
    # MAC Pools
    if ($ucsLANSetting.Component -eq "MACPool") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 | Add-UcsMacPool -Ucs $ucsConn -Name $ucsLANSetting.Setting_02 -Descr $ucsLANSetting.Setting_03 -ModifyPresent | Add-UcsMacMemberBlock -Ucs $ucsConn -From $ucsLANSetting.Setting_04 -To $ucsLANSetting.Setting_05 -ModifyPresent
    }

    # VNIC Templates
    if ($ucsLANSetting.Component -eq "VNICTemplate") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 | Add-UcsVnicTemplate -Ucs $ucsConn -Name $ucsLANSetting.Setting_02 -IdentPoolName $ucsLANSetting.Setting_03 -SwitchId $ucsLANSetting.Setting_04 -Target $ucsLANSetting.Setting_05 -TemplType $ucsLANSetting.Setting_06 -PinToGroupName $ucsLANSetting.Setting_07  -ModifyPresent
    }
    
    # VNIC Template VLANs
    if ($ucsLANSetting.Component -eq "VNICTemplateVLAN") {
      "Trying"
      Get-UcsOrg -Ucs $ucsConn -Name $ucsLANSetting.Setting_01 | Get-UcsVnicTemplate -Ucs $ucsConn -Name $ucsLANSetting.Setting_02 | Add-UcsVnicInterface -Ucs $ucsConn -Name $ucsLANSetting.Setting_03 -ModifyPresent
    }  

	# LAN Pin Groups
    if ($ucsLANSetting.Component -eq "LANPinGroup") {
      Add-UcsEthernetPinGroup  -Ucs $ucsConn -Name $ucsLANSetting.Setting_01
    }
	
	# LAN Pin Group Pinning
    if ($ucsLANSetting.Component -eq "LANPinGroup_pin") {
      Get-UcsEthernetPinGroup -Name $ucsLANSetting.Setting_01 -Ucs $ucsConn | Add-UcsEthernetPinGroupTarget -FabricId $ucsLANSetting.Setting_02 -EpDn $ucsLANSetting.Setting_03
    }
		
  }
}

# Process SAN Settings
if ($SAN) {
  foreach ($ucsSANSetting in $ucsSANSettings) {
      
    # VLANs
    if ($ucsSANSetting.Component -eq "VSAN") {
      Get-UcsFiSanCloud -Ucs $ucsConn -Id $ucsSANSetting.Setting_01 | Add-UcsVsan -Ucs $ucsConn -Name $ucsSANSetting.Setting_02 -FcoeVlan $ucsSANSetting.Setting_03 -id $ucsSANSetting.Setting_04 -ModifyPresent
    }
    
	# FC Uplink Port-channel
	if ($ucsSANSetting.Component -eq "FcUplinkPC") {
      Get-UcsFiSanCloud -Ucs $ucsConn -Id $ucsSANSetting.Setting_01 | Add-UcsFcUplinkPortChannel -Ucs $ucsConn -Name $ucsSANSetting.Setting_02  -PortId $ucsSANSetting.Setting_03
    }
	
	# FC Uplink Port-channel Members
	if ($ucsSANSetting.Component -eq "FcUplinkPCMember") {
     Get-UcsFiSanCloud -Ucs $ucsConn -Id $ucsSANSetting.Setting_01 | Get-UcsFcUplinkPortChannel -Ucs $ucsConn -PortId $ucsSANSetting.Setting_02 | Add-UcsFabricFcSanPcEp -Ucs $ucsConn -PortId $ucsSANSetting.Setting_03 -SlotId $ucsSANSetting.Setting_04
	 }
	
	# FC Pin Groups
	if ($ucsSANSetting.Component -eq "FcPinGroup") {
     Add-UcsFcPinGroup -Ucs $ucsConn -Name $ucsSANSetting.Setting_01 | Add-UcsFcPinGroupTarget -Ucs $ucsConn -FabricId $ucsSANSetting.Setting_02 -EpDn $ucsSANSetting.Setting_03
	 }
	
	
    # WWNN Pools
    if ($ucsSANSetting.Component -eq "WWNNPool") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsSANSetting.Setting_01 | Add-UcsWwnPool -Ucs $ucsConn -Name $ucsSANSetting.Setting_02 -Purpose node-wwn-assignment -Descr $ucsSANSetting.Setting_03 -ModifyPresent | Add-UcsWwnMemberBlock -Ucs $ucsConn -From $ucsSANSetting.Setting_04 -To $ucsSANSetting.Setting_05 -ModifyPresent
    }
    
    # WWPN Pools
    if ($ucsSANSetting.Component -eq "WWPNPool") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsSANSetting.Setting_01 | Add-UcsWwnPool -Ucs $ucsConn -Name $ucsSANSetting.Setting_02 -Purpose port-wwn-assignment -Descr $ucsSANSetting.Setting_03 -ModifyPresent | Add-UcsWwnMemberBlock -Ucs $ucsConn -From $ucsSANSetting.Setting_04 -To $ucsSANSetting.Setting_05 -ModifyPresent
    }
    
    # VHBA Templates
    if ($ucsSANSetting.Component -eq "VHBATemplate") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsSANSetting.Setting_01 | Add-UcsVhbaTemplate -Ucs $ucsConn -Name $ucsSANSetting.Setting_02 -Descr $ucsSANSetting.Setting_03 -IdentPoolName $ucsSANSetting.Setting_04 -SwitchId $ucsSANSetting.Setting_05 -TemplType $ucsSANSetting.Setting_06 -ModifyPresent | Add-UcsVhbaInterface -Ucs $ucsConn -Name $ucsSANSetting.Setting_07 -ModifyPresent
    }    
  }
}   

# Process Servers Settings
if ($Servers) {
  foreach ($ucsServersSetting in $ucsServersSettings) {
  
    # UUID Pools
    if ($ucsServersSetting.Component -eq "UUIDPool") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsUuidSuffixPool -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -Prefix $ucsServersSetting.Setting_04 -ModifyPresent | Add-UcsUuidSuffixBlock -Ucs $ucsConn -From $ucsServersSetting.Setting_05 -To $ucsServersSetting.Setting_06 -ModifyPresent
    }

    # Server Pools
    if ($ucsServersSetting.Component -eq "ServerPool") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsServerPool -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -ModifyPresent
    }

    # Server Pool Qualification
    if ($ucsServersSetting.Component -eq "ServerPoolQualification") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsServerPoolQualification -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -ModifyPresent | Add-UcsChassisQualification -Ucs $ucsConn -MinId $ucsServersSetting.Setting_04 -MaxId $ucsServersSetting.Setting_05 -ModifyPresent
    }

    # Server Pool Policy
    if ($ucsServersSetting.Component -eq "ServerPoolPolicy") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsServerPoolPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -PoolDn (Get-UcsOrg -Ucs $ucsConn $ucsServersSetting.Setting_01 | Get-UcsServerPool -Ucs $ucsConn -Name $ucsServersSetting.Setting_04 | select Dn).Dn -Qualifier $ucsServersSetting.Setting_05 -ModifyPresent
    }       

    # BIOS Policy
    if ($ucsServersSetting.Component -eq "BIOSPolicy") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsBiosPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -RebootOnUpdate $ucsServersSetting.Setting_04 -ModifyPresent
    }       

    # BIOS Policy Setting - VfQuietBoot

    if ($ucsServersSetting.Component -eq "BIOSPolicySettingVfQuietBoot") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsBiosPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Set-UcsBiosVfQuietBoot -Ucs $ucsConn -VpQuietBoot $ucsServersSetting.Setting_03 -Force
    }
    
    # IPMI Policy
    if ($ucsServersSetting.Component -eq "IPMIPolicy") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsIpmiAccessProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -ModifyPresent | Add-UcsAaaEpUser -Ucs $ucsConn -Name $ucsServersSetting.Setting_04 -Priv $ucsServersSetting.Setting_05 -Pwd $ucsServersSetting.Setting_06 -ModifyPresent
    }
    
    # Local Disk Policy
    if ($ucsServersSetting.Component -eq "LocalDiskPolicy") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsLocalDiskConfigPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -Mode $ucsServersSetting.Setting_04 -ProtectConfig $ucsServersSetting.Setting_05 -FlexFlashRAIDReportingState $ucsServersSetting.Setting_06 -FlexFlashState $ucsServersSetting.Setting_07 -ModifyPresent
    }
    
    # SOL Policy
    if ($ucsServersSetting.Component -eq "SOLPolicy") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsSolPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -AdminState $ucsServersSetting.Setting_04 -Speed $ucsServersSetting.Setting_05 -ModifyPresent    
    }

    # Boot Policy
    if ($ucsServersSetting.Component -eq "BootPolicy") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsBootPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Descr $ucsServersSetting.Setting_03 -EnforceVnicName $ucsServersSetting.Setting_04 -RebootOnUpdate $ucsServersSetting.Setting_05 -ModifyPresent
    }
    
    # Boot Policy SAN Storage
    if ($ucsServersSetting.Component -eq "BootPolicySAN") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsBootPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsLsbootStorage -Ucs $ucsConn -Order $ucsServersSetting.Setting_03 -ModifyPresent | Add-UcsLsbootSanImage -Ucs $ucsConn -Type $ucsServersSetting.Setting_04 -VnicName $ucsServersSetting.Setting_05 -ModifyPresent | Add-UcsLsbootSanImagePath -Ucs $ucsConn -Type $ucsServersSetting.Setting_06 -Lun $ucsServersSetting.Setting_07 -Wwn $ucsServersSetting.Setting_08 -ModifyPresent
    }
    
    # Boot Policy LAN
    if ($ucsServersSetting.Component -eq "BootPolicyLAN") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsBootPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsLsbootLan -Ucs $ucsConn -Order $ucsServersSetting.Setting_03 -ModifyPresent | Add-UcsLsbootLanImagePath -Ucs $ucsConn -VnicName $ucsServersSetting.Setting_04 -Type $ucsServersSetting.Setting_05 -ModifyPresent
    }

    # Boot Policy Virtual Media
    if ($ucsServersSetting.Component -eq "BootPolicyVirtualMedia") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsBootPolicy -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsLsbootVirtualMedia -Ucs $ucsConn -Order $ucsServersSetting.Setting_03 -Access $ucsServersSetting.Setting_04 -ModifyPresent
    }
    
    # Service Profile Template
    if ($ucsServersSetting.Component -eq "ServiceProfileTemplate") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Add-UcsServiceProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 -Type $ucsServersSetting.Setting_03 -Descr $ucsServersSetting.Setting_04 -BiosProfileName $ucsServersSetting.Setting_05 -BootPolicyName $ucsServersSetting.Setting_06 -IdentPoolName $ucsServersSetting.Setting_07 -LocalDiskPolicyName $ucsServersSetting.Setting_08 -SolPolicyName $ucsServersSetting.Setting_09 -MgmtAccessPolicyName $ucsServersSetting.Setting_10 -ModifyPresent
    }
    
    # Service Profile Vnic
    if ($ucsServersSetting.Component -eq "ServiceProfileTemplateVnic") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsServiceProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsVnic -Ucs $ucsConn -Name $ucsServersSetting.Setting_03 -NwTemplName $ucsServersSetting.Setting_04 -AdaptorProfileName $ucsServersSetting.Setting_05  -ModifyPresent
    }

    # Service Profile Vhba
    if ($ucsServersSetting.Component -eq "ServiceProfileTemplateVhba") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsServiceProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsVhba -Ucs $ucsConn -Name $ucsServersSetting.Setting_03 -NwTemplName $ucsServersSetting.Setting_04 -AdaptorProfileName $ucsServersSetting.Setting_05 -ModifyPresent
    }

    # Service Profile Fc Node
    if ($ucsServersSetting.Component -eq "ServiceProfileTemplateFcNode") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsServiceProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsVnicFcNode -Ucs $ucsConn -IdentPoolName $ucsServersSetting.Setting_03 -ModifyPresent
    }   
    
    # Service Profile Fc Node
    if ($ucsServersSetting.Component -eq "ServiceProfileTemplatePool") {
      Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01 | Get-UcsServiceProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsServerPoolAssignment -Ucs $ucsConn -Name $ucsServersSetting.Setting_03 -ModifyPresent
    }
    
    # Service Profile Template Instantiate
    if ($ucsServersSetting.Component -eq "ServiceProfileTemplateInstantiate") {
      $spOrg = Get-UcsOrg -Ucs $ucsConn -Name $ucsServersSetting.Setting_01
      Get-UcsServiceProfile -Ucs $ucsConn -Name $ucsServersSetting.Setting_02 | Add-UcsServiceProfileFromTemplate -Ucs $ucsConn -NewName $ucsServersSetting.Setting_03 -DestinationOrg $spOrg
    }
  }
}
