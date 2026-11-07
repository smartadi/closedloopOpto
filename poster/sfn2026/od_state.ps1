# od_state.ps1 -- is a file in the OneDrive folder uploaded? Run it after every save of the poster.
#
#   powershell -File poster/sfn2026/od_state.ps1 -Path C:\Users\aditya\OneDrive\Talks\SfN2026\SfN2026_poster_v3.pptx
#
# Prints the time, OneDrive's state, the placeholder status, the file attributes and the online item id.
#   state 2, ph 14, "Archive, ReparsePoint"  = uploaded and in sync
#   state 4, ph 6,  "Archive"                = waiting to upload ("Sync pending")
# The id is the online item: it stays the same while the file keeps its link and version history.
# 2026-11-06: SfN2026_poster_v2.pptx sat at state 4 from 11-05 15:41 on, through a OneDrive restart, a fresh
# copy moved over it and closing the PowerPoint online tabs; a new file in the same folder synced in 5 s.
# Read only: it changes nothing.
param([Parameter(Mandatory)][string]$Path)
$sh = New-Object -ComObject Shell.Application
$d = $sh.Namespace((Split-Path $Path)); $it = $d.ParseName((Split-Path $Path -Leaf))
if ($null -eq $it) { 'missing'; exit 1 }
$a = (Get-Item -LiteralPath $Path -Force).Attributes
'{0} | state {1} | ph {2} | {3} | id {4}' -f (Get-Date -Format 'HH:mm:ss'), $it.ExtendedProperty('System.StorageProviderState'),
    $it.ExtendedProperty('System.FilePlaceholderStatus'), $a, $it.ExtendedProperty('System.StorageProviderFileIdentifier')
