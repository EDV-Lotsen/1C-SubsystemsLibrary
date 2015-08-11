#If Server Or ThickClientOrdinaryApplication Or ExternalConnection  Then 

Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert("CurrentValue", Constants.UseSeparationByDataAreas.Get());
	
	If AdditionalProperties.CurrentValue <> Value  Then
		RefreshReusableValues();
		If Value Then
			EventHandlers = CommonUse.InternalEventHandlers(
				"StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas");
			AdditionalProperties.Insert("EventHandlers", EventHandlers);
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
 // The follow constants are mutually exclusive, are used in a separate functional options.
	//
	// Constant.IsStandaloneWorkstation      -> FO.StandaloneModeOperations
	// Constant.DontUseSeparationByDataAreas -> FO.LocalMode
	// Constant.UseSeparationByDataAreas     -> FO.SaaSOperations
	//
	// The constant names a saved to provide backward compatibility.
	
	If Value Then
		
		Constants.DontUseSeparationByDataAreas.Set(False);
		
	Else
		
		Constants.DontUseSeparationByDataAreas.Set(True);
		
	EndIf;
	
	If AdditionalProperties.Property("EventHandlers") Then
		For Each Handler In AdditionalProperties.EventHandlers Do
			Handler.Module.OnEnableSeparationByDataAreas();
		EndDo;
	EndIf;
	
EndProcedure

#EndIf 