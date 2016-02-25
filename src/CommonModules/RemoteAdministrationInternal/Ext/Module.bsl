////////////////////////////////////////////////////////////////////////////////
// Remote administration subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.SaaSOperations\OnSetInfobaseParameterValues"].Add(
		"RemoteAdministrationInternal");
	
	ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\RecordingIncomingMessageInterfaces"].Add(
		"RemoteAdministrationInternal");
	
	ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\RecordingOutgoingMessageInterfaces"].Add(
		"RemoteAdministrationInternal");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Is called before an attempt to write infobase parameters as constants
// with the same name.
//
// Parameters:
// ParameterValues - Structure - parameter values to set.
// If the parameter value is set in the procedure based on structure, 
// the corresponding KeyAndValue pair must be deleted
//
Procedure OnSetInfobaseParameterValues(Val ParameterValues) Export
	
	If ParameterValues.Property("ServiceURL") Then
		Constants.InternalServiceManagerURL.Set(ParameterValues.ServiceURL);
		ParameterValues.Delete("ServiceURL");
	EndIf;
	
	If ParameterValues.Property("AuxiliaryServiceUserName") Then
		Constants.AuxiliaryServiceManagerUserName.Set(ParameterValues.AuxiliaryServiceUserName);
		ParameterValues.Delete("AuxiliaryServiceUserName");
	EndIf;
	
	If ParameterValues.Property("AuxiliaryServiceUserPassword") Then
		Constants.AuxiliaryServiceManagerUserPassword.Set(ParameterValues.AuxiliaryServiceUserPassword);
		ParameterValues.Delete("AuxiliaryServiceUserPassword");
	EndIf;
	
EndProcedure

// Fills the passed array with common modules that contain handlers for interfaces of incoming messages.
//
// Parameters:
//  HandlerArray - array
//
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(RemoteAdministrationMessagesInterface);
	
EndProcedure

// Fills the passed array with common modules that contain handlers for interfaces of outgoing messages.
//
// Parameters:
//  HandlerArray - array
//
//
Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(RemoteAdministrationControlMessagesInterface);
	HandlerArray.Add(ApplicationManagementMessagesInterface);
	
EndProcedure

#EndRegion
