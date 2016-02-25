////////////////////////////////////////////////////////////////////////////////
// Dynamic configuration update control subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS
	
	ClientHandlers[
		"StandardSubsystems.BaseFunctionality\AfterStart"].Add(
			"DynamicConfigurationUpdateControlClient");
	
EndProcedure

#EndRegion
