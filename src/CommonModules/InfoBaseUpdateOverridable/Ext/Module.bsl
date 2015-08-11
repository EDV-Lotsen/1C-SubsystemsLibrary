////////////////////////////////////////////////////////////////////////////////
// Infobase version update subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns an infobase update handler list for all supported infobase versions.
//
// How to add a handler to the list:
// Handler = Handlers.Add();
// Handler.Version = "1.0.0.0";
// Handler.Procedure = "UpdateInfoBase.UpgradeToVersion_1_0_0_0";
//
// Is called before infobase data update.
//
Function UpdateHandlers() Export
	
	Handlers = InfoBaseUpdate.NewUpdateHandlerTable();
	
	// Attaching configuration update handlers
	//
	// Translator
	SystemSettings.RegisterUpdateHandlers(Handlers);
	// End Translator
	
	Return Handlers;
	
EndFunction

// Is called after the infobase update.
//
// Parameters:
//  PreviousInfoBaseVersion - String - infobase version before the update. It is
//   "0.0.0.0" if the infobase configuration was clear.
//  CurrentInfoBaseVersion - String - infobase version after the update.
//  ExecutedHandlers - ValueTree - list of the completed update handlers
//   grouped by version number.
//   You should use the ExecutedHandlers parameter in the following way:
// 	For Each Version In ExecutedHandlers.Rows Do
//
// 		If Version.Version = "*" Then
// 			Handlers that are executed always
// 		Else
// 			Handlers that are executed for a specific version 
// 		EndIf;
//
// 		For Each Handler In Version.Rows Do
// 			 ...
// 		EndDo;
//
// 	EndDo;
//
//  PutUpdateDetails - Boolean -	flag that shows whether the update description form 
// 										will be displayed.
// 
Procedure AfterUpdate(Val PreviousInfoBaseVersion, Val CurrentInfoBaseVersion, 
	Val ExecutedHandlers, PutUpdateDetails) Export
	
EndProcedure

// Is called on preparing a spreadsheet document with update details.
// 
// Parameters:
// Template - SpreadsheetDocument - update details.
// 
// See also the UpdateDetails common template.
//
Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
EndProcedure	

