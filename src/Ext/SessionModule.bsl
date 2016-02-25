#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


Procedure SessionParametersSetting(SessionParameterNames)
	
	// StandardSubsystems
	StandardSubsystemsServer.SessionParametersSetting(SessionParameterNames);
	// End StandardSubsystems
	
	// CloudTechnology
	CloudTechnology.ExecuteActionsOnSessionParametersSetting(SessionParameterNames);
	// End CloudTechnology
	
EndProcedure

#EndIf