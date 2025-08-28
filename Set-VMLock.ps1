# However, if you are using basic mode VM Connect - then it is possible that the next user to connect will be able to jump straight in and use your credentials if you do not remember to manually log out of the virtual machine.  
# Luckily - this problem can now be avoided.  If you open up PowerShell and run:
Set-VM "SAS-HV-DC01" -LockOnDisconnect On