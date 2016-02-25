
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

// The cryptography extensions installation commands handler
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	BeginInstallCryptoExtension();
EndProcedure
