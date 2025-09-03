# Массив контейнеров
$containers = @(
    "\\.\FAT12_E\96531026@2025-07-31-OOO PV-VS",
    "\\.\FAT12_E\96531309@2025-07-31-OOO PV-SIBIR 2",
    "\\.\FAT12_E\96642496@2025-08-04-OOO IMPORTLOGISTIK копия",
    "\\.\FAT12_E\96644866@2025-08-04-OOO PV-NOVYI URAL",
    "\\.\FAT12_E\96755673@2025-08-08-OOO DOBROSLAV",
    "\\.\FAT12_E\96755923@2025-08-08-OOO PRAVILNYI VYBOR",
    "\\.\FAT12_E\96756166@2025-08-08-OOO DS-KRYM",
    "\\.\FAT12_E\96756297@2025-08-08-OOO PV-URAL",
    "\\.\FAT12_E\96756357@2025-08-08-OOO SVOIMAG",
    "\\.\FAT12_E\96756688@2025-08-08-OOO PV-TSENTR 2",
    "\\.\FAT12_E\96756810@2025-08-08-OOO FUDLOGISTIK",
    "\\.\FAT12_E\96756917@2025-08-08-OOO PV SEVERO-ZAPAD",
    "\\.\FAT12_E\96757007@2025-08-08-OOO PV-PROIZVODSTVO",
    "\\.\FAT12_E\96757304@2025-08-08-OOO INIT",
    "\\.\FAT12_E\96757414@2025-08-08-OOO PV-SREDNII URAL",
    "\\.\FAT12_E\96757480@2025-08-08-OOO FL-IUG",
    "\\.\FAT12_E\96757625@2025-08-08-OOO PV-TSENTR 3",
    "\\.\FAT12_E\96757691@2025-08-08-OOO TSENTR LOGISTIK",
    "\\.\FAT12_E\96757852@2025-08-08-OOO PV-TSENTR",
    "\\.\FAT12_E\96757966@2025-08-08-OOO PV-IUG",
    "\\.\FAT12_E\96758104@2025-08-08-OOO PV-BALT",
    "\\.\FAT12_E\96758264@2025-08-08-OOO PV-ORENBURG",
    "\\.\FAT12_E\96758331@2025-08-08-OOO PV-VOLGA",
    "\\.\FAT12_E\96758422@2025-08-08-OOO PV-IUG 2",
    "\\.\FAT12_E\96758529@2025-08-08-OOO PV-DV",
    "\\.\FAT12_E\96758652@2025-08-08-OOO FL-ALKOTSENTR",
    "\\.\FAT12_E\96759040@2025-08-08-OOO PV-SIBIR",
    "\\.\FAT12_E\96759731@2025-08-08-OOO FL-TSENTR",
    "\\.\FAT12_E\96781132@2025-08-09-OOO BESTLER",
    "\\.\FAT12_E\96953233@2025-08-15-OOO GEFEST"
)

# Путь к cryptcp.exe
$cryptcpPath = "C:\Program Files\Crypto Pro\CSP\cryptcp.exe"

# Проверяем существование файла cryptcp.exe
if (-not (Test-Path $cryptcpPath)) {
    Write-Error "Файл cryptcp.exe не найден по пути: $cryptcpPath"
    exit 1
}

Write-Host "Начинаем обработку $($containers.Count) контейнеров..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Счетчик для отслеживания прогресса
$counter = 1

# Перебираем все контейнеры
foreach ($container in $containers) {
    Write-Host "[$counter/$($containers.Count)] Обрабатываем контейнер: $container" -ForegroundColor Yellow
    
    try {
        # Выполняем команду cryptcp
        $result = & $cryptcpPath -cspcert -cont $container -du 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Успешно обработан" -ForegroundColor Green
            # Выводим результат команды
            $result | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        } else {
            Write-Host "✗ Ошибка при обработке (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            $result | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        }
    }
    catch {
        Write-Host "✗ Исключение при выполнении: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "------------------------------------------------" -ForegroundColor Gray
    $counter++
}

Write-Host "Обработка завершена!" -ForegroundColor Green