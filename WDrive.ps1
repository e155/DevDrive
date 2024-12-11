$drvletter='W'

# Проверка наличия модуля Hyper-V
$featureName = "Microsoft-Hyper-V-All"
$feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName

if ($feature.State -ne "Enabled") {
    Write-Host "Модуль Hyper-V не установлен. Устанавливаем..."
    Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart

    Write-Host "Hyper-V установлен. Перезагрузка системы для завершения установки..."
    shutdown.exe /r /t 0
    exit
}

# Функция для проверки и монтирования VHDX
function Create-And-Mount-VHD {
    # Проверяем количество дисков, кроме диска C:
    $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne "C" -and -not ($_.DisplayRoot -like "\\*") }

    if ($disks.Count -gt 0) {
        foreach ($disk in $disks) {
            # Проверяем свободное место на каждом диске
            if ($disk.Free -gt 10GB) {
                # Путь для хранения VHDX файла
                $vhdxPath = Join-Path $disk.Root "Dev_DriveDLP.vhdx"
                
                # Проверяем, существует ли уже VHDX
                if (-Not (Test-Path $vhdxPath)) {
                    # Создаем VHDX диск
                    New-VHD -Path $vhdxPath -SizeBytes 10GB -Dynamic
                    
                    # Монтируем VHDX
                    Mount-VHD -Path $vhdxPath
                    
                    # Проверяем, доступна ли буква W:
                    $drvletter='W'



                    $drvlist=(Get-PSDrive -PSProvider filesystem).Name
                     If ($drvlist -notcontains $drvletter) {
                        # Инициализируем VHD и форматируем его
                        # Ищем первый диск с PartitionStyle "RAW"
$rawDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" } | Select-Object -First 1

if ($null -eq $rawDisk) {
    Write-Host "Не найден диск с PartitionStyle 'RAW'. Убедитесь, что VHDX корректно создан и подключен."
    return
}

# Инициализируем диск
Initialize-Disk -Number $rawDisk.Number -PartitionStyle MBR

# Создаем новый раздел и присваиваем ему букву
$partition = New-Partition -DiskNumber $rawDisk.Number -UseMaximumSize -DriveLetter $drvletter

# Форматируем раздел
Format-Volume -DriveLetter $partition.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Dev_Drive"

Write-Host "Диск успешно создан и форматирован."

                        
                        # Настраиваем постоянное монтирование
                        $taskName = "Mount Dev_Drive"
                        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                        Register-ScheduledTask -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command Mount-VHD -Path $vhdxPath") `
                                               -Trigger (New-ScheduledTaskTrigger -AtStartup) `
                                               -TaskName $taskName `
                                               -Settings $taskSettings `
                                               -Description "Automatically mount Dev_Drive on startup" `
                                               -User "SYSTEM" `
                                               -RunLevel Highest
                        Write-Host "Диск W: успешно создан и настроен на постоянное монтирование."
                    } else {
                        Write-Host "Буква W: уже занята."
                    }
                } else {
                    Write-Host "Файл $vhdxPath уже существует."
                }
                break
            } else {
                Write-Host "На диске $($disk.Name): недостаточно свободного места."
            }
        }
    } else {
        Write-Host "Жестких дисков кроме C: не найдено."
    }
}

# Выполнение основной функции
Create-And-Mount-VHD
