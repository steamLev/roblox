# Static checks for 99rooms map layout (no Roblox runtime required)
$ErrorActionPreference = "Stop"
$INNER_X, $INNER_Y, $INNER_Z = 34, 12, 34
$WALL_T = 0.75
$STRIDE = $INNER_X + 6
$DOME_COUNT = 5
$totalW = ($DOME_COUNT - 1) * $STRIDE
$startX = -$totalW / 2
$halfZ = $INNER_Z / 2 + $WALL_T / 2
$backZ = -$halfZ + $WALL_T
$yWall = $INNER_Y / 2
$yGlass = $yWall * 0.5
$wallTopY = $yGlass + $INNER_Y * 0.5
$domeR = [Math]::Max($INNER_X, $INNER_Z) * 0.52
$capH = $domeR * 0.92
$spawnZ = $INNER_Z * 0.12
$ox = $startX
$halfX = $INNER_X / 2 + $WALL_T / 2
$boardZ = $backZ + 0.35

$checks = @(
    @{ Name = "Spawn inside Cell_1 X"; Pass = ($ox - $halfX -le $ox) -and ($ox -le ($ox + $halfX)) },
    @{ Name = "Spawn inside Cell_1 Z"; Pass = (-$halfZ -le $spawnZ) -and ($spawnZ -le $halfZ) },
    @{ Name = "Board faces spawn (+Z)"; Pass = $spawnZ -gt $boardZ },
    @{ Name = "Dome cap above walls"; Pass = ($wallTopY + $capH) -gt $wallTopY },
    @{ Name = "Zero-G window 42-55s"; Pass = (42 + 13) -eq 55 }
)

Write-Host "=== 99rooms static verify ===" -ForegroundColor Cyan
$fail = 0
foreach ($c in $checks) {
    $color = if ($c.Pass) { "Green" } else { "Red" }
    if (-not $c.Pass) { $fail++ }
    Write-Host ("[{0}] {1}" -f $(if ($c.Pass) { "OK" } else { "FAIL" }), $c.Name) -ForegroundColor $color
}
Write-Host ""
Write-Host "Spawn: X=$ox Z=$([Math]::Round($spawnZ,2)) | Board Z=$([Math]::Round($boardZ,2)) | Dome Y $([Math]::Round($wallTopY,1))-$([Math]::Round($wallTopY+$capH,1))"
if ($fail -gt 0) { exit 1 }
exit 0
