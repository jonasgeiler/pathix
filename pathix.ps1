$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$systemPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')

Write-Output "
               _    _      _
              | |  | |    (_)
 _ __    __ _ | |_ | |__   _ __  __
| '_ \  / _` || __|| '_ \ | |\ \/ /
| |_) || (_| || |_ | | | || | >  <
| .__/  \__,_| \__||_| |_||_|/_/\_\
| |
|_|
"
Write-Warning "This script will modify the current user's and the system's PATH. Make sure to have some kind of backup before applying changes!"
Write-Output "
The following steps will be applied on the current user's and the system's PATH:

- Move entries to their correct target
    > Entries in the current user's PATH that are relevant for all users go to the system's PATH
    > Entries in the system's PATH that are only relevant for the current user go to the user's PATH

- Remove redundant entries
    > Duplicate entries in the current user's PATH
    > Duplicate entries in the system's PATH
    > Entries in the current user's PATH that already exist in the system's PATH

- Fix broken entries
    > Try to replace 'C:\Program Files' with 'C:\Program Files (x86)' in the entry and visa-versa
    > Otherwise remove them

- Shorten entries
    > Try to replace parts of the entry with another environment variable (f.e. 'C:\Program Files' with '%ProgramFiles%')
    > Normalize paths and remove redundant path separators at the end

- Sort entries

- Prepend '%SystemRoot%' to both PATHs so they correctly show up as a list when editing in control panel
"

Write-Output "
CURRENT USER'S OLD PATH:
$userPath

SYSTEM'S OLD PATH:
$systemPath
"


function NormalizePath($path) {
	# Make absolute
	$path = [System.IO.Path]::Combine(((Get-Location).Path), ($path))
	$path = [System.IO.Path]::GetFullPath($path)

	# Trim ending slash
	$path = $path.TrimEnd('\')

	return $path
}

[System.Collections.ArrayList] $userPathArr = $userPath.Split(';').ForEach({ NormalizePath($_) })
[System.Collections.ArrayList] $systemPathArr = $systemPath.Split(';').ForEach({ NormalizePath($_) })



Write-Output "
MOVE ENTRIES IN CURRENT USER'S PATH THAT ARE RELEVANT TO ALL USERS TO SYSTEM'S PATH:"

$userMoveablePaths = $userPathArr.Where({ !$_.StartsWith($env:USERPROFILE, 'CurrentCultureIgnoreCase') })

if ($userMoveablePaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	foreach ($path in $userMoveablePaths) {
		Write-Output "> Move '$path' to the system's PATH"

		$systemPathArr.Add($path) > $null
		$userPathArr.Remove($path)
	}
}


Write-Output "
MOVE USER-RELEVANT ENTRIES IN SYSTEM'S PATH TO CURRENT USER'S PATH:"

$systemMovablePaths = $systemPathArr.Where({ $_.StartsWith($env:USERPROFILE, 'CurrentCultureIgnoreCase') })

if ($systemMovablePaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	foreach ($path in $systemMovablePaths) {
		Write-Output "> Move '$path' to the current user's PATH"

		$userPathArr.Add($path) > $null
		$systemPathArr.Remove($path)
	}
}


Write-Output "
REMOVE DUPLICATES IN CURRENT USER'S PATH:"

$lowerUserPathArr = $userPathArr.ForEach({ $_.ToLower() })
[System.Collections.ArrayList] $userDuplicatePaths = @()

for ($i = 0; $i -lt $userPathArr.Count; $i++) {
	$path = $userPathArr[$i]

	if ($lowerUserPathArr.IndexOf($path.ToLower()) -ne $i) {
		$userDuplicatePaths.Add($path) > $null
	}
}

if ($userDuplicatePaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	foreach ($path in $userDuplicatePaths) {
		Write-Output "> Remove duplicate '$path'"

		$userPathArr.Remove($path)
	}
}


Write-Output "
REMOVE DUPLICATES IN SYSTEM'S PATH:"

$lowerSystemPathArr = $systemPathArr.ForEach({ $_.ToLower() })
[System.Collections.ArrayList] $systemDuplicatePaths = @()

for ($i = 0; $i -lt $systemPathArr.Count; $i++) {
	$path = $systemPathArr[$i]

	if ($lowerSystemPathArr.IndexOf($path.ToLower()) -ne $i) {
		$systemDuplicatePaths.Add($path) > $null
	}
}

if ($systemDuplicatePaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	foreach ($path in $systemDuplicatePaths) {
		Write-Output "> Remove duplicate '$path'"

		$systemPathArr.Remove($path)
	}
}


Write-Output "
REMOVE ENTRIES IN CURRENT USER'S PATH THAT ARE ALREADY IN SYSTEM'S PATH:"

$lowerSystemPathArr = $systemPathArr.ForEach({ $_.ToLower() })
$userRedundantPaths = $userPathArr.Where({ $lowerSystemPathArr.Contains($_.ToLower()) })

if ($userRedundantPaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	foreach ($path in $userRedundantPaths) {
		Write-Output "> Remove redundant '$path'"

		$userPathArr.Remove($path)
	}
}


Write-Output "
REMOVE OR FIX BROKEN ENTRIES IN CURRENT USER'S PATH:"

$userBrokenPaths = $userPathArr.Where({ !(Test-Path -Path $_) })

if ($userBrokenPaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	$commonProgramFiles32 = NormalizePath([System.Environment]::GetEnvironmentVariable('CommonProgramFiles(x86)'))
	$commonProgramFiles64 = NormalizePath([System.Environment]::GetEnvironmentVariable('CommonProgramFiles'))
	$programFiles32 = NormalizePath([System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)'))
	$programFiles64 = NormalizePath([System.Environment]::GetEnvironmentVariable('ProgramFiles'))

	foreach ($path in $userBrokenPaths) {
		$fixedPath = ''
		if ($path.StartsWith($commonProgramFiles32, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$commonProgramFiles64$($path.Substring($commonProgramFiles32.Length))"
		} elseif ($path.StartsWith($commonProgramFiles64, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$commonProgramFiles32$($path.Substring($commonProgramFiles64.Length))"
		} elseif ($path.StartsWith($programFiles32, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$programFiles64$($path.Substring($programFiles32.Length))"
		} elseif ($path.StartsWith($programFiles64, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$programFiles32$($path.Substring($programFiles64.Length))"
		} else {
			$fixedPath = $path
		}

		if (Test-Path -Path $fixedPath) {
			Write-Output "> Fix broken '$path' with '$fixedPath'"
		} else {
			Write-Output "> Remove broken '$path'"

			$userPathArr.Remove($path)
		}
	}
}


Write-Output "
REMOVE OR FIX BROKEN ENTRIES IN SYSTEM'S PATH:"

$systemBrokenPaths = $systemPathArr.Where({ !(Test-Path -Path $_) })

if ($systemBrokenPaths.Count -eq 0) {
	Write-Output "> Nothing to do..."
} else {
	$commonProgramFiles32 = NormalizePath([System.Environment]::GetEnvironmentVariable('CommonProgramFiles(x86)'))
	$commonProgramFiles64 = NormalizePath([System.Environment]::GetEnvironmentVariable('CommonProgramFiles'))
	$programFiles32 = NormalizePath([System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)'))
	$programFiles64 = NormalizePath([System.Environment]::GetEnvironmentVariable('ProgramFiles'))

	foreach ($path in $systemBrokenPaths) {
		$fixedPath = ''
		if ($path.StartsWith($commonProgramFiles32, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$commonProgramFiles64$($path.Substring($commonProgramFiles32.Length))"
		} elseif ($path.StartsWith($commonProgramFiles64, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$commonProgramFiles32$($path.Substring($commonProgramFiles64.Length))"
		} elseif ($path.StartsWith($programFiles32, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$programFiles64$($path.Substring($programFiles32.Length))"
		} elseif ($path.StartsWith($programFiles64, 'CurrentCultureIgnoreCase')) {
			$fixedPath = "$programFiles32$($path.Substring($programFiles64.Length))"
		} else {
			$fixedPath = $path
		}

		if (Test-Path -Path $fixedPath) {
			Write-Output "> Fix broken '$path' with '$fixedPath'"
		} else {
			Write-Output "> Remove broken '$path'"

			$systemPathArr.Remove($path)
		}
	}
}


Write-Output "
SHORTEN ENTRIES IN CURRENT USER'S PATH:"

$varsToShortenWith = @(
'CommonProgramFiles(x86)', # C:\Program Files (x86)\Common Files
'ProgramFiles(x86)', # C:\Program Files (x86)
'CommonProgramFiles', # C:\Program Files\Common Files
'ProgramFiles', # C:\Program Files
'AppData', # C:\Users\{username}\AppData\Roaming
'Temp', # C:\Users\{Username}\AppData\Local\Temp
'LocalAppData', # C:\Users\{username}\AppData\Local
'UserProfile', # C:\Users\{username}
'Public', # C:\Users\Public
'ProgramData', # C:\ProgramData
'SystemRoot' # C:\WINDOWS
)

function ShortenPath($path) {
	foreach ($var in $varsToShortenWith) {
		$varPath = NormalizePath([System.Environment]::GetEnvironmentVariable($var))

		if ( $path.StartsWith($varPath, 'CurrentCultureIgnoreCase')) {
			return "%$var%$($path.Substring($varPath.Length))"
		}
	}

	return $path
}

$shortenedUserPathArr = $userPathArr.ForEach({ ShortenPath($_) })

for ($i = 0; $i -lt $userPathArr.Count; $i++) {
	if ($userPathArr[$i] -ne $shortenedUserPathArr[$i]) {
		Write-Output "> Shorten '$($userPathArr[$i])' to '$($shortenedUserPathArr[$i])'"
	}
}

$userPathArr = $shortenedUserPathArr


Write-Output "
SHORTEN ENTRIES IN SYSTEM'S PATH:"

$shortenedSystemPathArr = $systemPathArr.ForEach({ ShortenPath($_) })

for ($i = 0; $i -lt $systemPathArr.Count; $i++) {
	if ($systemPathArr[$i] -ne $shortenedSystemPathArr[$i]) {
		Write-Output "> Shorten '$($systemPathArr[$i])' to '$($shortenedSystemPathArr[$i])'"
	}
}

$systemPathArr = $shortenedSystemPathArr


Write-Output "
SORT ENTRIES IN CURRENT USER'S PATH..."

$userPathArr.Sort()

Write-Output "> Done."


Write-Output "
SORT ENTRIES IN SYSTEM'S PATH..."

$systemPathArr.Sort()

Write-Output "> Done."


Write-Output "
PREPEND %SystemRoot% TO CURRENT USER'S PATH..."

$userPathArr.Remove('%SystemRoot%')
$userPathArr.Insert(0, '%SystemRoot%')

Write-Output "> Done."


Write-Output "
PREPEND %SystemRoot% TO SYSTEM'S PATH..."

$systemPathArr.Remove('%SystemRoot%')
$systemPathArr.Insert(0, '%SystemRoot%')

Write-Output "> Done."


# Build final strings
$newUserPath = $userPathArr.ToArray() -join ';'
$newSystemPath = $systemPathArr.ToArray() -join ';'

Write-Output "

CURRENT USER'S NEW PATH:
$newUserPath

SYSTEM'S NEW PATH:
$newSystemPath

"

$confirmation = Read-Host "Apply proposed changes to the current user's and the system's PATH? (check changes above) [y/N]"

if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Output "Exiting..."
    exit
}

Set-ItemProperty -Path "HKCU:\Environment" -Name Path -Value $newUserPath -Type ExpandString
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name Path -Value $newSystemPath -Type ExpandString

Write-Output "Applied changes."
