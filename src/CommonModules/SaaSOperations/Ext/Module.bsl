///////////////////////////////////////////////////////////////////////////////////
// SaaSOperations.
//
///////////////////////////////////////////////////////////////////////////////////
 
#Region Interface
 
// Returns the name of the common attribute that is a separator of main data.
//
// Returns: String.
//
Function MainDataSeparator() Export
	
	Return Metadata.CommonAttributes.DataAreaMainData.Name;
	
EndFunction
 
// Returns the name of the common attribute that is a separator of auxiliary data.
//
// Returns: String.
//

Function AuxiliaryDataSeparator() Export
	
	Return Metadata.CommonAttributes.DataAreaAuxiliaryData.Name;
	
EndFunction
 
// Clears all session parameters, except related with the DataArea common attribute.
//
Procedure ClearAllSessionParametersExceptSeparators() Export
	
	CommonUse.ClearSessionParameters(, "DataAreaValue,UseDataArea");
	
EndProcedure

// Locks the data area.
// 
// Parameters: 
// CheckNoOtherSessions - Boolean - flag that shows whether existence of other user sessions,
//                        which separator value is equal to the current one must be checked.
//                        If other sessions are found, an exception is raised.
// SeparatedLock        - Boolean - flag that shows whether the separated data lock must be set
//                        instead of the exclusive one.
//
Procedure LockCurrentDataArea(Val CheckNoOtherSessions = False, Val SeparatedLock = False) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Raise(NStr("en = 'A data area can be locked only if data separation is enabled"));
	EndIf;
	
	RecordKey = CreateAuxiliaryDataInformationRegisterRecordKey(


		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), CommonUse.SessionSeparatorValue()));	
		AttemptCount = 5;
	CurrentTry = 0;
	While True Do
		Try
			LockDataForEdit(RecordKey);
			Break;
		Except

			CurrentTry = CurrentTry + 1;
			
			If CurrentTry =  AttemptCount Then
				CommentPattern = NStr("en = 'Cannot lock the data area by reasons of:
					|%1'");
				CommentText = StringFunctionsClientServer.SubstituteParametersInString(CommentPattern, 
					DetailErrorDescription(ErrorInfo()));
				WriteLogEvent(
					NStr("en = 'Data area lock'", CommonUseClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					CommentText);
					
				TextPattern = NStr("en = 'Cannot lock the data area by reasons of:

					|%1'");
				Text = StringFunctionsClientServer.SubstituteParametersInString(TextPattern, 
					BriefErrorDescription(ErrorInfo()));
					
				Raise(Text);
			EndIf;
		EndTry;
	EndDo;
	
	If CheckNoOtherSessions Then
		
		ConflictingSessions = New Array();
		
		For Each Session In GetInfobaseSessions()  Do
			If Session.SessionNumber  = InfobaseSessionNumber() Then
				Continue;
			EndIf;
			
			ClientApplications = New Array;
			ClientApplications.Add(Upper("1CV8"));
			ClientApplications.Add(Upper("1CV8C"));
			ClientApplications.Add(Upper("WebClient"));
			ClientApplications.Add(Upper("COMConnection"));
			ClientApplications.Add(Upper("WSConnection"));
			ClientApplications.Add(Upper("BackgroundJob"));
			If ClientApplications.Find(Upper(Session.ApplicationName)) = Undefined Then
				Continue;
			EndIf;
			
			ConflictingSessions.Add(Session);
			
		EndDo;
		
		If ConflictingSessions.Count() > 0 Then
			
			SessionsText = "";
			For Each ConflictingSession In ConflictingSessions Do
				
				If Not IsBlankString(SessionsText) Then
					SessionsText = SessionsText + ",";
				EndIf;
				
				SessionsText = SessionsText + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 (session %2)'",  CommonUseClientServer.DefaultLanguageCode()),
					ConflictingSession.User.Name,
					Format(ConflictingSession.SessionNumber, "NG=0"));
				
			EndDo;
			
			ErrorMessage =  StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot lock the infobase because other users logged on to the application: %1'",
					CommonUseClientServer.DefaultLanguageCode()),
				SessionsText);
			Raise ErrorMessage;
			
		EndIf;
		
	EndIf;
	
	If Not SeparatedLock Then
		SetExclusiveMode(True);
		Return;
	EndIf;
	
	DataModel = SaaSOperationsCached.GetDataAreaModel();
	
	If SeparatedLock Then
		LockMode = DataLockMode.Shared;
	Else
		LockMode = DataLockMode.Exclusive;
	EndIf;
	
	DataLock = New DataLock;
	
	For Each ModelItem In DataModel Do
		
		MetadataObjectFullName = ModelItem.Key;
		MetadataObjectName = ModelItem.Value;
		
		LockSpace = MetadataObjectFullName;
		
		If IsFullRegisterName(MetadataObjectFullName) Then
			
			LockSets = True;
			If IsFullInformationRegisterName(MetadataObjectFullName) Then
				AreaMetadataObject = Metadata.InformationRegisters.Find(MetadataObjectName.Name);
				If AreaMetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					LockSets = False;
				EndIf;
			EndIf;
			
			If LockSets Then
				LockSpace = LockSpace + ".RecordSet";
			EndIf;
			
		ElsIf IsFullSequenceName(MetadataObjectFullName) Then
			
			LockSpace =  LockSpace + ".Records";
			
		ElsIf IsFullDocumentJournalName(MetadataObjectFullName) Or
				IsFullEnumerationName(MetadataObjectFullName) Or
				IsFullSequenceName(MetadataObjectFullName) Or
				ThisFullScheduledJobName(MetadataObjectFullName) Then
			
			Continue;
			
		EndIf;
		
		LockItem = DataLock.Add(LockSpace);
		LockItem.Mode = LockMode;
		
	EndDo;
	
	DataLock.Lock();
 
EndProcedure
 
// Release the exclusive lock of the current data area
//
Procedure UnlockCurrentDataArea() Export
	
	RecordKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), CommonUse.SessionSeparatorValue()));
		
	UnlockDataForEdit(RecordKey);
	
	SetExclusiveMode(False);
	
EndProcedure
 
// Checks whether the data area is locked.
//
// Parameters:
//  DataArea - Number - separator value of the data area whose lock state must be checked.
//
// Returns:
//  Boolean - True if data area is locked, False otherwise.
//

Function DataAreaLocked(Val DataArea) Export
	
	RecordKey =  CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), DataArea));
	
	Try
		LockDataForEdit(RecordKey);
	Except
		Return True;
	EndTry;
	
	UnlockDataForEdit(RecordKey);
	
	Return False;
	
EndFunction
 
// Prepares the data area for use. Starts the infobase update procedures. If necessary, fills
// the infobase with demo data. Sets a new state in the DataAreas register.
// 
// Parameters: 
//  DataArea - Separator value type - separator value of data area to be prepared.
//
Procedure PrepareDataAreaToUse(Val DataArea, Val ExportFileID, Val Option = Undefined) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), DataArea));
	LockDataForEdit(AreaKey);
	
	Try
		RecordManager = GetDataAreaRecordManager(DataArea, Enums.DataAreaStatuses.New);
		
		UsersInternal.AuthenticateCurrentUser();
		
		ErrorMessage = "";
		If Not ValueIsFilled(Option) Then
			
			PreparationResult = PrepareDataAreaForUseFromExport(DataArea, ExportFileID, 
				ErrorMessage);
			
		Else
			
			PreparationResult = PrepareDataAreaForUseFromPrototype(DataArea, ExportFileID, 
				Option, ErrorMessage);
				
		EndIf;
		
		ChangeAreaStatusAndInformManager(RecordManager,  PreparationResult, ErrorMessage);

	Except
		UnlockDataForEdit(AreaKey);
		Raise;
	EndTry;
	
	UnlockDataForEdit(AreaKey);

EndProcedure
 
// Copies area data into another area.
// 
// Parameters:
//  SourceArea - Separator value type - value of the source data area separator.
//  TargetArea - Separator value type - value of the target data area separator.
// 
Procedure CopyAreaData(Val SourceArea, Val TargetArea) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, SourceArea);
	
	ExportFileName = Undefined;
	
	If Not CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.DataAreaExportImport") Then
		
		RaiseNoCTLSubsystemException("CloudTechnology.SaaSOperations.DataAreaExportImport");
		
	EndIf;
	
	DataAreaExportImportModule = CommonUseClientServer.CommonModule("DataAreaExportImport");
	
	BeginTransaction();
	
	Try
		LockCurrentDataArea(, True);
		ExportFileName = DataAreaExportImportModule.ExportCurrentDataAreaToArchive();
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data area copying'", CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		If ExportFileName <> Undefined Then
			Try
				DeleteFiles(ExportFileName);
			Except
			EndTry;
		EndIf;
		Raise;
	EndTry;
	
	CommonUse.SetSessionSeparation(, TargetArea);
	
	Try
		CommonUse.LockInfobase();
		DataAreaExportImportModule.ImportCurrentDataAreaFromArchive(ExportFileName);
		CommonUse.UnlockInfobase();
	Except
		CommonUse.UnlockInfobase();
		WriteLogEvent(NStr("en = 'Data area copying'", CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			DeleteFiles(ExportFileName);
		Except
		EndTry;
		Raise;
	EndTry;
	
	Try
		DeleteFiles(ExportFileName);
	Except
	EndTry;
	
EndProcedure
 
// Deletes all data from the area except the predefined one. Sets the Deleted status for the
// data area. Sends the status change message to the Service manager. Once the actions have
// been performed, the data area become unusable.
//
// If all data must be deleted without changing the data area status and the data area must 
// stay usable, use the ClearAreaData() procedure instead.
//
// Parameters: 
//  DataArea    - Number(7,0) - separator of the data area to be cleared. When the procedure is
//                called, the data separation must already be switched to this area.
//  DeleteUsers - Boolean - flag that shows whether user data must be deleted from the data
//                area.
//
Procedure ClearDataArea(Val DataArea, Val DeleteUsers = True)  Export
	
	If Not Users.InfobaseUserWithFullAccess(, True)  Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), DataArea));
	LockDataForEdit(AreaKey);
	
	Try
		
		RecordManager = GetDataAreaRecordManager(DataArea, Enums.DataAreaStatuses.ToDelete);
		
		EventHandlers = CommonUse.InternalEventHandlers(
			"StandardSubsystems.SaaSOperations\DataAreaOnDelete");
		
		For Each Handler In EventHandlers Do
			Handler.Module.DataAreaOnDelete(DataArea);
		EndDo;
		
		SaaSOperationsOverridable.DataAreaOnDelete(DataArea);
		
		ClearAreaData(DeleteUsers); // Calling for clearing
		
		ChangeAreaStatusAndInformManager(RecordManager, "AreaDeleted", "");
		
	Except
		UnlockDataForEdit(AreaKey);
		Raise;
	EndTry;
	
	UnlockDataForEdit(AreaKey);
	
EndProcedure
 
// Removes all separated data from the data area (even when the data separation is disabled),
// except the predefined one.
//
// Parameters:
//  DeleteUsers - Boolean - flag that shows whether the infobase users must be deleted.
//
Procedure ClearAreaData(Val DeleteUsers) Export
	
	DataModel = SaaSOperationsCached.GetDataAreaModel();
	
	ClearingExceptions = New Array();
	ClearingExceptions.Add(Metadata.InformationRegisters.DataAreas.FullName());
	
	For Each ModelItem In DataModel Do
		
		MetadataObjectFullName = ModelItem.Key;
		MetadataObjectName = ModelItem.Value;
		
		If ClearingExceptions.Find(MetadataObjectFullName) <> Undefined Then
			Continue;
		EndIf;
		
		If IsFullConstantName(MetadataObjectFullName) Then
			
			AreaMetadataObject = Metadata.Constants.Find(MetadataObjectName.Name);
			ValueManager = Constants[MetadataObjectName.Name].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.Value = AreaMetadataObject.Type.AdjustValue();
			ValueManager.Write();
			
		ElsIf IsFullReferenceTypeObjectName(MetadataObjectFullName) Then
			
			IsExchangePlan = IsFullExchangePlanName(MetadataObjectFullName);
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLData_Table.Ref AS Ref
			|FROM
			|	" + MetadataObjectFullName + " AS _XMLData_Table";
			
			If IsFullCatalogName(MetadataObjectFullName) Or
					IsFullChartOfCharacteristicTypesName(MetadataObjectFullName) Or
					IsFullChartOfAccountsName(MetadataObjectFullName) Or
					IsFullChartOfCalculationTypesName(MetadataObjectFullName) Then
				
				Query.Text = Query.Text + "
				|WHERE 
				|	_XMLData_Table.Predefined = FALSE";
				
			ElsIf IsExchangePlan Then
				
				Query.Text = Query.Text + "
				|WHERE 
				|	_XMLData_Table.Ref <> &ThisNode";
				Query.SetParameter("ThisNode", ExchangePlans[MetadataObjectName.Name].ThisNode());
				
			EndIf;
			
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Delete = New ObjectDeletion(Selection.Ref);
				Delete.DataExchange.Load = True;
				Delete.Write();
			EndDo;
			
		ElsIf IsFullRegisterName(MetadataObjectFullName)
				Or IsFullRecalculationName(MetadataObjectFullName) Then
			
			IsInformationRegister = IsFullInformationRegisterName(MetadataObjectFullName);
			If IsInformationRegister Then
				AreaMetadataObject = Metadata.InformationRegisters.Find(MetadataObjectName.Name);
				IsIndependentInformationRegister = (AreaMetadataObject.WriteMode  = Metadata.ObjectProperties.RegisterWriteMode.Independent);
			Else
				IsIndependentInformationRegister = False;
			EndIf;
			
			Manager = CommonUse.ObjectManagerByFullName(MetadataObjectFullName);
			
			If IsIndependentInformationRegister  Then
				
				RecordSet = Manager.CreateRecordSet();
				RecordSet.DataExchange.Load = True;
				RecordSet.Write();
				
			Else
				
				SelectionParameters = SelectionParameters(MetadataObjectFullName);
				RecorderFieldName = SelectionParameters.RecorderFieldName;
				
				Query = New Query;
				Query.Text =
				"SELECT DISTINCT
				|	_XMLData_Table.Recorder AS Recorder
				|FROM
				|	" +  SelectionParameters.Table + " AS _XMLData_Table";
				
				If RecorderFieldName <> "Recorder" Then
					Query.Text = StrReplace(Query.Text, "Recorder", RecorderFieldName);
				EndIf;
				
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				While Selection.Next() Do
					RecordSet = Manager.CreateRecordSet();
					RecordSet.Filter[RecorderFieldName].Set(Selection[RecorderFieldName]);
					RecordSet.DataExchange.Load = True;
					RecordSet.Write();
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Users
	If DeleteUsers Then
		
		FirstAdministrator = Undefined;
		
		For Each IBUser In InfobaseUsers.GetUsers() Do
			
			If FirstAdministrator = Undefined And Users.InfobaseUserWithFullAccess(IBUser, True, False) Then
				
				// Putting off the deletion of the administrator. Deleting all other users first.
				FirstAdministrator = IBUser;
				
			Else
				
				IBUser.Delete();
				
			EndIf;
			
		EndDo;
		
		If FirstAdministrator <> Undefined Then
			FirstAdministrator.Delete();
		EndIf;
		
	EndIf;
	
	// Settings
	Storages = New Array;
	Storages.Add(ReportsVariantsStorage);
	Storages.Add(FormDataSettingsStorage);
	Storages.Add(CommonSettingsStorage);
	Storages.Add(ReportsUserSettingsStorage);
	Storages.Add(SystemSettingsStorage);
	
	For Each Storage  In Storages Do
		If TypeOf(Storage) <> Type("StandardSettingsStorageManager") Then
			// Settings is deleted when clearing data
			Continue;
		EndIf;
		
		Storage.Delete(Undefined, Undefined, Undefined);
	EndDo;
	
EndProcedure
 
// The procedure of the same name scheduled job.
// Finds all data areas with statuses, required to be processed by the application, and, if 
// necessary, plans a maintenance background job startup.
// 
Procedure DataAreaMaintenance() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	MaxRetryCount = 3;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea,
	|	DataAreas.Status AS Status,
	|	DataAreas.ExportID AS ExportID,
	|	DataAreas.Option AS Option
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.Status IN (VALUE(Enum.DataAreaStatuses.New), VALUE(Enum.DataAreaStatuses.ToDelete))
	|	AND DataAreas.ProcessingError = FALSE
	|
	|ORDER BY
	|	DataArea";
	Result = Query.Execute();
	Selection = Result.Select();
	
	Executing = 0;
	
	While Selection.Next() Do
		
		RecordKey = CreateAuxiliaryDataInformationRegisterRecordKey(
			InformationRegisters.DataAreas,
			New Structure(AuxiliaryDataSeparator(), Selection.DataArea));
		
		Try
			LockDataForEdit(RecordKey);
		Except
			Continue;
		EndTry;
		
		Manager = InformationRegisters.DataAreas.CreateRecordManager();
		Manager.DataAreaAuxiliaryData = Selection.DataArea;
		Manager.Read();
		
		If Manager.Status = Enums.DataAreaStatuses.New Then 
			MethodName = "SaaSOperations.PrepareDataAreaToUse";
		ElsIf Manager.Status = Enums.DataAreaStatuses.ToDelete Then 
			MethodName = "SaaSOperations.ClearDataArea";
		Else
			UnlockDataForEdit(RecordKey);
			Continue;
		EndIf;
		
		If Manager.Repeat < MaxRetryCount Then
		
			JobFilter = New  Structure;
			JobFilter.Insert("MethodName", MethodName);
			JobFilter.Insert("Key"       , "1");
			JobFilter.Insert("DataArea"  , Selection.DataArea);
			Jobs = JobQueue.GetJobs(JobFilter);
			If Jobs.Count() > 0 Then
				UnlockDataForEdit(RecordKey);
				Continue;
			EndIf;
			
			Manager.Repeat = Manager.Repeat + 1;
			
			ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
			FillPropertyValues(ManagerCopy, Manager);
			Manager = ManagerCopy;
			
			Manager.Write();

			MethodParameters = New Array;
			MethodParameters.Add(Selection.DataArea);
			
			If Selection.Status = Enums.DataAreaStatuses.New Then
				
				MethodParameters.Add(Selection.ExportID);
				If ValueIsFilled(Selection.Option) Then
					MethodParameters.Add(Selection.Option);
				EndIf;
			EndIf;
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName",         MethodName);
			JobParameters.Insert("Parameters",         MethodParameters);
			JobParameters.Insert("Key",                "1");
			JobParameters.Insert("DataArea",           Selection.DataArea);
			JobParameters.Insert("ExclusiveExecution", True);
			
			JobQueue.AddJob(JobParameters);
			
			UnlockDataForEdit(RecordKey);
		Else
			
			ChangeAreaStatusAndInformManager(Manager, ?(Manager.Status = Enums.DataAreaStatuses.New,
				"FatalError", "DeletionError"), NStr("en = 'Number of attempts to process the area is up'"));
			
			UnlockDataForEdit(RecordKey);
			
		EndIf;
		
	EndDo;
	
EndProcedure
 
// Returns a web service proxy to synchronize administrative actions in service mode.
// 
// Returns: 
//  WSProxy.
//  Service manager proxy.  
// 
Function GetServiceManagerProxy(Val UserPassword = Undefined) Export
	
	ServiceManagerURL = Constants.InternalServiceManagerURL.Get();
	If Not  ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	ServiceURL = ServiceManagerURL + "/ws/ManageApplication_1_0_3_1?wsdl";
	
	If UserPassword = Undefined Then
		UserName = Constants.AuxiliaryServiceManagerUserName.Get();
		UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();
	Else
		UserName = UserName();
	EndIf;
	
	Proxy = CommonUse.WSProxy(ServiceURL, "http://www.1c.ru/SaaS/ManageApplication/1.0.3.1",
		"ManageApplication_1_0_3_1", , UserName, UserPassword, 20);
		
	Return Proxy;
	
EndFunction
 
// Sets session separation.
//
// Parameters:
// Use      - Boolean - flag that shows whether the DataArea separator is used in the session.
// DataArea - Number  - DataArea separator value.
//
Procedure SetSessionSeparation(Val Use = Undefined, Val DataArea = Undefined) Export
	
	If Not  CommonUseCached.SessionWithoutSeparators() Then
		Raise(NStr("en = 'Changing separation settings is only allowed from sessions started without separation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Use <> Undefined Then
		SessionParameters.UseDataArea = Use;
	EndIf;
	
	If DataArea <> Undefined Then
		SessionParameters.DataAreaValue = DataArea;
	EndIf;
	
	DataAreaOnChange();
	
EndProcedure
 
// Returns a value of the current data area separator.
// If the value is not set an error is raised.
// 
// Returns: 
//  Separator value type.
//  The value of the current data area separator. 
// 
Function SessionSeparatorValue() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return 0;
	Else
		If Not  CommonUse.UseSessionSeparator() Then
			Raise(NStr("en = 'The separator value is not specified.'"));
		EndIf;
		
		// Getting value of the current data area separator
		Return SessionParameters.DataAreaValue;
	EndIf;
	
EndFunction
 
// Returns the flag that shows whether DataArea separator is used.

// 
// Returns: 
// Boolean - True if separation is used, otherwise returns False.
// 
Function UseSessionSeparator() Export
	
	Return SessionParameters.UseDataArea;
	
EndFunction
 
// Adds extra parameters to the client parameter structure when runs is the SaaS model.
//
// Parameters:
//  Parameters - Structure - client parameter structure
//
Procedure AddClientParametersSaaS(Val Parameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled()
		Or Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreaPresentation.Value AS Presentation
	|FROM
	|	Constant.DataAreaPresentation AS DataAreaPresentation
	|WHERE
	|	DataAreaPresentation.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
	SetPrivilegedMode(True);
	Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
	// Considering that the data is unchangeable
	Result = Query.Execute();
	SetPrivilegedMode(False);
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		If CommonUseCached.SessionWithoutSeparators() Then
			Parameters.Insert("DataAreaPresentation", 
				Format(CommonUse.SessionSeparatorValue(), "NZ=0; NG=") + " -" + Selection.Presentation);
		ElsIf Not IsBlankString(Selection.Presentation) Then
			Parameters.Insert("DataAreaPresentation", Selection.Presentation);
		EndIf;
	EndIf;
	
EndProcedure
 
// Adds parameter details to the parameter table by the constant name.

// Returns the added parameter.
//
// Parameters: 
//  ParameterTable - Value table - infobase parameter detail table.
//  ConstantName   - String - name of the constant to be added to the infobase parameter table.
//
// Returns: 
//  Value table row.
//  Row with details on the added parameter. 
// 
Function AddConstantToInfobaseParameterTable(Val ParameterTable, Val ConstantName) Export
	
	MetadataConstants = Metadata.Constants[ConstantName];
	
	CurParameterString = ParameterTable.Add();
	CurParameterString.Name = MetadataConstants.Name;
	CurParameterString.Details = MetadataConstants.Presentation();
	CurParameterString.Type = MetadataConstants.Type;
	
	Return CurParameterString;
	
EndFunction 
  
// Returns the infobase parameter table.
//
// Returns: 
//  Value table.
//  Table that describes infobase parameters.
//  Columns:
//   Name             - String - parameter name.
//   Details          - String - parameter details to be displayed in the user interface.
//   ReadProhibition  - Boolean - flag that shows whether reading of the infobase parameter is
//                      prohibited. Can be set, for example, for passwords.
//   WriteProhibition - Boolean - flag that shows whether reading of the infobase parameter is 
//                      prohibited.
//   Type             - Type description - parameter value type. It is allowed to use only 
//                      primitive types and enumerations that are in the configuration, used to
//                      manage this configuration.
// 
Function GetInfobaseParameterTable() Export
	
	ParameterTable = GetEmptyInfobaseParameterTable();
	
	InfobaseParameterTableOnFill(ParameterTable);
	
	SaaSOperationsOverridable.GetInfobaseParameterTable(ParameterTable);
	
	Return ParameterTable;
	
EndFunction
 
// Gets the application name, as it has been specified by a subscriber.

//
// Returns - String - application name.
//
Function GetApplicationName() Export
	
	SetPrivilegedMode(True);
	Return Constants.DataAreaPresentation.Get();
	
EndFunction
 
// Returns the block size in MB to transfer a large file in parts.
//
Function GetFileTransferBlockSize() Export
	
	SetPrivilegedMode(True);
	
	FileTransferBlockSize = Constants.FileTransferBlockSize.Get(); // MB
	If Not  ValueIsFilled(FileTransferBlockSize) Then
		FileTransferBlockSize = 20;
	EndIf;
	Return FileTransferBlockSize;

EndFunction
 
// Serializes a structural type object.
//
// Parameters:
//  StructuralTypeValue - Array, Structure, Map, or their fixed analogs.
//
// Returns:
//  String - serialized value of a structural type object.
//
Function WriteStructuralXDTODataObjectToString(Val StructuralTypeValue) Export
	
	XDTODataObject = StructuralObjectToXDTODataObject(StructuralTypeValue);
	
	Return WriteValueToString(XDTODataObject);
	
EndFunction
 
// Encodes a string value using the Base64 algorithm

//
// Parameters:
//  String -  String.
//
// Returns:
//  String - ase64 presentation.
//
Function StringToBase64(Val String)  Export
	
	Storage = New  ValueStorage(String, New Deflation(9));
	
	Return XMLString(Storage);
	
EndFunction
 
// Decodes Base64 presentation of the string into the original value.

//
// Parameters:
//  Base64String -  String.
//
// Returns:
//  String.
//
Function Base64ToString(Val Base64String) Export
	
	Storage = XMLValue(Type("ValueStorage"),  Base64String);
	
	Return Storage.Get();
	
EndFunction
 
// Returns the data area time zone.
// Is intended to be called from the sessions where the separation is disabled. In the sessions
// where the separation is enabled, use GetInfobaseTimeZone() instead
//
// Parameters:
//  DataArea -  Number - separator of the data area whose time zone is retrieved.
//
// Returns:
//  String, Undefined - data area time zone, Undefined if the time zone is not specified
//
Function GetDataAreaTimeZone(Val DataArea) Export
	
	Manager = Constants.DataAreaTimeZone.CreateValueManager();
	Manager.DataAreaAuxiliaryData  = DataArea;
	Manager.Read();
	TimeZone = Manager.Value;
	
	If Not ValueIsFilled(TimeZone)  Then
		TimeZone = Undefined;
	EndIf;
	
	Return TimeZone;
	
EndFunction
  

// Returns the internal Service manager address
//
// Returns:
//  String - internal Service manager address
//
Function InternalServiceManagerURL() Export
	
	Return Constants.InternalServiceManagerURL.Get();
	
EndFunction

// Returns the auxiliary Service manager user name
//
// Returns:
//  String - auxiliary Service manager user name
//
Function AuxiliaryServiceManagerUserName() Export
	
	Return Constants.AuxiliaryServiceManagerUserName.Get();
	
EndFunction
 
// Returns the auxiliary Service manager user password
//
// Returns:
//  String - Auxiliary Service manager user password
//
Function  AuxiliaryServiceManagerUserPassword() Export
	
	Return Constants.AuxiliaryServiceManagerUserPassword.Get();
	
EndFunction
 
// Handles the web service error info.
// If the passed details on the error is not empty, writes the full error details to the event
// log and raised an exception with the brief error details.
//
Procedure HandleWebServiceErrorInfo(Val ErrorInfo, Val SubsystemName = "", Val WebServiceName = "", Val OperationName = "") Export
	
	If ErrorInfo = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(SubsystemName) Then
		SubsystemName = Metadata.Subsystems.StandardSubsystems.Subsystems.SaaSOperations.Name;
	EndIf;
	
	EventName = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1.Error calling the web service operation'",  CommonUseClientServer.DefaultLanguageCode()),
		SubsystemName);
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'An error occurred when calling the %1 operation of the %2 web service: %3'", CommonUseClientServer.DefaultLanguageCode()),
		OperationName,
		WebServiceName,
		ErrorInfo.DetailErrorDescription);
	
	WriteLogEvent(
		EventName,
		EventLogLevel.Error,
		,
		,
		ErrorText);
		
	Raise ErrorInfo.BriefErrorDescription;
	
EndProcedure
 
// Returns the user alias to be used in the interface.
//
// Parameters:
//  UserID - UUID.
//
// Returns: String - infobase user alias to be shown in interface.
//
Function InfobaseUserAlias(Val UserID) Export
	
	Alias = "";
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations\UserAliasOnDetermine");
	
	For Each Handler In EventHandlers Do
		Handler.Module.UserAliasOnDetermine(UserID,  Alias);
	EndDo;
	
	Return Alias;
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////
// File operations

// Returns the full name of the file, received from the service manager file storage by the
// file ID.
//
// Parameters:
//  FileID - UUID - file ID in the service manager file storage.
//
// Returns:
//  String - full name of the file.
//
Function GetFileFromServiceManagerStorage(Val FileID) Export
	
	ServiceManagerURL = Constants.InternalServiceManagerURL.Get();
	If Not  ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", ServiceManagerURL);
	StorageAccessParameters.Insert("UserName", Constants.AuxiliaryServiceManagerUserName.Get());
	StorageAccessParameters.Insert("Password", Constants.AuxiliaryServiceManagerUserPassword.Get());
	
	FileDetails = GetFileFromStorage(FileID,  StorageAccessParameters, True, True);
	If FileDetails =  Undefined Then
		Return Undefined;
	EndIf;
	
	FileProperties = New File(FileDetails.FullName);
	If Not  FileProperties.Exist() Then
		Return Undefined;
	EndIf;
	
	Return FileProperties.FullName;
	
EndFunction
 
// Adds a file to the service manager storage.
//		
// Parameters:
//  AddressDataFile -  String/BinaryData/File - address of the temporary storage / file data / file.
//  FileName - String - Stored file name. 
//		
// Returns:
//  UUID - file ID in the storage.
//
Function PutFileToServiceManagerStorage(Val AddressDataFile, Val FileName = "") Export
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", Constants.InternalServiceManagerURL.Get());
	StorageAccessParameters.Insert("UserName", Constants.AuxiliaryServiceManagerUserName.Get());
	StorageAccessParameters.Insert("Password", Constants.AuxiliaryServiceManagerUserPassword.Get());
	
	Return PutFileToStorage(AddressDataFile,  StorageAccessParameters, FileName);

EndFunction

#EndRegion
 
#Region InternalInterface

// Checks whether the applied solution can be used in the service mode.
// If the applied solution cannot be used in the SaaS mode, an exception with the detailed
// reason info is raised.
//
Procedure CheckCanUseConfigurationSaaS() Export
	        
	SubsystemDescriptions =  StandardSubsystemsCached.SubsystemDescriptions().ByNames;
	CTLDetails = SubsystemDescriptions.Get("CloudTechnologyLibrary");
	
	If CTLDetails = Undefined Then
		
		Raise  StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The 1C:Cloud Technology Library is not embedded into the applied solution.
                   |The applied solution cannot be used in the service mode.
                   |
                   |To use the applied solution in the service mode, embed
                   |1C:Cloud Technology Library version %1 or later.'", Metadata.DefaultLanguage.LanguageCode),
			RequiredCTLVersion());
		
	Else
		
		CTLVersion = CTLDetails.Version;
		
		If CommonUseClientServer.CompareVersions(CTLVersion, RequiredCTLVersion()) < 0 Then
			
			Raise  StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'To use the applied solution in the service mode with the current 1C:SL version, update 1C:Cloud Technology Library.
                       |
                       |Version in use: %1, version %2 or later is required.'", Metadata.DefaultLanguage.LanguageCode),
				CTLVersion, RequiredCTLVersion());
			
		EndIf;
		
	EndIf;
	
EndProcedure
 
// Calls an exception if there is no required subsystem from the cloud technology library.

//
// Parameters:
//  SubsystemName - String.
//
Procedure RaiseNoCTLSubsystemException(Val SubsystemName) Export
	
	Raise  StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The action cannot be performed by the reason: The %1 subsystem is not embedded in the applied solution.
               |This subsystem is included in the cloud technology library, which is embedded in applied solutions independently.
               |Check whether the %1 subsystem embedded correctly.'"),
		SubsystemName
	);
	
EndProcedure
 
// Declares events of the SaaSOperations subsystem:
//
// Server events:
//   DataAreaOnDelete,
//   InfobaseParameterTableOnGet,
//   OnSetInfobaseParameterValues,
//   InfobaseParameterTableOnFill,
//   DefaultRightsOnSet,
//   AfterDataImportFromOtherMode.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents,  ServerEvents) Export
	
	// SERVER EVENTS
	
	// Is called when deleting the data area.
	// All data areas that cannot be deleted in the standard way must be deleted in this procedure.
	//
	// Parameters:
	// DataArea - Separator value type - separator of the data area to be deleted.
	//
	// Syntax:
	// Procedure DataAreaOnDelete(Val DataArea) Export
	//
	// (The same as SaaSOperationsOverridable.DataAreaOnDelete).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations\DataAreaOnDelete");
	
	// Generates the list of the infobase parameters.
	//
	// Parameters:
	// ParameterTable - ValueTable - table with parameter details.
	// For column content details - see SaaSOperations.GetInfobaseParameterTable().
	//
	// Syntax:
	// Procedure InfobaseParameterTableOnGet(Val ParameterTable) Export
	//
	// (The same as SaaSOperationsOverridable.GetInfobaseParameterTable).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations\InfobaseParameterTableOnGet");
	
	// Is called before the attempt of writing infobase parameters to the constants of the same names.
	//
	// Parameters:
	// ParameterValues - Structure - values of the parameters to be set.
	// If the parameter value is set in the procedure based on structure, the corresponding
	// KeyAndValue pair must be deleted.
	//
	// Syntax:
	// Procedure OnSetInfobaseParameterValues(Val ParameterValues) Export
	//
	// (The same as SaaSOperationsOverridable.OnSetInfobaseParameterValues).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations\OnSetInfobaseParameterValues");
	
	// Generates the list of the infobase parameters.
	//
	// Parameters:
	// ParameterTable - ValueTable - table with parameter details.
	// For column content details - see SaaSOperations.GetInfobaseParameterTable().
	//
	// Syntax:
	// Procedure  InfobaseParameterTableOnFill(Val ParameterTable) Export
	//
	// (The same as SaaSOperationsOverridable.GetInfobaseParameterTable).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill");
	
	// Provides the user with the default rights.
	// Is called in the service mode if rights of a user who is not an administrator is changed.
	//
	// Parameters:
	//  User -  CatalogRef.Users - user whose rights are set.
	//
	// Syntax:
	// Procedure DefaultRightsOnSet(User) Export
	//
	// (The same as SaaSOperationsOverridable.SetDefaultRights).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations\DefaultRightsOnSet");
	
	// Is called when determining the user alias for displaying in the interface.
	//
	// Parameters:
	//  UserID - UUID,
	//  Alias  - String - user alias.
	//
	// Syntax:
	// Procedure  UserAliasOnDetermine(UserID,  Alias) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaSOperations\UserAliasOnDetermine");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers,  ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers"].Add(
				"SaaSOperations");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
				"SaaSOperations");
	
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDetermineScheduledJobsUsed"].Add(
				"SaaSOperations");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"SaaSOperations");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnEnableSeparationByDataAreas"].Add(
			"SaaSOperations");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnAddStandardSubsystemClientLogicParametersOnStart"].Add(
			"SaaSOperations");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\StandardSubsystemClientLogicParametersOnAdd"].Add(
			"SaaSOperations");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
				"SaaSOperations");
	EndIf;
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Defines the title of the InformationCenterDesktop common form.
//
// Parameters:
// FormTitle - String - form title.
//
Procedure DefaultFormTitleOnDefineInformationCenter(FormTitle) Export
	
	ResultTitle = GetApplicationName();
	If Not IsBlankString(ResultTitle) Then 
		FormTitle = ResultTitle;
	EndIf;
	
EndProcedure
 
// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map:
//                     Key   - method alias, for example, ClearDataArea;
//                     Value - name of the method to be called, for example
//                             SaaSOperations.ClearDataArea;
//                             You can pass Undefined if the name equals alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("SaaSOperations.PrepareDataAreaToUse");
	
	NameAndAliasMap.Insert("SaaSOperations.ClearDataArea");
	
EndProcedure
 
// Generates a scheduled job table with flags that show whether a job is used in SaaS mode.
//
// Parameters:
//  UsageTable - ValueTable - table to be filled with scheduled jobs with usage flags. It contains the following columns::
//                ScheduledJob - String - name of the predefined scheduled job.
//                Use          - Boolean - True if the scheduled job must be executed in the 
//                               service mode. False otherwise.
//
Procedure OnDetermineScheduledJobsUsed(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "DataAreaMaintenance";
	NewRow.Use          = True;
	
EndProcedure
 
///////////////////////////////////////////////////////////////////////////////
// Verifying the safe mode of data separation

// Verifying the safe mode of data separation.
// To be called only from the session module.
//
Procedure EnablingDataSeparationSafeModeOnCheck()  Export
	
	If Not SafeMode()
		And CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData()
		And Not  CommonUseCached.SessionWithoutSeparators() Then
		
		SeparationSwitched = Undefined;
		Try
			SessionParameters.UseDataArea = False; // Special case, the standard function cannot be used
			SeparationSwitched = True;
		Except
			// Access violation are expected in the correctly published infobase
			SeparationSwitched = False;
		EndTry;
		
		If SeparationSwitched Then
			// The safe mode of data separation is not set
			WriteLogEvent(NStr("en = 'Publication error'", CommonUseClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error,
				,
				,
				NStr("en = 'Safe mode of data separation is not set'"));
			Raise(NStr("en = 'Infobase published incorrectly. Session will be terminated'"));
		EndIf;
		
	EndIf;
	
EndProcedure
 
///////////////////////////////////////////////////////////////////////////////
// Checking whether the data area is locked when starting

// Checking whether the data area is locked when starting.
// To be called only from StandardSubsystemsServer.AddClientParametersOnStart().
//
Procedure LockDataAreaOnStartOnCheck(ErrorDescription) Export
	
	If CommonUseCached.DataSeparationEnabled()
			And CommonUseCached.CanUseSeparatedData()
			And DataAreaLocked(CommonUse.SessionSeparatorValue()) Then
		
		ErrorDescription =
			NStr("en = 'The application cannot be started now.
			           |Scheduled maintenance operations are in progress.
			           |
			           |Try to start the application in a few minutes.'");
		
	EndIf;
	
EndProcedure
   

////////////////////////////////////////////////////////////////////////////////
// Checking shared data

// CheckSharedDataOnWrite event subscription handler
//
Procedure CheckSharedObjectOnWrite(Source, Cancel)  Export
	
	CheckSharedDataOnWrite(Source);
	
EndProcedure
 
// CheckSharedRecordSetOnWrite event subscription handler
//
Procedure  CheckSharedRecordSetOnWrite(Source, Cancel, Replacing) Export
	
	CheckSharedDataOnWrite(Source);
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Handling auxiliary area data

// Writes the value of a reference type separated with AuxiliaryDataSeparator switching the
// session separator the writing.
//
// Parameters:
//  AuxiliaryDataObject - object of a reference type or ObjectDeletion.
//
Procedure WriteAuxiliaryData(AuxiliaryDataObject) Export
	
	HandleAuxiliaryData(
		AuxiliaryDataObject,
		True,
		False);
	
EndProcedure
 
// Deletes the value of a reference type separated with AuxiliaryDataSeparator switching the
// session separator during the writing.
//
// Parameters:
//  AuxiliaryDataObject - reference type value.
//
Procedure DeleteAuxiliaryData(AuxiliaryDataObject) Export
	
	HandleAuxiliaryData(
		AuxiliaryDataObject,
		False,
		True);
	
EndProcedure
 
// Creates the record key for the information register included in the DataAreaAuxiliaryData
// separator content.
//
// Parameters:
//  Manager   - InformationRegisterManager - information register manager whose record key is
//              created.
//  KeyValues - Structure - contains values used for filling record key properties.
//              Structure item names must correspond with the names of key fields.
//
// Returns: InformationRegisterRecordKey.
//
Function  CreateAuxiliaryDataInformationRegisterRecordKey(Val Manager,  Val KeyValues) Export
	
	RecordKey = Manager.CreateRecordKey(KeyValues);
	
	DataArea = Undefined;
	Separator = AuxiliaryDataSeparator();
	
	If KeyValues.Property(Separator, DataArea) Then
		
		If RecordKey[Separator] <> DataArea Then
			
			Object = XDTOSerializer.WriteXDTO(RecordKey);
			Object[Separator]  = DataArea;
			RecordKey = XDTOSerializer.ReadXDTO(Object);
			
		EndIf;
		
	EndIf;
	
	Return RecordKey;
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////
// Functions for determining types of metadata objects by full metadata object names

// Reference data types

// Determines whether the metadata object is one of Document type objects by the full
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullDocumentName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Document", "Document");
	
EndFunction
 
// Determines whether the metadata object is one of Catalog type objects by the full
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullCatalogName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Catalog", "Catalog");
	
EndFunction
 
// Determines whether the metadata object is one of Enumeration type objects by the full
// metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullEnumerationName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Enum", "Enum");
	
EndFunction

// Determines whether the metadata object is one of Exchange plan type objects by the full
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullExchangePlanName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "ExchangePlan", "ExchangePlan");
	
EndFunction
 
// Determines whether the metadata object is one of Chart of characteristic types type
// objects by the full metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullChartOfCharacteristicTypesName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "ChartOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	
EndFunction

// Determines whether the metadata object is one of Business process type objects by the
// full metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullBusinessProcessName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "BusinessProcess", "BusinessProcess");
	
EndFunction
 
// Determines whether the metadata object is one of Task type objects by the full metadata
// object name.
// 
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
// 
// Returns:
//  Boolean.
//
Function IsFullTaskName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Task", "Task");

EndFunction
 
// Determines whether the metadata object is one of Chart of accounts type objects by the
// full metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullChartOfAccountsName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "ChartOfAccounts", "ChartOfAccounts");
	
EndFunction
 
// Determines whether the metadata object is one of Chart of calculation types type objects
// by the full metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullChartOfCalculationTypesName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "ChartOfCalculationTypes", "ChartOfCalculationTypes");
	
EndFunction

// Registers


// Determines whether the metadata object is one of Information register type objects by
// the full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullInformationRegisterName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "InformationRegister", "InformationRegister");
	
EndFunction
 
// Determines whether the metadata object is one of Accumulation register type objects by
// the full metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullAccumulationRegisterName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "AccumulationRegister", "AccumulationRegister");
	
EndFunction

// Determines whether the metadata object is one of Accounting register type objects by the
// full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullAccountingRegisterName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "AccountingRegister", "AccountingRegister");
	
EndFunction
 
// Determines whether the metadata object is one of Calculation register type objects by
// the full metadata object name.

//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullCalculationRegisterName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "CalculationRegister", "CalculationRegister")
		And Not IsFullRecalculationName(FullName);
	
EndFunction 
  
// Recalculations
 

// Determines whether the metadata object is one of Recalculation type objects by the full
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullRecalculationName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Recalculation", "Recalculation", 2);
	
EndFunction 
 
// Constants


// Determines whether the metadata object is one of Constant type objects by the full
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullConstantName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "Constant", "Constant");
	
EndFunction
 
// Document journals

// Determines whether the metadata object is one of Document journal type objects by the
// full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullDocumentJournalName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "DocumentJournal", "DocumentJournal");
	
EndFunction
 
// Sequences

// Determines whether the metadata object is one of Sequence type objects by the full 
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullSequenceName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "Sequence", "Sequence");
	
EndFunction
 
// ScheduledJobs

// Determines whether the metadata object is one of Scheduled job type objects by the full
// metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function ThisFullScheduledJobName(Val FullName) Export
	
	Return  CheckMetadataObjectTypeByFullName(FullName, "ScheduledJob", "ScheduledJob");
	
EndFunction
  

// Common

// Determines whether the metadata object is one of register type objects by the full
// metadata object name.
//
// Parameters:
//   FullName - String - full name of the metadata object whose type must be compared with the
//              specified type.

// Returns:
//  Boolean.
//
Function IsFullRegisterName(Val FullName) Export
	
	Return IsFullInformationRegisterName(FullName)
		Or IsFullAccumulationRegisterName(FullName)
		Or IsFullAccountingRegisterName(FullName)
		Or IsFullCalculationRegisterName(FullName)
	;
	
EndFunction
 
// Determines whether the metadata object is one of reference type objects by the full metadata
// object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the
//             specified type.
//
// Returns:
//  Boolean.
//
Function IsFullReferenceTypeObjectName(Val FullName) Export
	
	Return IsFullCatalogName(FullName)
		Or IsFullDocumentName(FullName)
		Or IsFullBusinessProcessName(FullName)
		Or IsFullTaskName(FullName)
		Or IsFullChartOfAccountsName(FullName)
		Or IsFullExchangePlanName(FullName)
		Or  IsFullChartOfCharacteristicTypesName(FullName)
		Or IsFullChartOfCalculationTypesName(FullName)
	;
	
EndFunction
 
// For internal use.
//
Function SelectionParameters(Val MetadataObjectFullName) Export
	
	Result = New Structure("Table,RecorderFieldName");
	
	If IsFullRegisterName(MetadataObjectFullName)
			Or IsFullSequenceName(MetadataObjectFullName) Then
		
		Result.Table = MetadataObjectFullName;
		Result.RecorderFieldName = "Recorder";
		
	ElsIf IsFullRecalculationName(MetadataObjectFullName) Then
		
		Substrings = StringFunctionsClientServer.SplitStringIntoSubstringArray(MetadataObjectFullName, ".");
		Result.Table = Substrings[0] + "." + Substrings[1] + "." + Substrings[3];
		Result.RecorderFieldName = "RecalculationObject";
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The SelectionParameters() function cannot be executed for the %1 object.'"),
			MetadataObjectFullName);
		
	EndIf;
	
	Return Result;
	
EndFunction
 
// For internal use.
//
Function DataAreasInUse() Export
	SetPrivilegedMode(True);
	
	Query = New Query("
		|SELECT
		|	DataAreaAuxiliaryData AS DataArea
		|In
		|	InformationRegister.DataAreas
		|Where
		|	Status = VALUE(Enum.DataAreaStatuses.Used)
		|	And  DataAreaAuxiliaryData <> 0
		|");
	Result = Query.Execute();
	
	Return Result;
EndFunction

#EndRegion
 
#Region InternalProceduresAndFunctions

// Returns the full path to the temporary file directory.
//
// Returns:
//  String - full path to the temporary file directory.
//
Function GetCommonTempFilesDir()
	
	SetPrivilegedMode(True);
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Linux_x86
		Or ServerPlatformType = PlatformType.Linux_x86_64 Then
		
		CommonTempDirectory = Constants.FileExchangeDirectorySaaSLinux.Get();
		PathSeparator = "/";
	Else
		CommonTempDirectory = Constants.FileExchangeDirectorySaaS.Get();
		PathSeparator = "\";
	EndIf;
	
	If IsBlankString(CommonTempDirectory) Then
		CommonTempDirectory = TrimAll(TempFilesDir());
	Else
		CommonTempDirectory = TrimAll(CommonTempDirectory);
	EndIf;
	
	If Right(CommonTempDirectory, 1) <> PathSeparator Then
		CommonTempDirectory = CommonTempDirectory + PathSeparator;
	EndIf;
	
	Return CommonTempDirectory;
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////
// Preparing data areas

// Gets the record manager for the DataAreas register in the transaction.
//
// Parameters:
//  DataArea - data area number.
//  Status   - Enums.InformationRegisterRecordManager - expected data area status.
//
// Returns:
//  InformationRegisters.DataAreas.RecordManager
//
Function GetDataAreaRecordManager(Val DataArea, Val Status)
	
	BeginTransaction();
	Try
		DataLock = New  DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode =  DataLockMode.Shared;
		DataLock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		
		If Not  RecordManager.Selected() Then
			MessagePattern = NStr("en = '%1 data area is not found'");
			MessageText =  StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea);
			Raise(MessageText);
		ElsIf RecordManager.Status <> Status Then
			MessagePattern = NStr("en = '%1 data area status is not %2'");
			MessageText =  StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea, Status);
			Raise(MessageText);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Preparing data area'", CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Return RecordManager;
	
EndFunction	
 
// Updates data area statuses in the DataArea register, sends a message to the service manager.
//
// Parameters:
//  RecordManager     - InformationRegisters.DataAreas.RecordManager.
//  PreparationResult - String - "Success", "ConversionRequired", "FatalError",
//                      "DeletionError", or "AreaDeleted." 
//  ErrorMessage      - String.
//
Procedure ChangeAreaStatusAndInformManager(Val RecordManager, Val PreparationResult, Val ErrorMessage)
	
	ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
	FillPropertyValues(ManagerCopy, RecordManager);
	RecordManager = ManagerCopy;

	IncludeErrorMessage = False;
	If PreparationResult = "Success" Then
		RecordManager.Status = Enums.DataAreaStatuses.Used;
		MessageType =  RemoteAdministrationControlMessagesInterface.MessageDataAreaPrepared();
	ElsIf PreparationResult = "ConversionRequired" Then
		RecordManager.Status = Enums.DataAreaStatuses.ImportFromFile;
		MessageType =  RemoteAdministrationControlMessagesInterface.MessageErrorPreparingDataAreaConversionRequired();
	ElsIf PreparationResult = "AreaDeleted" Then
		RecordManager.Status = Enums.DataAreaStatuses.Deleted;
		MessageType =  RemoteAdministrationControlMessagesInterface.MessageDataAreaDeleted();
	ElsIf PreparationResult = "FatalError" Then
		WriteLogEvent(NStr("en = 'Preparing data area'",  CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , ErrorMessage);
		RecordManager.ProcessingError = True;
		MessageType =  RemoteAdministrationControlMessagesInterface.MessageErrorPreparingDataArea();
		IncludeErrorMessage = True;
	ElsIf PreparationResult = "DeletionError" Then
		RecordManager.ProcessingError = True;
		MessageType =  RemoteAdministrationControlMessagesInterface.MessageErrorDeletingDataArea();
		IncludeErrorMessage = True;
	Else
		Raise NStr("en = 'Unexpected return code'");
	EndIf;
	
	// Send data area ready message to the service manager
	Message = MessagesSaaS.NewMessage(MessageType);
	Message.Body.Zone = RecordManager.DataAreaAuxiliaryData;
	If IncludeErrorMessage Then
		Message.Body.ErrorDescription = ErrorMessage;
	EndIf;

	BeginTransaction();
	Try
		MessagesSaaS.SendMessage(
			Message,
			SaaSOperationsCached.ServiceManagerEndpoint());
		
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure
 
// Imports data into the "standard" area.
// 
// Parameters: 
//   DataArea     - number of the data area to be filled.
//   ExportFileID - initial data file ID.
//   Option       - initial data variant.
//   ErrorMessage - String - error details (if any).
//
// Returns:
//  String - "Success" or "FatalError".
//
Function PrepareDataAreaForUseFromPrototype(Val DataArea, Val ExportFileID, 
												 		  Val Option, ErrorMessage)
	
	If Constants.CopyDataAreasFromPrototype.Get() Then
		
		Result =  ImportDataAreaFromSuppliedData(DataArea, ExportFileID, Option, ErrorMessage);
		If Result <> "Success" Then
			Return Result;
		EndIf;
		
	Else
		
		Result = "Success";
		
	EndIf;
	
	InfobaseUpdate.ExecuteInfobaseUpdate();
	
	Return Result;
	
EndFunction
	
// Imports data to the data area from the custom data.
// 
// Parameters: 
//   DataArea     - number of the data area to be filled.
//   ExportFileID - initial data file ID.
//   ErrorMessage - String - error details (if any).
//
// Returns:
//  String - "ConversionRequired", "Success", or "FatalError".
//
Function PrepareDataAreaForUseFromExport(Val DataArea, Val ExportFileID,  ErrorMessage)
	
	ExportFileName =  GetFileFromServiceManagerStorage(ExportFileID);
	
	If ExportFileName =  Undefined Then
		
		ErrorMessage = NStr("en = 'No initial data file for the data area'");
		
		Return "FatalError";
	EndIf;
	
	If Not CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.DataAreaExportImport") Then
		
		RaiseNoCTLSubsystemException("CloudTechnology.SaaSOperations.DataAreaExportImport");
		
	EndIf;
	
	DataAreaExportImportModule = CommonUseClientServer.CommonModule("DataAreaExportImport");
	
	If Not  DataAreaExportImportModule.DataInArchiveCompatibleWithCurrentConfiguration(ExportFileName) Then
		Result = "ConversionRequired";
	Else
		
		DataAreaExportImportModule.ImportCurrentDataAreaFromArchive(ExportFileName);
		Result = "Success";
		
	EndIf;
	
	Try
		DeleteFiles(ExportFileName);
	Except
		WriteLogEvent(NStr("en = 'Preparing data area'", CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Warning, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	Return Result;
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////

// Functions for determining types of metadata objects by full metadata object names

Function CheckMetadataObjectTypeByFullName(Val FullName, Val CurrentLocalization, Val EnglishLocalization, Val SubstringPosition = 0)
	
	Substrings = StringFunctionsClientServer.SplitStringIntoSubstringArray(FullName, ".");
	If Substrings.Count() > SubstringPosition Then
		TypeName = Substrings.Get(SubstringPosition);
		Return TypeName = CurrentLocalization Or TypeName = EnglishLocalization;
	Else
		Return False;
	EndIf;
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Is called when enabling the data separation.
//
Procedure  OnEnableSeparationByDataAreas() Export
	
	CheckCanUseConfigurationSaaS();
	SaaSOperationsOverridable.OnEnableSeparationByDataAreas();
	
EndProcedure
 
// Registers supplied data handlers
//
// When new common data notification is received, the NewDataAvailable procedures registered
// with GetSuppliedDataHandlers are called.
// The descriptor passed to the procedure is XDTODataObject Descriptor.
// 
// If NewDataAvailable sets Load to True, the data is imported, the descriptor and the path to
// data are passed into ProcessNewData(). The file is automatically deleted once the procedure 
// is executed.
// If the file is not specified in Service Manager, the argument is Undefined.
//
// Parameters: 
//   Handlers - ValueTable - table where the handlers are passed. 
//        Columns:
//         DataKind    - String - code of data kind processed in the handler.
//         HandlerCode - String(20) - is used when recovering data processing after failure.
//         Handler     - CommonModule -  module that contains the following procedures:
//                        NewDataAvailable(Descriptor,  Import) Export   
//                        ProcessNewData(Descriptor, PathToFile) Export
//                        DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	 
EndProcedure
 
// Adds the update handlers required by the subsystem.
//
// Parameters
//  Handlers - ValueTable - see details on the NewUpdateHandlerTable() function of the
//             InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
		
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "SaaSOperations.CheckSharedDataOnUpdate";
	Handler.SharedData = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 99;
	Handler.ExclusiveMode = False;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "SaaSOperations.CheckSeparatorsOnUpdate";
	Handler.SharedData = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 99;
	Handler.ExclusiveMode = False;
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "SaaSOperations.CheckCanUseConfigurationSaaS";
		Handler.SharedData = True;
		Handler.ExecuteInMandatoryGroup = True;
		Handler.Priority = 99;
		Handler.ExclusiveMode = False;
		
	EndIf;
	
EndProcedure
 
// Fills a structure of parameters required for running the application on a client. 
//
// Parameters
//   Parameters - Structure - parameter structure.
//
Procedure OnAddStandardSubsystemClientLogicParametersOnStart(Parameters) Export
	
	AddClientParametersSaaS(Parameters);
	
EndProcedure
 
// Fills a structure of parameters required for running the application on a client
//
// Parameters
//   Parameters    Structure  parameter structure
//
Procedure StandardSubsystemClientLogicParametersOnAdd(Parameters) Export
	
	AddClientParametersSaaS(Parameters);
	
EndProcedure
 
// Fills an array of types excluded from data import and export.

//
// Parameters
//  Types - Array of Type.
//
Procedure  OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.Constants.DataAreaKey);
	Types.Add(Metadata.InformationRegisters.DataAreas);
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Calls to other subsystems

// Generates the list of the infobase parameters.
//
// Parameters:
// ParameterTable - ValueTable - table with parameter details.
// For column content details, see SaaSOperations.GetInfobaseParameterTable().
//
Procedure InfobaseParameterTableOnFill(Val ParameterTable) Export
	
	If CommonUseCached.IsSeparatedConfiguration() Then
		AddConstantToInfobaseParameterTable(ParameterTable, "UseSeparationByDataAreas");
		
		AddConstantToInfobaseParameterTable(ParameterTable, "InfobaseUsageMode");
		
		AddConstantToInfobaseParameterTable(ParameterTable, "CopyDataAreasFromPrototype");
	EndIf;
	
	AddConstantToInfobaseParameterTable(ParameterTable, "InternalServiceManagerURL");
	
	AddConstantToInfobaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserName");
	
	CurParameterString =  AddConstantToInfobaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserPassword");
	CurParameterString.ReadProhibition = True;
	
	// For obsolete version compatibility
	CurParameterString = AddConstantToInfobaseParameterTable(ParameterTable, "InternalServiceManagerURL");
	CurParameterString.Name = "ServiceURL";
	
	CurParameterString =  AddConstantToInfobaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserName");
	CurParameterString.Name = "AuxiliaryServiceUserName";
	
	CurParameterString =  AddConstantToInfobaseParameterTable(ParameterTable, "AuxiliaryServiceManagerUserPassword");
	CurParameterString.Name = "AuxiliaryServiceUserPassword";
	CurParameterString.ReadProhibition = True;
	// End For obsolete version compatibility
	
	CurParameterString = ParameterTable.Add();
	CurParameterString.Name =  "ConfigurationVersion";
	CurParameterString.Details = NStr("en = 'Configuration version'");
	CurParameterString.WriteProhibition = True;
	CurParameterString.Type = New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable));
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill");
	
	For Each Handler In EventHandlers Do
		Handler.Module.InfobaseParameterTableOnFill(ParameterTable);
	EndDo;
	
EndProcedure
 
////////////////////////////////////////////////////////////////////////////////
// Operating through Service agent

// Removes specified sessions and terminates connections for the current infobase through Service agent.
// Sessions can be specified by their numbers in the input array or as a single number.
//
// Parameters:
//   SessionsToRemove - Array; Number - array of Number with session numbers or single session number.
//   InfobaseAdministrationParameters - Structure with the following fields:
//    InfobaseAdministratorName     - String.
//    InfobaseAdministratorPassword - String.
//    ClusterAdministratorName      - String.
//    ClusterAdministratorPassword  - String.
//    ServerClusterPort             - Number.
//    ServerAgentPort               - Number.
//
// Returns:
//   Boolean - True, if the operation done successfully.
//
Function TerminateSessionsByListViaServiceAgent(Val SessionsToRemove, Val InfobaseAdministrationParameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If TypeOf(SessionsToRemove) = Type("Array") Then
		SessionList = SessionsToRemove;
	ElsIf TypeOf(SessionsToRemove) = Type("Number") Then
		SessionList = New Array;
		SessionList.Add(SessionsToRemove);
	Else
		Raise(NStr("en = 'Invalid parameter type of SessionsToRemove.'"));
	EndIf;
	
	If SessionList.Count() = 0 Then
		Return True;
	EndIf;
	
	AgentPublication = Constants.ServiceAgentAddress.Get();
	AgentUser = Constants.ServiceAgentUserName.Get();
	AgentPassword = Constants.ServiceAgentUserPassword.Get();
	
	// Validating using versioning whether the interface is supported.
	SupportedVersionArray = CommonUse.GetInterfaceVersions(AgentPublication,
		AgentUser, AgentPassword, "AgentManagement");
		
	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
		Raise(NStr("en = 'Service agent. Selective session termination does not supported in this version.'"));
	EndIf;
	
	// Generating an XDTO string with input parameters for accessing the service operations.
	
	ParameterValues = New Structure;
	
	// Getting connection parameters for the current infobase.
	ConnectionParameters = StringFunctionsClientServer.GetParametersFromString(InfobaseConnectionString());
	ParameterValues.Insert("Infobase", ConnectionParameters.Ref);
	
	AdministrationParameterType = XDTOFactory.Type("http://v8.1c.ru/agent/scripts/1.0", "ClusterAdministrationInfo");
	ClusterAdministrationParameters = XDTOFactory.Create(AdministrationParameterType);
	ClusterAdministrationParameters.AgentConnectionString = 
		"tcp://" + ConnectionParameters.Srvr + ":" 
		+ Format(InfobaseAdministrationParameters.ServerAgentPort, "NG=");
	ClusterAdministrationParameters.ClusterPort = InfobaseAdministrationParameters.ServerClusterPort;
	ClusterAdministrationParameters.ClusterUserName = InfobaseAdministrationParameters.ClusterAdministratorName;
	ClusterAdministrationParameters.ClusterPassword = StringToBase64(InfobaseAdministrationParameters.ClusterAdministratorPassword);
	ClusterAdministrationParameters.IBUserName = InfobaseAdministrationParameters.InfobaseAdministratorName;
	ClusterAdministrationParameters.IBPassword = StringToBase64(InfobaseAdministrationParameters.InfobaseAdministratorPassword);
	
	ParameterValues.Insert("ClusterAdministrationParameters", ClusterAdministrationParameters);
	ParameterValues.Insert("SessionList", SessionList);
	
	XDTOParameters = WriteStructuralXDTODataObjectToString(ParameterValues);
	
	// Support of version 2 (with selective session termination) is required.
	
	Proxy = CommonUse.WSProxy(AgentPublication + "/ws/ManageAgent_1_0_2_1?wsdl",
		"http://www.1c.ru/SaaS/1.0/WS",
		"ManageAgent_1_0_2_1",
		,
		AgentUser,
		AgentPassword,
		20);
		
	
	// Executing using a web service operation.
	CompleteState = Undefined;
	Proxy.DoAction("TerminateSessionsByList", XDTOParameters, CompleteState);
	
	Return CompleteState = "ActionCompleted";
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////

// Processing infobase parameters

// Returns an empty table of infobase parameters
//
Function GetEmptyInfobaseParameterTable()
	
	Result = New  ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New  StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Details", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("ReadProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("WriteProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Return Result;
	
EndFunction
 
 ////////////////////////////////////////////////////////////////////////////////

// File operations

// Retrieves file description by its ID in the File register.
// If the file are stored on the disk and PathNotData = True, Data in the result structure = 
// Undefined, FullName = Full file name, otherwise Data is binary file data, FullName is
// Undefined.
// The Name key value always contains the name in the storage.
//		
// Parameters
//  FileID               - UUID.
//  ConnectionParameters - Structure:
//  						              URL      - String - Service URL. Mandatory to be filled in.
//  						              UserName - String - service user name.
//  						              Password - String - service user password.
//  PathNotData          - Boolean - what to return. 
//  CheckForExistence    - Boolean - flag that shows whether the file existence must be checked
//                         if it cannot be retrieved.
//		
// Returns:
//  FileDetails - Structure:
//                 Name     - String - file name in the storage.
//                 Data     - BinaryData - File data.
//                 FullName - String - full name of the file.
//  The file is automatically deleted once the temporary file storing time is up.
//
Function GetFileFromStorage(Val FileID, Val ConnectionParameters, 
	Val PathNotData = False, Val CheckForExistence = False) Export
	
	ExecutionStarted = CurrentUniversalDate();
	
	ProxyDetails = FileTransferServiceProxyDetails(ConnectionParameters);
	
	ExchangeOverFS = CanPassViaFSFromServer(ProxyDetails.Proxy, ProxyDetails.HasVersion2Support);
	
	If ExchangeOverFS Then
			
		Try
			Try
				FileName = ProxyDetails.Proxy.WriteFileToFS(FileID);
			Except
				ErrorDescription = DetailErrorDescription(ErrorInfo());
				If CheckForExistence And Not ProxyDetails.Proxy.FileExists(FileID) Then
					Return Undefined;
				EndIf;
				Raise ErrorDescription;
			EndTry;
			
			FileProperties = New File(GetCommonTempFilesDir() + FileName);
			If FileProperties.Exist() Then
				FileDetails = CreateFileDetails();
				FileDetails.Name = FileProperties.Name;
				
				ReceivedFileSize = FileProperties.Size();
				
				If PathNotData Then
					FileDetails.Data = Undefined;
					FileDetails.FullName = FileProperties.FullName;
				Else
					FileDetails.Data = New BinaryData(FileProperties.FullName);
					FileDetails.FullName = Undefined;
					Try
						DeleteFiles(FileProperties.FullName);
					Except
					EndTry;
				EndIf;
				
				WriteFileStorageEventToLog(
					NStr("en = 'Extracting'", CommonUseClientServer.DefaultLanguageCode()),
					FileID,
					ReceivedFileSize,
					CurrentUniversalDate() - ExecutionStarted,
					ExchangeOverFS);
				
				Return FileDetails;
			Else
				ExchangeOverFS = False;
			EndIf;
		Except
			WriteLogEvent(NStr("en = 'Getting file form storage'",  CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
			
	EndIf; // ExchangeOverFS
	
	PartCount = Undefined;
	FileNameInCatalog = Undefined;
	FileTransferBlockSize = GetFileTransferBlockSize();
	Try
		If ProxyDetails.HasVersion2Support Then
			TransferID = ProxyDetails.Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, PartCount);
		Else
			TransferID = Undefined;
			ProxyDetails.Proxy.PrepareGetFile(FileID,  FileTransferBlockSize * 1024, TransferID, PartCount);
		EndIf;
	Except
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		If CheckForExistence And Not ProxyDetails.Proxy.FileExists(FileID) Then
			Return Undefined;
		EndIf;
		Raise ErrorDescription;
	EndTry;
	
	FileNames = New Array;
	
	AssemblyDirectory = CreateAssemblyDirectory();
	
	If ProxyDetails.HasVersion2Support Then
		For PartNumber = 1 To PartCount Do
			PartData = ProxyDetails.Proxy.GetFilePart(TransferID, PartNumber, PartCount);
			FileNamePart = AssemblyDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	Else // 1st version
		For PartNumber = 1 to PartCount Do
			PartData = Undefined;
			ProxyDetails.Proxy.GetFilePart(TransferID,  PartNumber, PartData);
			FileNamePart = AssemblyDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	EndIf;
	PartData = Undefined;
	
	ProxyDetails.Proxy.ReleaseFile(TransferID);
	
	ArchiveName = GetTempFileName("zip");
	
	MergeFiles(FileNames, ArchiveName);
	
	Dearchiver = New  ZipFileReader(ArchiveName);
	If Dearchiver.Items.Count() > 1  Then
		Raise(NStr("en = 'The archive contains more than one file'"));
	EndIf;
	
	FileName = AssemblyDirectory + Dearchiver.Items[0].Name;
	Dearchiver.Extract(Dearchiver.Items[0], AssemblyDirectory);
	Dearchiver.Close();
	
	ResultFile = New File(GetTempFileName());
	MoveFile(FileName, ResultFile.FullName);
	ReceivedFileSize = ResultFile.Size();
	
	FileDetails = CreateFileDetails();
	FileDetails.Name = ResultFile.Name;
	
	If PathNotData Then
		FileDetails.Data = Undefined;
		FileDetails.FullName = ResultFile.FullName;
	Else
		FileDetails.Data = New BinaryData(ResultFile.FullName);
		FileDetails.FullName = Undefined;
		Try
			DeleteFiles(ResultFile.FullName);
		Except
		EndTry;
	EndIf;
	
	Try
		DeleteFiles(ArchiveName);
		DeleteFiles(AssemblyDirectory);
	Except
	EndTry;
	
	WriteFileStorageEventToLog(
		NStr("en = 'Extracting'",  CommonUseClientServer.DefaultLanguageCode()),
		FileID,
		ReceivedFileSize,
		CurrentUniversalDate() - ExecutionStarted,
		ExchangeOverFS);
	
	Return FileDetails;
	
EndFunction
 
// Adds a file to the service manager storage.
//		
// Parameters:
// AddressDataFile      - String/BinaryData/File - address of the temporary storage / file data / file.
// ConnectionParameters - Structure:
// 						              URL      - String - service URL. Mandatory to be filled in.
// 						              UserName - String - service user name.
// 						              Password - String - service user password.
// FileName             - String - Stored file name. 
//		
// Returns:
//  UUID - file ID in the storage.
//
Function PutFileToStorage(Val AddressDataFile, Val ConnectionParameters, Val FileName = "")
	
	ExecutionStarted = CurrentUniversalDate();
	
	ProxyDetails = FileTransferServiceProxyDetails(ConnectionParameters);
	
	Details = GetDataFileName(AddressDataFile, FileName);
	FileProperties = New File(Details.Name);
	
	ExchangeOverFS = CanTransferThroughFSToServer(ProxyDetails.Proxy, ProxyDetails.HasVersion2Support);
	If ExchangeOverFS Then
		
		// Save data to file
		CommonDirectory = GetCommonTempFilesDir();
		TargetFile = New File(CommonDirectory + FileProperties.Name);
		If TargetFile.Exist() Then
			If FileProperties.FullName = TargetFile.FullName Then // It's a single file. It can be 
			                                                      // read at the server immediately,
			                                                      // without passing.
				Result = ProxyDetails.Proxy.ReadFileFromFS(TargetFile.Name, FileProperties.Name);
				SourceFileSize = TargetFile.Size();
				WriteFileStorageEventToLog(
					NStr("en = 'Placement'", CommonUseClientServer.DefaultLanguageCode()),
					Result,
					SourceFileSize,
					CurrentUniversalDate() - ExecutionStarted,
					ExchangeOverFS);
				Return Result;
				// Cannot be deleted because it is a source file too.
			EndIf;
			// Source and target are different files. Specifying a unique name for the target file to
			// prevent files from other sessions from deletion.
			NewID = New UUID;
			TargetFile = New File(CommonDirectory + NewID + FileProperties.Extension);
		EndIf;
		
		Try
			If Details.Data = Undefined Then
				FileCopy(FileProperties.FullName, TargetFile.FullName);
			Else
				Details.Data.Write(TargetFile.FullName);
			EndIf;
			Result = ProxyDetails.Proxy.ReadFileFromFS(TargetFile.Name, FileProperties.Name);
			SourceFileSize = TargetFile.Size();
			WriteFileStorageEventToLog(
				NStr("en = 'Placement'", CommonUseClientServer.DefaultLanguageCode()),
				Result,
				SourceFileSize,
				CurrentUniversalDate() - ExecutionStarted,
				ExchangeOverFS);
		Except
			WriteLogEvent(NStr("en = 'Adding file.Exchange through FS'", CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
		
		DeleteTempFiles(TargetFile.FullName);
		
	EndIf; // ExchangeOverFS
		
	If Not ExchangeOverFS Then
		
		FileTransferBlockSize = GetFileTransferBlockSize(); // MB
		TransferID = New UUID;
		
		// Save data to file.
		AssemblyDirectory = CreateAssemblyDirectory();
		FullFileName = AssemblyDirectory + FileProperties.Name;
		
		If Details.Data = Undefined Then
			If FileProperties.Exist() Then
				FileCopy(FileProperties.FullName, FullFileName);
			Else
				Raise(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Adding file to the storage. File %1 is not found.'"), FileProperties.FullName));
			EndIf;
		Else
			Details.Data.Write(FullFileName);
		EndIf;
		
		TargetFile = New File(FullFileName);
		SourceFileSize = TargetFile.Size();
		
		// Compress file.
		SharedFileName = GetTempFileName("zip");
		Archiver = New ZipFileWriter(SharedFileName, , , , ZIPCompressionLevel.Minimum);
		Archiver.Add(FullFileName);
		Archiver.Write();
		
		// Split file into parts
		FileNames = SplitFile(SharedFileName, FileTransferBlockSize * 1024 * 1024, AssemblyDirectory); // MB => bytes
		
		Try
			DeleteFiles(SharedFileName);
		Except
		EndTry;
		
		// Pass file through the service in parts
		PartCount = FileNames.Count();
		If ProxyDetails.HasVersion2Support Then
			For PartNumber = 1 to PartCount Do	// Transfer in parts	
				FileNamePart = FileNames[PartNumber - 1];		
				FileData = New BinaryData(FileNamePart);		
				Try
					DeleteFiles(FileNamePart);
				Except
				EndTry;
				ProxyDetails.Proxy.PutFilePart(TransferID, PartNumber, FileData, PartCount);
			EndDo;
		Else // 1st version
			For PartNumber = 1 to PartCount Do	// Transfer in parts	
				FileNamePart = FileNames[PartNumber - 1];		
				FileData = New BinaryData(FileNamePart);		
				Try
					DeleteFiles(FileNamePart);
				Except
				EndTry;
				ProxyDetails.Proxy.PutFilePart(TransferID, PartNumber, FileData);
			EndDo;
		EndIf;
		
		Try
			DeleteFiles(AssemblyDirectory);
		Except
		EndTry;
		
		If ProxyDetails.HasVersion2Support Then
			Result = ProxyDetails.Proxy.SaveFileFromParts(TransferID, PartCount); 
		Else // 1st version
			Result = Undefined;
			ProxyDetails.Proxy.SaveFileFromParts(TransferID, PartCount, Result); 
		EndIf;
		
		WriteFileStorageEventToLog(
			NStr("en = 'Placement'", CommonUseClientServer.DefaultLanguageCode()),
			Result,
			SourceFileSize,
			CurrentUniversalDate() - ExecutionStarted,
			ExchangeOverFS);
		
	EndIf; // Not ExchangeOverFS
	
	Return Result;
	
EndFunction

// Returns a structure with a name and data of the file by the address in the temporary
// storage / details in the File object / binary data.
//		
// Parameters:
// AddressDataFile - String/BinaryData/File - Address of the file data storage / File data / File.
// FileName        - String.
//		
// Returns:
//  Structure:
//   Data - BinaryData - File data.
//   Name - String - File name.
//
Function GetDataFileName(Val AddressDataFile, Val FileName = "")
	
	If TypeOf(AddressDataFile) = Type("String") Then // Address of the data file in the temporary storage.
		If IsBlankString(AddressDataFile) Then
			Raise(NStr("en = 'Invalid storage address.'"));
		EndIf;
		FileData = GetFromTempStorage(AddressDataFile);
	ElsIf TypeOf(AddressDataFile) = Type("File") Then // Object of the File type.
		If Not AddressDataFile.Exist() Then
			Raise(NStr("en = 'File not found.'"));
		EndIf;
		FileData = Undefined;
		FileName = AddressDataFile.FullName;
	ElsIf TypeOf(AddressDataFile) = Type("BinaryData") Then // File data.
		FileData = AddressDataFile;
	Else
		Raise(NStr("en = 'Invalid data type'"));
	EndIf;
	
	If IsBlankString(FileName) Then
		FileName = GetTempFileName();
	EndIf;
	
	Return New Structure("Data, Name", FileData, FileName);
	
EndFunction

// Checks whether file transfer from server to client through the file system is possible.
//
// Parameters:
//  Proxy              - WSProxy - FilesTransfer* service proxy.
//  HasVersion2Support - Boolean.
//
// Returns:
//  Boolean.
//
Function CanPassViaFSFromServer(Val Proxy, Val HasVersion2Support)
	
	If Not HasVersion2Support Then
		Return False;
	EndIf;
	
	FileName = Proxy.WriteTestFile();
	If FileName = "" Then 
		Return False;
	EndIf;
	
	Result = ReadTestFile(FileName);
	
	Proxy.DeleteTestFile(FileName);
	
	Return Result;
	
EndFunction

// Checks whether file transfer from client to server through the file system is possible.
//
// Parameters:
//  Proxy              - WSProxy - FilesTransfer* service proxy.
//  HasVersion2Support - Boolean.
//
// Returns:
//  Boolean.
//
Function CanTransferThroughFSToServer(Val Proxy, Val HasVersion2Support)
	
	If Not HasVersion2Support Then
		Return False;
	EndIf;
	
	FileName = WriteTestFile();
	If FileName = "" Then 
		Return False;
	EndIf;
	
	Result = Proxy.ReadTestFile(FileName);
	
	FullFileName = GetCommonTempFilesDir() + FileName;
	DeleteTempFiles(FullFileName);
	
	Return Result;
	
EndFunction

// Creates a directory with a unique name to place their parts of file to be split.
//
// Returns:
//  String - Directory name.
//
Function CreateAssemblyDirectory()
	
	AssemblyDirectory = GetTempFileName();
	CreateDirectory(AssemblyDirectory);
	Return AssemblyDirectory + CommonUseClientServer.PathSeparator();
	
EndFunction

// Reads a test file from the disk comparing content and a name: they must be equal.
// The calling side must delete this file.
//
// Parameters:
//  FileName - String - file name without a path.
//
// Returns:
// Boolean - True, if the file has been read successfully and its content is equal its name.
//
Function ReadTestFile(Val FileName)
	
	FileProperties = New File(GetCommonTempFilesDir() + FileName);
	If FileProperties.Exist() Then
		Text = New TextReader(FileProperties.FullName, TextEncoding.ANSI);
		TestID = Text.Read();
		Text.Close();
		Return TestID = FileProperties.BaseName;
	Else
		Return False;
	EndIf;
	
EndFunction

// Writes the test file to the disk returning its name and size.
// The calling side must delete this file.
//
// Parameters:
//  FileSize - Number.
//
// Returns:
//  String - test file name without a path.
//
Function WriteTestFile() Export
	
	NewID = New UUID;
	FileProperties = New File(GetCommonTempFilesDir() + NewID + ".tmp");
	
	Text = New TextWriter(FileProperties.FullName, TextEncoding.ANSI);
	Text.Write(NewID);
	Text.Close();
	
	Return FileProperties.Name;
	
EndFunction

// Creates an empty structure of the required format.
//
// Returns:
//  Structure:
//   Name     - String - name of file in store;
//   Data     - BinaryData - file data.
// 	FullName - String - file name with path.
//
Function CreateFileDetails()
	
	FileDetails = New Structure;
	FileDetails.Insert("Name");
	FileDetails.Insert("Data");
	FileDetails.Insert("FullName");
	FileDetails.Insert("MandatoryParameters", "Name"); // mandatory parameters to be filled
	Return FileDetails;
	
EndFunction

// Retrieves the WSProxy object of the Web service specified by the base name.
//
// Parameters:
//  ConnectionParameters - Structure:
// 						               URL      - String - service URL. Mandatory to be filled in.
// 						               UserName - String - service user name.
// 						               Password - String - service user password.
// Returns:
//  Structure:
//   Proxy - WSProxy.
//   HasVersion2Support - Boolean.
//
Function FileTransferServiceProxyDetails(Val ConnectionParameters)
	
	BaseServiceName = "FilesTransfer";
	
	SupportedVersionArray = CommonUse.GetInterfaceVersions(ConnectionParameters, "FileTransferService");
	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
		HasVersion2Support = False;
		InterfaceVersion = "1.0.1.1"
	Else
		HasVersion2Support = True;
		InterfaceVersion = "1.0.2.1";
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		And ValueIsFilled(ConnectionParameters.UserName) Then
		
		UserName = ConnectionParameters.UserName;
		UserPassword = ConnectionParameters.Password;
	Else
		UserName = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	If InterfaceVersion = Undefined Or InterfaceVersion = "1.0.1.1" Then // 1st version
		ServiceName = BaseServiceName;
	Else // Version 2 and later
		ServiceName = BaseServiceName + "_" + StrReplace(InterfaceVersion, ".", "_");
	EndIf;
	
	ServiceURL = ConnectionParameters.URL + StringFunctionsClientServer.SubstituteParametersInString("/ws/%1?wsdl", ServiceName);
	
	Proxy = CommonUse.WSProxy(ServiceURL, 
		"http://www.1c.ru/SaaS/1.0/WS", ServiceName, , UserName, UserPassword, 600);
		
	Return New Structure("Proxy, HasVersion2Support", Proxy, HasVersion2Support);
		
EndFunction

Procedure WriteFileStorageEventToLog(Val Event,
	Val FileID, Val Size, Val Duration, Val TransferThroughFileSystem)
	
	EventData = New Structure;
	EventData.Insert("FileID", FileID);
	EventData.Insert("Size", Size);
	EventData.Insert("Duration", Duration);
	
	If TransferThroughFileSystem Then
		EventData.Insert("Transport", "file");
	Else
		EventData.Insert("Transport", "ws");
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'File storage'", CommonUseClientServer.DefaultLanguageCode()) + "." + Event,
		EventLogLevel.Information,
		,
		,
		CommonUse.ValueToXMLString(EventData));
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Temporary files

// Deletes file(s) from disk.
// If a mask with a path is passed as the file name, it is split to the path and the mask.
//
Procedure DeleteTempFiles(Val FileName)
	
	Try
		If Right(FileName, 1) = "*" Then // Mask
			Index = StringFunctionsClientServer.FindCharFromEnd(
				FileName, CommonUseClientServer.PathSeparator());
			If Index > 0 Then
				PathToFile = Left(FileName, Index - 1);
				FileMask = Mid(FileName, Index + 1);
				If FindFiles(PathToFile, FileMask, False).Count() > 0 Then
					DeleteFiles(PathToFile, FileMask);
				EndIf;
			EndIf;
		Else
			FileProperties = New File(FileName);
			If FileProperties.Exist() Then
				FileProperties.SetReadOnly(False); // Clearing the attribute
				DeleteFiles(FileProperties.FullName);
			EndIf;
		EndIf;
	Except
		WriteLogEvent(NStr("en = 'Deleting temporary file'", 
			CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Serialization

Function WriteValueToString(Val Value)
	
	Writer = New XMLWriter;
	Writer.SetString();
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		XDTOFactory.WriteXML(Writer, Value, , , , XMLTypeAssignment.Explicit);
	Else
		XDTOSerializer.WriteXML(Writer, Value, XMLTypeAssignment.Explicit);
	EndIf;
	
	Return Writer.Close();
		
EndFunction

// Shows whether selected type is serializable.
//
// Parameters:
//  StructuralType - Type.
//
// Returns:
//  Boolean.
//
Function StructuralTypeToSerialize(StructuralType);
	
	TypeToSerializeArray = SaaSOperationsCached.StructuralTypesToSerialize();
	
	For Each TypeToSerialize In TypeToSerializeArray Do 
		If StructuralType = TypeToSerialize Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
		
EndFunction

// Gets the XDTO presentation of a structural type object.
//
// Parameters:
//  StructuralTypeValue - Array, Structure, Map, or their fixed analogues.
//
// Returns:
//  Structural XDTO object - XDTO presentation of a structural type object.
//
Function StructuralObjectToXDTODataObject(Val StructuralTypeValue)
	
	StructuralType = TypeOf(StructuralTypeValue);
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The %1 type is not a structural type or its serialization is not supported.'"),
			StructuralType);
		Raise(ErrorMessage);
	EndIf;
	
	XMLValueType = XDTOSerializer.XMLTypeOf(StructuralTypeValue);
	StructuralType = XDTOFactory.Type(XMLValueType);
	XDTOStructure = XDTOFactory.Create(StructuralType);
	
	// Going over valid structural types.
	
	If StructuralType = Type("Structure") or StructuralType = Type("FixedStructure") Then
		
		PropertyType = StructuralType.Properties.Get("Property").Type;
		
		For Each KeyAndValue In StructuralTypeValue Do
			Property = XDTOFactory.Create(PropertyType);
			Property.Name = KeyAndValue.Key;
			Property.Value = TypeValueToXDTOValue(KeyAndValue.Value);
			XDTOStructure.Property.Add(Property);
		EndDo;
		
	ElsIf StructuralType = Type("Array") or StructuralType = Type("FixedArray") Then 
		
		For Each ItemValue In StructuralTypeValue Do
			XDTOStructure.Value.Add(TypeValueToXDTOValue(ItemValue));
		EndDo;
		
	ElsIf StructuralType = Type("Map") or StructuralType = Type("FixedMap") Then
		
		For Each KeyAndValue In StructuralTypeValue Do
			XDTOStructure.Pair.Add(StructuralObjectToXDTODataObject(KeyAndValue));
		EndDo;
	
	ElsIf StructuralType = Type("KeyAndValue")	Then	
		
		XDTOStructure.key = TypeValueToXDTOValue(StructuralTypeValue.Key);
		XDTOStructure.value = TypeValueToXDTOValue(StructuralTypeValue.Value);
		
	ElsIf StructuralType = Type("ValueTable") Then
		
		XDTOVTColumnType = StructuralType.Properties.Get("column").Type;
		
		For Each Column In StructuralTypeValue.Columns Do
			
			XDTOColumn = XDTOFactory.Create(XDTOVTColumnType);
			
			XDTOColumn.Name = TypeValueToXDTOValue(Column.Name);
			XDTOColumn.ValueType = XDTOSerializer.WriteXDTO(Column.ValueType);
			XDTOColumn.Title = TypeValueToXDTOValue(Column.Title);
			XDTOColumn.Width = TypeValueToXDTOValue(Column.Width);
			
			XDTOStructure.Column.Add(XDTOColumn);
			
		EndDo;
		
		XDTOTypeVTIndex = StructuralType.Properties.Get("index").Type;
		
		For Each Index In StructuralTypeValue.Indexes Do
			
			XDTOIndex = XDTOFactory.Create(XDTOTypeVTIndex);
			
			For Each IndexField In Index Do
				XDTOIndex.Column.Add(TypeValueToXDTOValue(IndexField));
			EndDo;
			
			XDTOStructure.Index.Add(XDTOIndex);
			
		EndDo;
		
		XDTOTypeVTRow = StructuralType.Properties.Get("row").Type;
		
		For Each VTRow In StructuralTypeValue Do
			
			XDTORow = XDTOFactory.Create(XDTOTypeVTRow);
			
			For Each ColumnValue In VTRow Do
				XDTORow.Value.Add(TypeValueToXDTOValue(ColumnValue));
			EndDo;
			
			XDTOStructure.Row.Add(XDTORow);
			
		EndDo;
		
	EndIf;
	
	Return XDTOStructure;
	
EndFunction

// Gets a structural type object from the XDTO object.
//
// Parameters:
//  XDTODataObject - XDTO object.
//
// Returns:
//  Structural type - Array, Structure, Map, or their fixed analogues.
// 
Function XDTODataObjectToStructuralObject(XDTODataObject)
	
	XMLDataType = New XMLDataType(XDTODataObject.Type().Name, XDTODataObject.Type().NamespaceURI);
	If CanReadXMLDataType(XMLDataType) Then
		StructuralType = XDTOSerializer.FromXMLType(XMLDataType);
	Else
		Return XDTODataObject;
	EndIf;
	
	If StructuralType = Type("String") Then
		Return "";
	EndIf;
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The %1 type is not a structural type or its serialization is not supported now.'"),
			StructuralType);
		Raise(ErrorMessage);
	EndIf;
	
	If StructuralType = Type("Structure")	or StructuralType = Type("FixedStructure") Then
		
		StructuralObject = New Structure;
		
		For Each Property In XDTODataObject.Property Do
			StructuralObject.Insert(Property.Name, XDTOValueToTypeValue(Property.Value)); 
		EndDo;
		
		If StructuralType = Type("Structure") Then
			Return StructuralObject;
		Else 
			Return New FixedStructure(StructuralObject);
		EndIf;
		
	ElsIf StructuralType = Type("Array") or StructuralType = Type("FixedArray") Then 
		
		StructuralObject = New Array;
		
		For Each ArrayItem In XDTODataObject.Value Do
			StructuralObject.Add(XDTOValueToTypeValue(ArrayItem)); 
		EndDo;
		
		If StructuralType = Type("Array") Then
			Return StructuralObject;
		Else 
			Return New FixedArray(StructuralObject);
		EndIf;
		
	ElsIf StructuralType = Type("Map") or StructuralType = Type("FixedMap") Then
		
		StructuralObject = New Map;
		
		For Each KeyAndValueXDTO In XDTODataObject.pair Do
			KeyAndValue = XDTODataObjectToStructuralObject(KeyAndValueXDTO);
			StructuralObject.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		
		If StructuralType = Type("Map") Then
			Return StructuralObject;
		Else 
			Return New FixedMap(StructuralObject);
		EndIf;
	
	ElsIf StructuralType = Type("KeyAndValue")	Then	
		
		StructuralObject = New Structure("Key, Value");
		StructuralObject.Key = XDTOValueToTypeValue(XDTODataObject.Key);
		StructuralObject.Value = XDTOValueToTypeValue(XDTODataObject.Value);
		
		Return StructuralObject;
		
	ElsIf StructuralType = Type("ValueTable") Then
		
		StructuralObject = New ValueTable;
		
		For Each Column In XDTODataObject.column Do
			
			StructuralObject.Columns.Add(
				XDTOValueToTypeValue(Column.Name), 
				XDTOSerializer.ReadXDTO(Column.ValueType), 
				XDTOValueToTypeValue(Column.Title), 
				XDTOValueToTypeValue(Column.Width));
				
		EndDo;
		For Each Index In XDTODataObject.index Do
			
			IndexString = "";
			For Each IndexField In Index.column Do
				IndexString = IndexString + IndexField + ",";
			EndDo;
			IndexString = TrimAll(IndexString);
			If StrLen(IndexString) > 0 Then
				IndexString = Left(IndexString, StrLen(IndexString) - 1);
			EndIf;
			
			StructuralObject.Indexes.Add(IndexString);
		EndDo;
		For Each XDTORow In XDTODataObject.row Do
			
			VTRow = StructuralObject.Add();
			
			ColumnCount = StructuralObject.Columns.Count();
			For Index = 0 to ColumnCount - 1 Do 
				VTRow[StructuralObject.Columns[Index].Name] = XDTOValueToTypeValue(XDTORow.value[Index]);
			EndDo;
			
		EndDo;
		
		Return StructuralObject;
		
	EndIf;
	
EndFunction

Function CanReadXMLDataType(Val XMLDataType)
	
	Writer= New XMLWriter;
	Writer.SetString();
	Writer.WriteStartElement("Dummy");
	Writer.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Writer.WriteNamespaceMapping("ns1", XMLDataType.NamespaceURI);
	Writer.WriteAttribute("xsi:type", "ns1:" + XMLDataType.TypeName);
	Writer.WriteEndElement();
	
	String = Writer.Close();
	
	Reader = New XMLReader;
	Reader.SetString(String);
	Reader.MoveToContent();
	
	Return XDTOSerializer.CanReadXML(Reader);
	
EndFunction

// Gets the XDTO type value by the platform type value. 
//
// Parameters:
//  TypeValue - Any type value.
//
// Returns:
//  Any type.
// 
Function TypeValueToXDTOValue(Val TypeValue)
	
	If TypeValue = Undefined
		Or TypeOf(TypeValue) = Type("XDTODataObject")
		Or TypeOf(TypeValue) = Type("XDTODataValue") Then
		
		Return TypeValue;
		
	Else
		
		If TypeOf(TypeValue) = Type("String") Then
			XDTOType = XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "string")
		Else
			XMLType = XDTOSerializer.XMLTypeOf(TypeValue);
			XDTOType = XDTOFactory.Type(XMLType);
		EndIf;
		
		If TypeOf(XDTOType) = Type("XDTOObjectType") Then // Structural type value.
			Return StructuralObjectToXDTODataObject(TypeValue);
		Else
			Return XDTOFactory.Create(XDTOType, TypeValue); // UUID, for example.
		EndIf;
		
	EndIf;
	
EndFunction

// Gets the platform type value by the XDTO type value.
//
// Parameters:
//  XDTODataValue - Any XDTO type value.
//
// Returns:
//  Any type.
// 
Function XDTOValueToTypeValue(XDTODataValue)
	
	If TypeOf(XDTODataValue) = Type("XDTODataValue") Then
		Return XDTODataValue.Value;
	ElsIf TypeOf(XDTODataValue) = Type("XDTODataObject") Then
		Return XDTODataObjectToStructuralObject(XDTODataValue);
	Else
		Return XDTODataValue;
	EndIf;
	
EndFunction 

// Fills the area with supplied data when preparing the area to use.
//
// Parameters:
//   DataArea     - number of the data area to be filled.
//   ExportFileID - initial data file ID.
//   Option       - initial data variant.
//   UsageMode    - demo or production.
//
// Returns:
//  String - "Success" or "FatalError".
//
Function ImportDataAreaFromSuppliedData(Val DataArea, Val ExportFileID, Val Option, FatalErrorMessage)
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	DataFileFound = False;
	
	Filter = New Array();
	Filter.Add(New Structure("Code, Value", "ConfigurationName", Metadata.Name));
	Filter.Add(New Structure("Code, Value", "ConfigurationVersion", Metadata.Version));
	Filter.Add(New Structure("Code, Value", "Option", Option));
	Filter.Add(New Structure("Code, Value", "Mode", 
		?(Constants.InfobaseUsageMode.Get() 
			= Enums.InfobaseUsageModes.Demo, 
			"Demo", "Production")));

	Descriptor = SuppliedData.DescriptorSuppliedDataInCache(ExportFileID);
	If Descriptor <> Undefined Then
		If SuppliedData.CharacteristicsCoincide(Filter, Descriptor.Characteristics) Then
			PrototypeData = SuppliedData.SuppliedDataFromCache(ExportFileID);
			ExportFileName = GetTempFileName();
			PrototypeData.Write(ExportFileName);
			DataFileFound = True;
		Else
			FatalErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The specified initial data file does not fit the applied solution configuration.
			|File descriptor: '"),
			SuppliedData.GetDataDescription(Descriptor));
			Return "FatalError";
		EndIf;
	EndIf;
	
	If Not DataFileFound Then
	
		Descriptors = SuppliedData.SuppliedDataDescriptorsFromManager("DataAreaPrototype", Filter);
	
		If Descriptors.Descriptor.Count() = 0 Then
			FatalErrorMessage = 
			NStr("en = 'The service manager has no initial data file for the current applied solution version.'");
			Return "FatalError";
		EndIf;
		
		If Descriptors.Descriptor[0].FileGUID <> ExportFileID Then
			FatalErrorMessage = 
			NStr("en = 'The initial data file in the service manager does not match the file specified in the area preparation message. The area cannot be prepared.'");
			Return "FatalError";
		EndIf;
		
		ExportFileName = GetFileFromServiceManagerStorage(ExportFileID);
			
		If ExportFileName = Undefined Then
			FatalErrorMessage = 
			NStr("en = 'The service manager does not have the required initial data file, probably it has been replaced. The area cannot be prepared.'");
			Return False;
		EndIf;
		
		SuppliedData.SaveSuppliedDataInCache(Descriptors.Descriptor[0], ExportFileName);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUse.SubsystemExists("CloudTechnology.SaaSOperations.DataAreaExportImport") Then
		
		RaiseNoCTLSubsystemException("CloudTechnology.SaaSOperations.DataAreaExportImport");
		
	EndIf;
	
	DataAreaExportImportModule = CommonUseClientServer.CommonModule("DataAreaExportImport");
	
	Try
		
		CommonUse.LockInfobase();
 
		ImportInfobaseUsers = False;
		CollapseUsers = (Not Constants.InfobaseUsageMode.Get() = Enums.InfobaseUsageModes.Demo);
		DataAreaExportImportModule.ImportCurrentDataAreaFromArchive(ExportFileName, ImportInfobaseUsers, CollapseUsers);
	
		CommonUse.UnlockInfobase();
	
	Except
		CommonUse.UnlockInfobase();		
		WriteLogEvent(NStr("en = 'Data area copying'", CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			DeleteFiles(ExportFileName);
		Except
		EndTry;
		
		Raise;
	EndTry;
	
	Try
		DeleteFiles(ExportFileName);
	Except
	EndTry;
	
	Return "Success";

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Checking shared data

// Is called when checking whether shared data can be written.
//
Procedure CheckSharedDataOnWrite(Val Source)
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		
		ExceptionPresentation = NStr("en = 'Access right violation!'", CommonUseClientServer.DefaultLanguageCode());
		
		WriteLogEvent(
			ExceptionPresentation,
			EventLogLevel.Error,
			Source.Metadata());
		
		Raise ExceptionPresentation;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handling auxiliary area data

// Handles the value of a reference type separated with the AuxiliaryDataSeparator separator
// switching session separation while writes it.
//
// Parameters:
//  AuxiliaryDataObject - object of a reference type or ObjectDeletion.
//  Write               - Boolean - flag that shows whether the value of a reference type must 
//                        be written.
//  Delete              - Boolean - flag that shows whether the value of a reference type must
//                        be deleted.
//
Procedure HandleAuxiliaryData(AuxiliaryDataObject, Val Write, Val Delete)
	
	Try
		
		MustRestoreSessionSeparation = False;
		
		If TypeOf(AuxiliaryDataObject) = Type("ObjectDeletion") Then
			ValidatedValue = AuxiliaryDataObject.Ref;
			ReferenceBeingChecked = True;
		Else
			ValidatedValue = AuxiliaryDataObject;
			ReferenceBeingChecked = False;
		EndIf;
		
		If CommonUse.IsSeparatedMetadataObject(ValidatedValue.Metadata(), CommonUseCached.AuxiliaryDataSeparator()) Then
			
			If CommonUseCached.CanUseSeparatedData() Then
				
				// In a separated session, just write the object
				If Write Then
					AuxiliaryDataObject.Write();
				EndIf;
				If Delete Then
					AuxiliaryDataObject.Delete();
				EndIf;
				
			Else
				
				// In a shared session, switch session separation to avoid lock conflict of the sessions
				// where another separator value is set.
				If ReferenceBeingChecked Then
					SeparatorValue = CommonUse.ObjectAttributeValue(ValidatedValue, CommonUseCached.AuxiliaryDataSeparator());
				Else
					SeparatorValue = AuxiliaryDataObject[CommonUseCached.AuxiliaryDataSeparator()];
				EndIf;
				CommonUse.SetSessionSeparation(True, SeparatorValue);
				MustRestoreSessionSeparation = True;
				If Write Then
					AuxiliaryDataObject.Write();
				EndIf;
				If Delete Then
					AuxiliaryDataObject.Delete();
				EndIf;
				
			EndIf;
			
		Else
			
			If Write Then
				AuxiliaryDataObject.Write();
			EndIf;
			If Delete Then
				AuxiliaryDataObject.Delete();
			EndIf;
			
		EndIf;
		
		If MustRestoreSessionSeparation Then
			CommonUse.SetSessionSeparation(False);
		EndIf;
		
	Except
		
		If MustRestoreSessionSeparation Then
			CommonUse.SetSessionSeparation(False);
		EndIf;
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Additional actions when changing session separation.
//
Procedure DataAreaOnChange() Export
	
	ClearAllSessionParametersExceptSeparators();
	
	If CommonUseCached.CanUseSeparatedData() Then
		UsersInternal.AuthenticateCurrentUser();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED DATA GETTING HANDLERS

// Registers supplied data handlers, both daily and total.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "DataAreaPrototype";
	Handler.HandlerCode = "DataAreaPrototype";
	Handler.Handler = SaaSOperations;
	
EndProcedure

// Is called when receiving a new data notification.
// In the procedure body, check whether the application requires this data. If it does, set the
// Import flag.
// 
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//   Import   - Boolean - return value.
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
	If Descriptor.DataType = "DataAreaPrototype" Then
		For Each Characteristic In Descriptor.Properties.Property Do
			If Characteristic.Code = "ConfigurationName" And Characteristic.Value = Metadata.Name Then
				Import = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
		
EndProcedure


// Is called after calling NewDataAvailable, is intended for merging the data.
//
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//   PathToFile - String or Undefined - full name of the file. The file is automatically
//                deleted once the procedure is executed. If the file is not specified in Service Manager, the argument is Undefined.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = "DataAreaPrototype" Then
		HandleSuppliedAppliedSolutionPrototype(Descriptor, PathToFile);
	EndIf;
	
EndProcedure

// The procedure is called if data processing is canceled due to an error
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
	
EndProcedure

Procedure HandleSuppliedAppliedSolutionPrototype(Val Descriptor, Val PathToFile)
	
	If ValueIsFilled(PathToFile) Then
		
		SuppliedData.SaveSuppliedDataInCache(Descriptor, PathToFile);
		
	Else
		
		Filter = New Array;
		For Each Characteristic In Descriptor.Properties.Property Do
			If Characteristic.IsKey Then
				Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
			EndIf;
		EndDo;

		For Each Ref In SuppliedData.SuppliedDataReferencesFromCache(Descriptor.DataType, Filter) Do
		
			SuppliedData.DeleteSuppliedDataFromCache(Ref);
		
		EndDo;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Verifies the metadata structure. Shared data must be protected from writing from sessions
// with separators disabled.
// 
Procedure CheckSharedDataOnUpdate() Export
	
	MetadataVerificationRules = New Map;
	
	MetadataVerificationRules.Insert(Metadata.Constants, "ConstantValueManager.%1");
	MetadataVerificationRules.Insert(Metadata.Catalogs, "CatalogObject.%1");
	MetadataVerificationRules.Insert(Metadata.Documents, "DocumentObject.%1");
	MetadataVerificationRules.Insert(Metadata.BusinessProcesses, "BusinessProcessObject.%1");
	MetadataVerificationRules.Insert(Metadata.Tasks, "TaskObject.%1");
	MetadataVerificationRules.Insert(Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypesObject.%1");
	MetadataVerificationRules.Insert(Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypesObject.%1");
	MetadataVerificationRules.Insert(Metadata.ExchangePlans, "ExchangePlanObject.%1");
	MetadataVerificationRules.Insert(Metadata.ChartsOfAccounts, "ChartOfAccountsObject.%1");
	MetadataVerificationRules.Insert(Metadata.AccountingRegisters, "AccountingRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.AccumulationRegisters, "AccumulationRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.CalculationRegisters, "CalculationRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.InformationRegisters, "InformationRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.ScheduledJobs);
	
	Exceptions = New Array();
	
	Exceptions.Add(Metadata.InformationRegisters.ProgramInterfaceCache);
	Exceptions.Add(Metadata.Constants.InstantMessageSendingLocked);
	
	// StandardSubsystems.DataExchange
	Exceptions.Add(Metadata.InformationRegisters.ExchangeTransportSettings);
	Exceptions.Add(Metadata.InformationRegisters.DataExchangeStates);
	Exceptions.Add(Metadata.InformationRegisters.SuccessfulDataExchangeStates);
	// End StandardSubsystems.DataExchange
	
	If CommonUse.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		Exceptions.Add(Metadata.Catalogs.Find("KeyOperations"));
		Exceptions.Add(Metadata.InformationRegisters.Find("TimeMeasurements"));
	EndIf;
	
	StandardSeparators = New Array;
	StandardSeparators.Add(Metadata.CommonAttributes.DataAreaMainData);
	StandardSeparators.Add(Metadata.CommonAttributes.DataAreaAuxiliaryData);
	
	VerificationProcedures = New Array;
	VerificationProcedures.Add(Metadata.EventSubscriptions.CheckSharedRecordSetOnWrite.Handler);
	VerificationProcedures.Add(Metadata.EventSubscriptions.CheckSharedObjectOnWrite.Handler);
	
	VerificationSubscriptions = New Array;
	For Each EventSubscription In Metadata.EventSubscriptions Do
		If VerificationProcedures.Find(EventSubscription.Handler) <> Undefined Then
			VerificationSubscriptions.Add(EventSubscription);
		EndIf;
	EndDo;
	
	SharedDataIncludingInVerificationSubscriptionsVerificationViolations = New Array();
	MultipleSeparatorObjectSeparationVerificationViolations = New Array();
	
	For Each MetadataVerificationRule In MetadataVerificationRules Do
		
		MetadataObjectsToVerify = MetadataVerificationRule.Key;
		MetadataObjectsTypeConstructor = MetadataVerificationRule.Value;
		
		For Each MetadataObjectToVerify In MetadataObjectsToVerify Do
			
			// 1. Metadata object several separator verification
			
			SeparatorCount = 0;
			For Each StandardSeparator In StandardSeparators Do
				If CommonUse.IsSeparatedMetadataObject(MetadataObjectToVerify, StandardSeparator.Name) Then
					SeparatorCount = SeparatorCount + 1;
				EndIf;
			EndDo;
			
			If SeparatorCount > 1 Then
				MultipleSeparatorObjectSeparationVerificationViolations.Add(MetadataObjectToVerify);
			EndIf;
			
			// 2. Checking whether shared metadata objects are included in the verification event subscription content
			
			If ValueIsFilled(MetadataObjectsTypeConstructor) Then
				
				If Exceptions.Find(MetadataObjectToVerify) <> Undefined Then
					Continue;
				EndIf;
				
				MetadataObjectType = Type(StringFunctionsClientServer.SubstituteParametersInString(
					MetadataObjectsTypeConstructor, MetadataObjectToVerify.Name));
				
				VerificationRequired = True;
				For Each StandardSeparator In StandardSeparators Do
					
					If CommonUse.IsSeparatedMetadataObject(MetadataObjectToVerify, StandardSeparator.Name) Then
						
						VerificationRequired = False;
						
					EndIf;
					
				EndDo;
				
				VerificationProvided = False;
				If VerificationRequired Then
					
					For Each VerificationSubscription In VerificationSubscriptions Do
						
						If VerificationSubscription.Source.ContainsType(MetadataObjectType) Then
							VerificationProvided = True;
						EndIf;
						
					EndDo;
					
				EndIf;
				
				If VerificationRequired And Not VerificationProvided Then
					SharedDataIncludingInVerificationSubscriptionsVerificationViolations.Add(MetadataObjectToVerify);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	ExceptionsToRaise = New Array();
	
	SeparatorText = "";
	For Each StandardSeparator In StandardSeparators Do
		
		If Not IsBlankString(SeparatorText) Then
			SeparatorText = SeparatorText + ",";
		EndIf;
		
		SeparatorText = SeparatorText + StandardSeparator.Name;
		
	EndDo;
	
	If SharedDataIncludingInVerificationSubscriptionsVerificationViolations.Count() > 0 Then
		
		ErrorMessage = "";
		For Each UncontrolledMetadataObject In SharedDataIncludingInVerificationSubscriptionsVerificationViolations Do
			
			If Not IsBlankString(ErrorMessage) Then
				ErrorMessage = ErrorMessage + ",";
			EndIf;
			
			ErrorMessage = ErrorMessage + UncontrolledMetadataObject.FullName();
			
		EndDo;
		
		SubscriptionText = "";
		For Each VerificationSubscription In VerificationSubscriptions Do
			
			If Not IsBlankString(SubscriptionText) Then
				SubscriptionText = SubscriptionText + ",";
			EndIf;
			
			SubscriptionText = SubscriptionText + VerificationSubscription.Name;
			
		EndDo;
		
		ExceptionsToRaise.Add(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'All metadata objects not included in the SL separators content (%1), must be included in the content of event subscriptions (%2) that verify whether shared data cannot be written in separated sessions.
                  |The following metadata objects do not meet the criterion: %3.'"),
			SeparatorText, SubscriptionText, ErrorMessage));
		
	EndIf;
	
	If MultipleSeparatorObjectSeparationVerificationViolations.Count() > 0 Then
		
		ErrorMessage = "";
		
		For Each BreakingMetadataObject In MultipleSeparatorObjectSeparationVerificationViolations Do
			
			If Not IsBlankString(ErrorMessage) Then
				ErrorMessage = ErrorMessage + ",";
			EndIf;
			
			ErrorMessage = ErrorMessage + BreakingMetadataObject.FullName();
			
		EndDo;
		
		ExceptionsToRaise.Add(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'All applied solution metadata object can be separated only with one SL separator (%1).
                  |The following objects do not meet the criterion: %2'"),
			SeparatorText, ErrorMessage));
		
	EndIf;
	
	ResultException = "";
	Iterator = 1;
	
	For Each ExceptionToRaise In ExceptionsToRaise Do
		
		If Not IsBlankString(ResultException) Then
			ResultException = ResultException + Chars.LF + Chars.CR;
		EndIf;
		
		ResultException = ResultException + Format(Iterator, "NFD=0; NG=0") + "." + ExceptionToRaise;
		Iterator = Iterator + 1;
		
	EndDo;
	
	If Not IsBlankString(ResultException) Then
		
		ResultException = NStr("en = 'The following errors are found in the applied solution metadata structure:'") + Chars.LF + Chars.CR + ResultException;
		Raise ResultException;
		
	EndIf;
	
EndProcedure

// Verifies the metadata structure. Common data must be ordered in the configuration metadata tree.
// 
Procedure CheckSeparatorsOnUpdate() Export
	
	AppliedDataOrder = 99;
	InternalDataOrder = 99;
	
	AppliedSeparator = Metadata.CommonAttributes.DataAreaMainData;
	InternalSeparator = Metadata.CommonAttributes.DataAreaAuxiliaryData;
	
	Iterator = 0;
	For Each CommonConfigurationAttribute In Metadata.CommonAttributes Do
		
		If CommonConfigurationAttribute = AppliedSeparator Then
			AppliedDataOrder = Iterator;
		ElsIf CommonConfigurationAttribute = InternalSeparator Then
			InternalDataOrder = Iterator;
		EndIf;
		
		Iterator = Iterator + 1;
		
	EndDo;
	
	If AppliedDataOrder <= InternalDataOrder Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Configuration metadata structure violation is detected: the %1 common attribute must be placed before the %2 common attribute in the configuration metadata tree.'"),
			InternalSeparator.Name,
			AppliedSeparator.Name);
		
	EndIf;
	
EndProcedure

// Returns the earliest 1C:Cloud technology library version supported by the current SL version.
//
// Returns: String - earliest supported CTL version in the following format: RR.SS.VV.BB.
//
Function RequiredCTLVersion()
	
	Return "1.0.2.1";
	
EndFunction

#EndRegion
