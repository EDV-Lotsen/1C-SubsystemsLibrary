////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Items.MessageText.Title = Parameters.MessageText;
	Items.RecommendedPlatformVersion.Title = Parameters.RecommendedPlatformVersion;
	SystemInfo = New SystemInfo;
	Items.Version.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.Version.Title, SystemInfo.AppVersion);
	If Parameters.Exit Then
		Items.FormNo.Visible = False;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure HyperlinkTextClick(Item)
	StandardProcessing = False;
	RunApp(Items.HyperlinkText.ToolTip);
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ContinueWork(Command)
	
	Close(DialogReturnCode.Cancel);
	
EndProcedure

&AtClient
Procedure ExitExecute(Command)
	
	Close(DialogReturnCode.OK);
	
EndProcedure
