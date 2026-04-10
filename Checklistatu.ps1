# ================= SISTEMA =================
$os = (Get-CimInstance Win32_OperatingSystem).Caption

# ================= CPU =================
$cpuObj = Get-CimInstance Win32_Processor
$cpu = $cpuObj.Name

if ($cpu -match "i[3579]-([0-9]{4,5})") {
    $num = $Matches[1]
    if ($num.Length -eq 5) {
        $gen = $num.Substring(0,2) + "ª Geração"
    } else {
        $gen = $num.Substring(0,1) + "ª Geração"
    }
} else {
    $gen = ""
}

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

# ================= DISCO (MULTIPLOS CORRIGIDO) =================
$diskLines = @()
$i = 1

# tenta método moderno
$physicalDisks = @()
try {
    $physicalDisks = Get-PhysicalDisk -ErrorAction Stop
} catch {}

if ($physicalDisks.Count -gt 0) {

    foreach ($disk in $physicalDisks) {

        $size = "{0:N0}GB" -f ($disk.Size /1GB)

        if ($disk.BusType -eq "NVMe") {
            $tipo = "NVMe SSD"
            $ssdStatus = "Sim"
        }
        elseif ($disk.MediaType -eq "SSD") {
            $tipo = "SATA SSD"
            $ssdStatus = "Sim"
        }
        else {
            $tipo = "HD"
            $ssdStatus = "Não"
        }

        $diskLines += "Disco ${i}: SSD: $ssdStatus --> $size ($tipo)"
        $i++
    }

} else {
    # fallback confiável
    $disks = Get-CimInstance Win32_DiskDrive

    foreach ($disk in $disks) {

        $size = if ($disk.Size) {
            "{0:N0}GB" -f ($disk.Size /1GB)
        } else {
            "Desconhecido"
        }

        if ($disk.Model -match "NVMe") {
            $tipo = "NVMe SSD"
            $ssdStatus = "Sim"
        }
        elseif ($disk.Model -match "SSD") {
            $tipo = "SATA SSD"
            $ssdStatus = "Sim"
        }
        else {
            $tipo = "HD"
            $ssdStatus = "Não"
        }

        $diskLines += "Disco ${i}: SSD: $ssdStatus --> $size ($tipo)"
        $i++
    }
}

$diskLine = $diskLines -join "`n"

# ================= REDE =================
$net = Get-CimInstance Win32_NetworkAdapter |
Where-Object { $_.NetEnabled -eq $true -and $_.PhysicalAdapter -eq $true } |
Select-Object -First 1

if ($net -and $net.Speed -ge 1000000000) {
    $gigabit = "Sim"
} else {
    $gigabit = "Não"
}

# ================= IP =================
$ipInfo = Get-CimInstance Win32_NetworkAdapterConfiguration |
Where-Object { $_.IPEnabled -eq $true }

$ip = $ipInfo.IPAddress | Where-Object { $_ -notlike "*:*" } | Select-Object -First 1

# ================= PLACA MÃE =================
$mb = Get-CimInstance Win32_BaseBoard
$mbInfo = "$($mb.Manufacturer) - $($mb.Product)"

# ================= NOME =================
$netbios = $env:COMPUTERNAME

# ================= SAÍDA =================
$output = @"
Sistema Operacional: $os

Processador: $cpu
($gen)

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
"@

# ================= SALVAR =================
$desktop = [Environment]::GetFolderPath("Desktop")
$path = "$desktop\$netbios.txt"

$output | Out-File $path -Encoding UTF8