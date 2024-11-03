# Add VMware PowerCLI Snap-in
add-pssnapin vmware.vimautomation.core

# Import custom module for SRM automation
Import-Module E:\scripts\Meadowcroft.SRM\Meadowcroft.Srm.psm1

# Connect to vCenter Server
Connect-viserver "vCenterServer"

# Connect to SRM Server
Connect-srmserver

# Define a script block to retrieve network configuration for the VM
$scriptblock = { Ipconfig /all }

# Create a new SRM command for running in the recovered VM with a timeout of 300 seconds
$srmcommand = New-Command -command $scriptblock -description "WinRecovery" -runinrecoveredvm -timeout 300

# Get all SRM Recovery Plans


$plans = Get-RecoveryPlan

# Loop through each Recovery Plan
FOREACH ($plan in $plans) {

    # Retrieve all Windows VMs from the Recovery Plan
    $winvms = $plan | Get-ProtectedVM | Where-Object { ($_.vm.guest.guestfamily -like "*win*") }

    # Loop through each Windows VM in the plan
    FOREACH ($winvm in $winvms) {

        # Get the name of the VM
        $vmname = $winvm.vm.name
        $vmname

        # Set the SRM post-recovery command
        $srmpostcommand = $srmcommand

        # Retrieve current recovery settings for the VM
        $settings = Get-RecoverySettings -ProtectedVm $winvm -RecoveryPlan $plan

        # Retrieve all current post-power-on commands
        $postcommands = $settings.postpoweroncallouts | ForEach-Object { $_ }

        # Remove all currently assigned recovery commands
        ForEach ($postcommand in $postcommands) {
            Remove-PostRecoveryCommand -RecoverySettings $settings -command $postcommand
        }

        # Add the new recovery command to the post-power-on commands
        Add-PostRecoveryCommand -RecoverySettings $settings -command $srmpostcommand

        # Apply the updated recovery settings to the recovery plan
        Set-RecoverySettings -RecoveryPlan $plan -ProtectedVm $winvm -RecoverySettings $settings
    }
}
