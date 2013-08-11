////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns parameter structure required for client script execution 
// on application start, that is, in following еvent handlers
// - BeforeStart,
// - OnStart
//
// Important: when running the application, do not use cache reset commands of modules 
// that reuse return values because this can lead to unpredictable errors and unneeded 
// service calls. 
//
// This pricedure is not intended for a direct call from a client script.
// Instead of it you should use the same name function from 
// StandardSubsystemsClientCached module.
//
// Implementation:
// You can use this template to set up client run parameters:
//
// Parameters.Insert(<ParameterName>, <script that gets parameter values>);
//
// Returns:
// Structure - client run parameter structure on start.
//
Function ClientParametersOnStart() Export
	
	Parameters = New Structure();
	
	// StandardSubsystems
	If Not AddStandardSubsystemsClientLogicExecutingParametersOnStart(Parameters) Then
		Return New FixedStructure(Parameters);
	EndIf;
	// End StandardSubsystems
	
	// You can use this template to set up system initialization parameters:
	//
	// Parameters.Insert(<ParameterName>, <script that gets parameter value>);
	//
	
	Return New FixedStructure(Parameters);
	
EndFunction

// Returns parameter structure required for configuration client script execution. 
// 
//
// This pricedure is not intended for a direct call from a client script.
// Instead of it you should use the same name function from 
// StandardSubsystemsClientCached module.
//
// Implementation:
// You can use this template to set up client run parameters:
//
// Parameters.Insert(<ParameterName>, <script that gets parameter value>);
//
// Returns:
// Structure - client run parameter structure
//
Function ClientParameters() Export
	
	Parameters = New Structure();
	
	// StandardSubsystems
	AddSubsystemsLibraryClientLogicExecutionParameters(Parameters);
	// End StandardSubsystems
	
	// You can use this template to set up system initialization parameters:
	//
	// Parameters.Insert(<ParameterName>, <script that gets parameter value>);
	//
	
	Return New FixedStructure(Parameters);
	
EndFunction

// Fills parameter structure required for client script execution 
// on application start, that is in following еvent handlers
// - BeforeStart,
// - OnStart
//
// Important: when running the application, do not use cache reset commands of modules 
// that reuse return values because this can lead to unpredictable errors and unneeded 
// service calls. 
//
// Parameters:
// Parameters - Structure - parameter structure.
//
// Returns:
// Boolean - False if further filling of parameters must be aborted.
//
Function AddStandardSubsystemsClientLogicExecutingParametersOnStart(Parameters) 
	
	// StandardSubsystems.BaseFunctionality
	If Not StandardSubsystemsServer.AddClientParametersOnStart(Parameters) Then
		Return False;
	EndIf;
	// End StandardSubsystems.BaseFunctionality
	
	// StandardSubsystems.UserSessions
	InfoBaseConnections.CheckDataAreaConnectionsLock(Parameters);
	// End StandardSubsystems.UserSessions
	
	Return True;
	
EndFunction

// Fills parameter structure required for configuration client script execution. 
// 
//
// Parameters:
// Parameters - Structure - parameter structure.
//
Procedure AddSubsystemsLibraryClientLogicExecutionParameters(Parameters) 
	
	// StandardSubsystems.BaseFunctionality
	StandardSubsystemsServer.AddClientParameters(Parameters);
	// End StandardSubsystems.BaseFunctionality
	
	// StandardSubsystems.UserSessions
	Parameters.Insert("SessionLockParameters", New FixedStructure(InfoBaseConnections.SessionLockParameters()));
	// End StandardSubsystems.UserSessions
	
	// StandardSubsystems.InfoBaseVersionUpdate
	Parameters.Insert("FirstRun", InfoBaseUpdate.FirstRun());
	Parameters.Insert("IsMasterNode", ExchangePlans.MasterNode() = Undefined);
	// End StandardSubsystems.InfoBaseVersionUpdate
	
	// StandardSubsystems.DataExchange
	DataExchangeServer.AddSubsystemsLibraryClientLogicExecutionParameters(Parameters);
	// End StandardSubsystems.DataExchange
	
	// StandardSubsystems.GetFilesFromInternet
	Parameters.Insert("ProxyServerSettings", GetFilesFromInternet.GetProxyServerSetting());
	// End StandardSubsystems.GetFilesFromInternet
	
	// StandardSubsystems.ScheduledJobs
	If CommonUse.FileInfoBase() Then
		Parameters.Insert("ScheduledJobExecutionSeparateSessionLaunchParameters", 
			New FixedStructure(ScheduledJobsServer.ScheduledJobExecutionSeparateSessionLaunchParameters(True)));
	EndIf;
	// End StandardSubsystems.ScheduledJobs

EndProcedure

// The procedure implements copying common data to separated data
//
Procedure FillSuppliedDataFromClassifier(Val Refs, Val IgnoreManualChanges = False) Export

	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.FillFromClassifier(Refs, IgnoreManualChanges);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

