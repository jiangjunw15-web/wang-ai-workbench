' AutoGPT Platform keepalive: hidden WSL session keeps the VM (and the
' autogpt container) alive; idempotent per boot.
Dim shell, exists
Set shell = CreateObject("Wscript.Shell")
exists = shell.Run("cmd /c wsl.exe -d AutoGPT -u root -- ps -o comm= -p 1 | findstr /C:init >nul 2>&1", 0, True)
If exists <> 0 Then
  ' distro not running yet; the following command boots it
End If
shell.Run "wsl.exe -d AutoGPT -u root -- sleep infinity", 0, False
