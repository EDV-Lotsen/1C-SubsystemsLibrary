////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Adds handlers of internal events (subscriptions).

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.SaaSOperations.DataExchangeSaaS\OnCreateStandaloneWorkstation"].Add(
		"DataExchangeInternalSaaSCTL");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers

Procedure OnCreateStandaloneWorkstation() Export
	
	If UsersInternalSaaSCTL.UserRegisteredAsShared(
			InfobaseUsers.CurrentUser().UUID) Then
		
		Raise NStr("en = 'Standalone workstations can only be created on behalf of a separated user.
			|The current user is a shared user.'");
		
	EndIf;
	
EndProcedure