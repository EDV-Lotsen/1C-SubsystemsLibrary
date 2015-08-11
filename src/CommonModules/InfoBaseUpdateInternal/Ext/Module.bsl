// Internal use only.
Function UpdateInfoBase(ExceptionIfUnableLockInfoBase = True,
	OnStartClientApplication = False, Restart = False, CurrentInfobaseLock = Undefined, Background = False) Export
	
	InfoBaseUpdate.ExecuteInfoBaseUpdate();
	
EndFunction

// Internal use only.
Function CheckUpdateObtainingLegalityRequired() Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.UpdateObtainingLegalityCheck") Then
		Return False;
	EndIf;
	
	If StandardSubsystemsServer.IsBaseVersion() Then
		Return False;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If CommonUse.IsSubordinateDIBNode() Then
		Return False;
	EndIf;
	
	LegalVersion = "";
	
	If InfoBaseUpdateInLocalMode() = "InitialFilling" Then
		LegalVersion = Metadata.Version;
	Else
		UpdateInfo = InfoBaseUpdateInfo();
		LegalVersion = UpdateInfo.LegalVersion;
	EndIf;
	
	Return LegalVersion <> Metadata.Version;
	
EndFunction

// Internal use only.
Function InfoBaseLockedForUpdate(PrivilegedMode = True) Export
	
	Message = "";
	
	CurrentInfoBaseUser = InfoBaseUsers.CurrentUser();
	
	If PrivilegedMode Then
		HasAdministrationRight = AccessRight("Administration", Metadata);
	Else
		HasAdministrationRight = AccessRight("Administration", Metadata, CurrentInfoBaseUser);
	EndIf;
	
	MessageToAdministrator =
		NStr("en = 'Log on is temporary disabled because of the application update.
              |To finish the application version update administrative rights are required
              |(System administrator or Full access rights).'; ru = 'Вход в программу временно невозможен в связи с обновлением на новую версию.
              |Для завершения обновления версии программы требуются административные права
              |(роли ""Администратор системы"" и ""Полные права"").'");
	
	SetPrivilegedMode(True);
	DataSeparationEnabled = CommonUseCached.DataSeparationEnabled();
	CanUseSeparatedData = CommonUseCached.CanUseSeparatedData();
	SetPrivilegedMode(False);
	
	If SharedDataUpdateRequired() Then
		
		MessageToDataAreaAdministrator =
			NStr("en='Log on is temporary disabled because of the application update."
"Contact the service administrator for more details.'");
		
		If CanUseSeparatedData Then
			Message = MessageToDataAreaAdministrator;
			
		ElsIf Not InfoBaseUpdate.CanUpdateInfoBase(PrivilegedMode, False) Then
			
			If HasAdministrationRight Then
				Message = MessageToAdministrator;
			Else
				Message = MessageToDataAreaAdministrator;
			EndIf;
		EndIf;
		
		Return Message;
	EndIf;
	
	If DataSeparationEnabled And Not CanUseSeparatedData Then
		Return "";
	EndIf;
		
	If InfoBaseUpdate.CanUpdateInfoBase(PrivilegedMode, True) Then
		Return "";
	EndIf;
	
	RetryDataExchangeMessageImportBeforeStart = False;
	If CommonUse.IsSubordinateDIBNode()
	   And CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		DataExchangeServerCallModule = CommonUse.CommonModule("DataExchangeServerCall");
		If DataExchangeServerCallModule.RetryDataExchangeMessageImportBeforeStart() Then
			RetryDataExchangeMessageImportBeforeStart = True;
		EndIf;
	EndIf;
	
	If Not InfoBaseUpdate.InfoBaseUpdateRequired()
	   And Not CheckUpdateObtainingLegalityRequired()
	   And Not RetryDataExchangeMessageImportBeforeStart Then
		Return "";
	EndIf;
	
	If HasAdministrationRight Then
		Return MessageToAdministrator;
	EndIf;

	If DataSeparationEnabled Then
		Message =
			NStr("en='Log on is temporary disabled because of the application update."
"You can get more details from the administrator'");
	Else
		Message =
			NStr("en='Log on is temporary disabled because of the application update."
"You can get more details from the administrator'");
	EndIf;
	
	Return Message;
	
EndFunction

// Internal use only.
Function SharedDataUpdateRequired() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		MetadataVersion = Metadata.Version;
		If IsBlankString(MetadataVersion) Then
			MetadataVersion = "0.0.0.0";
		EndIf;
		
		SharedDataVersion = InfoBaseUpdate.InfoBaseVersion(Metadata.Name, True);
		
		If InfoBaseUpdate.UpdateRequired(MetadataVersion, SharedDataVersion) Then
			Return True;
		EndIf;
		
		If Not CommonUseCached.CanUseSeparatedData() Then
			
			SetPrivilegedMode(True);
			Start = SessionParameters.ClientParametersAtServer.Get("StartInfoBaseUpdate");
			SetPrivilegedMode(False);
			
			If Start <> Undefined И InfoBaseUpdate.CanUpdateInfoBase() Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Internal use only.
Function NewInfoBaseUpdateInfo(OldInfo = Undefined)
	
	InfoBaseUpdateInfo = New Structure;
	InfoBaseUpdateInfo.Insert("UpdateBeginTime");
	InfoBaseUpdateInfo.Insert("UpdateEndTime");
	InfoBaseUpdateInfo.Insert("UpdatePeriod");
	InfoBaseUpdateInfo.Insert("DeferredUpdateBeginTime");
	InfoBaseUpdateInfo.Insert("DeferredUpdateEndTime");
	InfoBaseUpdateInfo.Insert("SessionNumber", New ValueList());
	InfoBaseUpdateInfo.Insert("UpdateHandlerParameters");
	InfoBaseUpdateInfo.Insert("DeferredUpdateComletedSuccessfully");
	InfoBaseUpdateInfo.Insert("HandlerTree", New ValueTree());
	InfoBaseUpdateInfo.Insert("ShowUpdateDetails", False);
	InfoBaseUpdateInfo.Insert("LegalVersion", "");
	
	If TypeOf(OldInfo) = Тип("Structure") Then
		FillPropertyValues(InfoBaseUpdateInfo, OldInfo);
	EndIf;
	
	Return InfoBaseUpdateInfo;
	
EndFunction

// Internal use only.
Function InfoBaseUpdateInfo() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled()
	   And Not CommonUseCached.CanUseSeparatedData() Then
		
		Return NewInfoBaseUpdateInfo();
	EndIf;
	
	InfoBaseUpdateInfo = Constants.InfoBaseUpdateInfo.Get().Get();
	If TypeOf(InfoBaseUpdateInfo) <> Type("Structure") Then
		Return NewInfoBaseUpdateInfo();
	EndIf;
	If InfoBaseUpdateInfo.Count() = 1 Then
		Return NewInfoBaseUpdateInfo();
	EndIf;
		
	InfoBaseUpdateInfo = NewInfoBaseUpdateInfo(InfoBaseUpdateInfo);
	Return InfoBaseUpdateInfo;
	
EndFunction

// Internal use only.
Function InfoBaseUpdateInLocalMode()
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
		"SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions";
	
	BatchExecutionResult = Query.ExecuteBatch();
	If BatchExecutionResult[0].IsEmpty() Then
		Return "InitialFilling";
		//Return "VersionUpdate"; 
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.IsMainConfiguration = TRUE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.SubsystemName = &MainConfigurationName
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Field1
		|FROM
		|	InformationRegister.SubsystemVersions AS SubsystemVersions
		|WHERE
		|	SubsystemVersions.IsMainConfiguration = TRUE
		|	AND SubsystemVersions.SubsystemName = &MainConfigurationName";
	Query.SetParameter("MainConfigurationName", Metadata.Name);
	BatchExecutionResult = Query.ExecuteBatch();
	If BatchExecutionResult[0].IsEmpty() And Not BatchExecutionResult[1].IsEmpty() Then
		Return "VersionUpdate"; 
	EndIf;
	
	Return ?(BatchExecutionResult[2].IsEmpty(), "MigrationFromOtherApplication", "VersionUpdate");
	
EndFunction	

// Internal use only.
Procedure StandardSubsystemClientLogicParametersOnAddOnStart(Parameters) Export
	
	Parameters.Insert("InitialDataFilling", DataUpdateMode() = "InitialFilling");
	Parameters.Insert("ShowUpdateDetails", ShowUpdateDetails());
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	HandlerState = NotProcessedHandlersState();
	If HandlerState = "" Then
		Return;
	EndIf;
	If HandlerState = "ErrorState"
		And Users.InfoBaseUserWithFullAccess(, True) Then
		Parameters.Insert("ShowFailedHandlersMessage");
	Else
		Parameters.Insert("ShowFailedHandlersNotification");
	EndIf;
	
EndProcedure

// Internal use only.
Function NotProcessedHandlersState()
	
	UpdateInfo = InfoBaseUpdateInfo();
	For Each LibraryTreeRow In UpdateInfo.HandlerTree.Rows Do
		For Each TreeRowVersion In LibraryTreeRow.Rows Do
			For Each Handler In TreeRowVersion.Rows Do
				If Handler.State = "Error" Then
					Return "ErrorState";
				ElsIf Handler.State <> "Completed" Then
					Return "NotProcessedState";
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return "";
	
EndFunction

// Internal use only.
Function ShowUpdateDetails()
	
	Return True;
	
EndFunction

// Internal use only.
Function DataUpdateMode()
	
	If InfoBaseUpdate.FirstRun() Then
		Return "InitialFilling";
	Else
		Return "VersionUpdate";
	EndIf;
	
EndFunction

// Internal use only.
Procedure InternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	ServerEvents.Add(
		"StandardSubsystems.InfoBaseVersionUpdate\UpdateHandlersOnAdd");
	
	ServerEvents.Add("StandardSubsystems.InfoBaseVersionUpdate\InfoBaseBeforeUpdate");
	
	ServerEvents.Add("StandardSubsystems.InfoBaseVersionUpdate\InfoBaseAfterUpdate");
	
EndProcedure

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BaseFunctionality\AfterStart"].Add(
		"InfoBaseUpdateClient");
	
	ClientHandlers["StandardSubsystems.BaseFunctionality\OnStart"].Add(
		"InfoBaseUpdateClient");
	
	// SERVER HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfoBaseVersionUpdate\UpdateHandlersOnAdd"].Add(
		"InfoBaseUpdateInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToSlave"].Add(
		"InfoBaseUpdateInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToMaster"].Add(
		"InfoBaseUpdateInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAddOnStart"].Add(
		"InfoBaseUpdateInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\RequiredExchangePlanObjectOnReceive"].Add(
		"InfoBaseUpdateInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExchangePlanInitialImageObjectsOnGet"].Add(
		"InfoBaseUpdateInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SessionParameterSettingHandlersOnAdd"].Add(
		"InfoBaseUpdateInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ServiceMode.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.ServiceMode.JobQueue\OnGetTemplateList"].Add(
				"InfoBaseUpdateInternal");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExceptionExchangePlanObjectOnReceive"].Add(
		"InfoBaseUpdateInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentAffairs") Then
		ServerHandlers["StandardSubsystems.CurrentAffairs\CurrentAffairsOnFill"].Add(
			"InfoBaseUpdateInternal");
	EndIf;
	
EndProcedure

// Internal use only.
Procedure SessionParameterSettingHandlersOnAdd(Handlers) Export
	
	Handlers.Insert("InfoBaseUpdateInProgress", "InfoBaseUpdateInternal.SessionParametersSetting");
	
EndProcedure

// Internal use only.
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	If ParameterName <> "InfoBaseUpdateInProgress" Then
		Return;
	EndIf;
	
	SessionParameters.InfoBaseUpdateInProgress = InfoBaseUpdate.InfoBaseUpdateRequired();
	SpecifiedParameters.Add("InfoBaseUpdateInProgress");
	
EndProcedure
