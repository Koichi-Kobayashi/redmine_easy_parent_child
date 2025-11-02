# Redmine Easy Parent Child Plugin - パッケージ化スクリプト
# このスクリプトはプラグインをZIP形式でパッケージ化します

param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "."
)

# UTF-8エンコーディングを設定（日本語文字の表示を正しくするため）
try {
    # コンソールの出力エンコーディングをUTF-8に設定
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
    
    # システムのコードページをUTF-8に変更
    $null = [Console]::OutputEncoding
    chcp 65001 | Out-Null
    
    # PowerShellの出力エンコーディングを設定
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # フォントを設定（日本語表示用）
    if ($Host.UI.RawUI) {
        try {
            $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 3000)
        } catch {}
    }
} catch {
    # エラーが発生しても続行
    Write-Warning "UTF-8 encoding setting failed, but continuing..."
}

# スクリプトのディレクトリに移動
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 日本語メッセージを変数に定義（UTF-8エンコーディングの問題を回避）
# シングルクォートを使用してエンコーディングの問題を回避
$Msg_PackagingScript = 'パッケージ化スクリプト'
$Msg_PluginDir = 'プラグインディレクトリ'
$Msg_OutputPath = '出力先'
$Msg_VersionDetected = 'init.rbから検出されたバージョン: '
$Msg_VersionMismatch = '指定されたバージョン({0})とinit.rbのバージョン({1})が異なります。init.rbのバージョンを使用しますか? (Y/N)'
$Msg_RemovingTempDir = '既存の一時ディレクトリを削除しています...'
$Msg_CopyingFiles = 'ファイルをコピーしています...'
$Msg_WarningMissingFiles = '警告: 以下の必須ファイルが見つかりません:'
$Msg_ContinueQuestion = '続行しますか? (Y/N)'
$Msg_PackagingCancelled = 'パッケージ化をキャンセルしました。'
$Msg_CreatingZip = 'ZIPファイルを作成しています...'
$Msg_RemovedExistingZip = '既存のZIPファイルを削除しました。'
$Msg_PackagingCompleted = 'パッケージ化が完了しました!'
$Msg_File = 'ファイル: '
$Msg_Size = 'サイズ: '
$Msg_ErrorCreatingZip = 'エラー: ZIPファイルの作成に失敗しました。'
$Msg_RemovingTempFiles = '一時ファイルを削除しています...'
$Msg_Completed = '完了しました!'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Redmine Easy Parent Child Plugin" -ForegroundColor Cyan
Write-Host $Msg_PackagingScript -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PluginName = "redmine_easy_parent_child"
$PluginDir = $ScriptDir
$OutputPath = Join-Path $OutputDir "$PluginName-v$Version.zip"

Write-Host "$Msg_PluginDir`: $PluginDir" -ForegroundColor Yellow
Write-Host "$Msg_OutputPath`: $OutputPath" -ForegroundColor Yellow
Write-Host ""

# init.rbからバージョンを読み取る（オプション）
$InitRbPath = Join-Path $PluginDir "init.rb"
if (Test-Path $InitRbPath) {
    $InitContent = Get-Content $InitRbPath -Raw -Encoding UTF8
    # バージョン文字列を検出（シングルクォートまたはダブルクォートで囲まれた値）
    # 正規表現を文字列連結で構築してエンコーディング問題を回避
    $quote = "'"
    $dquote = '"'
    $versionPattern = "version\s+[$quote$dquote]([^$quote$dquote]+)[$quote$dquote]"
    if ($InitContent -match $versionPattern) {
        $VersionFromInit = $Matches[1]
        Write-Host "$Msg_VersionDetected$VersionFromInit" -ForegroundColor Green
        if ($VersionFromInit -ne $Version) {
            $Confirm = Read-Host ($Msg_VersionMismatch -f $Version, $VersionFromInit)
            if ($Confirm -eq "Y" -or $Confirm -eq "y") {
                $Version = $VersionFromInit
                $OutputPath = Join-Path $OutputDir "$PluginName-v$Version.zip"
            }
        }
    }
}

# 除外するファイル/ディレクトリのパターン
$ExcludePatterns = @(
    ".git",
    ".gitignore",
    ".gitattributes",
    "*.log",
    "log\*",
    "tmp\*",
    ".DS_Store",
    "Thumbs.db",
    "node_modules",
    ".vs",
    ".vscode",
    ".idea",
    "*.swp",
    "*.swo",
    "*~",
    ".env",
    ".env.local",
    "package.ps1",
    "package.bat",
    "temp_package"
)

# 一時作業ディレクトリを作成
$TempDir = Join-Path $PluginDir "temp_package"
if (Test-Path $TempDir) {
    Write-Host $Msg_RemovingTempDir -ForegroundColor Yellow
    Remove-Item -Path $TempDir -Recurse -Force
}

$TempPluginDir = Join-Path $TempDir $PluginName
New-Item -ItemType Directory -Path $TempPluginDir -Force | Out-Null

Write-Host $Msg_CopyingFiles -ForegroundColor Yellow

# ファイルとディレクトリをコピー（除外パターンを適用）
Get-ChildItem -Path $PluginDir -Force | ForEach-Object {
    $Item = $_
    $ShouldExclude = $false
    
    # 除外パターンをチェック
    foreach ($Pattern in $ExcludePatterns) {
        if ($Item.Name -like $Pattern -or $Item.FullName -like "*\$Pattern" -or $Item.FullName -like "*\$Pattern\*") {
            $ShouldExclude = $true
            break
        }
        # ワイルドカードパターン対応
        if ($Pattern -like "*\*") {
            $BasePattern = $Pattern -replace "\\\*", ""
            if ($Item.FullName -like "*\$BasePattern") {
                $ShouldExclude = $true
                break
            }
        }
    }
    
    # 除外パターンに一致しない場合のみコピー
    if (-not $ShouldExclude -and $Item.Name -ne "temp_package") {
        if ($Item.PSIsContainer) {
            Copy-Item -Path $Item.FullName -Destination $TempPluginDir -Recurse -Force
        } else {
            Copy-Item -Path $Item.FullName -Destination $TempPluginDir -Force
        }
    }
}

# 必須ファイルの存在確認
$RequiredFiles = @("init.rb", "README.md", "README.ja.md")
$MissingFiles = @()
foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $TempPluginDir $File
    if (-not (Test-Path $FilePath)) {
        $MissingFiles += $File
    }
}

if ($MissingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host $Msg_WarningMissingFiles -ForegroundColor Red
    foreach ($File in $MissingFiles) {
        Write-Host "  - $File" -ForegroundColor Red
    }
    $Continue = Read-Host $Msg_ContinueQuestion
    if ($Continue -ne "Y" -and $Continue -ne "y") {
        Remove-Item -Path $TempDir -Recurse -Force
        Write-Host $Msg_PackagingCancelled -ForegroundColor Yellow
        exit 1
    }
}

Write-Host $Msg_CreatingZip -ForegroundColor Yellow

# 既存のZIPファイルを削除
if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Force
    Write-Host $Msg_RemovedExistingZip -ForegroundColor Yellow
}

# ZIPファイルを作成
try {
    Compress-Archive -Path "$TempDir\*" -DestinationPath $OutputPath -Force
    $ZipSize = (Get-Item $OutputPath).Length / 1MB
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host $Msg_PackagingCompleted -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "$Msg_File$OutputPath" -ForegroundColor Green
    Write-Host "$Msg_Size$([math]::Round($ZipSize, 2)) MB" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host $Msg_ErrorCreatingZip -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 一時ディレクトリを削除
Write-Host $Msg_RemovingTempFiles -ForegroundColor Yellow
Remove-Item -Path $TempDir -Recurse -Force

Write-Host ""
Write-Host $Msg_Completed -ForegroundColor Green
Write-Host ""
