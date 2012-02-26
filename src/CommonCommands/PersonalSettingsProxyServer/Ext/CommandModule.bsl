

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.ProxyServerParameters",
	                  New Structure("SettingProxyAtClient", True));
	
EndProcedure
