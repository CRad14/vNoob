add-pssnapin vmware.vimautomation.core 
Import-Module E:\scripts\Meadowcroft.SRM\Meadowcroft.Srm.psm1 
 
 
 

 
Connect-viserver "vCenterServer"
 
Connect-srmserver 
 
$scriptblock={Ipconfig /all}
 
 
 
$srmcommand=new-command -command $scriptblock -description "WinRecovery" -runinrecoveredvm -timeout 300 

 
 
#Grabs All SRM Plan
$plans=Get-RecoveryPlan  
 
FOREACH ($plan in $plans) 
{ 

#Retrieves all VMs from each Plan
$winvms=$plan |get-protectedvm |? {($_.vm.guest.guestfamily -like "*win*")} 
 
 
FOREACH ($winvm in $winvms) 
 
{ 
$vmname=$winvm.vm.name 
$vmname 


$srmpostcommand=$srmcommand
 
$settings=get-recoverysettings -ProtectedVm $winvm -RecoveryPlan $plan 
 
#Retrieves Current PostPower On Commands
$postcommands=$settings.postpoweroncallouts |% { $_ } 

#Remove All Currently assigned Recovery Commands
ForEach ($postcommand in $postcommands) 
{remove-postrecoverycommand -recoverysettings $settings -command $postcommand} 
 
#Sets the Recovery Commands 
Add-PostRecoveryCommand -RecoverySettings $settings -command $srmpostcommand 
 
Set-RecoverySettings -RecoveryPlan $plan -ProtectedVm $winvm -RecoverySettings $settings 
 
} 
}