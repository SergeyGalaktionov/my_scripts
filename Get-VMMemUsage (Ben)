# Prompt for the Hyper-V Server to use
 $HyperVServer = Read-Host "Specify the Hyper-V Server to use (enter '.' for the local computer)"
  
 # Prompt for the virtual machine to use
 $VMName = Read-Host "Specify the name of the virtual machine"
  
 # Get the management service
 $VMMS = gwmi -namespace root\virtualization Msvm_VirtualSystemManagementService -computername $HyperVServer
  
 # Get the virtual machine object
 $VM = gwmi MSVM_ComputerSystem -filter "ElementName='$VMName'" -namespace "root\virtualization" -computername $HyperVServer
  
 # SettingType = 3 ensures that we do not get snapshots
 $SystemSettingData = $VM.getRelated("Msvm_VirtualSystemSettingData") | where {$_.SettingType -eq 3}
  
 # Request the virtual machine state (100), current memory (103) and memory availability (112)
 $RequestedInformation = 100,103,112
  
 # Get the summary information for just the selected virtual machine
 $SummaryInformation = $VMMS.GetSummaryInformation($SystemSettingData, $RequestedInformation).SummaryInformation | select -first 1
      
 # Check that the virtual machine is running
 if ($SummaryInformation.EnabledState -eq "2")
    { write-host "Memory information for" $VMName
      write-host
      write-host "Current memory usage:" $SummaryInformation.MemoryUsage "MB"
      
      # If memory available == 2147483647 then no memory available value has been returned from the virtual machine
      if ($SummaryInformation.MemoryAvailable -ne 2147483647)
         { write-host "Current memory availability:" $SummaryInformation.MemoryAvailable"%"}
      else
         { write-host "Dynamic memory is not currently active on this virtual machine"}
    }
 else
    { write-host "The requested virtual machine is not currently running" }