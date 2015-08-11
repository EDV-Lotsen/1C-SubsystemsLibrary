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
	
	If TypeOf(ParametersOnApplicationStartAndExit) <> Type("Structure") Then
		ParametersOnApplicationStartAndExit = New Structure;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("RetrievedClientParameters", Undefined);
	
	If ParametersOnApplicationStartAndExit.Property("RetrievedClientParameters")
	   And TypeOf(ParametersOnApplicationStartAndExit.RetrievedClientParameters) = Type("Structure") Then
		
		Parameters.Insert("RetrievedClientParameters",
			ParametersOnApplicationStartAndExit.RetrievedClientParameters);
	EndIf;
	
	If ParametersOnApplicationStartAndExit.Property("SkipClearingDesktopHiding") Then
		Parameters.Insert("SkipClearingDesktopHiding");
	EndIf;
	
#If WebClient Then
	IsWebClient = True;
#Else
	IsWebClient = False;
#EndIf
	
	SystemInfo = New SystemInfo;
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	              Or SystemInfo.PlatformType = PlatformType.Linux_x86_64;

	Parameters.Insert("LaunchParameter", LaunchParameter);
	Parameters.Insert("InfoBaseConnectionString", InfoBaseConnectionString());
	Parameters.Insert("IsWebClient",    IsWebClient);
	Parameters.Insert("IsLinuxClient", IsLinuxClient);
	Parameters.Insert("HideDesktopOnStart", False);
	
	ClientParameters = StandardSubsystemsServerCall.ClientParametersOnStart(Parameters);
	
	StandardSubsystemsClient.HideDesktopOnStart(
		Parameters.HideDesktopOnStart, True);
	
	Return ClientParameters;
	
EndFunction

// Returns a parameter structure required to
// application run at client.
//
Function ClientParameters() Export
	
	#If ThinClient Then 
		ClientFileNameToExecute = "1cv8c.exe";
	#Else
		ClientFileNameToExecute = "1cv8.exe";
	#EndIf
	
	CurrentDate = CurrentDate();
	
	ClientParameters = New Structure;
	CurClientParameters = StandardSubsystemsServerCall.ClientParameters();
	For Each Parameter In CurClientParameters Do
		ClientParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	ClientParameters.SessionTimeOffset = ClientParameters.SessionTimeOffset - CurrentDate;
	ClientParameters.Insert("ClientFileNameToExecute", ClientFileNameToExecute);
	
	ClientParameters.Insert("ShowUpdateDetails", InfoBaseUpdate.ShowUpdateDetails());
	
	Return New FixedStructure(ClientParameters);
	
EndFunction

// Internal use only.
Function ClientEventHandlers(Event, IsInternal = False) Export
	
	Result = PreparedClientEventHandlers(Event, IsInternal);
	
	If Result = Undefined Then
		StandardSubsystemsServerCall.EventHandlersGettingOnError();
		RefreshReusableValues();
		Result = PreparedClientEventHandlers(Event, IsInternal, False);
	EndIf;
	
	Return Result;
	
EndFunction

// Internal use only.
Function PreparedClientEventHandlers(Event, IsInternal = False, FirstAttempt = True)
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.Property("ClientEventsHandlers") Then
		Return Undefined;
	EndIf;
	Parameters = ClientParameters.ClientEventsHandlers;
	
	If IsInternal Then
		Handlers = Parameters.InternalEventHandlers.Get(Event);
	Else
		Handlers = Parameters.EventHandlers.Get(Event);
	EndIf;
	
	If FirstAttempt And Handlers = Undefined Then
		Return Undefined;
	EndIf;
	
	If Handlers = Undefined Then
		If IsInternal Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 internal client event not found.'"), Event);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 client event not found.'"), Event);
		EndIf;
	EndIf;
	
	Array = New Array;
	
	For Each Handler In Handlers Do
		Element = New Structure;
		Module = Undefined;
		If FirstAttempt Then
			Try
				Module = CommonUseClient.CommonModule(Handler.Module);
			Except
				Return Undefined;
			EndTry;
		Else
			Module = CommonUseClient.CommonModule(Handler.Module);
		EndIf;
		Element.Insert("Module",    Module);
		Element.Insert("Version",   Handler.Version);
		Element.Insert("Subsystem", Handler.Subsystem);
		Array.Add(New FixedStructure(Element));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction
