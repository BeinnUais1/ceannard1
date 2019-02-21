$packs = Get-PackageProvider
If(!($packs.Name -clike 'nuget'))
{
	Install-PackageProvider -Name NuGet -scope CurrentUser -Force
}
$packs = Get-PackageProvider
If(!($packs.Name -clike 'nuget'))
{
	echo "ERROR: Unable to install NuGet."
}

$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGitHub'))
{
	Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
}
$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGithub'))
{
	echo "ERROR: Unable to install PSFG."
}

echo $mods.Name > C:\Users\$env:UserName\Desktop\hello.txt