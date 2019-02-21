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

Set-GitHubConfiguration -DisableTelemetry -SessionOnly
$secure = ConvertTo-SecureString "b93fe4ce3dc7709283ac470ac1d41392e6b50142" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential "USERNAME_IS_IGNORED", $secure
Set-GitHubAuthentication -Credential $cred
Get-GitHubUser -Current

echo $mods.Name > C:\Users\$env:UserName\Desktop\hello.txt
