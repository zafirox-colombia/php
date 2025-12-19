Dim shell, fso, appRoot, serverScript, browserUrl
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Definir rutas
appRoot = fso.GetParentFolderName(WScript.ScriptFullName)
serverScript = appRoot & "\app\src\UI\WebServer.ps1"
browserUrl = "http://localhost:8085"

' 1. Iniciar Servidor PowerShell (Oculto - WindowStyle 0)
' Usamos -ExecutionPolicy Bypass y -NoProfile para rapidez
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & serverScript & """", 0, False

' 2. Esperar brevemente para que levante el servidor (2 segundos)
WScript.Sleep 2000

' 3. Abrir Navegador
shell.Run browserUrl

Set shell = Nothing
Set fso = Nothing
