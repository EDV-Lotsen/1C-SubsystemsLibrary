//////////////////////////////////////////////////////////////////////////
// Event handlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	AskExitConfirmation = StandardSubsystemsServerCall.LoadOnExitConfirmationSetting();
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	WriteAndCloseServer();
	Close();
EndProcedure

&AtClient
Procedure Write(Command)
	WriteAndCloseServer();
EndProcedure

//////////////////////////////////////////////////////////////////////////
// Helper functions

&AtServer
Procedure WriteAndCloseServer()
	// StandardSubsystems.BaseFunctionality
	StandardSubsystemsServerCall.SaveExitConfirmationSettings(AskExitConfirmation);
	// End StandardSubsystems.BaseFunctionality
EndProcedure
