$time = (Get-Date) - (New-TimeSpan -Days 365)
$result = Get-WinEvent -FilterHashtable @{logname='Security';id=4732,4728;StartTime=$Time} -ErrorAction SilentlyContinue| ForEach-Object {
    $eventXml = ([xml]$_.ToXml()).Event
    [PSCustomObject]@{
        TimeCreated   = $eventXml.System.TimeCreated.SystemTime -replace '\.\d+.*$'
        NewUser = $eventXml.EventData.Data[0]."#text"
        Group = $eventXml.EventData.Data[2]."#text"
        Admin = $eventXml.EventData.Data[6]."#text"
        Computer      = $eventXml.System.Computer
    }
}
$result | Format-Table -AutoSize 