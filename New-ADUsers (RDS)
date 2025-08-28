# Скрипт для добавления пользователей в Active Directory с указанным OU

# Импортируем модуль ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

# Массив пользователей для добавления (с индивидуальными паролями)
$Users = @(
    @{
        FirstName      = "Иван"
        LastName       = "Иванов"
        DisplayName    = "Иванов Иван"
        SamAccountName = "iivanov"
        Password       = "Iv@n0v2024!"  # Индивидуальный пароль
    },
    @{
        FirstName      = "Петр"
        LastName       = "Петров"
        DisplayName    = "Петров Петр"
        SamAccountName = "ppetrov"
        Password       = "P3tr0v#2024"   # Индивидуальный пароль
    },
    @{
        FirstName      = "Сергей"
        LastName       = "Сергеев"
        DisplayName    = "Сергеев Сергей"
        SamAccountName = "ssergeev"
        Password       = "S3rg33v!2024"  # Индивидуальный пароль
    }
)

# Общие параметры для всех пользователей
$PasswordNeverExpires = $true
$GroupName = "RDSUsersCommon" # Группа, в которую нужно добавить пользователей
$Domain = "dt.selectel"       # Ваш домен
$OU = "OU=RDSUsers,OU=AllUsers,DC=dt,DC=selectel" # Указанное подразделение

foreach ($User in $Users) {
    try {
        # Проверяем, существует ли пользователь
        if (Get-ADUser -Filter "SamAccountName -eq '$($User.SamAccountName)'") {
            Write-Host "Пользователь $($User.SamAccountName) уже существует" -ForegroundColor Yellow
            continue
        }

        # Создаем нового пользователя
        New-ADUser -Name $User.DisplayName `
                   -GivenName $User.FirstName `
                   -Surname $User.LastName `
                   -DisplayName $User.DisplayName `
                   -SamAccountName $User.SamAccountName `
                   -UserPrincipalName "$($User.SamAccountName)@$Domain" `
                   -AccountPassword (ConvertTo-SecureString $User.Password -AsPlainText -Force) `
                   -PasswordNeverExpires $PasswordNeverExpires `
                   -Enabled $true `
                   -Path $OU `
                   -PassThru
        
        # Добавляем пользователя в группу (если группа существует)
        try {
            Add-ADGroupMember -Identity $GroupName -Members $User.SamAccountName -ErrorAction Stop
            Write-Host "Пользователь $($User.SamAccountName) добавлен в группу $GroupName" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Не удалось добавить в группу $($GroupName): $_" -ForegroundColor Red
        }
        
        Write-Host "Успешно создан: $($User.SamAccountName) в OU $OU с паролем [$($User.Password)]" -ForegroundColor Green
    }
    catch {
        Write-Host "Ошибка при создании $($User.SamAccountName): $_" -ForegroundColor Red
    }
}

Write-Host "`nОбработка завершена. Проверьте результаты выше." -ForegroundColor Cyan