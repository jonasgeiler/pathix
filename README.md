# pathix

A simple Powershell script to clean up your PATH on Windows

## What it does

- Move entries to their correct target
  - Entries in the current user's PATH that are relevant for all users go to the system's PATH
  - Entries in the system's PATH that are only relevant for the current user go to the user's PATH
- Remove redundant entries
  - Duplicate entries in the current user's PATH
  - Duplicate entries in the system's PATH
  - Entries in the current user's PATH that already exist in the system's PATH
- Remove or fix broken entries
  - Try to replace `C:\Program Files` with `C:\Program Files (x86)` in the entry and visa-versa
  - Otherwise, remove them
- Shorten entries
  - Try to replace parts of the entry with another environment variable (f.e. `C:\Program Files` with `%ProgramFiles%`)
  - Normalize paths and remove redundant path separators at the end
- Sort entries
- Prepend `%SystemRoot%` to both PATHs so they correctly show up as a list when editing in control panel

## How to use

Open PowerShell as Administrator and run:
```powershell
./pathix.ps1
```
> NOTE: Further information and instructions will be written to console.
