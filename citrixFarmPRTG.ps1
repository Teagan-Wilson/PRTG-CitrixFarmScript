#citrixFarmPRTG.ps1
#Teagan Wilson

param (
[string]$server,
[string]$domain,
[string]$username,
[string]$password
)

#Build the creds that get passwed from PRTG
$credentials = New-Object System.Management.Automation.PSCredential (($domain+'\'+$username), (ConvertTo-SecureString $password -AsPlainText -Force))

#Generate Script Block to run remotly on Citrix Farm Broker
$job = Invoke-Command -Computername $server -credential $credentials -ScriptBlock { 

#Load Citrix Powershell Modules (remotely on the Farm Broker)
add-pssnapin citrix*; 

#Get Active Citrix Active/Not Active Session Numbers
$ActiveSessions = (Get-BrokerSession | where {$_.SessionState -eq "Active"}).Count
$DisconnectedSessions = (Get-BrokerSession | where {$_.SessionState -ne "Active"}).Count

#Get Broker Status - Convert 'OK' or not to numeric 1 or 0
$BrokerStatus = if(((Get-BrokerServiceStatus).ServiceStatus -eq 'OK')) {1} else {0}

#Create Object with above information so we can pass it back out later. 
$Data= [PSCustomObject]@{
BrokerStatus = $BrokerStatus
ActiveSessions = $ActiveSessions
DisconnectedSessions = $DisconnectedSessions
}

#Get Session Information for each VDA in the farm add it to the custom object as another channel.
$servers = Get-BrokerMachine | Select MAchineName
ForEach ($machine in $servers)
{
$serversessions = (Get-BrokerSession | where {($_.SessionState -eq "Active") -and ($_.MachineName -eq $machine.MachineName)}).Count
$Data | Add-Member -MemberType NoteProperty -Name ('sessions-'+$machine.MachineName) -Value $serversessions
}

#Return Farm info
return $Data

} -asjob

#Wait for the job to finish and get the data
Wait-Job $job | Out-Null
$Data= Receive-Job -Job $job

#Build our XML object to output for PRTG
$returntext = '<prtg>' 
$Data.PSObject.Properties | foreach-object {
$returntext += '<result><channel>'+$_.Name+'</channel><value>'+$_.Value+'</value></result>'
$returntext = $returntext -replace " ",""
}
$returntext += '</prtg>'

write-host $returntext

#Below for debug
#$returntext | Out-File C:\ProgramData\citrixfarmscript-output.txt
exit 0
