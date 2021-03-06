function Send-Recycle{
 param([string]$Server,
 [string]$Apppool, 
 $Pools, 
 [string]$Message, 
 $PoolHash )
  
 # write-host "app pool is : $Apppool"  
  $email = ""
    if (($Apppool -eq $null) -or ($Apppool -eq "")){
       $Server
       
          # write-host "Server: $Server"
            #write-host "config: $Config"
            #write-host "pool: $Apppool"
            #write-host "Message: $Message"
            #$Pools = Get-Content $Config
            foreach ($Pool in $Pools){
               if ($Pool -ne $null){
                    #write-host "Pool: $Pool"
                   [string] $PName = $Pool
                    Invoke-command -computername $Server -scriptblock {Param($PoolName) import-module webadministration;Restart-WebAppPool -name $PoolName} -argumentlist $PName
                    #write-host "it's a recycle1"
                    if(-not $?) {#error logging
                        Write-Host "There was a problem, could not recycle the apppool $Pool on $server!"
                      }else{
                        Write-Host "The application Pool $Pool has recycled on $server."
                      }
                    if ($Message) {
                        $email = "true"
                    }
               } else{
                    Write-Host "No Application Pools listed"
               }
            }
         
        
    }else{
        
        if ($Apppool -eq "All") {
            #$PoolHash
            foreach ($key in $PoolHash.keys){
                [string] $PName = $PoolHash[$key]
                #write-host "pname is :$Pname"
                if ($PName -ne "All") {
                    Invoke-command -computername $Server -scriptblock {Param($PoolName) import-module webadministration;Restart-WebAppPool -name $PoolName} -argumentlist $PName
                    #write-host "it's a recycle2"
                    if(-not $?) {#error logging
                        Write-Host "There was a problem, could not recycle the apppool $PName on $server!"
                      }else{
                        Write-Host "The application Pool $PName has recycled on $server."
                      }
                    if ($Message) {
                        $email = "true"
                    }
                
                }
            }
       
       } else {
            # if the app pool is a comma delimited string
            
             $poollist = $Apppool.Split(",")
            foreach ($poolname in $poollist){
            #Not used #Invoke-command -computername "$Server" -scriptblock {import-module webadministration;Restart-WebAppPool -name $Apppool}
                Invoke-command -computername $Server -scriptblock {Param($PoolName) import-module webadministration;Restart-WebAppPool -name $PoolName} -argumentlist $poolname
                #write-host "it's a recycle3"
                if(-not $?) {#error logging
                        Write-Host "There was a problem, could not recycle the apppool $poolname on $server!"
                }else{
                        Write-Host "The application Pool $poolname has recycled on $server."
                      }
            }
            if ($Message) {
                $email = "true"
            }
       } #end else
    }
    
    if ($email){
     Send-Email $Message $Server
    }
 
 }
function Send-Email{
  param([string]$Message, $Server)
  $emailFrom = "Ops@primealliancesolutions.com"
  $emailTo = "outage@primealliancesolutions.com"
  #$emailTo = "jmckay@dexma.com"
  
  
  ## get the day of week, if it's the weekend we send to Prodops oncall pager
  
  ##

  $subject = "Apppools on $Server recycled "

  $body = $Message

  $smtpServer = "outbound.smtp.dexma.com"
  $smtp = new-object Net.Mail.SmtpClient($smtpServer)
  $smtp.Send($emailFrom, $emailTo, $subject, $body)
  
  if(-not $?) {#error logging
    Write-Host "There was an error sending the Email!"
  }
}
function Get-Pools{
param([string] $Server,$lNotify, $PoolHash )
    #$PoolHash2 = @()
    $hashCount = 1
    write-host "Loading started Apppools..."
   
    $Pools=Invoke-command -computername $Server -scriptblock {import-module webadministration;$(get-item IIS:\apppools).children} 
    foreach ($pool in $Pools) {
       
       $names = $pool.keys
       foreach ($name in $names){
        # write-host "notify is  - $lNotify"
            $state = Invoke-command -computername $Server -scriptblock {Param($PoolName)import-module webadministration;$(Get-Item "IIS:\Apppools\$PoolName").state} -argumentlist $name
           # write-host "$state"
         
         if ($state -eq "started"){

                $PoolHash["$hashCount"] = "$name"
                if ($lNotify -eq $true){
                    write-host "$hashCount : $name "
                }
                $hashCount = $hashCount + 1

             
         } else {
            #$hashCount = $hashCount + 1
           
         }
       }  
    }
    
   $PoolHash["$hashCount"] = "ALL"
   #write-host "$hashCount : All"
    if ($lNotify -eq $true){
        
        write-host "$hashCount : All"
        $Id = read-host "Please Enter the number(s) of the app pool above you want to recycle, Please use a comma for multiple entries, (1,2,3...)"
        $List = $Id.Split(",")
        $nCount = 0
        foreach ($idList in $List){
            if ($nCount -eq 1){
                $poolname = $poolname + "," + $PoolHash[$idList] 
            }else {
                $poolname = $PoolHash[$idList] 
                $nCount = 1
            }
           
        }
    } else {
        [string] $shashCount = "$hashCount"
        $poolname = $PoolHash[$shashCount] 
    }
    
    
    #write-host "$hashCount Pool is $poolname " 
    #$PoolHash = $PoolHash2 
    $poolname2 = $PoolHash["8"] 
     #write-host "Pool is $poolname2 " 
    return $poolname

} 
function Print-Help{

    write-host "`n`nUSEAGE:`n                 E:\DEXMA\SUPPORT\APPPOOLRESTART_WSS.PS1 [server/environment] [message](optional)"
    write-host "`n`n`nOPTIONS:`n`n                 [server]        Name of the server your recycle if you want to recycle on one server only"
    
    write-host "                 [environment]   Groups in the config file, 'STAGE', 'PROD','STAGE LS'... this will recycle every server  in the apppoollist config files"
    write-host "                 [message]       The message in the email that is sent to change control, if left blank the script will ask if you wish to send a message, if 'PLIST' a list of running app pools will be displayed for the user to select which pool to recycle"
    write-host "`n`n`nCONFIG FILES:`n`n                 [Config]        e:\dexma\support\apppoolrestart.xml the one config file is used for all environments and app pools "

    write-host "`n `n `n-If no parameters are passed the script will prompt for all needed information. `n-If a message is sent, a seperate email is sent for each server recycled."
    write-host "-The script will recycle all app pools listed within the config file unless 'PLIST' is passed as the message, in which case the app pools will be listed"
    write-host "`n `nEXAMPLES: `n                 >E:\DEXMA\SUPPORT\APPPOOLRESTART_WSS.PS1 ""STAGE""  ""Recycling app pools due to migration"""
    write-host "                 >E:\DEXMA\SUPPORT\APPPOOLRESTART_WSS.PS1 ""STGWEBSVCXXX""  "
    write-host "                 >E:\DEXMA\SUPPORT\APPPOOLRESTART_WSS.PS1 ""PROD""  ""PLIST"" `n `n "
}
########################################################################### 
[string] $Env = $args[0]
$Message = $args[1]
$Pool = ""
$lMessage = $false
$PoolHash = @{}
$ConfigFile = "e:\dexma\support\apppoolrestart.xml"
$Pools = @()
$NoConfig = ""
[xml]$APR = Get-Content $ConfigFile 

IF (($Env -eq "/?") -or ($Env -eq "?") -or ($Env -eq "-help")){
    Print-Help
    exit
}

$Env = $Env.ToUpper()

#$AConfigFile = "e:\dexma\support\apppoolnames.config"
if ($Message -eq "PLIST") {
    $NoConfig = "PLIST"
    $Message = ""
    $lMessage = $true
} else {
    
    foreach ($poolname in $APR.{apppool.restart}.{App.Pools}.pools){
       #write-host "Pool: $poolname"
       $Pools += $poolname
    }
    write-host "pools: $Pools"
}


if (($Message -eq $null) -or ($Message -eq "") ){
        [string] $A = read-host "Do you want to send an email message? Yes (y), No (n) or any key."
        if (($A.ToUpper() -eq "Y") -or ($A.ToUpper() -eq "YES" )){
            $Message = read-host "Enter Your Email Message Here"
        }
    }
    
######New Code

$lGroups = $false
$Servers = @()
foreach ($Group in $APR.{apppool.restart}.{Server.Groups}.Group){
  [string]$Name = $Group.name
  $Name = $Name.ToUpper()
  #
  if ($Name -eq $Env){
    $lGroups = $true
    foreach ($Servernames in $Group.server){
        
        $Servers += $Servernames
    }
    break
  }
}

if ($lGroups){
    foreach ($Server in $Servers){ 
        if ($NoConfig -eq "PLIST"){ 
            if ($Pool -eq ""){
                 $Pool= Get-Pools $Server $lMessage $PoolHash
            }
        
        }
       #write-host "Server:$Server"
        Send-Recycle $Server $Pool $Pools $Message $PoolHash 
        
        
        
    }      
} else {
    if (($Env -eq $null) -or ($Env -eq "")){
        $Env= read-host "Please enter the name of the server"
    }
        
        if ($NoConfig -eq "PLIST"){
            
            $Pool= Get-Pools $Env  $lMessage $PoolHash
            
            Send-Recycle $Env  $Pool "" $Message $PoolHash 
        }else {
            Send-Recycle $Env  "" $Pools $Message ""
        }

        #$Path = "\\$ServerName\Dexma\support\$AlertFile"
        
      
}
<#
#######Old code######
if (($Env -ne "PROD") -and ($Env -ne "STAGE")) {
    if (($Env -eq $null) -or ($Env -eq "")){
        $Server= read-host "Please enter the name of the server"
    }else{
        $Server = $Env
        
    }
    #write-host "config:$AConfigFile" 
    if (!(test-path $AConfigFile)){
        $Pool= Get-Pools $Server $lMessage $PoolHash

    }
    
    #write-host " Pool is $Pool " 
    #$pn = $PoolHash["8"]
    #write-host "PoolHash us $pn"
    Send-Recycle $Server $Pool $AConfigFile $Message $PoolHash
}else{   


    

    
    if ($Env -eq "STAGE" ){
        $ConfigFile = "e:\dexma\support\apppoollist_STAGE.config"
    }
    #$AlertFile = "manualrecycleapp.txt"
    $Servers = Get-Content $ConfigFile
        foreach ($Server in $Servers){
            if ($Server -ne $null) {
                $ServerName = $Server
                
                if ($ServerName -ne "") {
                    if (!(test-path $AConfigFile)){
                        if ($Pool -eq ""){
                             $Pool= Get-Pools $Server $lMessage $PoolHash
                        }
                        Send-Recycle $ServerName $Pool "" $Message $PoolHash 
                    }else {
                        Send-Recycle $ServerName $Pool $AConfigFile $Message $PoolHash 
                    }

                    #$Path = "\\$ServerName\Dexma\support\$AlertFile"
                    
                }
                
            }
        }
        
        #Write-Host "Please wait at least 3 min for the recycle to take affect"
    
 } 
 #>
   