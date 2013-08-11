////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a flag that shows whether the configuration is a base one.
//
// Example:
// If configurations are released in pairs, the base version name
// may contain an additional word "Base". Then the function
// determines the base version as follows:
//
//	Return Find(Upper(Metadata.Name), "BASE") > 0;
//
// Returns:
// Boolean - True if the configuration is a base one.
//
Function IsBaseConfigurationVersion() Export

	Return Find(Upper(Metadata.Name), "BASE") > 0;

EndFunction

// Returns a map of session parameter names to their initialization handlers.
//
Function SubsystemsLibrarySessionParameterInitHandlers() Export
	
	// Use the following format to set session parameter handlers:
	// Handlers.Insert("<SessionParameterName>|<SessionParameterNamePrefix*>", "Handler");
	//
	// Note: The * character in the end of a session parameter name means
	// that the same handler will be called to initialize all session parameters
	// whose names begin with SessionParameterNamePrefix.
	//
	
	Handlers = New Map;
	
	// StandardSubsystems.DataExchange
	Handlers.Insert("ORMCachedValueRefreshDate", "DataExchangeServer.SessionParametersSetting");
	Handlers.Insert("DataExchangeEnabled", "DataExchangeServer.SessionParametersSetting");
	Handlers.Insert("UsedExchangePlans", "DataExchangeServer.SessionParametersSetting");
	Handlers.Insert("SelectiveObjectChangeRecordRules", "DataExchangeServer.SessionParametersSetting");
	Handlers.Insert("ObjectChangeRecordRules", "DataExchangeServer.SessionParametersSetting");
	// End StandardSubsystems.DataExchange
	
	// StandardSubsystems.AccessManagement
	Handlers.Insert("RestrictAccessByType*", "AccessManagement.SessionParametersSetting");
	Handlers.Insert("AccessTypes*", "AccessManagement.SessionParametersSetting");
	Handlers.Insert("AddSubordinatesAccessToHeads", "AccessManagement.SessionParametersSetting");
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.Users
	Handlers.Insert("CurrentUser", "Users.SessionParametersSetting");
	Handlers.Insert("CurrentExternalUser", "Users.SessionParametersSetting");
	// End StandardSubsystems.Users
	
	// StandardSubsystems.PerformanceEstimation
	Handlers.Insert("CurrentTimeMeasurement", "PerformanceEstimationServerCall.SessionParametersSetting");
	// End StandardSubsystems.PerformanceEstimation
	
	Return Handlers;
	
EndFunction

// Returns the list of metadata object names. These objects can contain references
// that do not affect application business logic.
//
// Returns:
// Array - Array of String, for example, "InformationRegister.ObjectVersions".
//
Function RefSearchExclusions() Export
	
	Array = New Array;
	
	// StandardSubsystems.Users
	Array.Add(Metadata.InformationRegisters.UserGroupContent.FullName());
	// End StandardSubsystems.Users
	
	Return Array;
	
EndFunction

// Generates a name list of shared information registers that store separated data.
// 
// Parameters:
// SharedRegisters - Array of String.

Procedure GetSharedInformationRegistersWithSeparatedData(Val SharedRegisters) Export
	
	// StandardSubsystems.InfoBaseVersionUpdate
	SharedRegisters.Add("SubsystemVersions");
	// End StandardSubsystems.InfoBaseVersionUpdate
	
	// StandardSubsystems.ServiceMode.JobQueue
	SharedRegisters.Add("JobQueue");
	// End StandardSubsystems.ServiceMode.JobQueue
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SharedRegisters.Add("SuppliedDataRelations");
	SharedRegisters.Add("DataAreasForSuppliedDataUpdate");
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Generates a list of data types that cannot be copied between areas.
// 
// Parameters:
// SharedRegisters - Array of Type.
//
Procedure GetNonImportableToDataAreaTypes(Val Types) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	For Each MapRow In CommonUse.GetSeparatedAndSharedDataMapTable() Do
		TypeMetadata = Metadata.FindByType(MapRow.SharedDataType);
		If Catalogs.AllRefsType().ContainsType(MapRow.SharedDataType) Then
			Types.Add(Type("CatalogObject." + TypeMetadata.Name));
		Else // Information register
			Types.Add(Type("InformationRegisterRecordSet." + TypeMetadata.Name));
		EndIf;
	EndDo;
	
	Types.Add(Type("InformationRegisterRecordSet.SuppliedDataRelations"));
	Types.Add(Type("InformationRegisterRecordSet.DataAreasForSuppliedDataUpdate"));
	// End StandardSubsystems.ServiceMode.SuppliedData
	
	// StandardSubsystems.Users
	Types.Add(Type("CatalogObject.ExternalUsers"));
	// End StandardSubsystems.Users
	
	// StandardSubsystems.ServiceMode.JobQueue
	Types.Add(Type("InformationRegisterRecordSet.JobQueue"));
	// End StandardSubsystems.ServiceMode.JobQueue
	
EndProcedure

// Generates a list of data types that should not be exchanged between
// infobases.
// 
// Parameters:
// SharedRegisters - Array of Type.
//
Procedure GetNonExportableFromInfoBaseTypes(Val Types) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	Types.Add(Type("InformationRegisterRecordSet.SuppliedDataRelations"));
	Types.Add(Type("InformationRegisterRecordSet.DataAreasForSuppliedDataUpdate"));
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Is called on data area deletion.
// All data that cannot be deleted in the standard way must
// be deleted in this procedure.
//
// Parameters:
// DataArea - Separator value type - separator value of the data are being deleted.
//
Procedure OnDeleteDataArea(Val DataArea) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	Deletion = New ObjectDeletion(SuppliedDataCached.GetDataAreaNode(DataArea));
	Deletion.DataExchange.Load = True;
	Deletion.Write();
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Generates an infobase parameter list.
//
// Parameters:
// ParameterTable - Table value - parameter description table.
// For column content details, see ServiceMode.GetInfoBaseParameterTable()
//
Procedure GetInfoBaseParameterTable(Val ParameterTable) Export
	
	// StandardSubsystems.ServiceMode
	If CommonUseCached.IsSeparatedConfiguration() Then
		ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "UseSeparationByDataAreas");
		
		ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "InfoBaseUsageMode");
		
		ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "CopyDataAreasFromPrototype");
	EndIf;
	
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "InternalServiceManagerURL");
	
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserName");
	
	ParameterRow = ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserPassword");
	ParameterRow.ReadProhibition = True;
	
	// For compatibility with earlier versions
	ParameterRow = ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "InternalServiceManagerURL");
	ParameterRow.Name = "ServiceURL";
	
	ParameterRow = ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserName");
	ParameterRow.Name = "AuxiliaryServiceUserName";
	
	ParameterRow = ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserPassword");
	ParameterRow.Name = "AuxiliaryServiceUserPassword";
	ParameterRow.ReadProhibition = True;
	// End For compatibility with its earlier versions
	
	ParameterRow = ParameterTable.Add();
	ParameterRow.Name = "ConfigurationVersion";
	ParameterRow.Details = NStr("en = 'Configuration version'");
	ParameterRow.WriteProhibition = True;
	ParameterRow.Type = New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable));
	
	// StandardSubsystems.ServiceMode.SuppliedData
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "SuppliedDataServiceAddress");
	
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "AuxiliarySuppliedDataServiceUserName");
	
	ParameterRow = ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, 
		"AuxiliarySuppliedDataServiceUserPassword");
	ParameterRow.ReadProhibition = True;
	// End StandardSubsystems.ServiceMode.SuppliedData
	
	// StandardSubsystems.ScheduledJobs
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "MaxActiveBackgroundJobExecutionTime");
	
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "MaxActiveBackgroundJobCount");
	// End StandardSubsystems.ScheduledJobs
	
	// StandardSubsystems.UserSessions
	ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "LockMessageOnConfigurationUpdate");
	// End StandardSubsystems.UserSessions
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	// (For compatibility with earlier versions)
	ParameterRow = ServiceMode.AddConstantToInfoBaseParameterTable(ParameterTable, "DataExchangeWebServiceURL");
	ParameterRow.Name = "ExchangeServiceURL";
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// Is called before the attempt to get infobase 
// parameter values from constants with the same names.
//
// Parameters:
// ParameterNames - String array - names of parameters whose values you want to get.
// Parameter names that the procedure gets must be deleted from the structure.
// ParameterValues - Structure - parameter values.
//
Procedure OnReceiveInfoBaseParameterValues(Val ParameterNames, Val ParameterValues) Export
	
	// StandardSubsystems.ServiceMode
	
	// ConfigurationVersion
	Index = ParameterNames.Find("ConfigurationVersion");
	If Index <> Undefined Then
		ParameterValues.Insert("ConfigurationVersion", Metadata.Version);
		ParameterNames.Delete(Index);
	EndIf;
	
	// ServiceURL
	Index = ParameterNames.Find("ServiceURL");
	If Index <> Undefined Then
		ParameterValues.Insert("ServiceURL", Constants.InternalServiceManagerURL.Get());
		ParameterNames.Delete(Index);
	EndIf;
	
	// AuxiliaryServiceUserName
	Index = ParameterNames.Find("AuxiliaryServiceUserName");
	If Index <> Undefined Then
		ParameterValues.Insert("AuxiliaryServiceUserName", Constants.AuxiliaryServiceManagerUserName.Get());
		ParameterNames.Delete(Index);
	EndIf;
	
	// End StandardSubsystems.ServiceMode
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	// ExchangeServiceURL
	Index = ParameterNames.Find("ExchangeServiceURL");
	If Index <> Undefined Then
		ParameterValues.Insert("ExchangeServiceURL", Constants.DataExchangeWebServiceURL.Get());
		ParameterNames.Delete(Index);
	EndIf;
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
EndProcedure

// Is called before the attempt to write infobase 
// parameter values to constants with the same names.
//
// Parameters:
// ParameterValues - structure - parameter values.
// When this procedure sets a parameter value, the corresponding KeyAndValue pair must be deleted from the structure.
//
Procedure OnSetInfoBaseParameterValues(Val ParameterValues) Export
	
	// StandardSubsystems.ServiceMode
	
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
	
	// End StandardSubsystems.ServiceMode
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	If ParameterValues.Property("ExchangeServiceURL") Then
		Constants.DataExchangeWebServiceURL.Set(ParameterValues.ExchangeServiceURL);
		ParameterValues.Delete("ExchangeServiceURL");
	EndIf;
	
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
EndProcedure

// IS called on enabling separation by data areas.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	// StandardSubsystems.ServiceMode.JobQueue
	JobQueue.UpdateSeparatedScheduledJobs();
	
	If Constants.MaxActiveBackgroundJobExecutionTime.Get() = 0 Then
		Constants.MaxActiveBackgroundJobExecutionTime.Set(600);
	EndIf;
	
	If Constants.MaxActiveBackgroundJobCount.Get() = 0 Then
		Constants.MaxActiveBackgroundJobCount.Set(1);
	EndIf;
	// End StandardSubsystems.ServiceMode.JobQueue
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.DeleteWorldCountriesCatalogItems();
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.ServiceMode
	ServiceModeOverridable.OnEnableSeparationByDataAreas();
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// Is called after the end of data import from a local infobase version
// to service data area or vice versa.
//
Procedure AfterDataImportFromOtherMode() Export
		
EndProcedure

// Locks the current area by starting a transaction and setting an exclusive lock
// to all separated metadata object areas.
//
Procedure LockCurrentDataArea() Export
	
	// StandardSubsystems.ServiceMode
	BeginTransaction();
	ServiceMode.LockCurrentDataArea(True);
	
	Return;
	// End StandardSubsystems.ServiceMode
	
	Raise(NStr("en = 'Service mode subsystem is not available'"));
	
EndProcedure

// Unlocks the current area by committing (or, in case of errors, rolling back) a transaction.
//
Procedure UnlockCurrentDataArea() Export
	
	// StandardSubsystems.ServiceMode

	If IsBlankString(ErrorInfo().Description) Then
		CommitTransaction();
	Else
		RollbackTransaction();
	EndIf;
	
	Return;
	// End StandardSubsystems.ServiceMode
	
	Raise(NStr("en = 'Service mode subsystem is not available'"));
	
EndProcedure

// Additional actions to be executed at the session separation.
//
Procedure DataAreaOnChange() Export
	
	// StandardSubsystems.ServiceMode
	ServiceMode.ClearAllSessionParametersExceptSeparators();
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// Sets the session separation.
//
// Parameters:
// Use - Boolean - flag that shows whether the DataArea separator is used in a session;
// DataArea - Number - DataArea separator value.
//
Procedure SetSessionSeparation(Val Use, Val DataArea = Undefined) Export
	
	// StandardSubsystems.ServiceMode
	ServiceMode.SetSessionSeparation(Use, DataArea);
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// Returns the current data area separator value.
// If the value has not been set, an exception is raised.
// 
// Returns: 
// Separator value type.
// Current data area separator value.
// 
Function SessionSeparatorValue() Export
	
	// StandardSubsystems.ServiceMode
	Return ServiceMode.SessionSeparatorValue();
	// End StandardSubsystems.ServiceMode
	
	Raise(NStr("en = 'Service mode subsystem is not available'"));
	
EndFunction

// Returns a flag that shows whether the DataArea separator is used for the current session.
// 
// Returns: 
// Boolean - True if the separator is used, otherwise is False.
//
Function UseSessionSeparator() Export
	
	// StandardSubsystems.ServiceMode
	Return ServiceMode.UseSessionSeparator();
	// End StandardSubsystems.ServiceMode
	
	Raise(NStr("en = 'Service mode subsystem is not available'"));
	
EndFunction

// The overridable handler that is called before writing a user.
//
// Parameters:
// UserObject - CatalogObject.Users - user being written.
//
Procedure BeforeWriteUser(UserObject) Export
	
	// StandardSubsystems.ServiceMode
	UsersServiceMode.BeforeWriteUser(UserObject);
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// The overridable handler that is called on writing a user.
//
// Parameters:
// UserObject - CatalogObject.Users - user being written;
// UserDetails - XDTO object: {"http://1c-dn.com/SaaS/1.0/XMLSchema/ManagementApplication"}UserInfo -
// service manager user details; 
// UserExists - Boolean - flag that shows whether the user existed at start of the writing transaction;
// AccessAllowed - Boolean - flag that shows whether access to the infobase is allowed after writing the user;
// CreateServiceUser - Boolean - flag that shows whether a new service user will be created.
//
Procedure UserOnWrite(UserObject, UserDetails, UserExists, AccessAllowed, CreateServiceUser) Export
	
	// StandardSubsystems.ServiceMode
	UsersServiceMode.UserOnWrite(UserObject, UserDetails, UserExists, 
		AccessAllowed, CreateServiceUser);
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// The overridable handler that is called on getting the Users catalog form. 
//
// Parameters:
// See the FormGetProcessing platform handler for details.
//
Procedure GetUserFormProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	// StandardSubsystems.ServiceMode
	UsersServiceMode.GetUserFormProcessing(FormType, Parameters, SelectedForm, 
		AdditionalInformation, StandardProcessing);
	// End StandardSubsystems.ServiceMode
	
EndProcedure

// The overridable handler that is called on writing an additional data processor.
//
// Parameters:
// ScheduledJob - ScheduledJob - scheduled job being written.
// Use - Boolean - flag that shows whether the job is enabled.

Procedure OnWriteAdditionalHandlerJob(ScheduledJob, Use) Export
	
EndProcedure

// Enables or disables the scheduled job that fills access management data.
//
// Parameters:
// Use - Boolean - True if the job is enabled, otherwise is False.
//
Procedure SetUseFillAccessManagementDataScheduledJob(Val Use) Export
	
EndProcedure

// Adds client startup parameters in service mode.
//
// Parameters:
// Parameters - Structure - parameter structure.
//
Procedure AddClientParametersServiceMode(Val Parameters) Export
	
	// StandardSubsystems.ServiceMode
	ServiceMode.AddClientParametersServiceMode(Parameters);
	// End StandardSubsystems.ServiceMode
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Base functionality
//

// Returns a library update handler list.
//
// The list only contains library update handlers that are used in the current
// configuration, sorted alphabetically. 
// The configuration update handlers must be listed in the 
// InfoBaseUpdateOverridable.UpdateHandlers() function.
//
// Returns:
// ValueTable - See the
// InfoBaseUpdate.NewUpdateHandlerTable() function for details.

Function StandardSubsystemsUpdateHandlers() Export
	
	Handlers = InfoBaseUpdate.NewUpdateHandlerTable();
	
	// Attaching library update handlers
	
	// StandardSubsystems.BaseFunctionality
	StandardSubsystemsServer.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.BaseFunctionality
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.DataExchange
	DataExchangeServer.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.DataExchange
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	DataExchangeServiceMode.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	// StandardSubsystems.ServiceMode.MessageExchange
	MessageExchangeInternal.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.MessageExchange
	
	// StandardSubsystems.ServiceMode.InfoBaseVersionUpdateServiceMode
	InfobaseUpdateServiceMode.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.InfoBaseVersionUpdateServiceMode
	

	// StandardSubsystems.GetFilesFromInternet
	GetFilesFromInternet.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.GetFilesFromInternet
	
	// StandardSubsystems.Users
	Users.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.Users
	
	// StandardSubsystems.ServiceMode.UsersServiceMode
	UsersServiceMode.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.UsersServiceMode
	
	// StandardSubsystems.EmailOperations
	Email.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.EmailOperations
	
	// StandardSubsystems.ScheduledJobs
	ScheduledJobsServer.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ScheduledJobs
	
	// StandardSubsystems.JobQueue
	JobQueue.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.JobQueue
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.RegisterUpdateHandlers(Handlers);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
	Return Handlers;
	
EndFunction

// Checks whether an infobase user with a specified ID is
// in the shared user list.
//
// Parameters:
// InfoBaseUserID - UUID - infobase user ID.
//
Function IsSharedInfoBaseUser(Val InfoBaseUserID) Export
	
	// StandardSubsystems.ServiceMode.UsersServiceMode
	Return UsersServiceMode.IsSharedInfoBaseUser(InfoBaseUserID);
	// End StandardSubsystems.ServiceMode.UsersServiceMode
	Return False;
	
EndFunction

// In the service mode, adds the current user to the list of shared users,
// if separators are not enabled for this user.
//
Procedure RegisterSharedUser() Export
	
	// StandardSubsystems.ServiceMode.UsersServiceMode 
	UsersServiceMode.RegisterSharedUser();
	// End StandardSubsystems.ServiceMode.UsersServiceMode
	
EndProcedure

// Returns a flag that shows whether changing users is allowed.
//
// Returns:
// Boolean - True if changing users is allowed, otherwise is False.
//
Function CanChangeUsers() Export
	
	// StandardSubsystems.ServiceMode.UsersServiceMode
	Return UsersServiceMode.CanChangeUsers();
	// End StandardSubsystems.ServiceMode.UsersServiceMode
	Return True;
	
EndFunction

// Returns a flag that shows whether the GetFilesFromInternet subsystem is available.
//
// Returns - Boolean - 
// True if the subsystem is available, any other value if the subsystem 
// is not available.
//
Procedure CanGetFilesFromInternet(ReturnValue) Export
	
	// StandardSubsystems.GetFilesFromInternet
	ReturnValue = True;
	// End StandardSubsystems.GetFilesFromInternet
	
EndProcedure

// Gets a file from the internet via HTTP(S) or FTP and saves it to a temporary file.
//
// Parameters:
// URL - String - file URL in the following format:
// [Protocol://]<Server>/<A path to the file on the HTTP or FTP server>;
// ReceivingParameters - structure with the following properties:
// PathForSaving - String - path on the 1C:Enterprise server (including a file name) for saving the downloaded file;
// User - String - account used for connecting to the HTTP or FTP server;
// Password - String - password used for connecting to the HTTP or FTP server;
// Port - Number - port used for connecting to the HTTP or FTP server; 
// SecureConnection - Boolean - in case of HTTP this flag shows
// whether a secure HTTPS connection is used;
// PassiveConnection - Boolean - in case of FTP this flag shows 
// whether the connection mode is passive or active;
// ReturnValue - (output parameter), a structure with the following properties:
// State - Boolean - this key is always present in the structure, it can have the following values:
// True - function execution completed successfully;
// False - function execution failed;
// Path - String - path to the file on the 1C:Enterprise server. This key is used only 
// if State is True.
// ErrorMessage - String - error message if State is False.
//
Procedure DownloadFileAtServer(Val Address, Val ReceivingParameters, ReturnValue) Export
	
	// StandardSubsystems.GetFilesFromInternet
	ReturnValue = GetFilesFromInternet.DownloadFileAtServer(Address, ReceivingParameters);
	// End StandardSubsystems.GetFilesFromInternet
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Supplied data
//

// Creates a table of separated and shared data maps 
//
// Returns:
// ValueTable - data type maps
//
Function SeparatedAndSharedDataMapTable() Export
	
	ValueTable = New ValueTable;
	
	// StandardSubsystems.ServiceMode.SuppliedData
	ValueTable.Columns.Add("SuppliedDataKind");
	ValueTable.Columns.Add("SharedDataType");
	ValueTable.Columns.Add("SeparatedDataType");
	ValueTable.Columns.Add("CopyToAllDataAreas");
	
	GetSeparatedAndSharedDataMapTable(ValueTable);
	SuppliedDataOverridable.GetSeparatedAndSharedDataMapTable(ValueTable);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
	Return ValueTable;
	
EndFunction

// Fills a table of separated and shared data maps
//
// Parameters:
// MapTable - ValueTable - table to be 
// filled with maps
//
Procedure GetSeparatedAndSharedDataMapTable(MapTable) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
		
	// StandardSubsystems.ContactInformation
	NewRow = MapTable.Add();
	NewRow.SuppliedDataKind = Enums.SuppliedDataTypes.Catalog_WorldCountries;
	NewRow.SharedDataType = Type("CatalogRef.WorldCountries");
	NewRow.CopyToAllDataAreas = False;
	// End StandardSubsystems.ContactInformation
	
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Overrides actions on filling a data area with supplied data
//
// Parameters:
// SharedDataRef - Ref - supplied data reference
//
Procedure OnFillDataAreaWithSuppliedData(SharedDataRef) Export
		
EndProcedure

// Updates a separated record set with data from a shared one. 
//
// Parameters:
// Prototype - InformationRegisterRecordSet - shared record set that will be a prototype
// to a separated one;
// MDObject - MetadataObject - shared information register metadata;
// Manager - InformationRegisterManager - separated information register manager;
// SourceType - Type - shared register record key type;
// TargetType - Type - separated register record key type;
// TargetObject - InformationRegisterRecordSet - if standard update processing is 
// overridden in this procedure, the record set that is not written must be assigned to this parameter;
// StandardProcessing - Boolean - if standard update processing is 
// overridden in this procedure, False must be recorded to this parameter.
//
Procedure BeforeCopyRecordSetFromPrototype(Prototype, ObjectMetadata, Manager, SourceType, 
	TargetType, TargetObject, StandardProcessing) Export
	
EndProcedure
	
// Updates a separated object with data from a shared one.
//
// Parameters:
// Prototype - CatalogObject - shared object that will be a prototype
// to a separated one;
// MDObject - MetadataObject - shared catalog metadata;
// Manager - CatalogManager - separated catalog manager;
// SourceType - Type - shared catalog reference type;
// TargetType - Type - separated catalog reference type;
// TargetObject - CatalogObject - if standard update processing was 
// overridden in this procedure, the object that is not written must be recorded to this parameter;
// StandardProcessing - Boolean - if standard update processing is 
// overridden in this procedure, False must be recorded to this parameter.
//
Procedure BeforeCopyObjectFromPrototype(Prototype, SourceMetadata, Manager, SourceType, 
	TargetType, TargetObject, StandardProcessing) Export
	
EndProcedure

// Copies items of a shared catalog to a new data area
//
// Parameters:
// CatalogCodeList - Array - array of catalog codes
// SourceType - type - type of a shared catalog,
// that is used as a sourse.
//
Procedure CopySuppliedDataCatalogItems(CatalogCodeList, SourceType) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.CopyCatalogItems(CatalogCodeList, SourceType);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Reads a current state of a separated object and updates the form accordingly.
//
Procedure ReadSuppliedDataManualEditFlag(Val Form) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.ReadManualEditFlag(Form);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Writes a state of a separated object.
//
Procedure WriteSuppliedDataManualChangeFlag(Val Form) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.WriteManualChangeFlag(Form);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Copies shared object data to a separated object, and changes 
// a separated object state.
//
Procedure RestoreItemFromSharedData(Val Form) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.RestoreItemFromSharedData(Form);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Creates a node for a data area with the specified
// separator value.
//
// Parameters:
// DataArea - Number - separator value of a data area.
//
Procedure CreateDataAreaNode(Val DataArea) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.CreateDataAreaNode(DataArea);
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Job queue
//

// Fills a name list of shared scheduled job that
// will run in a separated mode.
//
// Parameters:
// SeparatedScheduledJobList - Array - Array of shared scheduled job names 
// that will be executed by Scheduled Jobs subsystem
// in data areas.
//
Procedure FillSeparatedScheduledJobList(SeparatedScheduledJobList) Export

	// StandardSubsystems.AccessManagement
	SeparatedScheduledJobList.Add("DataFillingForAccessRestrictions");
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	SeparatedScheduledJobList.Add("StartingAdditionalDataProcessors");
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.FileFunctions
	SeparatedScheduledJobList.Add("TextExtraction");
	// End StandardSubsystems.FileFunctions
	
	// StandardSubsystems.BusinessProcessesAndTasks
	SeparatedScheduledJobList.Add("TaskMonitoring");
	SeparatedScheduledJobList.Add("NewPerformerTaskNotifications");
	// End StandardSubsystems.BusinessProcessesAndTasks
	
	// StandardSubsystems.TotalAndAggregateManagement
	SeparatedScheduledJobList.Add("UpdateAggregates");
	SeparatedScheduledJobList.Add("RebuildAggregates");
	SeparatedScheduledJobList.Add("TotalsPeriodSetup");
	// End StandardSubsystems.TotalAndAggregateManagement
	
	// StandardSubsystems.EditProhibitionDates 
	SeparatedScheduledJobList.Add("CurrentRelativeEditProhibitionDateValueRecalculation");
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Interactions
	SeparatedScheduledJobList.Add("SendReceiveEmails");
	// End StandardSubsystems.Interactions
	
EndProcedure

// Generates a scheduled job table
// with a usage flag.
//
// Parameters:
// UsageTable - ValueTable - table to be filled
// with scheduled jobs and usage flags
//
Procedure FillScheduledJobUsageTable(UsageTable) Export
	
	// StandardSubsystems.DataExchange
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "DataExchangeExecution";
	NewRow.Use = False;
	// End StandardSubsystems.DataExchange
	
EndProcedure

// Sets a text presentation of a subject.
//
// Parameters
// SubjectRef – AnyRef – object of reference type.
// Presentation	- String - text presentation.
//
Procedure SetSubjectPresentation(SubjectRef, Presentation) Export
		
EndProcedure

// Generates a list of available methods for processing the job queue 
//
// Parameters:
// AllowedMethods - Array - names of methods that can be called
// for processing the job queue
// 
Procedure GetJobQueueAllowedMethods(Val AllowedMethods) Export
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	AllowedMethods.Add("DataExchangeServiceMode.SetDataChangeFlag");
	AllowedMethods.Add("DataExchangeServiceMode.ExecuteDataExchange");
	AllowedMethods.Add("DataExchangeServiceMode.ExecuteDataExchangeScenarioActionInFirstInfoBase");
	AllowedMethods.Add("DataExchangeServiceMode.ExecuteDataExchangeScenarioActionInSecondInfoBase");
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	// StandardSubsystems.ServiceMode.InfoBaseVersionUpdateServiceMode
	AllowedMethods.Add("InfobaseUpdateServiceMode.UpdateCurrentDataArea");
	// End StandardSubsystems.ServiceMode.InfoBaseVersionUpdateServiceMode
	
	// StandardSubsystems.ServiceMode
	AllowedMethods.Add("ServiceMode.PrepareDataAreaToUse");
	// End StandardSubsystems.ServiceMode
	
	// StandardSubsystems.ServiceMode
	AllowedMethods.Add("ServiceMode.ClearDataArea");
	// End StandardSubsystems.ServiceMode
	
	// StandardSubsystems.ServiceMode.SuppliedData
	AllowedMethods.Add("SuppliedData.UpdateSuppliedData");
	// End StandardSubsystems.ServiceMode.SuppliedData
	
	// StandardSubsystems.ServiceMode.AccessManagementServiceMode
	AllowedMethods.Add("AccessManagement.DataFillingForAccessRestrictionsJobHandler");
	// End StandardSubsystems.ServiceMode.AccessManagementServiceMode
	
EndProcedure

// Overrides an array of object attributes that can have reminder dates.
// For example, you can hide attributes whose dates contain service data, or 
// attributes whose dates make no sense as reminders, such as a document date or a task date.
// 
// Parameters
// Source	 - Any reference - reference to object, for which an array of attributes with dates is generated.
// AttributeArray - Array - array of attribute names (as they are named in metadata), that contain dates
//
Procedure OnFillSourceAttributeListWithReminderDates(Source, AttributeArray) Export
		
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// User session termination
//

// StandardSubsystems.UserSessions 

// It is recommended that you call this procedure at the 1C:Enterprise server on session close.
//
// Parameters
// SessionNumber - Number - session number.
// Result - Boolean – result of closing the session.
// ErrorMessage - String - error message text is returned to this parameter in case of function execution failure.
// StandardProcessing - Boolean - pass False to this parameter to disable standard processing of session closing.
//
Procedure OnCloseSession(SessionNumber, Result, ErrorMessage, StandardProcessing) Export
	
	// StandardSubsystems.ServiceMode.BasicFunctionalityServiceMode
	If InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
		Return;
	EndIf;	
		
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;	
	
	// Passing control to the service agent if the server is not running Windows

	StandardProcessing = False;
	SetPrivilegedMode(True);
	Parameters = InfoBaseConnectionsCached.GetInfoBaseAdministrationParameters();
	Try
		Result = ServiceMode.TerminateSessionsByListViaServiceAgent(SessionNumber, Parameters);	
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Result = False;
	EndTry;
	// End StandardSubsystems.ServiceMode.BasicFunctionalityServiceMode
	
EndProcedure

// End StandardSubsystems.UserSessions 

// StandardSubsystems.CalendarSchedules 

/////////////////////////////////////////////////////////////////////////////////
// Calendar schedules 
//

// Performs necessary actions before writing a BusinessCalendarData 
// information register record set.
// In particular, the procedure generates in the passed Query object a TT_OldKeys 
// temporary table with record set data in the passed Query object. 
//
// Parameters:
// Query - query object; the register data table is generated in a temporary table manager of this object. 
// RecordSet - information register record set
//
Procedure BusinessCalendarDataBeforeWriteRecordSet(Cancel, Replacing, RecordSet, Query) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.GenerateRecordSetTempDataTable(Query, RecordSet, "BusinessCalendar, Date, Year"); 
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// Performs necessary actions on writing a BusinessCalendarData 
// information register data set.
// In particular, the procedure records changes of register record set data 
// in the "Supplied data" exchange plan.
//
// Parameters:
// Query - a query object whose temporary table manager includes the register data table that was generated before register data was changed.
// RecordSet - information register record set
//
Procedure BusinessCalendarDataOnWriteRecordSet(Cancel, Replacing, RecordSet, Query) Export
	
	// StandardSubsystems.ServiceMode.SuppliedData
	SuppliedData.RegisterRecordSetDataChanges(Query, RecordSet, "BusinessCalendar", "BusinessCalendar, Date, Year"); 
	// End StandardSubsystems.ServiceMode.SuppliedData
	
EndProcedure

// End StandardSubsystems.CalendarSchedules 


/////////////////////////////////////////////////////////////////////////////////
// Interface versioning

// Fills a structure with arrays of supported versions of all subsystems to be versioned,
// The procedure uses subsystem names as keys.
// It provides functionality of the InterfaceVersioning web service.
// At the embedding stage you have to change the procedure body so that it returns actual version sets (see the following example).
//
// Parameters:
// SupportedVersionStructure - structure with the following parameters: 
//	- Keys = Subsystem names 
//	- Values = Arrays of supported version descriptions.
//
// Example:
//
//	// FileTransferServer
//	VersionArray = New Array;
//	VersionArray.Add("1.0.1.1");	
//	VersionArray.Add("1.0.2.1"); 
//	SupportedVersionStructure.Insert("FileTransferServer", VersionArray);
//	// End FileTransferServer
//
Procedure GetSupportedVersions(Val SupportedVersionStructure) Export
	
	// StandardSubsystems.DataExchange
	VersionArray = New Array;
	VersionArray.Add("2.0.1.6");
	SupportedVersionStructure.Insert("DataExchange", VersionArray);
	// End StandardSubsystems.DataExchange
	
	// StandardSubsystems.ServiceMode.DataExchangeServiceMode
	VersionArray = New Array;
	VersionArray.Add("2.0.1.6");
	SupportedVersionStructure.Insert("DataExchangeServiceMode", VersionArray);
	// End StandardSubsystems.ServiceMode.DataExchangeServiceMode
	
	// StandardSubsystems.ServiceMode.MessageExchange
	VersionArray = New Array;
	VersionArray.Add("2.0.1.6");
	SupportedVersionStructure.Insert("MessageExchange", VersionArray);
	// End StandardSubsystems.ServiceMode.MessageExchange
	
EndProcedure

// Performs additional connection parameter conversions.
//
// Parameters:
// ConnectionParameterStructure - structure with the following parameters:
//	- URL - String - published application address;
//	- UserName - String - service user name;
//	- Password - String - service user password;
// InterfaceName - String.
//
// Example:
// 	// You have to decode a base64 presentation of a password before the connection is established:
//	If ConnectionParameterStructure.Property("Password")
//		And ValueIsFilled(ConnectionParameterStructure.Password) Then
//
// 		ConnectionParameterStructure.password = Base64ToString(ConnectionParameterStructure.password);
//
// EndIf;
//
Procedure ConvertServiceConnectionParameters(Val ConnectionParameterStructure, Val InterfaceName = Undefined) Export
	
	
EndProcedure