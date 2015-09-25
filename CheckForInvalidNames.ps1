<#
                                                             
.SYNOPSIS  
    Search for invalid file and foldernames    
.DESCRIPTION  
    Search provided path for folders and filenames with invalid names; for synching local network folders with Office 365
.NOTES  
    File Name      : CheckInvalidNames.ps1
    Author         : David Bisnhtok © 2015 ZEFTOL CO
    Date           : 09/10/2015
    Prerequisite   : PowerShell V1 and up.

#>

Clear-Host # clear screen

$client =
@"
  __ __  ___   ___   _____ ______ _____ _    _ 
 /_ /_ |/ _ \ / _ \ / ____|  ____|_   _| |  | |
  | || | (_) | (_) | (___ | |__    | | | |  | |
  | || |\__, |\__, |\___ \|  __|   | | | |  | |
  | || |  / /   / / ____) | |____ _| |_| |__| |
  |_||_| /_/   /_/ |_____/|______|_____|\____/
"@

write-host $client `n `n `n

<# 

the rules are stored in a xml document

rule data structure:

rule id = unique identifier for each rule

rule name = name of rule

rule category = descriptive string that indicates what rule is being applied in plain langauge

*rule type =  indicates if single char or whole string; ie "Char" or "String"

*rule comparison type = indicates how comparison is performed; ie "Match" or ?

rule value = the actual value (char or string) to look for

rule apply to = "File" or "Folder" or "Both" ("Both" = both file and folder) or "Extension"

rule version = indicates if applies to "SharePoint Online" or "SharePoint Server 2013" or "Both"

rule position = either "1" (or "2","3", etc...) or "ALL" for where to look for value to match on; if "Whole" then not part match but name must equal whole word

#>


# SharePoint Online rules

# SharePoint Foundation and SharePoint Server rules

<#

Source: https://support.microsoft.com/en-us/kb/2933738

Restrictions and limitations when you sync SharePoint libraries to your computer through OneDrive for Business

Article ID: 2933738 - Last Review: 07/09/2015 18:54:00 - Revision: 29.0

Applies to
Microsoft SharePoint Online
Microsoft SharePoint Server 2013
OneDrive for Business
Keywords:
o365 o365e o365p o365a o365m o365022013 kbfixme kbmsifixme KB2933738

#>

# run time switches = which rule version to apply, starting folder, 
# how report is delivered local file system or email, 
# path of output folder for report OR email address for report,

#Set-Variable FILE -option Constant -value "File"
#Set-Variable FOLDER -option Constant -value "Folder"

# list of paths checked
# list of paths marked invalid with reasons why marked as invalid

$global:stoptraverse = $False

$global:ItemsChecked = @()

$global:ItemCounter = 0

$global:FoldersChecked = @()

$global:FolderCounter = 0

$global:FilesChecked = @()

$global:FileCounter = 0

$global:InvalidFolders = @()

$global:InvalidFolderCounter = 0

$global:InvalidFiles = @()

$global:InvalidFileCounter = 0

function GetNameRulesXMLPath
{

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$False,Position=1)]
        [bool]$DebugMode = $True
    )

    # get target folder from configuartion file

    # assumption that config file in same folder as script

    # assumption : config file name is same as script, CheckForInvalidNames.XML
 
    $configfileDIR ="c:\Workspace\powershell\CheckForInvalidNames\"
    $configfilename = "CheckForInvalidNames.XML"
    $configfilepath = "$configfileDIR$configfilename"
 
    $rulexmldir = $null
    $rulexmlfilename = $null
    $rulexmlpath = $null

    try
    {

        if ($DebugMode) 
        {
            write-host "Retrieving Config settings...$configfilepath" `n
        }

        [xml]$ConfigFile = Get-Content $configfilepath 

        # look for ConfigSettings element
        $rulexmldir = $ConfigFile.ConfigSettings.RuleXMLDIR
        $rulexmlfilename = $ConfigFile.ConfigSettings.RuleXMLFileName

        if ($rulexmldir -And $rulexmlfilename)
        {
            $rulexmlpath = "$rulexmldir$rulexmlfilename"
        }

    }
    catch
    {
  
        if ($DebugMode) 
        {
            write-host "Exception Type : " $_.Exception.GetType().FullName
            write-host "Exception Message : " write-host "Exception : " $_.Exception.Message
        }
    
    }

    if ($DebugMode) 
    {
	    if ($rulexmlpath) 
	    {
		    write-host "Target Path of Rule XML Settings : " $rulexmlpath `n
	    }
		
    }

    return $rulexmlpath

}



function GetNameRules
{

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,Position=1)]
        [string]$rulexmlpath,
        [Parameter(Mandatory=$False,Position=2)]
  	    [bool]$DebugMode = $True
    )

    try
    {

        if ($DebugMode) 
        {
            write-host "Retrieving Invalid Name Rules...$rulexmlpath" `n
        }

        # folder name rules
        # list of invalid folder chars
        # list of invalid folder names
        # file name rules
        # list of invalid filename chars
        # list of invalid file names

        [xml]$rules = Get-Content $rulexmlpath 

        if ($rules)
        {
            <#

            # write-host $RuleFile `n
            foreach ($rule in $rules.SharePointNameRules.Rule)
            {
                write-host $rule.name
            }

            #>
        }

    }
    catch
    {
  
        if ($DebugMode) 
        {
            write-host "Exception Type : " $_.Exception.GetType().FullName
            write-host "Exception Message : " write-host "Exception : " $_.Exception.Message
        }
    
    }

    return $rules

}

function TraverseFolder
{

    [CmdletBinding()]
 	Param
 	(
  	    [Parameter(Mandatory=$True,Position=1)]
  	    [string]$startfolder,
        [Parameter(Mandatory=$True,Position=2)]
        [object[]]$filenamerules,
        [Parameter(Mandatory=$True,Position=3)]
        [object[]]$filerules,
        [Parameter(Mandatory=$True,Position=4)]
        [object[]]$fileextensionrules,
        [Parameter(Mandatory=$True,Position=5)]
        [object[]]$foldernamerules,
        [Parameter(Mandatory=$True,Position=6)]
        [object[]]$folderrules,
        [Parameter(Mandatory=$False,Position=7)]
  	    [bool]$CompleteSearch = $True,
	    [Parameter(Mandatory=$False,Position=8)]
  	    [bool]$DebugMode = $True
 	)

    try
    {

        $SourceObjects = get-childitem $startfolder

        if ($SourceObjects) 
	    {

            $Qkey = 81 # A "q" key

            foreach ($element in $SourceObjects)
            {

                if ($host.ui.RawUi.KeyAvailable)
                { 
                    $key = $host.ui.RawUI.ReadKey("NoEcho, IncludeKeyUp") 
                    if (($key.VirtualKeyCode -eq $Qkey) -AND ($key.ControlKeyState -match "^(Right|Left)CtrlPressed$"))
                    { 
                        Write-Host `n
                        Write-Host "You pressed the key Ctrl+q, script ends." `n
                        # stop loop
                        $global:stoptraverse = $True
                        break
                    }
                }

                $errorfound = $False
                $checktype = $null
                $checkvalue = $null

                if ($element -is [System.IO.DirectoryInfo])
                {

                    $checktype = "Folder"
                    $path = "$startfolder$element\"

                    # if $element is folder then search it
                    write-host "Checking Folder : $path"

                    $checkvalue = "$($element.Name)"
                    $fullname = "$($element.FullName)"

                    $errorfound = CheckForInvalidRulesFolder $checkvalue $fullname $foldernamerules $folderrules

                }
                else
                {
                    $checktype = "File"

                    write-host "Checking File : $element"
                    
                    $checkvalue = "$($element.FullName)"

                    $errorfound = CheckForInvalidRulesFile $checkvalue $filenamerules $filerules $fileextensionrules

                }

                if ($errorfound -and ($CompleteSearch -eq $False))
                {
                    # stop loop
                    $global:stoptraverse = $True
                    break
                }

                if (($checktype -eq "Folder") -and ($global:stoptraverse -eq $False))
                {

                    TraverseFolder $path $filenamerules $filerules $fileextensionrules $foldernamerules $folderrules $CompleteSearch

                }

                if ($global:stoptraverse)
                {
                    return
                }

            }


        }

    }
    catch
    {
         
        if ($DebugMode) 
        {
            write-host "Exception Type : " $_.Exception.GetType().FullName
            write-host "Exception Message : " write-host "Exception : " $_.Exception.Message
        }

    }

    

}

function CheckForInvalidRulesFolder
{
    [CmdletBinding()]
 	Param
 	(
  	    [Parameter(Mandatory=$True,Position=1)]
  	    [string]$checkvalue,
        [Parameter(Mandatory=$True,Position=2)]
  	    [string]$fullname,
        [Parameter(Mandatory=$True,Position=3)]
        [object[]]$foldernamerules,
        [Parameter(Mandatory=$True,Position=4)]
        [object[]]$folderrules,
	    [Parameter(Mandatory=$False,Position=5)]
  	    [bool]$DebugMode = $True
 	)

    $foldername = $checkvalue.ToLower()

    $global:ItemCounter++

    # Item checked: UID, Name, Full Path, Type (File or Folder)
    $object = New-Object –TypeName PSObject
    $object | Add-Member –MemberType NoteProperty –Name UID –Value $global:ItemCounter
    $object | Add-Member –MemberType NoteProperty –Name Name –Value $checkvalue
    $object | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullname
    $object | Add-Member –MemberType NoteProperty –Name Type –Value "Folder"
    # Write-Output $object

    $global:ItemsChecked += $object

    $global:FolderCounter++

    # Folder checked: UID, Name, Full Path
    $folder = New-Object –TypeName PSObject
    $folder | Add-Member –MemberType NoteProperty –Name UID –Value $global:FolderCounter
    $folder | Add-Member –MemberType NoteProperty –Name Name –Value $checkvalue
    $folder | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullname

    $global:FoldersChecked += $folder

    $noerrorfound = $True
    $errorfound = $False

    # Folder names can have up to 250 characters.

    if ($foldername.Length -gt 250)
    {

        $noerrorfound = $False
        write-host "Invalid folder size : $foldername.Length"

        $global:InvalidFolderCounter++

        # Invalid Folder: UID, Name, Full Path, Reason
        $invalidfolder = New-Object –TypeName PSObject
        $invalidfolder | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFolderCounter
        $invalidfolder | Add-Member –MemberType NoteProperty –Name Name –Value $checkvalue
        $invalidfolder | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullname
        $invalidfolder | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid folder size : $foldername.Length"
        $invalidfolder | Add-Member –MemberType NoteProperty –Name RuleId –Value ""
        $invalidfolder | Add-Member –MemberType NoteProperty –Name Category –Value "folder size"

        $global:InvalidFolders += $invalidfolder

    }

    if ($noerrorfound)
    {
        foreach ($rule in $foldernamerules)
        {
                    
            # check value
            if ($foldername.Contains($($rule.value.ToLower())))
            {
                $noerrorfound = $False
                write-host "Invalid folder name :  $foldername contains $($rule.value)"

                $global:InvalidFolderCounter++

                # Invalid Folder: UID, Name, Full Path, Reason
                $invalidfolder = New-Object –TypeName PSObject
                $invalidfolder | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFolderCounter
                $invalidfolder | Add-Member –MemberType NoteProperty –Name Name –Value $checkvalue
                $invalidfolder | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullname
                $invalidfolder | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid folder name :  $foldername contains $($rule.value)"
                $invalidfolder | Add-Member –MemberType NoteProperty –Name RuleId –Value $rule.id
                $invalidfolder | Add-Member –MemberType NoteProperty –Name Category –Value $rule.category

                $global:InvalidFolders += $invalidfolder

            }

        }

        if ($noerrorfound)
        {

            foreach ($rule in $folderrules)
            {
                    
                # check value
                if ($foldername.Equals($($rule.value.ToLower())))
                {

                    $noerrorfound = $False
                    write-host "Invalid folder name :  $foldername not allowed"

                    $global:InvalidFolderCounter++

                    # Invalid Folder: UID, Name, Full Path, Reason
                    $invalidfolder = New-Object –TypeName PSObject
                    $invalidfolder | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFolderCounter
                    $invalidfolder | Add-Member –MemberType NoteProperty –Name Name –Value $checkvalue
                    $invalidfolder | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullname
                    $invalidfolder | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid folder name :  $foldername not allowed"
                    $invalidfolder | Add-Member –MemberType NoteProperty –Name RuleId –Value $rule.id
                    $invalidfolder | Add-Member –MemberType NoteProperty –Name Category –Value $rule.category

                    $global:InvalidFolders += $invalidfolder

                }

            }
         
        }

    }

    if ($noerrorfound -eq $False)
    {
        $errorfound = $True
    }

    return $errorfound

}

function CheckForInvalidRulesFile
{

    [CmdletBinding()]
 	Param
 	(
  	    [Parameter(Mandatory=$True,Position=1)]
  	    [string]$checkvalue,
        [Parameter(Mandatory=$True,Position=2)]
        [object[]]$filenamerules,
        [Parameter(Mandatory=$True,Position=3)]
        [object[]]$filerules,
        [Parameter(Mandatory=$True,Position=4)]
        [object[]]$fileextensionrules,
	    [Parameter(Mandatory=$False,Position=6)]
  	    [bool]$DebugMode = $True
 	)

    $noerrorfound = $True
    $errorfound = $False

    # write-host  $checkvalue
    $fileref = Get-Item $checkvalue

    if ($fileref)
    {

        # fileinfo attributes
        $filesize = $fileref.Length
        $filefullname = $fileref.Name.ToLower()
        $filename = $fileref.BaseName.ToLower()
        $fileextension = $fileref.Extension.ToLower()
        $fullpath = $fileref.FullName

        $global:ItemCounter++

        # Item checked: UID, Name, Full Path, Type (File or Folder)
        $object = New-Object –TypeName PSObject
        $object | Add-Member –MemberType NoteProperty –Name UID –Value $global:ItemCounter
        $object | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
        $object | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
        $object | Add-Member –MemberType NoteProperty –Name Type –Value "File"
        # Write-Output $object

        $global:ItemsChecked += $object


        $global:FileCounter++

        # Item checked: UID, Name, Full Path, Type (File or Folder)
        $file = New-Object –TypeName PSObject
        $file | Add-Member –MemberType NoteProperty –Name UID –Value $global:FileCounter
        $file | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
        $file | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
        # Write-Output $object

        $global:FilesChecked += $file

        # Size limit for syncing files
        # In any SharePoint library, you can sync files of up to 2 gigabytes (GB) : 2147483648 (check for 2147483646)

        if ($filesize -gt 2147483646)
        {
            $noerrorfound = $False
            write-host "Invalid file size :  $filesize"

            $global:InvalidFileCounter++

            # Invalid File: UID, Name, Full Path, Reason
            $invalidfile = New-Object –TypeName PSObject
            $invalidfile | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFileCounter
            $invalidfile | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
            $invalidfile | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
            $invalidfile | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid file size :  $filesize"
            $invalidfile | Add-Member –MemberType NoteProperty –Name RuleId –Value ""
            $invalidfile | Add-Member –MemberType NoteProperty –Name Category –Value "file size"

            $global:InvalidFiles += $invalidfile

        }
        else
        {

            # In SharePoint Online, file names can have up to 256 characters.
            # In SharePoint Server 2013, file names can have up to 128 characters.
            if ($filefullname.Length -gt 256) # assumption : extension is considered part of file name
            {
                $noerrorfound = $False
                write-host "Invalid file name : file name is $filefullname.Length characters"

                $global:InvalidFileCounter++

                # Invalid File: UID, Name, Full Path, Reason
                $invalidfile = New-Object –TypeName PSObject
                $invalidfile | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFileCounter
                $invalidfile | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
                $invalidfile | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
                $invalidfile | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid file name : file name is $filefullname.Length characters"
                $invalidfile | Add-Member –MemberType NoteProperty –Name RuleId –Value ""
                $invalidfile | Add-Member –MemberType NoteProperty –Name Category –Value "file name length"

                $global:InvalidFiles += $invalidfile

            }

            if ($noerrorfound)
            {
                
                # Folder name and file name combinations can have up to 250 characters.
                if ($fullpath.Length -gt 250)
                {
                    $noerrorfound = $False
                    write-host "Invalid file name : full path is $fullpath.Length characters"

                    $global:InvalidFileCounter++

                    # Invalid File: UID, Name, Full Path, Reason
                    $invalidfile = New-Object –TypeName PSObject
                    $invalidfile | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFileCounter
                    $invalidfile | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
                    $invalidfile | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
                    $invalidfile | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid file name : full path is $fullpath.Length characters"
                    $invalidfile | Add-Member –MemberType NoteProperty –Name RuleId –Value ""
                    $invalidfile | Add-Member –MemberType NoteProperty –Name Category –Value "full path length"

                    $global:InvalidFiles += $invalidfile

                }

                if ($noerrorfound)
                {
                
                    foreach ($rule in $filenamerules)
                    {
                    
                        # check value
                        if ($filename.Contains($($rule.value.ToLower())))
                        {
                            $noerrorfound = $False
                            write-host "Invalid file name :  $filename contains $($rule.value)"

                            $global:InvalidFileCounter++

                            # Invalid File: UID, Name, Full Path, Reason
                            $invalidfile = New-Object –TypeName PSObject
                            $invalidfile | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFileCounter
                            $invalidfile | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
                            $invalidfile | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
                            $invalidfile | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid file name :  $filename contains $($rule.value)"
                            $invalidfile | Add-Member –MemberType NoteProperty –Name RuleId –Value $rule.id
                            $invalidfile | Add-Member –MemberType NoteProperty –Name Category –Value $rule.category

                            $global:InvalidFiles += $invalidfile

                        }

                    }

                    if ($noerrorfound)
                    {
                
                        foreach ($rule in $fileextensionrules)
                        {
                    
                            # check value
                            if ($fileextension.Contains($($rule.value.ToLower())))
                            {

                                $noerrorfound = $False
                                write-host "Invalid file extension : $filename has $fileextension"

                                $global:InvalidFileCounter++

                                # Invalid File: UID, Name, Full Path, Reason
                                $invalidfile = New-Object –TypeName PSObject
                                $invalidfile | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFileCounter
                                $invalidfile | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
                                $invalidfile | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
                                $invalidfile | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid file extension : $filename has $fileextension"
                                $invalidfile | Add-Member –MemberType NoteProperty –Name RuleId –Value $rule.id
                                $invalidfile | Add-Member –MemberType NoteProperty –Name Category –Value $rule.category

                                $global:InvalidFiles += $invalidfile

                            }

                        }

                        if ($noerrorfound)
                        {
                    
                            foreach ($rule in $filerules)
                            {
                    
                                # check value
                                if ($filefullname.Equals($($rule.value.ToLower())))
                                {

                                    $noerrorfound = $False
                                    write-host "Invalid file name : $filefullname"

                                    $global:InvalidFileCounter++

                                    # Invalid File: UID, Name, Full Path, Reason
                                    $invalidfile = New-Object –TypeName PSObject
                                    $invalidfile | Add-Member –MemberType NoteProperty –Name UID –Value $global:InvalidFileCounter
                                    $invalidfile | Add-Member –MemberType NoteProperty –Name Name –Value $filefullname
                                    $invalidfile | Add-Member –MemberType NoteProperty –Name FullPath –Value $fullpath
                                    $invalidfile | Add-Member –MemberType NoteProperty –Name Reason –Value "Invalid file name : $filefullname"
                                    $invalidfile | Add-Member –MemberType NoteProperty –Name RuleId –Value $rule.id
                                    $invalidfile | Add-Member –MemberType NoteProperty –Name Category –Value $rule.category

                                    $global:InvalidFiles += $invalidfile

                                }

                            }
                        }

                    }

                }

            }

        }

    }
    else
    {
        $noerrorfound = $False
        write-host "INvalid file name passed as parameter"
    }

    if ($noerrorfound -eq $False)
    {
        $errorfound = $True
    }

    return $errorfound
    
}

function sendMail
{
	[CmdletBinding()]
 	Param
 	(
  	[Parameter(Mandatory=$True,Position=1)]
  	[object[]]$EmailBody,
	[Parameter(Mandatory=$False,Position=2)]
  	[bool]$DebugMode = $True
 	)

    $configfileDIR ="c:\Workspace\powershell\CheckForInvalidNames\"
    $configfilename = "CheckForInvalidNames.XML"
    $configfilepath = "$configfileDIR$configfilename"

    [xml]$ConfigFile = Get-Content $configfilepath

	# look for settings
    $emailSubject = "Check For INvalid Folder And File Names Results"

	$emailFrom = $ConfigFile.ConfigSettings.emailFrom
	$emailTo = $ConfigFile.ConfigSettings.emailTo
	$smtpServer = $ConfigFile.ConfigSettings.smtpServer
	$smtpDomain = $ConfigFile.ConfigSettings.smtpDomain
	$smtpUID = $ConfigFile.ConfigSettings.smtpUID
	$smtpPWD = $ConfigFile.ConfigSettings.smtpPWD

	$smtp = New-Object System.Net.Mail.SmtpClient($smtpServer)
	$mailCredentials = New-Object System.Net.NetworkCredential
	$mailCredentials.Domain = $smtpDomain
	$mailCredentials.UserName = $smtpUID
	$mailCredentials.Password = $smtpPWD
	$smtp.Credentials = $mailCredentials
	$smtp.Send($emailFrom,$emailTo,$emailSubject,$($EmailBody))

}

# starting folder to search

# formatted report

# email address to send report

# create function as entry point

function CheckForInvalidNames
{

    [CmdletBinding()]
 	Param
 	(
  	[Parameter(Mandatory=$True,Position=1)]
  	[string]$startfolder,
    [Parameter(Mandatory=$False,Position=2)]
  	[bool]$CompleteSearch = $True,
    [Parameter(Mandatory=$False,Position=3)]
  	[bool]$emailyn = $False,
	[Parameter(Mandatory=$False,Position=4)]
  	[bool]$DebugMode = $True
 	)

    $result = @()

    $result += $client

    $result += ""

    $result += "Check For Invalid Folder And File Name Results..."

    $result += ""

    # get current date time stamp    
    $starttime = (get-date).ToString("MM/dd/yyyy hh:mm:ss")

    # $startfolder = "c:\"

    write-host "Start date time : $starttime" `n
    $result += "Start date time : $starttime"
    $result += ""

    write-host "Checking for invalid names..." `n
    $result += "Checking for invalid names..."
    $result += ""

    write-host "Start search folder : " $startfolder `n
    $result += "Start search folder : $($startfolder)"
    $result += ""

    $rulexmlpath = GetNameRulesXMLPath

    [xml]$rules = GetNameRules $rulexmlpath

    # seperate out the rules for each category

    # get list of rules that apply to File names
    $filenamerules = ($rules.SharePointNameRules.Rule | where {($_.applyto -eq "Both" -or $_.applyto -eq "File") -and $_.pos -ne "Whole"})
    $filerules = ($rules.SharePointNameRules.Rule | where {($_.applyto -eq "Both" -or $_.applyto -eq "File") -and $_.pos -eq "Whole"})
    $fileextensionrules = ($rules.SharePointNameRules.Rule | where {$_.applyto -eq "Extension"})

    # get list of rules that apply to Folder names
    $foldernamerules = ($rules.SharePointNameRules.Rule | where {($_.applyto -eq "Both" -or $_.applyto -eq "Folder") -and $_.pos -ne "Whole"})
    $folderrules = ($rules.SharePointNameRules.Rule | where {($_.applyto -eq "Both" -or $_.applyto -eq "Folder") -and $_.pos -eq "Whole"})

    # rest all global vars
    $global:stoptraverse = $False
    
    $global:ItemsChecked = @()
    $global:FoldersChecked = @()
    $global:FilesChecked = @()
    $global:InvalidFolders = @()
    $global:InvalidFiles = @()

    $global:ItemCounter = 0
    $global:FolderCounter = 0
    $global:FileCounter = 0
    $global:InvalidFolderCounter = 0
    $global:InvalidFileCounter = 0

    # start search
    TraverseFolder $startfolder $filenamerules $filerules $fileextensionrules $foldernamerules $folderrules $CompleteSearch

    # how many total items examined
    write-host "Total Items Examined : $($global:ItemsChecked.Count)" `n
    $result += "Total Items Examined : $($global:ItemsChecked.Count)"

    $result += ""
    
    # how many files examined
    write-host "Files Examined : $($global:FilesChecked.Count)" `n
    $result += "Files Examined : $($global:FilesChecked.Count)"
    
    $result += ""

    # how many invalid file names found
    write-host "Invalid Files Found : $($global:InvalidFiles.Count)" `n
    $result += "Invalid Files Found : $($global:InvalidFiles.Count)"

    $result += ""

    $result += $global:InvalidFiles 

    $result += ""

    # how many folders examined
    write-host "Folders Examined : $($global:FoldersChecked.Count)" `n
    $result += "Folders Examined : $($global:FoldersChecked.Count)"

    $result += ""

    # how mnay invalid folder names found
    write-host "Invalid Folders Found : $($global:InvalidFolders.Count)" `n
    $result += "Invalid Folders Found : $($global:InvalidFolders.Count)"

    $result += ""

    $result += $global:InvalidFolders

    $result += ""

    # get current date time stamp    
    $endtime = (get-date).ToString("MM/dd/yyyy hh:mm:ss")

    write-host "End date time : $endtime" `n
    $result += "End date time : $endtime"

    $result += ""

    $timediff = NEW-TIMESPAN -Start $starttime -End $endtime

    If ($timediff.TotalSeconds -ge 59)
    {
        
        If ($timediff.TotalMinutes -ge 59)
        {
            write-host "Time elapsed :  $($timediff.TotalHours) hours" `n
            $result += "Time elapsed :  $($timediff.TotalHours) hours"
            $result += ""
        }
        else
        {
            write-host "Time elapsed :  $($timediff.TotalMinutes) minutes" `n
            $result += "Time elapsed :  $($timediff.TotalMinutes) minutes"
            $result += ""
        }
    }
    else
    {
         write-host "Time elapsed :  $($timediff.TotalSeconds) seconds" `n
         $result += "Time elapsed :  $($timediff.TotalSeconds) seconds"
         $result += ""
    }

    # create report as txt file in starting folder
    $result | Format-Table -Wrap -AutoSize | out-file -filepath $startfolder\CheckForInvalidNamesReport.txt -width 4096

    #write-output $result

    if ($emailyn)
    {
        sendMail $result
    }

}

# CheckForInvalidNames "c:\"



