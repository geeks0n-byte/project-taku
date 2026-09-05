# Shared Godot executable resolver for local PowerShell scripts.
# Dot-source this file, then call Resolve-GodotExecutable.

function Read-GodotEnv {
	$vars = @{}
	foreach ($file in @("godot.env", "godot.local.env")) {
		$envFile = Join-Path $PSScriptRoot $file
		if (-not (Test-Path -LiteralPath $envFile)) {
			continue
		}
		foreach ($line in Get-Content -LiteralPath $envFile) {
			if ($line -match '^\s*#') { continue }
			if ($line -match '^\s*([^=]+)=(.*)$') {
				$vars[$Matches[1].Trim()] = $Matches[2].Trim()
			}
		}
	}
	if ($vars.Count -eq 0) {
		throw "Missing tools/godot.env"
	}
	return $vars
}

function Get-WindowsGodotBasename {
	param([hashtable]$Config)
	$variant = $Config.GODOT_VARIANT
	if ([string]::IsNullOrWhiteSpace($variant)) {
		return "Godot_v$($Config.GODOT_VERSION)-$($Config.GODOT_RELEASE)_win64.exe"
	}
	return "Godot_v$($Config.GODOT_VERSION)-$($Config.GODOT_RELEASE)_${variant}_win64.exe"
}

function Test-GodotVersionMatch {
	param([string]$ExePath, [string]$ExpectedVersion)
	if (-not (Test-Path -LiteralPath $ExePath)) {
		return $false
	}
	try {
		$versionOutput = & $ExePath --version 2>&1 | Out-String
		return $versionOutput -match [regex]::Escape($ExpectedVersion)
	}
	catch {
		return $false
	}
}

function Ensure-WindowsGodotDownload {
	param([hashtable]$Config)
	$cacheDir = Join-Path (Split-Path -Parent $PSScriptRoot) $Config.GODOT_CI_CACHE_DIR
	$basename = Get-WindowsGodotBasename -Config $Config
	$target = Join-Path $cacheDir $basename
	if (Test-Path -LiteralPath $target) {
		return $target
	}
	$zipName = [System.IO.Path]::ChangeExtension($basename, ".zip")
	$zipUrl = "https://github.com/godotengine/godot-builds/releases/download/$($Config.GODOT_VERSION)-$($Config.GODOT_RELEASE)/$zipName"
	$zipPath = Join-Path $cacheDir "godot.zip"
	New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
	Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
	Expand-Archive -LiteralPath $zipPath -DestinationPath $cacheDir -Force
	Remove-Item -LiteralPath $zipPath -Force
	if (-not (Test-Path -LiteralPath $target)) {
		throw "Downloaded Godot archive did not contain $basename"
	}
	return $target
}

function Resolve-GodotExecutable {
	param(
		[string]$ExplicitPath = "",
		[switch]$AllowDownload
	)
	$config = Read-GodotEnv
	$version = $config.GODOT_VERSION
	$root = Split-Path -Parent $PSScriptRoot
	$candidates = @()

	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		$candidates += $ExplicitPath
	}
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_EXE)) {
		$candidates += $env:GODOT_EXE
	}
	if ($config.ContainsKey("GODOT_EXE") -and -not [string]::IsNullOrWhiteSpace($config.GODOT_EXE)) {
		$candidates += $config.GODOT_EXE
	}

	$pathGodot = Get-Command godot -ErrorAction SilentlyContinue
	if ($pathGodot) {
		$candidates += $pathGodot.Source
	}

	$cached = Join-Path $root $config.GODOT_CI_CACHE_DIR
	$cached = Join-Path $cached (Get-WindowsGodotBasename -Config $config)
	$candidates += $cached

	foreach ($candidate in $candidates) {
		if (Test-GodotVersionMatch -ExePath $candidate -ExpectedVersion $version) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
	}

	if ($AllowDownload -or $env:GODOT_ALLOW_DOWNLOAD -eq "1") {
		$downloaded = Ensure-WindowsGodotDownload -Config $config
		if (Test-GodotVersionMatch -ExePath $downloaded -ExpectedVersion $version) {
			return (Resolve-Path -LiteralPath $downloaded).Path
		}
	}

	$hint = @(
		"Godot $version not found.",
		"Set GODOT_EXE, add godot to PATH, cache under $($config.GODOT_CI_CACHE_DIR),",
		"or set GODOT_ALLOW_DOWNLOAD=1 / pass -AllowDownload."
	) -join " "
	throw $hint
}
