
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	DontShowAgain = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SystemInfo = New SystemInfo;
	
	If Find(SystemInfo.UserAgentInformation, "Firefox") <> 0 Then
		Items.Additions.CurrentPage = Items.MozillaFireFox;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ContinueExecute(Command)
	If DontShowAgain = True Then
		CommonUseServerCall.CommonSettingsStorageSaveAndRefreshCachedValues(
			"ProgramSettings",
			"ShowFileEditTips",
			False);
	EndIf;
	Close(DontShowAgain);
EndProcedure

#EndRegion
