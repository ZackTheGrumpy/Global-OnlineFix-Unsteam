# Require Admin Rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[INFO] Requesting Administrator privileges..." -ForegroundColor Yellow
    if ($PSCommandPath) {
        try {
            Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        }
        catch {
            Write-Host "[ERROR] Failed to elevate: $_" -ForegroundColor Red
            Read-Host "Press Enter to exit..."
        }
    }
    else {
        # Running from memory (iex). Re-launch elevated with iex.
        try {
            $cmd = ""
            if ($AppID) {
                $cmd += "`$AppID = '$AppID'; "
            }
            $cmd += "irm `"tinyurl.com/WannabePatcher`" | iex"
            Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -Verb RunAs
        }
        catch {
            Write-Host "[ERROR] Failed to elevate: $_" -ForegroundColor Red
            Start-Sleep -Seconds 5
        }
    }
    exit
}

$ErrorActionPreference = "Stop"
$BASE_URL = "https://raw.githubusercontent.com/ZackTheGrumpy/Global-OnlineFix-Unsteam/main/Unsteam/"

function Log {
    param([string]$Message, [string]$Level = "INFO")
    if ($Level -eq "ERROR") {
        Write-Host "[$Level] $Message" -ForegroundColor Red
    }
    elseif ($Level -eq "SUCCESS") {
        Write-Host "[INFO] $Message" -ForegroundColor Green
    }
    else {
        Write-Host "[$Level] $Message" -ForegroundColor Cyan
    }
}

function Find-SteamPath {
    $registryKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )
    
    foreach ($key in $registryKeys) {
        if (Test-Path $key) {
            $pathVal = (Get-ItemProperty -Path $key -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
            if ($pathVal -and (Test-Path "$pathVal\steam.exe")) {
                Log "Found Steam via Registry: $pathVal"
                return $pathVal
            }
        }
    }
    
    $commonPaths = @(
        "C:\Program Files (x86)\Steam",
        "C:\Program Files\Steam",
        "D:\Steam",
        "E:\Steam"
    )
    
    foreach ($pathVal in $commonPaths) {
        if (Test-Path "$pathVal\steam.exe") {
            Log "Found Steam via Common Paths: $pathVal"
            return $pathVal
        }
    }
    
    Log "Steam installation not found!" "ERROR"
    return $null
}

function Get-SteamLibraryPaths {
    param([string]$SteamPath)
    
    $libraryVdf = Join-Path $SteamPath "steamapps\libraryfolders.vdf"
    $libraries = @($SteamPath)
    
    if (-not (Test-Path $libraryVdf)) {
        return $libraries | Select-Object -Unique
    }
    
    try {
        $content = Get-Content $libraryVdf -Raw -ErrorAction SilentlyContinue
        $matches = [regex]::Matches($content, '"path"\s+"(.+?)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $matches) {
            $pathVal = $match.Groups[1].Value.Replace("\\", "\")
            if (Test-Path -PathType Container $pathVal) {
                $libraries += $pathVal
            }
        }
    }
    catch {
        Log "Error parsing libraryfolders.vdf: $_" "ERROR"
    }
    
    return $libraries | Select-Object -Unique
}

function Find-GameByAppId {
    param([array]$Libraries, [string]$AppId)
    
    foreach ($lib in $Libraries) {
        $steamapps = Join-Path $lib "steamapps"
        $manifest = Join-Path $steamapps "appmanifest_${AppId}.acf"
        
        if (Test-Path $manifest) {
            try {
                $content = Get-Content $manifest -Raw -ErrorAction SilentlyContinue
                $match = [regex]::Match($content, '"installdir"\s+"(.+?)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($match.Success) {
                    $installDir = $match.Groups[1].Value
                    $gamePath = Join-Path $steamapps "common\$installDir"
                    if (Test-Path -PathType Container $gamePath) {
                        return $gamePath
                    }
                }
            }
            catch {
                Log "Error reading manifest: $_" "ERROR"
            }
        }
    }
    return $null
}

function Find-GameExe {
    param([string]$GameFolder)
    
    try {
        $exeFiles = Get-ChildItem -Path $GameFolder -Filter "*.exe" -Recurse -File -ErrorAction SilentlyContinue
        $ignoreList = @('uninstall', 'crash', 'report', 'setup', 'config', 'launcher', 'unitycrashhandler')
        
        foreach ($exe in $exeFiles) {
            $lowerName = $exe.Name.ToLower()
            $shouldIgnore = $false
            foreach ($ignore in $ignoreList) {
                if ($lowerName -match $ignore) {
                    $shouldIgnore = $true
                    break
                }
            }
            if (-not $shouldIgnore) {
                return $exe.FullName
            }
        }
    }
    catch {
        Log "Error finding game executable: $_" "ERROR"
    }
    return $null
}

function Download-File {
    param([string]$Url, [string]$DestPath, [int]$DependencyIndex)
    Log "Downloading Dependency $DependencyIndex..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing -ErrorAction Stop
        return $true
    }
    catch {
        Log "Download failed: $_" "ERROR"
        return $false
    }
}

function Modify-UnsteamIni {
    param([string]$IniPath, [string]$ExePath, [string]$DllPath, [string]$AppId)
    try {
        $content = Get-Content $IniPath -Raw -ErrorAction Stop
        
        $content = $content -replace '(?m)^exe_file=.*$', "exe_file=$ExePath"
        $content = $content -replace '(?m)^dll_file=.*$', "dll_file=$DllPath"
        $content = $content -replace '(?m)^real_app_id=.*$', "real_app_id=$AppId"
        
        Set-Content -Path $IniPath -Value $content -Encoding UTF8 -ErrorAction Stop
        Log "Configured Setting Enabling Online..."
        return $true
    }
    catch {
        Log "Error modifying unsteam.ini: $_" "ERROR"
        return $false
    }
}

Write-Host "=== WannaLine Co-op Fixer ===" -ForegroundColor Yellow

$steamPath = Find-SteamPath
if (-not $steamPath) {
    Read-Host "Steam not found. Press Enter to exit"
    exit
}

if (-not $AppID) {
    while ($true) {
        $AppID = (Read-Host "`nEnter Steam AppID").Trim()
        if ($AppID -match "^\d+$") {
            break
        }
        Write-Host "Invalid AppID. Please enter a number." -ForegroundColor Yellow
    }
}
else {
    Log "Using provided AppID: $AppID"
}

Log "Scanning libraries..."
$libraries = Get-SteamLibraryPaths -SteamPath $steamPath
$gamePath = Find-GameByAppId -Libraries $libraries -AppId $appId

if (-not $gamePath) {
    Log "Game with AppID $appId not found installed." "ERROR"
    Read-Host "Press Enter to exit"
    exit
}

Log "Found game at: $gamePath" "SUCCESS"

$gameExeFull = Find-GameExe -GameFolder $gamePath
if (-not $gameExeFull) {
    Log "Could not find game executable." "ERROR"
    Read-Host "Press Enter to exit"
    exit
}

$gameExeDir = Split-Path $gameExeFull -Parent
$gameExeName = Split-Path $gameExeFull -Leaf
Log "Game Executable: $gameExeName" "SUCCESS"

$gameName = Split-Path $gamePath -Leaf

$filesMap = @{
    "unsteam.dll" = "unsteam.dll"
    "unsteam.ini" = "unsteam.ini"
    "winmm.dll"   = "winmm.dll"
}

$successCount = 0
$depIndex = 1
foreach ($sourceName in $filesMap.Keys) {
    $destName = $filesMap[$sourceName]
    $url = $BASE_URL + $sourceName
    $dest = Join-Path $gameExeDir $destName
    if (Download-File -Url $url -DestPath $dest -DependencyIndex $depIndex) {
        $successCount++
    }
    $depIndex++
}

if ($successCount -eq $filesMap.Count) {
    $exeInSubfolder = (Resolve-Path $gameExeDir).Path -ne (Resolve-Path $gamePath).Path
    
    if ($exeInSubfolder) {
        $extractedIni = Join-Path $gameExeDir "unsteam.ini"
        $rootIni = Join-Path $gamePath "unsteam.ini"
        
        if (Test-Path $extractedIni) {
            Copy-Item -Path $extractedIni -Destination $rootIni -Force
            
            $fullDllPath = Join-Path $gameExeDir "unsteam.dll"
            
            Modify-UnsteamIni -IniPath $extractedIni -ExePath $gameExeFull -DllPath $fullDllPath -AppId $appId | Out-Null
            Modify-UnsteamIni -IniPath $rootIni -ExePath $gameExeFull -DllPath $fullDllPath -AppId $appId | Out-Null
            Log "Configured INI files for $gameName"
        }
    }
    else {
        $iniPath = Join-Path $gameExeDir "unsteam.ini"
        if (Test-Path $iniPath) {
            Modify-UnsteamIni -IniPath $iniPath -ExePath $gameExeName -DllPath "unsteam.dll" -AppId $appId | Out-Null
            Log "Configured INI file for $gameName"
        }
    }
    
    Write-Host "`n=== SUCCESS! ===" -ForegroundColor Green
    Write-Host "Co-op Mode Enabled. Happy Gaming!" -ForegroundColor Green
    Write-Host "Launch your game from Steam to play!" -ForegroundColor Green
}
else {
    Log "Failed to download all fix files." "ERROR"
}

Write-Host "`nExit in 10 seconds.."
Start-Sleep -Seconds 10
