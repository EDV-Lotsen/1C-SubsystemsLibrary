////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a parameter structure required for
// running the application in the client mode, that is in following еvent handlers
// - BeforeStart,
// - OnStart
//
// Important: when running the application, do not use cache reset commands of modules 
// that reuse return values because this can lead to unpredictable errors and unneeded 
//service calls. 
//
Function ClientParametersOnStart() Export
	
	Return StandardSubsystemsServerCallOverridable.ClientParametersOnStart();
	
EndFunction

// Returns a parameter structure required to
// application run at client.
//
Function ClientParameters() Export
	CurrentDate = CurrentDate(); // current client computer date 
	ClientParameters = New Structure;
	For Each Parameter In StandardSubsystemsServerCallOverridable.ClientParameters() Do
		ClientParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	ClientParameters.SessionTimeOffset = ClientParameters.SessionTimeOffset - CurrentDate;
	
	Return New FixedStructure(ClientParameters);
	
EndFunction
