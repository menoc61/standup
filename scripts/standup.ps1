<#
.SYNOPSIS
    CSPH StandUp — project control script (PowerShell).

.DESCRIPTION
    One entry point for everything this repository needs: environment setup,
    dependency resolution, code quality, builds, installs and release packaging
    for Android, iOS, web, Windows, macOS and Linux.

    Run it with no arguments for an interactive menu, or with a verb for
    scripting and CI. Both paths call the same functions, so the menu can never
    drift away from what the command line does.

.PARAMETER Command
    The verb to run. Defaults to the interactive menu.

.EXAMPLE
    .\scripts\standup.ps1
    Runs the interactive menu.

.EXAMPLE
    .\scripts\standup.ps1 Doctor
    Reports the state of the toolchain.

.EXAMPLE
    .\scripts\standup.ps1 Build -Platform android -Mode release
    Builds a release APK.

.NOTES
    Requires PowerShell 5.1 or newer, and Flutter on PATH.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Command = 'menu',

    [Parameter(Position = 1)]
    [string] $Target,

    [Parameter(Position = 2)]
    [string] $Mode,

    [switch] $AssumeYes,
    # Named -Trace rather than -Debug: CmdletBinding() already defines a
    # -Debug common parameter and the script would fail to load.
    [switch] $Trace,
    [switch] $NoColor,
    # Reuses an existing build output and only runs the post-build steps, which
    # is what CI needs for the web job's Drift asset copy.
    [switch] $SkipBuild,
    [string] $FlutterVersion,
    [string] $DeviceId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Platform compatibility ───────────────────────────────────────────────────

<#
    Windows PowerShell 5.1 has no $IsWindows / $IsMacOS / $IsLinux; they arrived
    in PowerShell 6. Under Set-StrictMode an undefined variable is a terminating
    error, not merely empty, so the whole script would fail on the first platform
    check. Defining them here means every later check can be written the same way
    on both editions.
#>
if (-not (Test-Path 'variable:IsWindows')) {
    # Detect the real host rather than assuming Windows. PowerShell 5.1 only ever
    # ran on Windows in practice, but the shim is also reached by hosts that
    # dot-source this script, and hardcoding $true made every platform check
    # below answer wrongly on a non-Windows host.
    $global:IsMacOS   = $true  # overwritten immediately when we detect Windows
    $global:IsLinux   = $false
    $global:IsWindows = $false

    # $PSVersionTable.PSEdition is 'Desktop' on 5.1 and 'Core' on 6+, and Core is
    # available on all three operating systems, so it cannot decide this alone.
    if ($env:OS -eq 'Windows_NT') {
        $global:IsWindows = $true
        $global:IsMacOS   = $false
    }
    elseif ($IsMacOS) {
        $global:IsMacOS = $true
    }
    else {
        $global:IsLinux = $true
    }
}

# ── Locations ───────────────────────────────────────────────────────────────

$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ProjectRoot = (Resolve-Path (Join-Path $Script:ScriptDir '..')).Path
Set-Location $Script:ProjectRoot

# ── Configuration ────────────────────────────────────────────────────────────

$Script:AppName = 'CSPH StandUp'
$Script:AndroidPackage = 'com.healthwellness.standup_app'
$Script:IOSBundleId = 'com.healthwellness.standupApp'
$Script:Platforms = @('android', 'ios', 'web', 'windows', 'macos', 'linux')
$Script:ValidModes = @('debug', 'profile', 'release')
$Script:SkipBuild = [bool] $SkipBuild

if ($NoColor -or $env:NO_COLOR -eq '1') {
    # Suppress colour by pointing every helper at the default foreground.
    $script:NoColor = $true
}

# ── Output helpers ───────────────────────────────────────────────────────────

# Windows PowerShell 5.1 does not render ANSI escape sequences, so colouring is
# done with the console's own attributes on a whole line rather than with escape
# codes embedded in a string. That is why there is no colour palette here.

function Write-Info    { param([string] $Message) Write-Host "> $Message" -ForegroundColor Cyan }
function Write-Success { param([string] $Message) Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Warn    { param([string] $Message) Write-Host "!  $Message" -ForegroundColor Yellow }
function Write-Err     { param([string] $Message) Write-Host "X  $Message" -ForegroundColor Red }
function Write-Debug   { param([string] $Message) if ($Trace) { Write-Host "   $Message" -ForegroundColor DarkGray } }

function Write-Section {
    param([string] $Title)
    Write-Host ''
    Write-Host $Title -ForegroundColor White
    Write-Host ('-' * $Title.Length) -ForegroundColor DarkGray
}

function Write-Item {
    # Two-column layout used throughout `doctor`, so the values line up.
    param([string] $Label, [string] $Value)
    Write-Host ("  {0,-12} {1}" -f $Label, $Value)
}

function Get-NativeVersion {
<#
.SYNOPSIS
    Runs a native command for its version banner and returns the first line.

.DESCRIPTION
    Tools like `java -version` and `cmake --version` print to stderr, and Windows
    PowerShell 5.1 turns native stderr into error records. Under
    $ErrorActionPreference = 'Stop' that aborts the caller, so the preference is
    relaxed for the duration of the call. Reporting a version must never be the
    thing that stops a diagnostic from finishing.
#>
    param(
        [Parameter(Mandatory = $true)] [string] $Command,
        [string[]] $Arguments = @(),
        [string] $FilePath
    )

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $exe = if ($FilePath) { $FilePath } else { $Command }
        $output = & $exe @Arguments 2>&1 | Out-String
        $first = ($output -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        if ($null -eq $first) { return 'unknown' }
        return $first.Trim()
    } catch {
        return 'unknown'
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Stop-WithError {
    param([string] $Message)
    Write-Err $Message
    exit 1
}

function Confirm-Action {
    param([string] $Prompt)
    if ($AssumeYes -or $env:STANDUP_ASSUME_YES -eq '1') { return $true }
    $reply = Read-Host "$Prompt [y/N]"
    return $reply -match '^(y|yes)$'
}

# ── Toolchain resolution ─────────────────────────────────────────────────────

<#
.SYNOPSIS
    Locates the Flutter executable, preferring a project-pinned SDK.

.DESCRIPTION
    Building against a different Flutter version produces different asset
    bundles and occasionally different behaviour, so "works on my machine" is
    usually a version mismatch rather than a code fault. When a .fvmrc exists and
    fvm is installed, that pinned SDK wins.
#>
function Resolve-Flutter {
    if ($env:FLUTTER_BIN) { return $env:FLUTTER_BIN }

    $fvmrc = Join-Path $Script:ProjectRoot '.fvmrc'
    if ((Test-Path $fvmrc) -and (Get-Command fvm -ErrorAction SilentlyContinue)) {
        Write-Debug 'using fvm'
        return 'fvm'
    }

    $onPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $candidates = @(
        (Join-Path $HOME 'development\flutter\bin\flutter.bat'),
        (Join-Path $HOME 'flutter\bin\flutter.bat'),
        'C:\flutter\bin\flutter.bat',
        'C:\src\flutter\bin\flutter.bat'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }

    return $null
}

$Script:Flutter = $null

function Initialize-Flutter {
    if ($Script:Flutter) { return }
    $resolved = Resolve-Flutter
    if (-not $resolved) {
        Stop-WithError 'Flutter not found. Install it from https://docs.flutter.dev/get-started/install then re-run.'
    }
    $Script:Flutter = $resolved
    Write-Debug "flutter: $Script:Flutter"
}

function Set-FlutterVersion {
<#
.SYNOPSIS
    Activates the SDK version requested with -FlutterVersion.

.DESCRIPTION
    Switching SDK versions in place is a machine-level change that FVM exists to
    manage, so this does not try to reinstall anything. It verifies that a
    version-pinning tool is available and otherwise explains the two supported
    ways forward. Silently building with the wrong version would be worse than
    refusing, because it produces a confusing failure much later.
#>
    param([string] $Requested)

    if (-not $Requested -or $Requested -eq 'stable') { return }

    Initialize-Flutter
    $current = Get-NativeVersion -FilePath $Script:Flutter -Arguments @('--version')

    if ($current -like "*Flutter $Requested*") {
        Write-Success "already on Flutter $Requested"
        return
    }

    if (Get-Command fvm -ErrorAction SilentlyContinue) {
        Write-Info "switching to Flutter $Requested via fvm"
        & fvm use $Requested --force
        if ($LASTEXITCODE -ne 0) { Stop-WithError "fvm could not activate Flutter $Requested" }
        $Script:Flutter = 'fvm'
        return
    }

    Stop-WithError @"
Flutter $Requested was requested but the active SDK is different.
  current: $current
Install a version manager, then re-run:
  dart pub global activate fvm
  fvm install $Requested
  fvm use $Requested --force
Or point at an SDK directly:
  `$env:FLUTTER_BIN = 'C:\path\to\flutter\bin\flutter.bat'
"@
}

<#
.SYNOPSIS
    Builds the --dart-define arguments for optional Supabase credentials.
#>
function Get-DartDefines {
    $defines = @()
    if ($env:SUPABASE_URL) { $defines += "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)" }
    if ($env:SUPABASE_PUBLISHABLE_KEY) { $defines += "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($env:SUPABASE_PUBLISHABLE_KEY)" }
    return $defines
}

<#
.SYNOPSIS
    Invokes a flutter subcommand, echoing it first for a reproducible log.

.DESCRIPTION
    Streaming output keeps long builds visible instead of appearing to hang,
    and the exit code is propagated so callers can branch on it.
#>
function Invoke-Flutter {
    param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $FlutterArgs)

    Initialize-Flutter
    Write-Debug "flutter $($FlutterArgs -join ' ')"

    if ($Script:Flutter -eq 'fvm') {
        & fvm flutter @FlutterArgs
    } else {
        & $Script:Flutter @FlutterArgs
    }

    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($FlutterArgs -join ' ') failed with exit code $LASTEXITCODE"
    }
}

# ── doctor ───────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Reports what is installed and what each platform still needs.

.DESCRIPTION
    Read-only by design: this is the command to run first when something will
    not build, so it must never change the machine.
#>
function Invoke-Doctor {
    Write-Section 'Host'
    Write-Host ("  platform    " + [System.Environment]::OSVersion.Platform)
    Write-Host ("  arch        " + $env:PROCESSOR_ARCHITECTURE)
    Write-Host ("  powershell  " + $PSVersionTable.PSVersion.ToString())

    Write-Section 'Flutter'
    $flutterPath = Resolve-Flutter
    if ($flutterPath) {
        Write-Host "  path        $flutterPath"
        try {
            $version = (& $flutterPath --version 2>&1 | Select-Object -First 1)
            Write-Host "  version     $version"
        } catch {
            Write-Warn "unable to read the Flutter version: $_"
        }
        $fvmrc = Join-Path $Script:ProjectRoot '.fvmrc'
        if (Test-Path $fvmrc) {
            Write-Host "  fvmrc       $((Get-Content $fvmrc -Raw).Trim())"
            if (Get-Command fvm -ErrorAction SilentlyContinue) {
                Write-Success 'fvm available, the pinned version will be used'
            } else {
                Write-Warn '.fvmrc is present but fvm is not installed'
            }
        }
    } else {
        Write-Err 'Flutter not found — run: .\scripts\standup.ps1 Setup'
    }

    Write-Section 'Project files'
    foreach ($file in @('pubspec.yaml', 'analysis_options.yaml', 'supabase_schema.sql', '.metadata')) {
        if (Test-Path (Join-Path $Script:ProjectRoot $file)) {
            Write-Success $file
        } else {
            Write-Warn "$file missing"
        }
    }

    Write-Section 'Dependencies'
    if (Test-Path (Join-Path $Script:ProjectRoot 'pubspec.lock')) {
        try {
            Invoke-Flutter pub deps --style=compact *> $null
            Write-Success 'pubspec.lock resolves'
        } catch {
            Write-Warn 'pub deps fails — try: .\scripts\standup.ps1 Deps'
        }
    } else {
        Write-Warn 'no pubspec.lock — try: .\scripts\standup.ps1 Deps'
    }

    Write-Section 'Generated code'
    $generated = Join-Path $Script:ProjectRoot 'lib\data\local\app_database.g.dart'
    $source = Join-Path $Script:ProjectRoot 'lib\data\local\app_database.dart'
    if (Test-Path $generated) {
        # A generated file that merely has an older mtime is not proof of
        # staleness — a regeneration that produces identical output does not
        # rewrite it. So this only reports the timestamps and points at the
        # command that actually settles the question.
        if (Test-Path $source) {
            $generatedAt = (Get-Item $generated).LastWriteTime
            $sourceAt = (Get-Item $source).LastWriteTime
            Write-Host ("  generated   " + $generatedAt.ToString('yyyy-MM-dd HH:mm:ss'))
            Write-Host ("  table defs  " + $sourceAt.ToString('yyyy-MM-dd HH:mm:ss'))
            if ($sourceAt -gt $generatedAt) {
                Write-Warn 'the table definitions are newer than the generated code'
                Write-Host '    confirm with: .\scripts\standup.ps1 Verify   (it regenerates and diffs)'
            }
        } else {
            Write-Success 'Drift code present'
        }
    } else {
        Write-Warn 'app_database.g.dart missing — try: .\scripts\standup.ps1 Codegen'
    }

    Write-Section 'Android'
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        Write-Item 'java' (Get-NativeVersion -Command 'java' -Arguments @('-version'))
    } else {
        Write-Warn 'java not on PATH — Android builds need a JDK 17'
    }

    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
    if ($sdk -and (Test-Path $sdk)) {
        Write-Host "  sdk         $sdk"
        $platformAdb = Join-Path $sdk 'platform-tools\adb.exe'
        $pathAdb = Get-Command adb -ErrorAction SilentlyContinue
        # Two adb binaries is the classic cause of INSTALL_FAILED_USER_RESTRICTED
        # being misdiagnosed as a device problem.
        if ($pathAdb -and (Test-Path $platformAdb) -and ($pathAdb.Source -ne $platformAdb)) {
            Write-Warn "another adb is on PATH ($($pathAdb.Source)); prefer $platformAdb"
        } elseif ($pathAdb) {
            Write-Host "  adb         $($pathAdb.Source)"
        } else {
            Write-Host "  adb         not on PATH (use $platformAdb)"
        }
    } else {
        Write-Warn 'ANDROID_HOME / ANDROID_SDK_ROOT not set'
    }

    if (Test-Path (Join-Path $Script:ProjectRoot 'android\key.properties')) {
        Write-Success 'release signing configured'
    } else {
        Write-Host '  key.properties absent — release builds fall back to debug signing'
    }

    Write-Section 'iOS'
    Write-Warn 'iOS builds require macOS with Xcode'

    Write-Section 'Desktop toolchains'
    # Flutter builds Windows through CMake + MSVC. Both are checked here because
    # neither failure is obvious from the Flutter side: the tool reports "Visual
    # Studio not installed" without saying which workload is missing.
    $cmake = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmake) {
        Write-Item 'cmake' (Get-NativeVersion -FilePath $cmake.Source -Arguments @('--version'))
    } else {
        Write-Warn 'cmake not on PATH — it ships with the Visual Studio C++ workload'
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $install = Get-NativeVersion -FilePath $vswhere -Arguments @(
            '-latest', '-products', '*', '-requires',
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            '-format', 'value', '-property', 'installationPath'
        )
        if ($install -and $install -notlike '*VC.Tools*' -and (Test-Path $install)) {
            Write-Success "Visual Studio C++ tools: $install"
        } else {
            Write-Warn 'Visual Studio is installed but the "Desktop development with C++" workload is missing'
            Write-Host '    add it with: winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
        }
    } else {
        Write-Warn 'Visual Studio not installed — Windows builds are not possible yet'
        Write-Host '    install with: winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
    }

    Write-Section 'Home-screen widgets'
    $provider = 'android\app\src\main\kotlin\com\healthwellness\standup_app\widget\StandUpWidgetProvider.kt'
    if (Test-Path (Join-Path $Script:ProjectRoot $provider)) {
        Write-Success 'Android provider present'
    } else {
        Write-Warn 'Android provider missing'
    }

    $manifest = Join-Path $Script:ProjectRoot 'android\app\src\main\AndroidManifest.xml'
    if ((Test-Path $manifest) -and (Select-String -Path $manifest -Pattern 'StandUpWidgetProvider' -Quiet)) {
        Write-Success 'Android receiver registered'
    } else {
        Write-Warn 'Android receiver not registered in the manifest'
    }

    $iosWidget = 'ios\StandUpWidget\CSPHStandUpWidget.swift'
    if (Test-Path (Join-Path $Script:ProjectRoot $iosWidget)) {
        $pbxproj = 'ios\Runner.xcodeproj\project.pbxproj'
        if ((Test-Path (Join-Path $Script:ProjectRoot $pbxproj)) -and
            (Select-String -Path (Join-Path $Script:ProjectRoot $pbxproj) -Pattern 'StandUpWidget' -Quiet)) {
            Write-Success 'iOS widget target installed'
        } else {
            Write-Warn 'iOS widget sources exist but the Xcode target is missing'
            Write-Host '    install with: ruby scripts/ios/add_widget_target.rb (macOS only)'
        }
    } else {
        Write-Warn 'iOS widget sources missing'
    }

    Write-Host ''
}

# ── setup / init ─────────────────────────────────────────────────────────────

function Invoke-Init {
    Write-Section 'Resolving Flutter'
    $Script:Flutter = Resolve-Flutter
    if (-not $Script:Flutter) {
        Stop-WithError 'Flutter not found. Install it from https://docs.flutter.dev/get-started/install'
    }
    Write-Success "using $Script:Flutter"

    Write-Section 'Project dependencies'
    Invoke-Flutter pub get
    Write-Success 'packages resolved'

    Write-Section 'Generated code'
    Invoke-Codegen

    Write-Section 'Ready'
    Write-Success "$Script:AppName is initialised"
    Write-Host '  next: .\scripts\standup.ps1 Doctor'
    Write-Host '        .\scripts\standup.ps1 Run -Target windows'
}

function Invoke-Setup {
    Write-Section 'Project dependencies'
    Invoke-Flutter pub get
    Write-Success 'packages resolved'

    if ($IsMacOS) {
        Write-Section 'macOS tooling'
        if (-not (Get-Command pod -ErrorAction SilentlyContinue)) {
            Write-Warn 'cocoaPods missing: sudo gem install cocoapods'
        }
        if (Test-Path (Join-Path $Script:ProjectRoot 'ios')) {
            Push-Location (Join-Path $Script:ProjectRoot 'ios')
            try { & pod install } catch { Write-Warn "pod install failed: $_" }
            finally { Pop-Location }
        }
    }

    Write-Section 'Done'
    Write-Success 'environment prepared'
}

function Invoke-Codegen {
    Write-Section 'Drift code generation'
    Invoke-Flutter pub run build_runner build --delete-conflicting-outputs
    Write-Success 'generated files refreshed'
}

# ── Code quality ─────────────────────────────────────────────────────────────

function Invoke-Analyze {
    Write-Section 'Static analysis'
    # --fatal-infos and --fatal-warnings match CI, so a green local run means a
    # green pipeline.
    Invoke-Flutter analyze --fatal-infos --fatal-warnings
    Write-Success 'no issues'
}

function Invoke-Format {
    param([switch] $Check)
    Write-Section 'Formatting'
    if ($Check) {
        Invoke-Flutter format --output=none --set-exit-if-changed lib test
        Write-Success 'formatting is clean'
    } else {
        Invoke-Flutter format lib test
        Write-Success 'formatted'
    }
}

function Invoke-Test {
    Write-Section 'Tests'
    Invoke-Flutter test
    Write-Success 'tests passed'
}

<#
.SYNOPSIS
    The gate CI runs, in the same order, so local and pipeline agree.
#>
function Invoke-Verify {
    Write-Section 'Verify'
    Invoke-Format -Check
    Invoke-Analyze
    Invoke-Codegen

    Write-Section 'Git state'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Push-Location $Script:ProjectRoot
        try {
            $dirty = & git status --porcelain lib/ 2>$null
            if ($dirty) {
                Write-Warn 'lib/ changed after code generation — commit the regenerated files'
                & git --no-pager diff --stat lib/
            } else {
                Write-Success 'generated code is committed'
            }
        } catch {
            Write-Warn "unable to inspect the git state: $_"
        } finally {
            Pop-Location
        }
    }

    Invoke-Test
    Write-Host ''
    Write-Success 'verification passed'
}

function Invoke-Deps {
    Write-Section 'Dependencies'
    Invoke-Flutter pub get
    try { Invoke-Flutter pub outdated } catch { Write-Warn 'pub outdated failed' }
}

<#
.SYNOPSIS
    Shows whether Supabase credentials are present, without printing them.
#>
function Invoke-Env {
    $envFile = Join-Path $Script:ProjectRoot '.env'
    if (Test-Path $envFile) {
        Write-Info 'found .env'
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
                Set-Item -Path "env:$($Matches[1])" -Value $Matches[2].Trim('"', "'")
            }
        }
    }

    Write-Section 'Supabase environment'
    if ($env:SUPABASE_URL) { Write-Success 'SUPABASE_URL set' } else { Write-Warn 'SUPABASE_URL not set — the app runs offline-only' }
    if ($env:SUPABASE_PUBLISHABLE_KEY) { Write-Success 'SUPABASE_PUBLISHABLE_KEY set' } else { Write-Warn 'SUPABASE_PUBLISHABLE_KEY not set' }

    Write-Host ''
    Write-Host 'Create .env in the project root with:'
    Write-Host '  SUPABASE_URL=https://<project-ref>.supabase.co'
    Write-Host '  SUPABASE_PUBLISHABLE_KEY=<publishable key>'
    Write-Host 'The file is gitignored; never commit the service-role key.'
}

# ── Builds ───────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Copies the Drift web assets into the built web bundle.

.DESCRIPTION
    `flutter build web` has no knowledge of Drift, so `sqlite3.wasm` and
    `drift_worker.js` are left out of the output and the deployed app throws on
    its first query. Both live in the resolved `drift` package in the pub cache,
    so the cache location is derived from pubspec.lock rather than hardcoded —
    that keeps this working across cache relocation and package upgrades.

    Missing assets are reported rather than silently skipped: a web build that
    cannot open its database is not a build worth shipping.
#>
function Copy-DriftWebAssets {
    $webDir = Join-Path $Script:ProjectRoot 'build\web'
    if (-not (Test-Path $webDir)) {
        Write-Warn 'build\web does not exist yet'
        return
    }

    $lock = Join-Path $Script:ProjectRoot 'pubspec.lock'
    if (-not (Test-Path $lock)) {
        Write-Warn 'pubspec.lock not found; cannot locate the drift package'
        return
    }

    # Parse the lock rather than globbing the whole cache: a recursive search of
    # the pub cache takes minutes and can pick up a different version's assets.
    $driftVersion = $null
    $inDrift = $false
    foreach ($line in Get-Content $lock) {
        if ($line -match '^\s{2}drift:\s*$') { $inDrift = $true; continue }
        if ($inDrift -and $line -match 'version:\s*"([^"]+)"') { $driftVersion = $Matches[1]; break }
        if ($inDrift -and $line -match '^\s{2}\S') { break }
    }

    if (-not $driftVersion) {
        Write-Warn 'could not determine the drift version from pubspec.lock'
        return
    }

    $cacheRoot = if ($env:PUB_CACHE) {
        $env:PUB_CACHE
    } elseif ($IsWindows) {
        Join-Path $env:LOCALAPPDATA 'Pub\Cache'
    } else {
        Join-Path $HOME '.pub-cache'
    }
    $driftDir = Join-Path $cacheRoot "hosted\pub.dev\drift-$driftVersion"
    if (-not (Test-Path $driftDir)) {
        $driftDir = Join-Path $cacheRoot "hosted/pub.dev/drift-$driftVersion"
    }

    $assets = @{
        'drift_worker.js' = Join-Path $driftDir 'drift_worker.js'
        'sqlite3.wasm'    = Join-Path $driftDir 'extension\devtools\build\sqlite3.wasm'
    }

    foreach ($name in $assets.Keys) {
        $source = $assets[$name]
        if (Test-Path $source) {
            Copy-Item $source (Join-Path $webDir $name) -Force
            Write-Success "build\web\$name"
        } else {
            Write-Err "$name not found at $source"
            Write-Host  '  the web build will fail at runtime; re-run: .\scripts\standup.ps1 Codegen'
        }
    }
}

<#
.SYNOPSIS
    Reports whether this host can produce the target, with the reason when not.
#>
function Test-PlatformSupported {
    param([string] $Name)

    if ($Script:Platforms -notcontains $Name) {
        Stop-WithError "unknown platform '$Name' (expected one of: $($Script:Platforms -join ' ') all)"
    }

    switch ($Name) {
        'android' {
            if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
                Write-Warn 'android needs a JDK'; return $false
            }
        }
        'ios' {
            if (-not $IsMacOS) { Write-Warn 'ios needs macOS + Xcode'; return $false }
        }
        'macos' {
            if (-not $IsMacOS) { Write-Warn 'macos needs macOS + Xcode'; return $false }
        }
        'windows' {
            if (-not $IsWindows) { Write-Warn 'windows builds need Windows + Visual Studio C++'; return $false }
        }
        'linux' {
            if (-not $IsLinux) { Write-Warn 'linux builds need Linux + GTK dev headers'; return $false }
        }
    }
    return $true
}

function Invoke-Build {
    param([string] $Platform, [string] $BuildMode = 'release')

    if (-not $Platform) {
        Stop-WithError "build requires a platform: $($Script:Platforms -join ' ') all"
    }
    if ($Script:ValidModes -notcontains $BuildMode) {
        Stop-WithError "build mode must be debug, profile or release (got '$BuildMode')"
    }

    if ($Platform -eq 'all') {
        Invoke-BuildAll -BuildMode $BuildMode
        return
    }

    # The requested SDK version is honoured before any work starts, so a version
    # problem fails immediately rather than partway through a long build.
    Set-FlutterVersion -Requested $FlutterVersion

    Write-Section "Building $Platform ($BuildMode)"
    $defines = Get-DartDefines

    # --skip-build reuses an existing output and only performs the post-build
    # steps. CI uses it for the web job: the compile is already done, and all
    # that remains is copying the Drift assets.
    if (-not $Script:SkipBuild) {
        switch ($Platform) {
        'android' {
            Invoke-Flutter build apk "--$BuildMode" @defines
            Write-Success 'APK: build\app\outputs\flutter-apk\'
        }
        'ios' {
            # --no-codesign keeps a first run or a CI build from failing on a
            # missing provisioning profile.
            Invoke-Flutter build ios "--$BuildMode" --no-codesign @defines
            if ($BuildMode -eq 'release') {
                Write-Success 'build\ios\iphoneos\ (unsigned — sign in Xcode for a device)'
            } else {
                Write-Success 'build\ios\'
            }
        }
        'web' {
            Invoke-Flutter build web --release @defines
        }
        'windows' {
            Invoke-Flutter build windows "--$BuildMode" @defines
            Write-Success 'build\windows\x64\runner\'
        }
        'macos' {
            Invoke-Flutter build macos "--$BuildMode" @defines
            Write-Success 'build\macos\'
        }
        'linux' {
            Invoke-Flutter build linux "--$BuildMode" @defines
            Write-Success 'build\linux\x64\release\bundle\'
        }
        }
    }
    else {
        Write-Info '--skip-build: reusing the existing output'
    }

    # The asset copy runs either way. It is cheap, and it is the step most likely
    # to be skipped by accident, which is exactly how a web build ends up
    # throwing on its first database query in production.
    if ($Platform -eq 'web') {
        Copy-DriftWebAssets
        Write-Success 'build\web\'
    }
}

<#
.SYNOPSIS
    Builds every platform this host can support, skipping the rest with a note.

.DESCRIPTION
    Each platform runs in its own try/catch so one failure does not hide the
    state of the others; the summary reports all three outcomes.
#>
function Invoke-BuildAll {
    param([string] $BuildMode = 'release')

    Write-Section "Building every supported platform ($BuildMode)"
    $built = @(); $skipped = @(); $failed = @()

    foreach ($platform in $Script:Platforms) {
        if (-not (Test-PlatformSupported -Name $platform)) {
            $skipped += $platform
            continue
        }
        try {
            Invoke-Build -Platform $platform -BuildMode $BuildMode
            $built += $platform
        } catch {
            Write-Err "$platform failed: $_"
            $failed += $platform
        }
    }

    Write-Section 'Summary'
    if ($built)    { Write-Success "built:   $($built -join ' ')" }
    if ($skipped)  { Write-Warn   "skipped: $($skipped -join ' ') (not supported on this host)" }
    if ($failed)   { Write-Err    "failed:  $($failed -join ' ')" }

    if ($failed.Count -gt 0) { throw "one or more platforms failed to build" }
}

# ── Run and install ──────────────────────────────────────────────────────────

function Invoke-Run {
    param([string] $Platform)

    if (-not $Platform) { Stop-WithError "run requires a platform: $($Script:Platforms -join ' ')" }
    if (-not (Test-PlatformSupported -Name $Platform)) {
        Stop-WithError "'$Platform' is not supported on this host"
    }

    Write-Section "Running on $Platform"
    $defines = Get-DartDefines

    switch ($Platform) {
        'android' {
            $id = if ($DeviceId) { $DeviceId } else { Get-FirstDevice 'android' }
            if (-not $id) {
                Write-Warn 'no android device detected — start an emulator or connect a phone'
                try { Invoke-Flutter devices } catch { }
                return
            }
            Write-Info "device $id"
            Invoke-Flutter run -d $id @defines
        }
        'ios' {
            $id = if ($DeviceId) { $DeviceId } else { Get-FirstDevice 'ios' }
            if (-not $id) {
                Write-Warn 'no ios device detected — connect a device or start a simulator'
                try { Invoke-Flutter devices } catch { }
                return
            }
            Write-Info "device $id"
            Invoke-Flutter run -d $id @defines
        }
        'web' {
            $port = if ($env:STANDUP_WEB_PORT) { $env:STANDUP_WEB_PORT } else { '8080' }
            Write-Info "http://localhost:$port"
            Invoke-Flutter run -d chrome --web-port $port @defines
        }
        default {
            Invoke-Flutter run -d $Platform @defines
        }
    }
}

<#
.SYNOPSIS
    First device id reported by flutter for the platform, or null.
#>
function Get-FirstDevice {
    param([string] $Platform)
    Initialize-Flutter
    try {
        $json = (& $Script:Flutter devices --machine 2>$null) -join "`n"
        if (-not $json) { return $null }
        return ($json |
            ConvertFrom-Json |
            Where-Object { $_.targetPlatform -eq $Platform } |
            Select-Object -First 1 -ExpandProperty id)
    } catch {
        Write-Debug "unable to list devices: $_"
        return $null
    }
}

function Invoke-Install {
    param([string] $Platform)

    if (-not $Platform) { Stop-WithError 'install requires a platform: android ios' }
    if (-not (Test-PlatformSupported -Name $Platform)) {
        Stop-WithError "'$Platform' is not supported on this host"
    }

    Write-Section "Installing on $Platform"

    if ($Platform -eq 'android') {
        $apk = Join-Path $Script:ProjectRoot 'build\app\outputs\flutter-apk\app-release.apk'
        if (-not (Test-Path $apk)) {
            Stop-WithError 'no APK yet — run: .\scripts\standup.ps1 Build -Platform android -Mode release'
        }

        # The SDK adb is preferred over PATH: a second adb on PATH is the usual
        # cause of INSTALL_FAILED_USER_RESTRICTED being blamed on the device.
        $adb = $null
        $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
        if ($sdk) {
            $candidate = Join-Path $sdk 'platform-tools\adb.exe'
            if (Test-Path $candidate) { $adb = $candidate }
        }
        if (-not $adb) {
            $cmd = Get-Command adb -ErrorAction SilentlyContinue
            if ($cmd) { $adb = $cmd.Source }
        }
        if (-not $adb) { Stop-WithError 'adb not found — set ANDROID_HOME' }

        Write-Info 'devices:'
        & $adb devices -l
        Write-Info "installing $apk"

        & $adb install -r $apk
        if ($LASTEXITCODE -ne 0) {
            Write-Err 'adb install failed'
            Write-Host 'On Xiaomi/Redmi, "Install via USB" is off by default.'
            Write-Host 'Enable Developer options -> Install via USB, then confirm on the phone.'
            throw 'install failed'
        }
        Write-Success 'installed'

        # `adb shell monkey` always writes its invocation banner to stderr, so it
        # goes through the same relaxed-preference wrapper as the version probes.
        $previous = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $adb shell monkey -p $Script:AndroidPackage -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Success 'launched' } else { Write-Warn 'installed; launch manually if needed' }
        } finally {
            $ErrorActionPreference = $previous
        }
        return
    }

    if ($Platform -eq 'ios') {
        # A signed build is required for a physical device, so this is mostly a
        # reminder rather than an installer.
        Write-Warn 'iOS installs go through Xcode: open ios\Runner.xcworkspace and run'
        Write-Host '  or use: .\scripts\standup.ps1 Run -Target ios -DeviceId <udid>'
    }
}

# ── Widgets ──────────────────────────────────────────────────────────────────

function Invoke-Widget {
    param([string] $Action = 'info')

    switch ($Action) {
        'info' {
            Write-Section 'Home-screen widgets'
            Write-Host "  Android provider : $($Script:AndroidPackage).widget.StandUpWidgetProvider"
            Write-Host '  Android layout   : android\app\src\main\res\layout\csph_standup_widget.xml'
            Write-Host '  iOS kind         : CSPHStandUpWidget'
            Write-Host "  App Group        : group.$($Script:IOSBundleId)"
            Write-Host ''
            Write-Host 'Add the widget:'
            Write-Host '  Android: long-press the home screen -> Widgets -> CSPH StandUp'
            Write-Host '  iOS:     long-press the home screen -> + -> search StandUp'
            Write-Host ''
            Write-Host 'After a language change or a logged break, run:'
            Write-Host '  .\scripts\standup.ps1 Widget -Target refresh'
        }
        'refresh' {
            # The launcher holds its own copy of the payload, so a rebuild or a
            # fresh install needs an explicit push rather than waiting for a break.
            Write-Section 'Refreshing widget payload'
            Invoke-Flutter test test\widget_snapshot_test.dart
            Write-Success 'payload contract verified — launch the app once to publish'
        }
        'install-ios' {
            if (-not $IsMacOS) { Stop-WithError 'the widget target can only be installed on macOS' }
            if (-not (Get-Command ruby -ErrorAction SilentlyContinue)) { Stop-WithError 'ruby is required (macOS ships it)' }
            Write-Section 'Installing the iOS widget target'
            & ruby (Join-Path $Script:ProjectRoot 'scripts\ios\add_widget_target.rb')
            if ($LASTEXITCODE -ne 0) { Stop-WithError 'the widget target installer failed' }
            Write-Success 'target installed — now run: (cd ios && pod install)'
        }
        default {
            Stop-WithError 'widget action must be info, refresh or install-ios'
        }
    }
}

# ── Release ──────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Packages every distributable artifact this host can produce.
#>
function Invoke-Release {
    Write-Section 'Release artifacts'
    $dist = Join-Path $Script:ProjectRoot 'dist'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $produced = @()

    Write-Section 'Android APK'
    try {
        Invoke-Build -Platform android -BuildMode release
        Copy-Item (Join-Path $Script:ProjectRoot 'build\app\outputs\flutter-apk\app-release.apk') (Join-Path $dist 'standup-android-release.apk') -Force
        $produced += 'standup-android-release.apk'
        Write-Success 'packaged'
    } catch {
        Write-Err "android release failed: $_"
    }

    if ($IsWindows) {
        Write-Section 'Windows bundle'
        try {
            Invoke-Build -Platform windows -BuildMode release
            $runner = Join-Path $Script:ProjectRoot 'build\windows\x64\runner\Release'
            if (Test-Path $runner) {
                $zip = Join-Path $dist 'standup-windows.zip'
                if (Test-Path $zip) { Remove-Item $zip -Force }
                Compress-Archive -Path (Join-Path $runner '*') -DestinationPath $zip
                $produced += 'standup-windows.zip'
                Write-Success 'packaged'
            }
        } catch {
            Write-Err "windows release failed: $_"
        }
    } else {
        Write-Warn 'Windows artifact skipped — requires Windows'
    }

    if ($IsMacOS) {
        Write-Section 'macOS app'
        try {
            Invoke-Build -Platform macos -BuildMode release
            $app = Join-Path $Script:ProjectRoot "build\macos\Build\Products\Release\$($Script:AppName).app"
            if (Test-Path $app) {
                $zip = Join-Path $dist 'standup-macos.zip'
                if (Test-Path $zip) { Remove-Item $zip -Force }
                Compress-Archive -Path $app -DestinationPath $zip
                $produced += 'standup-macos.zip'
                Write-Success 'packaged'
            }
        } catch {
            Write-Err "macos release failed: $_"
        }
    } else {
        Write-Warn 'macOS artifact skipped — requires macOS'
    }

    if ($IsLinux) {
        Write-Section 'Linux bundle'
        try {
            Invoke-Build -Platform linux -BuildMode release
            $bundle = Join-Path $Script:ProjectRoot 'build\linux\x64\release\bundle'
            if (Test-Path $bundle) {
                & tar -czf (Join-Path $dist 'standup-linux.tar.gz') -C (Split-Path -Parent $bundle) bundle
                $produced += 'standup-linux.tar.gz'
                Write-Success 'packaged'
            }
        } catch {
            Write-Err "linux release failed: $_"
        }
    } else {
        Write-Warn 'Linux artifact skipped — requires Linux'
    }

    if ($env:STANDUP_BUILD_WEB -ne '0') {
        Write-Section 'Web bundle'
        try {
            Invoke-Build -Platform web -BuildMode release
            $tar = Join-Path $dist 'standup-web.tar.gz'
            & tar -czf $tar -C (Join-Path $Script:ProjectRoot 'build') web
            $produced += 'standup-web.tar.gz'
            Write-Success 'packaged'
        } catch {
            Write-Err "web release failed: $_"
        }
    }

    Write-Section 'Artifacts'
    if ($produced.Count -eq 0) {
        throw 'nothing was produced'
    }
    foreach ($artifact in $produced) {
        $size = '{0:N1} MB' -f ((Get-Item (Join-Path $dist $artifact)).Length / 1MB)
        Write-Host "  $artifact  ($size)"
    }
    Write-Host ''
    Write-Success 'release artifacts in dist\'
}

# ── Maintenance ──────────────────────────────────────────────────────────────

function Invoke-Clean {
    Write-Section 'Cleaning'
    if (-not (Confirm-Action 'Remove build\, .dart_tool\ and platform build directories?')) {
        Write-Host 'cancelled'
        return
    }

    try { Invoke-Flutter clean } catch { Write-Warn 'flutter clean failed' }

    foreach ($dir in @('build', 'dist', 'android\.gradle', 'android\app\build',
                       'ios\Flutter\ephemeral', 'macos\Flutter\ephemeral',
                       'linux\flutter\ephemeral', 'windows\flutter\ephemeral')) {
        $full = Join-Path $Script:ProjectRoot $dir
        if (Test-Path $full) {
            Remove-Item $full -Recurse -Force
            Write-Info "removed $dir"
        }
    }
    Write-Success 'clean'
}

function Invoke-Version {
    Write-Section 'Versions'
    Initialize-Flutter
    & $Script:Flutter --version
    Write-Host ''
    Write-Host "  project      $($Script:AppName)"
    Write-Host "  android pkg  $($Script:AndroidPackage)"
    Write-Host "  ios bundle   $($Script:IOSBundleId)"
    Write-Host "  app group    group.$($Script:IOSBundleId)"
}

function Show-Help {
    $platforms = $Script:Platforms -join ' '
    $modes = $Script:ValidModes -join ' '

    Write-Host ''
    Write-Host "$($Script:AppName) control script" -ForegroundColor Green
    Write-Host ''
    Write-Host "USAGE" -ForegroundColor White
    Write-Host '  .\scripts\standup.ps1 [command] [-Target <value>] [-Mode <value>]'
    Write-Host ''
    Write-Host "ENVIRONMENT" -ForegroundColor White
    Write-Host '  init                        resolve dependencies and generate code'
    Write-Host '  setup                       install project packages'
    Write-Host '  doctor                      report toolchain and platform readiness'
    Write-Host '  deps                        fetch packages and list outdated ones'
    Write-Host '  env                         show Supabase configuration status'
    Write-Host '  version                     tool versions and bundle identifiers'
    Write-Host ''
    Write-Host "CODE" -ForegroundColor White
    Write-Host '  analyze                     static analysis (CI parity: fatal infos/warnings)'
    Write-Host '  format [-Check]             format lib\ and test\'
    Write-Host '  codegen                     regenerate Drift code'
    Write-Host '  test                        run the test suite'
    Write-Host '  verify                      format + analyze + codegen drift check + tests'
    Write-Host ''
    Write-Host "BUILD" -ForegroundColor White
    Write-Host '  build -Target <platform> [-Mode <mode>]'
    Write-Host "                              platforms: $platforms all"
    Write-Host "                              modes:    $modes"
    Write-Host '  build -Target all           build every platform this host supports'
    Write-Host '  run -Target <platform>      launch on a device or emulator'
    Write-Host '  install -Target android|ios install a built artifact'
    Write-Host '  release                     package distributables into dist\'
    Write-Host '  clean                       remove build output'
    Write-Host ''
    Write-Host "WIDGETS" -ForegroundColor White
    Write-Host '  widget -Target info         where the widget lives and how to add it'
    Write-Host '  widget -Target refresh      verify the payload contract and re-publish'
    Write-Host '  widget -Target install-ios  add the WidgetKit target to the Xcode project'
    Write-Host ''
    Write-Host "OTHER" -ForegroundColor White
    Write-Host '  logs                        stream device logs'
    Write-Host '  help                        this text'
    Write-Host ''
    Write-Host "OPTIONS" -ForegroundColor White
    Write-Host '  -AssumeYes                  skip confirmation prompts'
    Write-Host '  -Trace                      echo every command before running it'
    Write-Host '  -DeviceId <id>              target a specific device'
    Write-Host '  -NoColor                    disable colour'
    Write-Host '  NO_COLOR=1                  same, via the environment'
    Write-Host ''
    Write-Host "EXAMPLES" -ForegroundColor White
    Write-Host '  .\scripts\standup.ps1'
    Write-Host '  .\scripts\standup.ps1 Doctor'
    Write-Host '  .\scripts\standup.ps1 Build -Target android -Mode release'
    Write-Host '  .\scripts\standup.ps1 Build -Target all -Mode release'
    Write-Host '  .\scripts\standup.ps1 Run -Target windows'
    Write-Host '  .\scripts\standup.ps1 Release -AssumeYes'
    Write-Host ''
}
# ── Interactive menu ─────────────────────────────────────────────────────────

function Read-Prompt {
    param([string] $Text)
    return (Read-Host "> $Text").Trim()
}

function Invoke-Menu {
    Clear-Host
    Write-Host "  $($Script:AppName)" -NoNewline -ForegroundColor Green
    Write-Host '  - project control' -ForegroundColor DarkGray
    Write-Host "  interactive menu - 'q' quits - 'h' shows help" -ForegroundColor DarkGray

    while ($true) {
        Write-Section 'Menu'
        Write-Host @"
  1  doctor          check the toolchain
  2  init            set up the project
  3  verify          format + analyze + codegen + tests
  4  run             launch on a platform
  5  build           build a release artifact
  6  install         install on a device
  7  test            run the tests
  8  widget          home-screen widget tools
  9  release         package everything distributable
  0  clean           remove build output
  q  quit
"@

        $choice = (Read-Prompt 'select').ToLower()
        if (-not $choice) { continue }

        try {
            switch ($choice) {
                '1' { Invoke-Doctor }
                '2' { Invoke-Init }
                '3' { Invoke-Verify }
                '4' {
                    $platform = (Read-Prompt 'platform [android|ios|web|windows|macos|linux]').ToLower()
                    if ($platform) { Invoke-Run -Platform $platform }
                }
                '5' {
                    $platform = (Read-Prompt "platform [$($Script:Platforms -join '|')|all]").ToLower()
                    if ($platform) {
                        $mode = (Read-Prompt 'mode [debug|profile|release] (release)').ToLower()
                        if (-not $mode) { $mode = 'release' }
                        Invoke-Build -Platform $platform -BuildMode $mode
                    }
                }
                '6' {
                    $platform = (Read-Prompt 'platform [android|ios]').ToLower()
                    if ($platform) { Invoke-Install -Platform $platform }
                }
                '7' { Invoke-Test }
                '8' {
                    $action = (Read-Prompt 'action [info|refresh|install-ios] (info)').ToLower()
                    if (-not $action) { $action = 'info' }
                    Invoke-Widget -Action $action
                }
                '9' { Invoke-Release }
                '0' { Invoke-Clean }
                'h' { Show-Help }
                'q' { Write-Section 'Bye'; return }
                default { Write-Warn "unknown choice: $choice" }
            }
        } catch {
            # A failed action must not exit the menu; the user needs to see the
            # message and decide what to do next.
            Write-Err $_.Exception.Message
        }

        Write-Section ''
        Read-Host '  press enter to continue' | Out-Null
    }
}

# ── Entry point ──────────────────────────────────────────────────────────────

switch ($Command.ToLower()) {
    'menu'     { Invoke-Menu }
    'init'     { Invoke-Init }
    'setup'    { Invoke-Setup }
    'doctor'   { Invoke-Doctor }
    'deps'     { Invoke-Deps }
    'env'      { Invoke-Env }
    'version'  { Invoke-Version }
    'analyze'  { Invoke-Analyze }
    'format'   { Invoke-Format -Check:($Mode -eq '--check') }
    'codegen'  { Invoke-Codegen }
    'test'     { Invoke-Test }
    'verify'   { Invoke-Verify }
    'build'    { Invoke-Build -Platform $Target -BuildMode $(if ($Mode) { $Mode } else { 'release' }) }
    'run'      { Invoke-Run -Platform $Target }
    'install'  { Invoke-Install -Platform $Target }
    'widget'   { Invoke-Widget -Action $(if ($Target) { $Target } else { 'info' }) }
    'release'  { Invoke-Release }
    'clean'    { Invoke-Clean }
    'logs'     { Initialize-Flutter; Invoke-Flutter logs }
    'help'     { Show-Help }
    default {
        Write-Err "unknown command '$Command'"
        Write-Host ''
        Show-Help
        exit 1
    }
}
