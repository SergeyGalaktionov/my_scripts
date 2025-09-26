# Получаем данные TPM
$tpmInfo = Get-TpmEndorsementKeyInfo -HashAlgorithm sha256

# Создаем экземпляр WMI
$wmiClass = [wmiclass]"\\.\root\cimv2:Win32_TPMEndorsementKey"
$wmiInstance = $wmiClass.CreateInstance()

# Заполняем обязательные ключевые поля
$wmiInstance.ComputerName = $env:COMPUTERNAME
$wmiInstance.HashAlgorithm = "SHA256"

# Заполняем остальные поля
$wmiInstance.PublicKeyHash = $tpmInfo.PublicKeyHash
$wmiInstance.CollectionTime = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime((Get-Date))
$wmiInstance.IsAvailable = $true

# Сохраняем
$wmiInstance.Put()