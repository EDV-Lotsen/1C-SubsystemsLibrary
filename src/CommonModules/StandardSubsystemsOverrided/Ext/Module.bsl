
// Not interactive IB data update on library version change
// Required IB update "input point" in library.
Procedure RunInfobaseUpdate() Export
	
	InfobaseUpdate.RunUpdateIteration("StandardSubsystems", LibVersion(), 
		UpdateHandlers());
	
EndProcedure

// Returns version number of the SL.
//
Function LibVersion() Export
	
	Return "1.0.7.5";
	
EndFunction

// Returns list of procedures-handlers of library update
//
// Value returned:
//   Structure - description of the structure fields see in function
//               InfobaseUpdate.NewUpdateHandlersTable()
Function UpdateHandlers()
	
	Handlers = InfobaseUpdate.NewUpdateHandlersTable();
	
	// Connect procedures-handlers of library update
		
	// EmailOperations
	Handler = Handlers.Add();
	Handler.Version = "1.0.0.0";
	Handler.Procedure = "Emails.FillSystemAccount";
	// End EmailOperations
	
	// ContactInformation
	Handler = Handlers.Add();
	Handler.Version = "1.0.1.1";
	Handler.Procedure = "ContactInformationManagementOverrided.ContactInformationIBUpdate";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.1.3";
	Handler.Procedure = "ContactInformationManagement.LoadWorldCountries";
	// End ContactInformation
	
	// AddressClassifier
	Handler = Handlers.Add();
	Handler.Version = "1.0.1.1";
	Handler.Procedure = "AddressClassifier.LoadFirstLevelAddressClassifierUnits";
	// End AddressClassifier
		
	// FullTextSearch
	Handler = Handlers.Add();
	Handler.Version = "1.0.3.10";
	Handler.Procedure = "FullTextSearchServer.InitializeFunctionalOptionFullTextSearch";
	// End FullTextSearch
	
	// GetFilesFromInternet
	Handler = Handlers.Add();
	Handler.Version = "1.0.4.1";
	Handler.Procedure = "GetFilesFromInternet.StoredProxySettingsUpdate";
	// End GetFilesFromInternet
	
	// ObjectVersioning
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "ObjectVersioning.UpdateObjectVersioningSettings";
	// End ObjectVersioning
	
	// Users
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2";
	Handler.Procedure = "Users.FillUserIDs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.15";
	Handler.Procedure = "Users.FilingRegisterUserGroupMembers";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "ExternalUsers.FillContentOfGroupsOfExternalUsers";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "ExternalUsers.CreateInfobaseUsersForExternalUsers";
	// End Users
	
	// FileOperations
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2"; // on update to 1.0.5.2 handler will be executed
	Handler.Procedure = "FileOperations.FillVersionNoFromCatalogCode";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2"; // on update to 1.0.5.2 handler will be executed
	Handler.Procedure = "FileOperations.FillFileStorageTypeInBase";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.7"; // on update to 1.0.5.7 handler will be executed
	Handler.Procedure = "FileOperations.ChangePictogramIndex";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.3"; // on update to 1.0.6.3 handler will be executed
	Handler.Procedure = "FileOperations.FillVolumePaths";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.7.1";
	Handler.Procedure = "FileOperations.OverwriteAllFiles";

	// End FileOperations
	
	// Properties
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.7";
	Handler.Procedure = "AdditionalDataAndAttributesManagement.RefreshListOfAdditionalProperties";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.7.1";
	Handler.Procedure = "AdditionalDataAndAttributesManagement.RefreshRenamedRoles_SSL_1_0_7_1";	
	// End Properties
	
	// Currencies
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.9";
	Handler.Procedure = "WorkWithExchangeRates.UpdateHandwritingStorageFormat";
	// End Currencies
	
	
	// Calendars
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.2";
	Handler.Procedure = "Calendars.CreateRegularCalendarFor2012Year";
	// End Calendars
	
	// Individuals
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "Individuals.FillIndividualDocumentsByClassifier";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.8";
	Handler.Procedure = "Individuals.ConvertPersonalIDsToDocuments";
	// End Individuals
	
	// AdditionalReportsAndDataProcessors
	Handler = Handlers.Add();
	Handler.Version = "1.0.7.1";
	Handler.Procedure = "AdditionalReportsAndDataProcessors.UpdateDataProcessorsAccessUserSettings";
	// End AdditionalReportsAndDataProcessors
	
	Return Handlers;
	
EndFunction

// Returns structure of parameters, for the initialization of
// configuration at client.
//
Function ClientParameters() Export
	
	Parameters = New Structure();
	
	// StandardSubsystems
	Parameters.Insert("AuthorizationError", Users.AuthorizationError());
	If ValueIsFilled(Parameters.AuthorizationError) Then
		Return New FixedStructure(Parameters);
	EndIf;
	Parameters.Insert("InformationBaseLockedForUpdate", 
		InfobaseUpdate.IsImpossibleToUpdateInfobase());
	Parameters.Insert("InfobaseUpdateRequired", 
		InfobaseUpdate.InfobaseUpdateRequired());
	Parameters.Insert("AuthorizedUser", 				 Users.AuthorizedUser());
	Parameters.Insert("ThisIsBasicConfigurationVersion", ThisIsBasicConfigurationVersion());
	
	Parameters.Insert("ApplicationTitle", TrimAll(Constants.SystemTitle.Get()));
		
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	Parameters.Insert("FileInformationBase", CommonUse.FileInformationBase());
	// End StandardSubsystems
	
	// UserSessionTermination
	Parameters.Insert("SessionLockParameters", New FixedStructure(InfobaseConnections.SessionLockParameters()));
	// End UserSessionTermination
	
	// CheckLegalityOfUpdatesObtaining
	Parameters.Insert("ThisIsMasterNode", 		ExchangePlans.MasterNode() = Undefined);
	// End CheckLegalityOfUpdatesObtaining
	
	// GetFilesFromInternet
	Parameters.Insert("ProxyServerSettings", 	GetFilesFromInternet.GetProxyServerSetting());
	// End GetFilesFromInternet
	
	// FileOperations
	Parameters.Insert("FileOperationsPersonalSettings", 
		New FixedStructure(FileOperations.GetFileOperationsPersonalSettingsServer()));
	// End FileOperations
	
	// ScheduledJobs
	If CommonUse.FileInformationBase() Then
		Parameters.Insert("OpenParametersOfScheduledJobsProcessingSession", 
			New FixedStructure(ScheduledJobsServer.OpenParametersOfScheduledJobsProcessingSession(True)));
	EndIf;
	// End ScheduledJobs
	
	// For assigning parameters of system initialization following templated can be used:
	//
	// Parameters.Insert(<ParameterName>, <parameter value get code>);
	//
	
	Return New FixedStructure(Parameters);
	
EndFunction

// Returns flag, indicating if configuration is basic.
//
// Implementation example:
//  If configurations are issued in pairs, then in the name of basic version
//  additional word "Basic" may be included. Then logics
//  of the determination of basic version is following:
//
//	Return Find(Upper(Metadata.Name), "BASIC") > 0;
//
// Value returned:
//   Boolean   - True, if configuration is - basic.
//
Function ThisIsBasicConfigurationVersion() Export

	Return Find(Upper(Metadata.Name), "BASIC") > 0;

EndFunction
