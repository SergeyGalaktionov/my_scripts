$VpnName = "SSTP SELECTEL"  
$ServerAddress = "sstp.galaktionov.tech"  
$DnsSuffix = "dt.selectel"

# Создать новое SSTP VPN подключение
$VpnParams = @{
Name = $VpnName
ServerAddress = $ServerAddress
TunnelType = 'Sstp'
AuthenticationMethod = 'MSChapv2'
SplitTunneling = $true
RememberCredential = $true
UseWinlogonCredential = $false
DnsSuffix = $DnsSuffix
IdleDisconnectSeconds = 3600
EncryptionLevel = 'Maximum'
}

Add-VpnConnection @VpnParams

# Добавить маршрут
Add-VpnConnectionRoute -ConnectionName $VpnName -DestinationPrefix "192.168.1.0/24"
   
# Добавить NRPT правило
Add-DnsClientNrptRule -Namespace "dt.selectel" -NameServers "192.168.1.3","192.168.1.2"