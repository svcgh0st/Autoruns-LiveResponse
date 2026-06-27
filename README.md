Portable Autoruns collector
===========================

Purpose
-------
Run this folder on a Windows host to collect Autoruns entries into a CSV.

Quick use
---------
1. Copy the whole folder to a USB drive or investigation share.
2. On the target host, right-click Run-Autoruns-Collector.cmd and choose "Run as administrator".
3. Choose a scan mode, or press Enter for the default.
4. The CSV will be saved in the results folder with the computer name and timestamp.

Scan modes
----------
1. Triage recent 30 days, default: recent entries, Microsoft-signed entries hidden, empty placeholder rows removed.
2. Recent 30 days full/noisy: all signature states, filtered to entries whose Autoruns Time value is within the last 30 days.
3. Unsigned only: unsigned Autoruns entries only.
4. Full normal: normal full Autoruns CSV with no recent-days or unsigned-only filter.

What is included
----------------
- Export-Autoruns.ps1: the collection/filter script
- Run-Autoruns-Collector.cmd: menu runner
- autoruns-ignore.txt: optional ignore list; one text fragment per line
- autorunsc64.exe / autorunsc.exe: Microsoft Sysinternals Autoruns command-line tools
- Eula.txt: Sysinternals license text

Notes for compromised hosts
---------------------------
- Prefer running from read-only media if available.
- Save or copy results to trusted external storage.
- The script uses the official Sysinternals Autorunsc binary and accepts the Sysinternals EULA automatically.
- Unsigned does not automatically mean malicious; treat the CSV as a triage list.

Manual command
--------------
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Export-Autoruns.ps1" -RecentDays 30 -SignatureFilter All -HideMicrosoft -DropEmptyRows -OutputCsv ".\results\autoruns-triage-recent30.csv"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Export-Autoruns.ps1" -RecentDays 30 -SignatureFilter All -OutputCsv ".\results\autoruns-recent30-full.csv"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Export-Autoruns.ps1" -SignatureFilter Unsigned -OutputCsv ".\results\autoruns-unsigned.csv"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Export-Autoruns.ps1" -SignatureFilter All -OutputCsv ".\results\autoruns-full.csv"
