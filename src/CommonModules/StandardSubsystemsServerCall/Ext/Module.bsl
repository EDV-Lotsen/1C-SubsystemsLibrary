////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Writes current user exit confirmation setting.
// 

// Parameters:
// Value - Boolean - value to set.
//
Procedure SaveExitConfirmationSettings(Value) Export
	
	CommonUse.CommonSettingsStorageSave("UserCommonSettings", "AskConfirmationOnExit", Value);
	
EndProcedure

// Returns current user exit confirmation setting.
// 
//
Function LoadOnExitConfirmationSetting() Export
	
	Result = CommonUse.CommonSettingsStorageLoad("UserCommonSettings", "AskConfirmationOnExit");
	If Result = Undefined Then
		Result = True;
	EndIf;
	Return Result;
	
EndFunction

// Internal use only.
Function WriteErrorToEventLogOnStartOrExit(Exit, Val Event, Val ErrorDescription) Export
	
	If Event = "Start" Then
		EventName = NStr("en = 'Application start'", Metadata.DefaultLanguage.LanguageCode);
		If Exit Then
			ErrorDescriptionBegin = NStr("en='An exception raised during the application start. The application terminated.'");
		Else
			ErrorDescriptionBegin = NStr("en='An exception raised during the application start.'");
		EndIf;
	Else
		EventName = NStr("en = 'Application exit'", Metadata.DefaultLanguage.LanguageCode);
		ErrorDescriptionBegin = NStr("en='An exception raised during the application exit.'");
	EndIf;
	
	ErrorDescription = ErrorDescriptionBegin
		+ Chars.LF + Chars.LF
		+ ErrorDescription;
	WriteLogEvent(EventName, EventLogLevel.Error,,, ErrorDescription);
	Return ErrorDescriptionBegin;

EndFunction

// Internal use only.
Procedure EventHandlersGettingOnError() Export
	
	If Not ExclusiveMode() And TransactionActive() Then
		Return;
	EndIf;
	
	If Not CommonUseCached.DataSeparationEnabled()
	 Or Not CommonUseCached.CanUseSeparatedData() Then
		If Not ExclusiveMode() Then
			Try
				SetExclusiveMode(True);
			Except
				Return;
			EndTry;
		EndIf;
		
		Try
			Constants.InternalEventParameters.CreateValueManager().Refresh();
		Except
			SetExclusiveMode(False);
			RefreshReusableValues();
			Raise;
		EndTry;
		
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Internal use only.
Procedure HideDesktopOnStart(Hide = True) Export
	
	//SetExclusiveMode(True);
	
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	
	If Hide = True Then
		CurrentParameters.Insert("HideDesktopOnStart", True);
		
	ElsIf CurrentParameters.Get("HideDesktopOnStart") <> Undefined Then
		CurrentParameters.Delete("HideDesktopOnStart");
	EndIf;
	
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	
EndProcedure

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
	
	Parameters = New Structure;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd");
	
	For Each Handler In EventHandlers Do
		Handler.Module.StandardSubsystemClientLogicParametersOnAdd(Parameters);
	EndDo;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\ClientParametersOnAdd");
	
	For Each Handler In EventHandlers Do
		Handler.Module.ClientParametersOnAdd(Parameters);
	EndDo;
	
	AppliedSolutionParameters = New Structure;
	CommonUseOverridable.ClientParameters(AppliedSolutionParameters);
	
	For Each Parameter In AppliedSolutionParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	Return CommonUse.FixedData(Parameters);
	
EndFunction

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
Function ClientParametersOnStart(Parameters) Export
	
	StoreTempParameters(Parameters);
	
	If Parameters.RetrievedClientParameters <> Undefined Then
		If Not Parameters.Property("SkipClearingDesktopHiding") Then
			HideDesktopOnStart(False);
		EndIf;
	EndIf;
	
	PrivilegedModeSetOnStart = PrivilegedMode();
	
	SetPrivilegedMode(True);
	If SessionParameters.ClientParametersAtServer.Count() = 0 Then
		ClientParameters = New Map;
		ClientParameters.Insert("LaunchParameter", Parameters.LaunchParameter);
		ClientParameters.Insert("InfoBaseConnectionString", Parameters.InfoBaseConnectionString);
		ClientParameters.Insert("PrivilegedModeSetOnStart", PrivilegedModeSetOnStart);
		ClientParameters.Insert("IsWebClient",    Parameters.IsWebClient);
		ClientParameters.Insert("IsLinuxClient", Parameters.IsLinuxClient);
		SessionParameters.ClientParametersAtServer = New FixedMap(ClientParameters);
		
		If Not CommonUseCached.DataSeparationEnabled() Then
			If ExchangePlans.MasterNode() <> Undefined
			 Or ValueIsFilled(Constants.MasterNode.Get()) Then
				If GetInfoBasePredefinedData()
				     <> PredefinedDataUpdate.DontAutoUpdate Then
					SetInfoBasePredefinedDataUpdate(
						PredefinedDataUpdate.DontAutoUpdate);
				EndIf;
				If ExchangePlans.MasterNode() <> Undefined
				   And Not ValueIsFilled(Constants.MasterNode.Get()) Then
					MasterNodeManager = Constants.MasterNode.CreateValueManager();
					MasterNodeManager.Value = ExchangePlans.MasterNode();
					InfoBaseUpdate.WriteData(MasterNodeManager);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	SetPrivilegedMode(False);
	
	If Not StandardSubsystemsServer.AddClientParametersOnStart(Parameters) Then
		FixedParameters = FixedClientParametersWithoutTempParameters(Parameters);
		Return FixedParameters;
	EndIf;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAddOnStart");
	For Each Handler In EventHandlers Do
		Handler.Module.StandardSubsystemClientLogicParametersOnAddOnStart(Parameters);
	EndDo;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\ClientParametersOnAddOnStart");
	For Each Handler In EventHandlers Do
		Handler.Module.ClientParametersOnAddOnStart(Parameters);
	EndDo;
	
	AppliedSolutionParameters = New Structure;
	CommonUseOverridable.ClientParametersOnStart(AppliedSolutionParameters);
	
	For Each Parameter In AppliedSolutionParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	FixedParameters = FixedClientParametersWithoutTempParameters(Parameters);
	Return FixedParameters;
	
EndFunction

// Internal use only.
Procedure StoreTempParameters(Parameters)
	
	Parameters.Insert("TempParameterNames", New Array);
	
	For Each KeyAndValue In Parameters Do
		Parameters.TempParameterNames.Add(KeyAndValue.Key);
	EndDo;
	
EndProcedure

// Internal use only.
Function FixedClientParametersWithoutTempParameters(Parameters)
	
	ClientParameters = Parameters;
	Parameters = New Structure;
	
	For Each TempParameterName In ClientParameters.TempParameterNames Do
		Parameters.Insert(TempParameterName, ClientParameters[TempParameterName]);
		ClientParameters.Delete(TempParameterName);
	EndDo;
	Parameters.Delete("TempParameterNames");
	
	SetPrivilegedMode(True);
	
	Parameters.HideDesktopOnStart =
		SessionParameters.ClientParametersAtServer.Get(
			"HideDesktopOnStart") <> Undefined;
	
	SetPrivilegedMode(False);
	
	Return CommonUse.FixedData(ClientParameters);
	
EndFunction
