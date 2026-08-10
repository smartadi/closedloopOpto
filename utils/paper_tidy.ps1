<#
.SYNOPSIS
  Audit / tidy the paper figure tree against the "PDF means locked" policy in PAPER.md.

.DESCRIPTION
  Classifies every asset under paper/ into KEEP (a locked panel listed in PAPER.md),
  ARCHIVE (superseded / stale duplicate / dead figure folder) or EXPLORE (exploratory
  PNG that should not sit beside locked panels), and prints the plan.

  NOTHING MOVES unless you pass -Apply. Moves are into paper/_archive/ and
  paper/explore/ with the ORIGINAL RELATIVE PATH PRESERVED, so an Illustrator file
  that loses a link can be repointed at the mirrored path. Nothing is ever deleted.

  ** Illustrator warning ** The .ai files in paper/images/ link to panel PDFs by path.
  Moving a linked PDF makes Illustrator prompt on next open. Run without -Apply first,
  read the plan, and only then decide.

.EXAMPLE
  pwsh utils/paper_tidy.ps1                 # dry run - prints the plan, moves nothing
  pwsh utils/paper_tidy.ps1 -Only RootDupes # dry run, one rule only
  pwsh utils/paper_tidy.ps1 -Apply          # actually move
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [ValidateSet('All', 'RootDupes', 'Figure4', 'Figure5Stale', 'Variants', 'ExplorePngs')]
    [string]$Only = 'All'
)

$ErrorActionPreference = 'Stop'

# Anchor to the repo root via this script's own location - never the CWD.
# (This is the same bug that scattered exports into projects\paper; see PAPER.md.)
$repoRoot  = Split-Path -Parent $PSScriptRoot
$paperDir  = Join-Path $repoRoot 'paper'
$imagesDir = Join-Path $paperDir 'images'
$archive   = Join-Path $paperDir '_archive'
$explore   = Join-Path $paperDir 'explore'

if (-not (Test-Path $paperDir)) { throw "No paper/ directory under $repoRoot" }

$plan = [System.Collections.Generic.List[object]]::new()

function Add-Plan {
    param($File, $Dest, $Rule, $Reason)
    $plan.Add([pscustomobject]@{
        Rule   = $Rule
        From   = $File.FullName.Substring($paperDir.Length + 1)
        To     = $Dest
        Reason = $Reason
        Size   = $File.Length
    })
}

function Get-MirroredDest {
    param($File, $Base)
    $rel = $File.FullName.Substring($paperDir.Length + 1)
    Join-Path $Base $rel
}

$want = { param($r) $Only -eq 'All' -or $Only -eq $r }

# --- Rule 1: stale duplicates in paper/ root that also live current in images/figureN/ ---
# These are the dangerous ones: same basename, months older, and a relink can grab them.
if (& $want 'RootDupes') {
    Get-ChildItem -Path $paperDir -Filter *.pdf -File | ForEach-Object {
        $twin = Get-ChildItem -Path $imagesDir -Filter $_.Name -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
        if ($twin) {
            $age = [int]($twin.LastWriteTime - $_.LastWriteTime).TotalDays
            $why = if ($age -gt 0) {
                "tree copy is $age d newer ($($twin.LastWriteTime.ToString('yyyy-MM-dd')) vs $($_.LastWriteTime.ToString('yyyy-MM-dd')))"
            } else {
                'duplicate of a file already in images/'
            }
            Add-Plan $_ (Get-MirroredDest $_ $archive) 'RootDupes' $why
        }
    }
}

# --- Rule 2: figure4/ is a graveyard - old sine panels + exploratory factor grid ---
# The planned 4A-4E do not exist yet, and the folder name now collides with the
# state-dependence figure that will need it.
if (& $want 'Figure4') {
    $f4 = Join-Path $imagesDir 'figure4'
    if (Test-Path $f4) {
        Get-ChildItem -Path $f4 -File | ForEach-Object {
            $reason = switch -Regex ($_.Name) {
                '^sine_(4[A-F]|panel_[A-F])' { 'old Fig-5 sine panel, superseded by figure5/sine_5*'; break }
                '^(factor_|claim[0-9])'      { 'exploratory error-contribution grid (incl. _z variants)'; break }
                '^(wb_|rrr_)'                { 'widebrain/RRR - figure assignment still TBD'; break }
                '^prestim_dev_vs_mse'        { 'CIRCULAR panel - x is the first sample inside the y window'; break }
                default                      { 'figure4/ holds no locked panel; 4A-4E do not exist yet' }
            }
            Add-Plan $_ (Get-MirroredDest $_ $archive) 'Figure4' $reason
        }
    }
}

# --- Rule 3: figure5/ retired-session panels + dropped 5G/5H + misplaced assemblies ---
if (& $want 'Figure5Stale') {
    $f5 = Join-Path $imagesDir 'figure5'
    if (Test-Path $f5) {
        Get-ChildItem -Path $f5 -File | ForEach-Object {
            $reason = $null
            if ($_.Name -match '2026-07-14|2026-07-01') {
                $reason = 'retired session - primary is s3 (2026-07-21); combined panels carry s1/s2'
            } elseif ($_.Name -match '^sine_5[GH]_') {
                $reason = 'panel DROPPED 2026-07-29, replaced by combined 5I/5K'
            } elseif ($_.Name -match '^Figure[0-9]') {
                $reason = 'assembled figure sitting inside a PANEL folder - belongs in images/'
            }
            if ($reason) { Add-Plan $_ (Get-MirroredDest $_ $archive) 'Figure5Stale' $reason }
        }
    }
}

# --- Rule 4: metric/colour variants must not be PDFs beside a locked panel ---
if (& $want 'Variants') {
    Get-ChildItem -Path $imagesDir -Filter *.pdf -File -Recurse |
        Where-Object { $_.Name -match '_(cb|z|cperr|peakdev)\.pdf$' } |
        ForEach-Object {
            Add-Plan $_ (Get-MirroredDest $_ $explore) 'Variants' 'variant export - policy says PNG under explore/'
        }
}

# --- Rule 5: exploratory PNG dumps living inside the figure tree ---
if (& $want 'ExplorePngs') {
    $saga = Join-Path $imagesDir 'predictor_saga'
    if (Test-Path $saga) {
        Get-ChildItem -Path $saga -File | ForEach-Object {
            Add-Plan $_ (Get-MirroredDest $_ $explore) 'ExplorePngs' 'exploratory output - correct format, wrong tree'
        }
    }
}

# Dedupe: a file can match more than one rule (e.g. figure4/*_z.pdf hits both Figure4
# and Variants). First rule wins - otherwise Apply would try to move it twice and the
# second Move-Item would throw on the now-missing source.
$plan = @($plan | Group-Object From | ForEach-Object { $_.Group[0] })

# ---------------------------------------------------------------- report ----
if ($plan.Count -eq 0) {
    Write-Host "Nothing to do - tree already matches the policy." -ForegroundColor Green
    return
}

Write-Host ''
Write-Host ('=' * 78)
Write-Host (' PAPER TIDY - {0}' -f $(if ($Apply) { 'APPLYING' } else { 'DRY RUN (nothing will move)' }))
Write-Host ('=' * 78)

$plan | Group-Object Rule | Sort-Object Name | ForEach-Object {
    $mb = [math]::Round((($_.Group | Measure-Object Size -Sum).Sum / 1MB), 1)
    Write-Host ''
    Write-Host ("-- {0}  ({1} files, {2} MB)" -f $_.Name, $_.Count, $mb) -ForegroundColor Cyan
    $_.Group | Sort-Object From | ForEach-Object {
        Write-Host ("   {0}" -f $_.From)
        Write-Host ("       -> {0}" -f $_.Reason) -ForegroundColor DarkGray
    }
}

$totalMb = [math]::Round((($plan | Measure-Object Size -Sum).Sum / 1MB), 1)
Write-Host ''
Write-Host ("TOTAL: {0} files, {1} MB" -f $plan.Count, $totalMb) -ForegroundColor Yellow

if (-not $Apply) {
    Write-Host ''
    Write-Host 'Dry run only. Re-run with -Apply to move these into paper/_archive and paper/explore.' -ForegroundColor Yellow
    Write-Host 'Paths are mirrored, so a broken Illustrator link is recoverable at the same relative path.' -ForegroundColor Yellow
    return
}

# ----------------------------------------------------------------- apply ----
$moved = 0
foreach ($p in $plan) {
    $src = Join-Path $paperDir $p.From
    $dst = $p.To
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host ("SKIP (source gone): {0}" -f $p.From) -ForegroundColor DarkYellow
        continue
    }
    if (Test-Path -LiteralPath $dst) {
        Write-Host ("SKIP (target exists): {0}" -f $p.From) -ForegroundColor DarkYellow
        continue
    }
    Move-Item -LiteralPath $src -Destination $dst
    $moved++
}
Write-Host ''
Write-Host ("Moved {0} of {1} files. Nothing deleted." -f $moved, $plan.Count) -ForegroundColor Green
Write-Host 'If Illustrator prompts for a missing link, point it at paper/_archive/<same relative path>.'
