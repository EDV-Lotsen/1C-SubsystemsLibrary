

Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert("CurrentValue", Constants.UseSeparationByDataAreas.Get());
	
EndProcedure

Procedure OnWrite(Cancel)
	
	Constants.DontUseSeparationByDataAreas.Set(Not Value);
	
	If AdditionalProperties.CurrentValue <> Value Then
		RefreshReusableValues();
		If Value Then
			StandardSubsystemsOverridable.OnEnableSeparationByDataAreas();
		EndIf;
	EndIf;
	
EndProcedure