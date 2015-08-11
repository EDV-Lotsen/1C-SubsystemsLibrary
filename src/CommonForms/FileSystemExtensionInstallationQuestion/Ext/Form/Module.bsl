////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("Message") Then
		If Parameters.Message <> Undefined Then
			Items.CommentDecoration.Title = Parameters.Message + Chars.LF + NStr("en = ' Install and plug in?'");
		EndIf;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure DontInstall(Command)
	Close(False); // Don't offer
EndProcedure

&AtClient
Procedure SetLater(Command)
	Close(True); // Offer later - in another session
EndProcedure

&AtClient
Procedure SetNow(Command)
	
	BeginInstallFileSystemExtension(New NotifyDescription("SetNowEnd", ThisObject));	
	
EndProcedure

&AtClient
Procedure SetNowEnd(AdditionalParameters) Export
    
    ExtensionConnected = Undefined;

    
    BeginAttachingFileSystemExtension(New NotifyDescription("SetNowEndEnd", ThisObject));

EndProcedure

&AtClient
Procedure SetNowEndEnd(Attached, AdditionalParameters1) Export
	
	ExtensionConnected = Attached;
	If Not ExtensionConnected Then
		Close(True); // Offer later - in another session
	Else	
		Close(False); // Don't offer
	EndIf;

EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close(True); // Offer later - in another session
EndProcedure