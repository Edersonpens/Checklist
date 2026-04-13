# ================= SISTEMA ================= 
$os = (Get-CimInstance Win32_OperatingSystem).Caption

# ================= CPU =================
$cpuObj = Get-CimInstance Win32_Processor
$cpu = $cpuObj.Name

# cores e threads
$cores = $cpuObj.NumberOfCores
$threads = $cpuObj.NumberOfLogicalProcessors

# ================= RAM =================
$ram = Get-CimInstance Win32_PhysicalMemory
$totalRam = "{0:N2} GB" -f ((($ram.Capacity | Measure-Object -Sum).Sum) /1GB)

$ramTypeCode = ($ram | Select-Object -First 1).SMBIOSMemoryType
switch ($ramTypeCode) {
    24 {$ramType = "DDR3"}
    26 {$ramType = "DDR4"}
    34 {$ramType = "DDR5"}
    default {$ramType = "Desconhecido"}
}

$ramSpeed = ($ram | Select-Object -First 1).Speed

# ================= DISCO =================
$diskLines = @()
$i = 1

$physicalDisks = @()
$reliability = @()

try { $physicalDisks = Get-PhysicalDisk -ErrorAction Stop } catch {}
try { $reliability = Get-StorageReliabilityCounter } catch {}

if ($physicalDisks.Count -gt 0) {

    foreach ($disk in $physicalDisks) {

        $size = "{0:N0}GB" -f ($disk.Size /1GB)
        $modelo = $disk.FriendlyName
        $tipo = "HD"

        $rel = $reliability | Where-Object { $_.DeviceId -eq $disk.DeviceId }

        if ($rel -and $rel.RotationRate -ne $null) {
            if ($rel.RotationRate -eq 0) { $tipo = "SSD" }
            elseif ($rel.RotationRate -gt 0) { $tipo = "HD" }
        } else {
            if ($disk.MediaType -eq "SSD") { $tipo = "SSD" }
            elseif ($disk.MediaType -eq "HDD") { $tipo = "HD" }
        }

        $diskLines += "Disco ${i}: $modelo --> $size ($tipo)"
        $i++
    }

} else {

    $disks = Get-CimInstance Win32_DiskDrive

    foreach ($disk in $disks) {

        $size = if ($disk.Size) {
            "{0:N0}GB" -f ($disk.Size /1GB)
        } else {
            "Desconhecido"
        }

        $modelo = $disk.Model

        if ($disk.Model -match "SSD|NVMe") {
            $tipo = "SSD"
        } else {
            $tipo = "HD"
        }

        $diskLines += "Disco ${i}: $modelo --> $size ($tipo)"
        $i++
    }
}

$diskLine = $diskLines -join "`n"

# ================= REDE =================
$net = Get-CimInstance Win32_NetworkAdapter |
Where-Object { $_.NetEnabled -eq $true -and $_.PhysicalAdapter -eq $true } |
Select-Object -First 1

$gigabit = if ($net -and $net.Speed -ge 1000000000) { "Sim" } else { "Não" }

# ================= IP =================
$ipInfo = Get-CimInstance Win32_NetworkAdapterConfiguration |
Where-Object { $_.IPEnabled -eq $true }

$ip = $ipInfo.IPAddress | Where-Object { $_ -notlike "*:*" } | Select-Object -First 1

# ================= DATA =================
$dataHora = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$dataArquivo = Get-Date -Format "ddMMyyyy"

# ================= PLACA MÃE =================
$mb = Get-CimInstance Win32_BaseBoard
$mbInfo = "$($mb.Manufacturer) - $($mb.Product)"

# ================= NOME =================
$netbios = $env:COMPUTERNAME

# ================= SAÍDA =================
$output = @"
Sistema Operacional: $os

Processador: $cpu
$cores cores / $threads threads

Memória Total: $totalRam ($ramType $ramSpeed MHz)

Armazenamento:
$diskLine

Gigabit - $gigabit

Fonte:
Balança:
Impressora:
Leitor código de barras:
PinPad:
Teclado:

Placa Mãe:
$mbInfo

Rede:
$($net.Name)

NetBIOS Name    $netbios

IP:
$ip

$dataHora
"@

# ================= SALVAR =================
$desktop = [Environment]::GetFolderPath("Desktop")
$path = "$desktop\$netbios $dataArquivo.txt"

$output | Out-File $path -Encoding UTF8
