# watch_schema.ps1
# PowerShell file watcher: supabase_schema.sql değişirse otomatik Rake task çalıştırır

$folder = "D:\Projects\RubyTeklif\db"
$file = "supabase_schema.sql"

Write-Host "Watching $folder\$file for changes..."

$filter = [System.IO.Path]::GetFileName($file)
$fsw = New-Object System.IO.FileSystemWatcher $folder, $filter
$fsw.NotifyFilter = [System.IO.NotifyFilters]'LastWrite'

$action = {
    Write-Host "$(Get-Date -Format "HH:mm:ss") - Detected change in supabase_schema.sql, updating schema..."
    Set-Location "D:\Projects\RubyTeklif"
    rake db:update_all
}

Register-ObjectEvent $fsw Changed -Action $action | Out-Null

while ($true) { Start-Sleep 1 }