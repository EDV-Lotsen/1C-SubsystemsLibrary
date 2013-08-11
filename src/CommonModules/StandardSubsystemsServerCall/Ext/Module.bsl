////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Writes current user exit confirmation setting.
// 

// Parameters:
// Value - Boolean - value to set.
//
Procedure SaveExitConfirmationSettings(Value) Export
	
	CommonUse.CommonSettingsStorageSave("UserCommonSettings", "AskConfirmationOnExit", Value);
	
EndProcedure

// Returns current user exit confirmation setting.
// 
//
Function LoadOnExitConfirmationSetting() Export
	
	Result = CommonUse.CommonSettingsStorageLoad("UserCommonSettings", "AskConfirmationOnExit");
	If Result = Undefined Then
		Result = True;
	EndIf;
	Return Result;
	
EndFunction
