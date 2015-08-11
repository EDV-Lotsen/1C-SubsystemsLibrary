
// Internal use only.
Procedure InternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	ServerEvents.Add(
		"StandardSubsystems.ServiceMode.JobQueue\OnGetTemplateList");
	ServerEvents.Add(
		"StandardSubsystems.ServiceMode.JobQueue\OnGetHandlerAliases");
	ServerEvents.Add(
		"StandardSubsystems.ServiceMode.JobQueue\OnGetErrorHandlers");
	ServerEvents.Add(
		"StandardSubsystems.ServiceMode.JobQueue\OnGetScheduledJobUsages");
	
EndProcedure

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas"].Add(
		"StandardSubsystemsOverridable");
	
EndProcedure
