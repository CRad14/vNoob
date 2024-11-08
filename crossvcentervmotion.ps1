#Blog post at vnoob.com/

# Connect to Source and Target vCenter Servers
$sourceVC = "SourcevCenter"
$targetVC = "TargetvCenter"

# Define the list of VM names to migrate
#$vmNames = "SingleVM"  # Replace with the names of VMs you want to migrate
$targetClusterName = "Clustername"  # Replace with the target cluster name in the target vCenter
$vmhost = "VMHost" # Used for clearing out a specific ESXi host

# Connect to both vCenter servers
Connect-VIServer -Server $sourceVC 
Connect-VIServer -Server $targetVC 

# Get VMs hosted on the specified ESXi host from the source vCenter
$vmnames = Get-VMHost $vmhost -Server $sourceVC | Get-VM # Can be modified to get all VMs on vCenter by removing vmhost reference

# Loop through each VM and perform migration
foreach ($vmName in $vmNames) {
    
    # Retrieve the VM from the source vCenter
    $vm = Get-VM -Name $vmName -Server $sourceVC
    "VM"
    $vm

    # Get VM guest information
    $vmGuestInfo = Get-VMGuest -VM $vm
    $ipv4Addresses = $vmGuestInfo.IPAddress | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } | Select-Object -First 1

    # Initial network connectivity test
    Write-Host "Testing initial connectivity with IP $ipv4Addresses" -ForegroundColor Yellow
    $initialping = Test-NetConnection $ipv4Addresses 

    # Check initial ping response
    if ($ipv4Addresses -eq $null) {
        Write-Warning "No IPv4 Address found"
    } elseif ($initialping.PingSucceeded) {
        Write-Host "Initial ping succeeded" -ForegroundColor Green
    } else {
        Write-Warning "Initial ping failed"
    }

    # Test connectivity by VM Name
    Write-Host "Testing connectivity with VM Name $($vm.Name)" -ForegroundColor Yellow
    $pingtest = Test-NetConnection $vm.Name
    if (-not $pingtest.PingSucceeded) {
        Write-Warning "Ping failed for VM Name $($vm.Name)"
    } else {
        Write-Host "Ping succeeded for VM Name $($vm.Name)" -ForegroundColor Green
    }

    # Test connectivity by VM Guest Name
    Write-Host "Testing connectivity with VM Guest Name $($vmGuestInfo.HostName)" -ForegroundColor Yellow
    $pingtest = Test-NetConnection $vmGuestInfo.HostName
    if (-not $pingtest.PingSucceeded) {
        Write-Warning "Ping failed for VM Guest Name $($vmGuestInfo.HostName)"
    } else {
        Write-Host "Ping succeeded for VM Guest Name $($vmGuestInfo.HostName)" -ForegroundColor Green
    }

    # Retrieve source VM's datastore and portgroup
    $sourceDatastore = (Get-HardDisk -VM $vm | Get-Datastore)
    $sourcePortGroup = Get-VM $vm | Get-VirtualPortGroup -Distributed
    $sourcedatastorecenter = $sourceDatastore.Uid.Split("@")[1].Split("/")[0]

    Write-Host "Source Information:" -ForegroundColor Cyan
    $sourcePortGroup.Name
    $sourceDatastore.Name
    $sourcedatastorecenter

    # Validate VM network settings (Portgroup and Datastore)
    if ($sourcePortGroup.Count -gt 1) {
        Write-Warning "$vm has multiple portgroups, skipping."
        continue
    } elseif ($sourcePortGroup.Count -lt 1 -or $sourcePortGroup -eq $null) {
        Write-Warning "$vm has no portgroups, skipping."
        continue
    }

    if ($sourceDatastore.Count -gt 1) {
        Write-Warning "$vm has multiple datastores, skipping."
        continue
    } elseif ($sourceDatastore.Count -lt 1 -or $sourceDatastore -eq $null) {
        Write-Warning "$vm has no datastores, skipping."
        continue
    }

    # Retrieve corresponding datastore and portgroup in the target vCenter
    $targetDatastore = Get-Datastore -Name $sourceDatastore.Name -Server $targetVC
    $targetPortGroup = Get-VirtualPortGroup -Name $sourcePortGroup -Server $targetVC -Distributed
    $targetdatastorecenter = $targetDatastore.Uid.Split("@")[1].Split("/")[0]
  
    $targetCluster = Get-Cluster -Name $targetClusterName -Server $targetVC
    $targetHost = $targetCluster | Get-VMHost | Get-Random -Count 1

    Write-Host "Destination Information:" -ForegroundColor Cyan
    $targetPortGroup.Name
    $targetPortGroup.Uid.Split("@")[1].Split("/")[0]
    $targetDatastore.Name
    $targetdatastorecenter
    $targetHost.Name

    # Confirm migration
    $response = Read-Host "Are you sure you want to continue? (y/n)"
    if ($response -ne "y") {
        Write-Warning "Aborting migration for $vmName"
        continue
    }

    # Execute Cross vCenter vMotion
    Move-VM -VM $vm `
        -Destination $targetHost `
        -Datastore $targetDatastore `
        -NetworkAdapter (Get-NetworkAdapter -VM $vm) `
        -PortGroup $targetPortGroup `
        -Confirm:$true

    Write-Output "Migrated VM '$vmName' to target vCenter with portgroup '$sourcePortGroup' and datastore '$sourceDatastore'."

    # Post-migration connectivity check
    Start-Sleep -Seconds 2
    Write-Host "Testing post-migration connectivity with IP $ipv4Addresses" -ForegroundColor Yellow
    $pingtest = Test-NetConnection $ipv4Addresses
    if (-not $pingtest.PingSucceeded) {
        Write-Warning "Ping failed for VM, considering rollback."
    } else {
        Write-Host "Post-migration ping succeeded" -ForegroundColor Green
    }

    # Check post-migration connectivity by VM Name and Guest Name
    Write-Host "Testing with VM Name $($vm.Name)" -ForegroundColor Yellow
    $pingtest = Test-NetConnection $vm.Name
    if (-not $pingtest.PingSucceeded) {
        Write-Warning "Ping failed for VM Name $($vm.Name), considering rollback."
    } else {
        Write-Host "VM Name $($vm.Name) connectivity verified" -ForegroundColor Green
    }

    Write-Host "Testing with VM Guest Name $($vmGuestInfo.HostName)" -ForegroundColor Yellow
    $pingtest = Test-NetConnection $vmGuestInfo.HostName
    if (-not $pingtest.PingSucceeded) {
        Write-Warning "Ping failed for VM Guest Name $($vmGuestInfo.HostName), considering rollback."
    } else {
        Write-Host "VM Guest Name $($vmGuestInfo.HostName) connectivity verified" -ForegroundColor Green
    }
}

# Optional: Disconnect from vCenter Servers
# Disconnect-VIServer -Server $sourceVC -Confirm:$false
# Disconnect-VIServer -Server $targetVC -Confirm:$false
