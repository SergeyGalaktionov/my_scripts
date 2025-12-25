#======= Stage 0 - Variables ======= 

$ServerName = ''
$DomainName = ''
$Mlnx5Adapter1Name = 'NIC1'
$Mlnx5Adapter2Name = 'NIC2'
$Mlnx5Adapter1ipAddress = ''
$Mlnx5Adapter1DNS1ipAddress = ''
$Mlnx5Adapter1DNS2ipAddress = ''
$Mlnx5AdapterDefaultGW = ''
$SETswitchName = 'SET'
$vEthernetAdapterCL1 = "CL1"
$vEthernetAdapterCL2 = "CL2"
$vEthernetAdapterCL1IpAddress = ''
$vEthernetAdapterCL2IpAddress = ''
$vEthernetAdapterCL1VLAN = ''
$vEthernetAdapterCL2VLAN = ''
$vEthernetAdapterMGMT = 'MGMT'
$ClusterNodes = '', ''
$ClusterName = ''
$ClusterIP = ''


#======= STAGE 1 - Host Configuration =======

# 1.1 Active Memory Dump
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -value 1
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\CrashControl -Name FilterPages -value 1

# 1.2 Power Plan
powercfg /SetActive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c # High Performance

# 1.3 Core Scheduler
bcdedit /set hypervisorschedulertype Core # Classic

# 1.4 Configuring Minroot (резервируем 8 logical processors для root partition)
bcdedit /set hypervisorrootproc 8

# 1.5 Configure Max Evenlope Size to be 8Mb to be able to copy files using PSSession
Set-Item -Path WSMan:\localhost\MaxEnvelopeSizekb -Value 8192

# 1.6 Firewall (Optional)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# 1.7 RDP Access (Optional)
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# 1.8 NICs Config
$Adapters = Get-NetAdapter -Physical | Where-Object {$_.LinkSpeed -match '10 Gbps'}
$Adapters[0] | Rename-NetAdapter -NewName $Mlnx5Adapter1Name
$Adapters[1] | Rename-NetAdapter -NewName $Mlnx5Adapter2Name

New-NetIPAddress -InterfaceAlias $Mlnx5Adapter1Name -AddressFamily IPv4 -IPAddress $Mlnx5Adapter1ipAddress -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias $Mlnx5Adapter1Name -ServerAddresses ($Mlnx5Adapter1DNS1ipAddress, $Mlnx5Adapter1DNS2ipAddress)
New-NetRoute -DestinationPrefix 0.0.0.0/0 -InterfaceAlias $Mlnx5Adapter1Name -NextHop $Mlnx5AdapterDefaultGW
Disable-NetAdapter -Name $Mlnx5Adapter1Name -Confirm:$False
Enable-NetAdapter -Name $Mlnx5Adapter1Name -Confirm:$False

# 1.9 Domain Join
Add-Computer -DomainName $DomainName -Credential (Get-Credential) -NewName $ServerName -Restart -Force

# 1.10 Enable Secured Core - Optional
# 1.10.1 Device Guard
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 1 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d 3 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequireMicrosoftSignedBootChain" /t REG_DWORD /d 1 /f

# 1.10.2 Credential Guard
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 2 /f

# 1.10.3 HVCI
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "HVCIMATRequired" /t REG_DWORD /d 1 /f

# 1.10.4 DMA Protection
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DmaSecurity" /v "DmaProtection" /t REG_DWORD /d 1 /f # нужна поддержка DMA Remapping, может конфликтовать с HBA и RAID контроллерами


# 1.11 Regional Settings
Set-TimeZone -ID "Russian Standard Time"
Set-WinHomeLocation -GeoId 203
Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

#======= STAGE 2 - Roles and Features ======= 

# 2.1 Enable Roles and Features
Install-WindowsFeature -Name 'Hyper-V' -IncludeAllSubFeature -IncludeManagementTools
Install-WindowsFeature -Name 'NetworkVirtualization' -IncludeManagementTools
Install-WindowsFeature -Name 'Failover-Clustering' -IncludeAllSubFeature -IncludeManagementTools
Install-WindowsFeature -Name 'Data-Center-Bridging' -IncludeManagementTools
Install-WindowsFeature -Name 'FS-SMBBW'
Install-WindowsFeature -Name 'BitLocker' -IncludeManagementTools
Install-WindowsFeature -Name 'System-Insights'
Install-WindowsFeature -Name 'Multipath-IO' -IncludeManagementTools

Restart-Computer -Force

# 2.2 Enable MPIO for FC
Enable-MSDSMAutomaticClaim -BusType FC

# 2.3 Add Hardware ID for Dell Compellent
New-MSDSMSupportedHW -VendorId "COMPELNT" -ProductId "Compellent Vol"

# 2.4 Set default load balance policy
Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR  # Round Robin

# 2.5 MPIO Registry Settings (Dell Storage рекомендации)
$MpioRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mpio\Parameters"

Set-ItemProperty -Path $MpioRegPath -Name "PDORemovePeriod" -Value 120
Set-ItemProperty -Path $MpioRegPath -Name "PathRecoveryInterval" -Value 25
Set-ItemProperty -Path $MpioRegPath -Name "UseCustomPathRecoveryInterval" -Value 1
Set-ItemProperty -Path $MpioRegPath -Name "PathVerifyEnabled" -Value 1
Set-ItemProperty -Path $MpioRegPath -Name "DiskPathCheckInterval" -Value 25

Restart-Computer -Force


#======= STAGE 3 - NIC's Advanced Properties =======

# 3.1 Nic's Properties (Mellanox) для другового вендора может отличаться
Reset-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName * -ErrorAction SilentlyContinue
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*Encapsulation Overhead*" -RegistryValue "0" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Encapsulated Task Offload" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*NVGRE Encapsulated Task Off*" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*VXLAN Encapsulated Task Off*" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*Flow Control*" -RegistryValue "0" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*Interrupt Moderation*" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*IPV4 Checksum Offload*" -RegistryValue "3" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Jumbo Packet" -RegistryValue "9014" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Large Send Offload V2 (IPv4)" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Large Send Offload V2 (IPv6)" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*Maximum number of RSS Proce*" -RegistryValue "16" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "NetworkDirect Functionality" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "NetworkDirect Technology" -RegistryValue "4"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Preferred NUMA Node" -RegistryValue "65535" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Maximum Number of RSS Queues" -RegistryValue "16" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Packet Direct" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Priority & Vlan Tag" -RegistryValue "3" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "PTP Hardware Timestamp" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Quality Of Service" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "QOS Offload" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Supported traffic classes*" -RegistryValue "255"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Receive Buffers" -RegistryValue "2048" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Recv Segment Coalescing (IPv4)" -RegistryValue "0"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Recv Segment Coalescing (IPv6)" -RegistryValue "0"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Receive Side Scaling" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "RSS Base Processor Number" -RegistryValue "0" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Virtual Switch RSS" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "RSS Load Balancing Profile" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "SR-IOV" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "TCP/UDP Checksum Offload (IPv4)" -RegistryValue "3" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "TCP/UDP Checksum Offload (IPv6)" -RegistryValue "3" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Send Buffers" -RegistryValue "2048"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "UDP Segmentation Offload(IPv4)" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "UDP Segmentation Offload(IPv6)" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Virtual Machine Queues" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "VMQ VLAN Filtering" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "VXLAN UDP destination port number" -RegistryValue "4789" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "DcbxMode" -RegistryValue "0"
Remove-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -RegistryKeyword "DevxEnabled"
Remove-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -RegistryKeyword "DisableLocalLoopbackFlags"
Remove-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -RegistryKeyword "NetworkAddress"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Receive Completion Method" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*Network Direct Maximum Transmission Unit*" -RegistryValue "4096"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Rx Interrupt Moderation Type" -RegistryValue "2" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Rx Interrupt Moderation Profile" -RegistryValue "1"
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Send Completion Method" -RegistryValue "1" ## нет в ConnectX-6 Lx
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "Tx Interrupt Moderation Profile" -RegistryValue "1" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "VLAN ID" -RegistryValue "0" 
Set-NetAdapterAdvancedProperty -Name $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -DisplayName "*MultiPrioSq*" -RegistryValue "1"
Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disabled

#======= STAGE 4 - RDMA Config (Optional) =======

# 4.1 VLAN-based PFC
Remove-NetQosTrafficClass
Remove-NetQosPolicy -Confirm:$False
Set-NetQosDcbxSetting -Willing $False -Confirm:$False # (Global)
Set-NetQosDcbxSetting -InterfaceAlias $Mlnx5Adapter1Name -Willing $False -Confirm:$False
Set-NetQosDcbxSetting -InterfaceAlias $Mlnx5Adapter2Name -Willing $False -Confirm:$False
New-NetQosPolicy -Name "SMBDirect" -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3 # (лучше использовать -SMB но на него ругается Validate-DC)
New-NetQosPolicy -Name "Cluster" -Cluster -PriorityValue8021Action 7
New-NetQosPolicy -Name "Default" -Default -PriorityValue8021Action 0

Enable-NetQosFlowControl -Priority 3 #(можно и 7 - не обязательно для кластерного трафика обеспечивать lossless)
Disable-NetQosFlowControl -Priority 0,1,2,4,5,6,7

Enable-NetAdapterQos -Name $Mlnx5Adapter1Name
Enable-NetAdapterQos -Name $Mlnx5Adapter2Name
New-NetQosTrafficClass "SMBDirect" -Priority 3 -BandwidthPercentage 50 -Algorithm ETS
New-NetQosTrafficClass "Cluster" -Priority 7 -BandwidthPercentage 1 -Algorithm ETS #(для 10 Gbps = 2%, для 25 Gbps = 1%)

#======= STAGE 5 - Virtual Switch =======

# 5.1 New VMSwitch
New-VMSwitch -Name $SETswitchName -NetAdapterName $Mlnx5Adapter1Name,$Mlnx5Adapter2Name -AllowManagementOS $true -EnableEmbeddedTeaming $true -MinimumBandwidthMode Weight  # -EnableIov $true (требует -MinimumBandwidthMode None для SCVMM)
Set-VMSwitch -Name $SETswitchName -EnableRscOffload 1
Set-VMSwitch -Name $SETswitchName -DefaultQueueVmmqEnabled $true -DefaultQueueVrssQueueSchedulingMode Dynamic # (SCVMM ставит DefaultQueueVrssQueueSchedulingMode в Static, в 2022 по дефолту VMMQ,VRSS включены)

# 5.2 Management vNICs
Get-VMNetworkAdapter -ManagementOS | Rename-VMNetworkAdapter -NewName $vEthernetAdapterMGMT
Get-NetAdapter -Name "vEthernet (MGMT)" | Rename-NetAdapter -NewName $vEthernetAdapterMGMT
Disable-NetAdapterBinding -InterfaceAlias $vEthernetAdapterMGMT -ComponentID ms_tcpip6

# 5.3 Cluster vNICs
Add-VMNetworkAdapter -ManagementOS -SwitchName $SETswitchName -Name $vEthernetAdapterCL1
Add-VMNetworkAdapter -ManagementOS -SwitchName $SETswitchName -Name $vEthernetAdapterCL2

Get-NetAdapter -Name "vEthernet (CL1)" | Rename-NetAdapter -NewName $vEthernetAdapterCL1
Get-NetAdapter -Name "vEthernet (CL2)" | Rename-NetAdapter -NewName $vEthernetAdapterCL2

Set-DnsClient -InterfaceAlias  $vEthernetAdapterCL1 -RegisterThisConnectionsAddress $false
Set-DnsClient -InterfaceAlias  $vEthernetAdapterCL2 -RegisterThisConnectionsAddress $false

Disable-NetAdapterBinding -InterfaceAlias $vEthernetAdapterCL1 -ComponentID ms_tcpip6
Disable-NetAdapterBinding -InterfaceAlias $vEthernetAdapterCL2 -ComponentID ms_tcpip6

New-NetIPAddress -InterfaceAlias $vEthernetAdapterCL1 -AddressFamily IPv4 -IPAddress $vEthernetAdapterCL1IpAddress -PrefixLength 24
New-NetIPAddress -InterfaceAlias $vEthernetAdapterCL2 -AddressFamily IPv4 -IPAddress $vEthernetAdapterCL2IpAddress -PrefixLength 24

Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName $vEthernetAdapterCL1 -Access -VlanId $vEthernetAdapterCL1VLAN
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName $vEthernetAdapterCL2 -Access -VlanId $vEthernetAdapterCL2VLAN

Set-VMNetworkAdapter -ManagementOS -VMNetworkAdapterName $vEthernetAdapterCL1 -IeeePriorityTag On
Set-VMNetworkAdapter -ManagementOS -VMNetworkAdapterName $vEthernetAdapterCL2 -IeeePriorityTag On

Set-VMNetworkAdapter -Name $vEthernetAdapterCL1 -ManagementOS -VmmqEnabled $true # в 2022 по дефолту VMMQ,VRSS включены
Set-VMNetworkAdapter -Name $vEthernetAdapterCL2 -ManagementOS -VmmqEnabled $true

Set-VMNetworkAdapterTeamMapping -ManagementOS -VMNetworkAdapterName $vEthernetAdapterCL1 -PhysicalNetAdapterName $Mlnx5Adapter1Name
Set-VMNetworkAdapterTeamMapping -ManagementOS -VMNetworkAdapterName $vEthernetAdapterCL2 -PhysicalNetAdapterName $Mlnx5Adapter2Name

# 5.4 Jumbo Frames
Set-NetAdapterAdvancedProperty -Name $vEthernetAdapterCL1 -RegistryKeyword *JumboPacket -RegistryValue 9014
Set-NetAdapterAdvancedProperty -Name $vEthernetAdapterCL2 -RegistryKeyword *JumboPacket -RegistryValue 9014

# 5.5 Enable RDMA on ManagementOS Cluster vNics (Optional)
Get-NetAdapter -Name $vEthernetAdapterCL1,$vEthernetAdapterCL2 | Enable-NetAdapterRdma
Disable-NetAdapter -Name $vEthernetAdapterCL1,$vEthernetAdapterCL2 -Confirm:$False
Enable-NetAdapter -Name $vEthernetAdapterCL1,$vEthernetAdapterCL2 -Confirm:$False

# 5.6 Disable NetBIOS on NICs
$NetBIOSAdapters=(Get-WmiObject Win32_NetworkAdapterConfiguration -filter IPEnabled=TRUE)
Foreach ($NetBIOSAdapter in $NetBIOSAdapters)
{
  Write-Host $NetBIOSAdapter
  $NetBIOSAdapter.settcpipnetbios(2)
}

# 5.7 Enable BitLocker - OS Drive (GPO Settings должны быть описаны)
Enable-BitLocker "C:" -RecoveryPasswordProtector
Restart-Computer -Force


#======= STAGE 6 - VM Host Parameters =======

# 6.1 LM Transport
Set-VMHost -CimSession $ClusterNodes -VirtualMachineMigrationPerformanceOption SMB  -VirtualMachineMigrationAuthenticationType Kerberos -MaximumStorageMigrations 3 # -MaximumVirtualMachineMigrations 3 (Cluster)

# 6.2 Enhanced Session Mode
Set-VMhost -CimSession $ClusterNodes -EnableEnhancedSessionMode $true


#======= STAGE 7 - SMB Parameters =======

# 7.1 SMB Server Encryption + Signing (в 2022 обещали поддержку, возможно нужно будет включить)
Set-SmbServerConfiguration -EncryptData $false -Confirm:$False
Set-SmbServerConfiguration -RequireSecuritySignature $False -Confirm:$False
Set-SmbServerConfiguration -EnableSecuritySignature $false -Confirm:$false

# 7.2 SMB Client
Set-SmbClientConfiguration -RequireSecuritySignature $false -Confirm:$false
Set-SmbClientConfiguration -EnableSecuritySignature $false -Confirm:$false


#======= STAGE 8 - Cluster Configuration =======

# 8.1 Cluster Validation
Test-Cluster -Node $ClusterNodes -Include "Inventory", "Network", "Storage", "System Configuration"

# 8.2 Failover Cluster Creation
New-Cluster -Name $ClusterName -Node $ClusterNodes -StaticAddress $ClusterIP

# 8.3 Cluster Quorum
Set-ClusterQuorum -NodeAndFileShareMajority \\blablabla\Witness$ # -Credential (Get-Credential)

# 8.4 Cluster Networks
(Get-ClusterNetwork | Where-Object Role -eq "ClusterAndClient").Metric = 30000
(Get-ClusterNetwork | Where-Object Role -eq "ClusterAndClient").Name = "Management Network"
(Get-ClusterNetwork -Name "Cluster Network*" | Where-Object Role -eq "Cluster").Metric = 10000
(Get-ClusterNetwork -Name "Cluster Network*" | Where-Object Role -eq "Cluster").Name = "SMB Network"

# 8.5 Virtual Machine MigrationExcludeNetworks
$ClientNetwork = (Get-ClusterNetwork | ? Role -eq ClusterAndClient).Id
Get-ClusterResourceType -Name "Virtual Machine" | Set-ClusterParameter -Name MigrationExcludeNetworks -Value $ClientNetwork

# 8.6 Cluster RDMA (For Redirected Access)
(Get-Cluster).UseRdmaForStorage=1

# 8.7 Thresholds (All Nodes Same Site/Subnet)
(Get-Cluster).SameSubnetThreshold = 20
(Get-Cluster).SameSubnetDelay = 2000

# 8.8 Route History Length (Twice of Subnet Threshold)
(Get-Cluster).RouteHistoryLength = 40

# 8.9 Resiliency Level (Allow)
(Get-Cluster).ResiliencyLevel = 1

# 8.10 Security
(Get-Cluster).SecurityLevel = 0 # 0 = Clear Text, 1 = Signed (default), 2 = Encrypted
(Get-Cluster).SecurityLevelForStorage = 0 # 0 = Clear Text (default), 1 = Both CSV and SBL traffic are signed, 2 = Both CSV and SBL traffic are encrypted

# 8.11 Cluster In-Memory Cache Size
(Get-Cluster).BlockCacheSize = 16384

# 8.12 VM and CSV Balancing
(Get-Cluster).AutoBalancerMode = 2 # обсуждаемо
(Get-Cluster).AutoBalancerLevel = 1 # Low Level агрессивности балансировки
(Get-Cluster).CsvBalancer = 0

# 8.13 GUM
(Get-Cluster).DatabaseReadWriteMode = 0

# 8.14 HostRecordTTL
Get-ClusterResource "Cluster Name" | Set-ClusterParameter HostRecordTTL 300 # changes will take effect until Cluster Name is taken offline and then online again

# 8.15 PTR
Get-ClusterResource "Cluster Name" | Set-ClusterParameter PublishPTRRecords 1

# 8.16 Cluster Log
Set-ClusterLog -Size 2048 #-Level # возможно нужно повысить детализацию и размер

# 8.17 SMB Bandwidth Limit for Live Migration Traffic
$NICs=(Get-VMSwitch -CimSession $ClusterNodes[0]).NetAdapterInterfaceDescriptions
$BytesPerSecond=((Get-NetAdapter -CimSession $ClusterNodes[0] -InterfaceDescription $NICs).TransmitLinkSpeed | Measure-Object -Sum).Sum/8
Set-SmbBandwidthLimit -Category LiveMigration -BytesPerSecond ($BytesPerSecond*0.4) -CimSession $ClusterNodes

# 8.18 Set Maximum Paralle LMs at Cluster Level
(Get-Cluster).MaximumParallelMigrations =  3 # (Windows Server 2022+ only)

# 8.19 Enable BitLocker - CSV Volumes (ручные манипуляции, никакой автоматики!) - Optional!!!
Get-ClusterSharedVolume -Name "Cluster Virtual Disk (KLG-HV-T10N01)" | Suspend-ClusterResource
Enable-BitLocker -MountPoint "" -RecoveryPasswordProtector
(Get-BitlockerVolume -MountPoint "C:\ClusterStorage\KLG-HV-T10N01").KeyProtector
Get-ClusterSharedVolume "Cluster Virtual Disk (KLG-HV-T10N01)" | Set-ClusterParameter -Name BitLockerProtectorInfo -Value "{FAC5A0FF-9122-4D4C-810B-E9D03E1FED72}:095986-135894-409178-691053-277156-291027-546964-669702" -Create
Get-ClusterSharedVolume "Cluster Virtual Disk (KLG-HV-T10N01)" | Get-ClusterParameter BitLockerProtectorInfo
Get-ClusterSharedVolume -Name "Cluster Virtual Disk (KLG-HV-T10N01)" | Resume-ClusterResource

#======= STAGE 9 - Network Settings Validation =======

# 9.1 Validate vSwitch
Get-VMSwitch -CimSession $ClusterNodes | Select-Object Name,IOV*,NetAdapterInterfaceDescriptions,ComputerName

# 9.2 Validate vNICs
Get-VMNetworkAdapter -CimSession $ClusterNodes -ManagementOS

# 9.3 Validate vNICs to pNICs Mapping
Get-VMNetworkAdapterTeamMapping -CimSession $ClusterNodes -ManagementOS | Select-Object ComputerName,NetAdapterName,ParentAdapter

# 9.4 Validate JumboFrames Setting
Get-NetAdapterAdvancedProperty -CimSession $ClusterNodes -DisplayName "Jumbo Packet"

# 9.5 Verify RDMA Settings
Get-NetAdapterRdma -CimSession $ClusterNodes | Sort-Object -Property PSComputerName,Name

# 9.6 Validate if VLANs were set
Get-VMNetworkAdapterVlan -CimSession $ClusterNodes -ManagementOS

# 9.7 Verify IP Config 
Get-NetIPAddress -CimSession $ClusterNodes -InterfaceAlias 'CL*' -AddressFamily IPv4 | Sort-Object -Property PSComputerName,InterfaceAlias | Select-Object PSComputerName,InterfaceALias,IPAddress

# 9.8 Validate DCBX Setting
Invoke-Command -ComputerName $ClusterNodes -ScriptBlock {Get-NetQosDcbxSetting} | Sort-Object PSComputerName | Select-Object PSComputerName,Willing

# 9.9 Validate Policy (no result since it's not available in VM)
Invoke-Command -ComputerName $ClusterNodes -ScriptBlock {Get-NetAdapterQos | Where-Object enabled -eq true} | Sort-Object PSComputerName

# 9.10 Validate QOS Policies
Get-NetQosPolicy -CimSession $ClusterNodes | Sort-Object PSComputerName,Name | Select-Object PSComputerName,NetDirectPort,PriorityValue

# 9.11 Validate Flow Control Setting 
Invoke-Command -ComputerName $ClusterNodes -ScriptBlock {Get-NetQosFlowControl} | Sort-Object  -Property PSComputername,Priority | Select-Object PSComputerName,Priority,Enabled
        
# 9.12 Validate QoS Traffic Classes
Invoke-Command -ComputerName $ClusterNodes -ScriptBlock {Get-NetQosTrafficClass} |Sort-Object PSComputerName,Name | Select-Object PSComputerName,Name,PriorityFriendly,Bandwidth

# 9.13 Validate RDMA operational status
Get-SmbClientNetworkInterface -CimSession $ClusterNodes | Where-Object RdmaCapable -eq $true | Select-Object PSComputerName, InterfaceIndex, RdmaCapable

# 9.14 Validate MPIO Settings
Get-MPIOSetting

# 9.15 Validate MPIO Supported Hardware
Get-MSDSMSupportedHW

# 9.16 Validate Load Balance Policy
Get-MSDSMGlobalDefaultLoadBalancePolicy

# 9.17 Validate MPIO Disks and Paths
Get-PhysicalDisk | ? {$_.BusType -eq "Fibre Channel"}
mpclaim -s -d

# 9.18 Validate FC HBA Ports
Get-InitiatorPort | ? ConnectionType -eq 'Fibre Channel' | Select-Object NodeAddress, PortAddress, ConnectionType, OperationalStatus
