////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns a command description by form item name.
// 
// See PrintManagement.PrintCommandDescription
//
Function PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage) Export
	
	Return PrintManagementServerCall.PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage);
	
EndFunction

#EndRegion
