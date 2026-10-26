' AutoGPT Platform + Magpie relay autostart (runs hidden at logon)
Set shell = CreateObject("Wscript.Shell")
' 1) port relay for WSL -> Windows loopback services (magpie/proxy/wang)
shell.Run "cmd /c node D:\automate\relay.js", 0, False
' 2) 王将军 local console service (AI 排序管理 / Magpie 连接)
shell.Run "cmd /c bash D:\automate\wang\start.sh", 0, False
' 3) keep WSL VM alive so the autogpt container keeps running
shell.Run "wsl.exe -d AutoGPT -u root -- sleep infinity", 0, False
