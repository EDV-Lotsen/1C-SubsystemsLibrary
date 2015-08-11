////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Adds update handlers required to Translator objects in the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see InfoBaseUpdate.NewUpdateHandlerTable function for details. 
//
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.2.1";
	Handler.Priority = 1;
	Handler.SharedData = True;
	Handler.Procedure = "InfoBaseUpdateSL.MetadataObjectIDsUpdate_2_0_2_1";
	
EndProcedure

// See comment to the procedure with the same name in the CommonUseOverridable module.
Procedure BasicFunctionalityCommonParametersOnDefine(CommonParameters) Export
	
	CommonParameters.PersonalSettingsFormName = "CommonForm.UserSettingsForm";
	
EndProcedure

