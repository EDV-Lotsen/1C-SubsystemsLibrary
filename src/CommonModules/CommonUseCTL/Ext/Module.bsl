Function GetSLProgramEventHandlers(Val Event) Export
	
	If ProgramEventsSupported() Then
		
		Return Eval("CommonUse.InternalEventHandlers(Event)");
		
	Else
		Return New Array();
	EndIf;
	
EndFunction

Function ConfigurationContainsSL()
	
	Return (Metadata.Subsystems.Find("StandardSubsystems") <> Undefined);
	
EndFunction

Function ProgramEventsSupported()
	
	If Not ConfigurationContainsSL() Then
		Return False;
	EndIf;
	
	Try
		
		Parameters = Eval("StandardSubsystemsCached.ProgramEventParameters()");
		Return True;
		
	Except
		Return False;
	EndTry;
	
EndFunction
