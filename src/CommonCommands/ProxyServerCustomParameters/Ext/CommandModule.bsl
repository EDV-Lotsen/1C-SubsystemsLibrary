
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
#If WebClient Then
	ShowMessageBox(, NStr("en = 'Proxy server parameters for web client are entered in the browser settings.'"));
	Return;
#EndIf
	
	OpenForm("CommonForm.ProxyServerParameters", New Structure ("ProxySettingsAtClient", True));
	
EndProcedure

#EndRegion
