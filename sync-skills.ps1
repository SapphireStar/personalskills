param(
    [string]$LibraryPath = (Join-Path $PSScriptRoot "skills"),
    [string]$WorkspacePath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $LibraryPath)) {
    Write-Host "找不到 skill 库目录: $LibraryPath"
    exit 1
}

$UserScope = Join-Path $env:USERPROFILE ".claude\skills"
$WorkspaceScope = Join-Path $WorkspacePath ".claude\skills"

Write-Host "Skill 库      : $LibraryPath"
Write-Host "User scope    : $UserScope"
Write-Host "Workspace scope: $WorkspaceScope"
Write-Host ""

# 对一个目录下所有文件做递归内容哈希，拼成一个整体哈希，用于判断目录内容是否一致
function Get-DirHash {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return $null }
    $files = Get-ChildItem -Path $Dir -Recurse -File | Sort-Object FullName
    $sb = New-Object System.Text.StringBuilder
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Dir.Length).TrimStart('\')
        $hash = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
        [void]$sb.Append("$rel`:$hash;")
    }
    if ($sb.Length -eq 0) { return "EMPTY" }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hashBytes) -replace '-', '')
}

# 覆盖式合并拷贝：只新增/覆盖库里存在的文件，不删除本地已有的额外文件
function Copy-Skill {
    param([string]$Src, [string]$Dst)
    New-Item -ItemType Directory -Path $Dst -Force | Out-Null
    Copy-Item -Path (Join-Path $Src '*') -Destination $Dst -Recurse -Force
}

$skillDirs = Get-ChildItem -Path $LibraryPath -Directory
if (-not $skillDirs) {
    Write-Host "skill 库为空，没有可比对的 skill。"
    exit 0
}

$updates = @()

foreach ($skillDir in $skillDirs) {
    $name = $skillDir.Name
    $libHash = Get-DirHash $skillDir.FullName

    $userDir = Join-Path $UserScope $name
    $wsDir = Join-Path $WorkspaceScope $name
    $userHash = Get-DirHash $userDir
    $wsHash = Get-DirHash $wsDir

    $userStatus = if ($null -eq $userHash) { "新增" } elseif ($userHash -ne $libHash) { "有新版本" } else { "已最新" }
    $wsStatus = if ($null -eq $wsHash) { "新增" } elseif ($wsHash -ne $libHash) { "有新版本" } else { "已最新" }

    if ($userStatus -ne "已最新" -or $wsStatus -ne "已最新") {
        $updates += [PSCustomObject]@{
            Name       = $name
            SrcPath    = $skillDir.FullName
            UserStatus = $userStatus
            WsStatus   = $wsStatus
            UserDir    = $userDir
            WsDir      = $wsDir
        }
    }
}

if ($updates.Count -eq 0) {
    Write-Host "所有 skill 均已是最新版本，无需更新。"
    exit 0
}

Write-Host "发现 $($updates.Count) 个 skill 有差异:"
foreach ($u in $updates) {
    Write-Host ("  - {0}  [User: {1}]  [Workspace: {2}]" -f $u.Name, $u.UserStatus, $u.WsStatus)
}
Write-Host ""

foreach ($u in $updates) {
    Write-Host "================================================"
    Write-Host "Skill: $($u.Name)"
    Write-Host "  User scope      ($UserScope): $($u.UserStatus)"
    Write-Host "  Workspace scope ($WorkspaceScope): $($u.WsStatus)"
    Write-Host ""
    Write-Host "是否用库中版本更新本地 skill？(仅新增/覆盖同名文件，不会删除本地额外文件)"
    Write-Host "  [1] 更新到 User scope"
    Write-Host "  [2] 更新到 Workspace scope"
    Write-Host "  [3] 两者都更新"
    Write-Host "  [4] 跳过"
    $choice = Read-Host "请输入选项 (1/2/3/4，直接回车默认跳过)"

    switch ($choice) {
        "1" {
            Copy-Skill $u.SrcPath $u.UserDir
            Write-Host "已更新到 User scope: $($u.UserDir)"
        }
        "2" {
            Copy-Skill $u.SrcPath $u.WsDir
            Write-Host "已更新到 Workspace scope: $($u.WsDir)"
        }
        "3" {
            Copy-Skill $u.SrcPath $u.UserDir
            Copy-Skill $u.SrcPath $u.WsDir
            Write-Host "已更新到 User scope 和 Workspace scope"
        }
        default {
            Write-Host "跳过 $($u.Name)"
        }
    }
    Write-Host ""
}

Write-Host "全部处理完成。"
