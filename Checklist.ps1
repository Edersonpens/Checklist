# ================= SISTEMA =================
$os = (Get-CimInstance Win32_OperatingSystem).Caption

# ================= CPU =================
$cpuObj = Get-CimInstance Win32_Processor
$cpu = $cpuObj.Name

if ($cpu -match "i[3579]-([0-9]{4,5})") {
    $gen = $Matches[1].Substring(0,1) + "ª Geração"
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
    default {$ramType = ""}
}

$ramSpeed = ($ram | Select-Object -First 1).Speed

# ================= DISCO =================
$physical = Get-PhysicalDisk | Select-Object -First 1

$diskSize = "{0:N0}GB" -f ($physical.Size /1GB)
$diskModel = $physical.FriendlyName

if ($diskModel -match "NVMe") {
    $tipo = "NVMe SSD"
} elseif ($diskModel -match "SSD") {
    $tipo = "ATA SATA SSD"
} else {
    $tipo = "Disco"
}

if ($physical.MediaType -eq "SSD") {
    $ssdStatus = "Sim"
} else {
    $ssdStatus = "Não"
}

$diskLine = "SSD: $ssdStatus --> $diskSize ($tipo)"

# ================= REDE =================
$net = Get-CimInstance Win32_NetworkAdapter |
Where-Object { $_.NetEnabled -eq $true -and $_.PhysicalAdapter -eq $true } |
Select-Object -First 1

if ($net.Name -match "Gigabit|GbE|Gbe") {
    $gigabit = "Sim"
} elseif ($net.Speed -ge 1000000000) {
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