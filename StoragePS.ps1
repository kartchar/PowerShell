Login-AzureRmAccount
Select-AzurermSubscription -SubscriptionName "SPEARFISH_PROD" 

# Variables
$ResourceGroup = "vnetinjectiongaprod"
$StorageAccountName = 'vnetinjectiongaprod'
$OutputPath = 'C:\Temp\reportinfo' 

#Fetch Storage Context
$StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroup -AccountName $StorageAccountName).Value[0]
$StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
#$StorageContext | Get-AzureStorageContainer

$container = Get-AzureStorageContainer -Context $StorageContext | Sort-Object -Property LastModified -Descending | Select-Object -First 1
$blob = Get-AzureStorageBlob -Context $StorageContext -Container $container.Name
#$blob = Get-AzureStorageBlob -Context $StorageContext -Container $container.Name

# Download data
New-Item -Path "c:\Temp\" -Name "Reportinfo" -ItemType "directory"

foreach($file in $blob.Name)
{
    Get-AzureStorageBlobContent -Blob $file -Container $container.Name -Context $StorageContext -Destination $OutputPath    
}
Write-Host "files downloaded" 

# 1. Successful Workspaces Report.

# Fetch content from Successful Workspaces Json.
$successInput = Get-Content -Path 'C:\Temp\Reportinfo\successfulWorkspaces.json' | Out-String | ConvertFrom-Json
$successArr = @() 

foreach($successWorkSpace in $successInput.workspace_id)
{
    $successSub = $successWorkSpace.substring(15,36)
    $successArr += @{"Subscription ID" = $successSub; "Workspace ID(s)" = $successWorkSpace}
}

$successArr.ForEach({[PSCustomObject]$_}) | Select-Object "Subscription ID", "Workspace ID(s)"`
| Sort-Object -Property "Subscription ID" -Descending | Export-Csv -Path 'C:\Temp\Reportinfo\SuccessfulSubs.csv' -NoTypeInformation



# 2. Expected errors Workspaces Report.

# Fetch content from Expected Errors Workspaces Json.
$expInput = Get-Content -Path 'C:\Temp\Reportinfo\expectedErroredWorkspaces.json' | Out-String | ConvertFrom-Json
$expArr = @()

foreach($expWorkSpace in $expInput.workspace_id)
{
    $expSub = $expWorkSpace.substring(15,36)
    $expArr += @{"Subscription ID" = $expSub; "Workspace ID(s)" = $expWorkSpace}
}

$expArr.ForEach({[PSCustomObject]$_}) | Select-Object "Subscription ID", "Workspace ID(s)"`
| Sort-Object -Property "Subscription ID" -Descending | Export-Csv -Path 'C:\Temp\Reportinfo\ExpectedErrors.csv' -NoTypeInformation


# 3. Unexpected errors Workspaces Report.

# Fetch content from Unexpected errors Workspaces Json.
$UnexpInput = Get-Content -Path 'C:\Temp\Reportinfo\unexpectedErroredWorkspaces.json' | Out-String | ConvertFrom-Json

$UnexpArr = @()
foreach($UnexpWorkSpace in $UnexpInput.workspace_id)
{
    $errMsgs = $null
    $UnexpSub = $UnexpWorkSpace.substring(15,36)
    ($UnexpInput | Where-object {$_.workspace_id -eq $UnexpWorkSpace}).error_msgs | Foreach {`
    $errMsgs += "$_,`n"}

    $UnexpArr += @{"Subscription ID" = $UnexpSub; "Workspace ID(s)" = $UnexpWorkSpace; "Error Messages" = $errMsgs}
}

$UnexpArr.ForEach({[PSCustomObject]$_}) | Select-Object "Subscription ID", "Workspace ID(s)", "Error Messages"`
| Sort-Object -Property "Subscription ID" -Descending | Export-Csv -Path 'C:\Temp\Reportinfo\UnexpectedErrors.csv' -NoTypeInformation


# 4. Only successful subs

$successSubs = @()
$expSubs = @()
$successSubs = $successInput.subscription_id
$expSubs = $expInput.subscription_id
$UnexpSubs = $UnexpInput.subscription_id

$expSubsTrans = $expSubs | ForEach-Object {
    $_ -replace '_.*?$'}
$UnexpSubsTrans = $UnexpSubs | ForEach-Object {
    $_ -replace '_.*?$'}


$resultValue = $successSubs | Where-Object {($_ -notin $expSubsTrans) -and ($_ -notin $UnexpSubsTrans)}
$OnlySuccessSubs = $resultValue | Select-Object @{Name='Subscription ID';Expression={$_}}

#$OnlySuccessSubs | foreach { new-object psobject -Property @{"Subscription ID" = $_.Name}}
$OnlySuccessSubs | Export-Csv -Path 'C:\Temp\Reportinfo\OnlySuccessSubs.csv' -NoTypeInformation
