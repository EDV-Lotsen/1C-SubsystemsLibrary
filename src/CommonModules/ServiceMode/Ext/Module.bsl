///////////////////////////////////////////////////////////////////////////////////
// ServiceMode.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Clears all session parameters, except related with the DataArea 
// common attribute.
//
Procedure ClearAllSessionParametersExceptSeparators() Export
	
	CommonUse.ClearSessionParameters(, "DataAreaValue,UseDataArea");
	
EndProcedure

// Sets managed lock to lock namespaces of all
// objects, that is a part of the separator, and shared information registers, 
// that stores separated data (by the current separator value).
// Optional, checks if there are any other user sessions
// in the current data area.
// Can be used only in transaction.
// Can be used only if separation is enabled and the separator value 
// is set.
// 
// Parameters: 
// CheckNoOtherSessions - Boolean - flag that shows whether presense of other
// user sessions which separator value is equal to the current one must be checked.
// If other sessions are found an exception will be raised.
// SeparatedDataLock - Boolean - flag that shows whether the separated data lock 
// must be set instead of the exclusive data lock.
//
Procedure LockCurrentDataArea(Val CheckNoOtherSessions = False, Val SeparatedDataLock = False) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Raise(NStr("en = 'Lock of data area can be set only if data separation is enabled"));
	EndIf;
	
	If SeparatedDataLock Then
		LockMode = DataLockMode.Shared;
	Else
		LockMode = DataLockMode.Exclusive;
	EndIf;
	
	DataLock = New DataLock;
	
	CommonAttributeMD = Metadata.CommonAttributes.DataArea;
	
	// Constants
	For Each MetadataConstants In Metadata.Constants Do
		If Not CommonUse.IsSeparatedMetadataObject(MetadataConstants) Then
			Continue;
		EndIf;
		
		LockItem = DataLock.Add(MetadataConstants.FullName());
		LockItem.Mode = LockMode;
	EndDo;
	
	// Reference types
	
	ObjectKinds = New Array;
	ObjectKinds.Add("Catalogs");
	ObjectKinds.Add("Documents");
	ObjectKinds.Add("ChartsOfCharacteristicTypes");
	ObjectKinds.Add("ChartsOfAccounts");
	ObjectKinds.Add("ChartsOfCalculationTypes");
	ObjectKinds.Add("BusinessProcesses");
	ObjectKinds.Add("Tasks");
	ObjectKinds.Add("ExchangePlans");
	
	For Each ObjectKind In ObjectKinds Do
		MetadataCollection = Metadata[ObjectKind];
		For Each ObjectMD In MetadataCollection Do
			If Not CommonUse.IsSeparatedMetadataObject(ObjectMD) Then
				Continue;
			EndIf;
			
			LockItem = DataLock.Add(ObjectMD.FullName());
			LockItem.Mode = LockMode;
		EndDo;
	EndDo;
	
	// Registers and sequences
	TableKinds = New Array;
	TableKinds.Add("AccumulationRegisters");
	TableKinds.Add("CalculationRegisters");
	TableKinds.Add("AccountingRegisters");
	TableKinds.Add("InformationRegisters");
	TableKinds.Add("Sequences");
	For Each TableKind In TableKinds Do
		MetadataCollection = Metadata[TableKind];
		KindManager = Eval(TableKind);
		For Each RegisterMD In MetadataCollection Do
			If Not CommonUse.IsSeparatedMetadataObject(RegisterMD) Then
				Continue;
			EndIf;
			
			LockSets = True;
			If TableKind = "InformationRegisters"
				And RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				
				LockSets = False;
			EndIf;
			
			If LockSets Then
				LockItem = DataLock.Add(RegisterMD.FullName() + ".RecordSet");
			Else
				LockItem = DataLock.Add(RegisterMD.FullName());
			EndIf;
			LockItem.Mode = LockMode;
			
			If TableKind = "Sequences" Then
				LockItem = DataLock.Add(RegisterMD.FullName() + ".Records");
				LockItem.Mode = LockMode;
			EndIf;
		EndDo;
	EndDo;
	
	SeparatorValue = CommonUse.SessionSeparatorValue();
	
	// Exchange plans
	For Each ObjectMD In Metadata.ExchangePlans Do
		If Not CommonUse.IsSeparatedMetadataObject(ObjectMD) Then
			Continue;
		EndIf;
		
		LockItem = DataLock.Add(ObjectMD.FullName());
		LockItem.Mode = LockMode;
	EndDo;
	
	// Shared information registers with separated data
	SharedRegisters = SharedInformationRegistersWithSeparatedData();
	
	For Each RegisterName In SharedRegisters Do
		LockItem = DataLock.Add("InformationRegister." + RegisterName);
		LockItem.SetValue("DataArea", SeparatorValue);
		LockItem.Mode = LockMode;
	EndDo;
	
	DataLock.Lock();
	
	If CheckNoOtherSessions Then
		For Each Session In GetInfoBaseSessions() Do
			If Session.SessionNumber = InfoBaseSessionNumber() Then
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
			
			// There are other users
			Raise(NStr("en = 'Error accessing the infobase in separated mode'"));
		EndDo;
	EndIf;
	
EndProcedure

// Returns names of shared information registers, that store 
// separated data (related to a certain data area)
// 
// Returns: 
// Array of String.
// Names of information registers with separated data.
// 
Function SharedInformationRegistersWithSeparatedData() Export
	
	SharedRegisters = New Array;
	
	StandardSubsystemsOverridable.GetSharedInformationRegistersWithSeparatedData(SharedRegisters);
	ServiceModeOverridable.GetSharedInformationRegistersWithSeparatedData(SharedRegisters);
	
	Return SharedRegisters;
	
EndFunction

// Prepares the data area to use. Starts
// Infobase update procedures; if nececcary, fills Infobase with demo
// data; sets a new state in the DataAreas register.
// 
// Parameters: 
// DataArea - Separator value type - separator
// value of data area to be prepared.
//
Procedure PrepareDataAreaToUse(Val DataArea, Val ExportFileID = Undefined) Export
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to execute the action'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = InformationRegisters.DataAreas.CreateRecordKey(New Structure("DataArea", DataArea));
	LockDataForEdit(AreaKey);
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataArea", DataArea);
		Item.Mode = DataLockMode.Shared;
		DataLock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataArea = DataArea;
		RecordManager.Read();
		
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = '%1 data area is not found'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea);
			Raise(MessageText);
		ElsIf RecordManager.State <> Enums.DataAreaStates.New Then
			MessagePattern = NStr("en = '%1 data area is not a new one'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea);
			Raise(MessageText);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data area preparation'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
	Users.AuthenticateCurrentUser();
	
	If ExportFileID <> Undefined Then
		ExportFileName = GetFileFromServiceManagerStorage(ExportFileID);
		
		DataImportExport.ImportCurrentAreaFromArchive(ExportFileName);
		Try
			DeleteFiles(ExportFileName);
		Except
			WriteLogEvent(NStr("en = 'Data area preparation'"), 
				EventLogLevel.Warning, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
	Else
		If Constants.InfoBaseUsageMode.Get() = Enums.InfoBaseUsageModes.Demo
			or Constants.CopyDataAreasFromPrototype.Get() Then
			
			CopyAreaData(0, DataArea);
		EndIf;
	EndIf;
	
	InfoBaseUpdate.ExecuteInfoBaseUpdate(ExportFileID <> Undefined);
	
	RecordManager.State = Enums.DataAreaStates.Used;
	
	// Sending a message to the service manager, that the data area is prepared 
	Message = RemoteAdministrationMessages.NewMessage(
		RemoteAdministrationMessagesCached.MessageDataAreaPrepared());
	Message.DataArea = DataArea;
	
	BeginTransaction();
	Try
		RemoteAdministrationMessages.SendMessage(
			Message,
			ServiceModeCached.ServiceManagerEndPoint());
		
		RecordManager.Write();
		
		UnlockDataForEdit(AreaKey);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data area preparation'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Copies area data into another area.
// 
// Parameters: 
// SourceArea - Separator value type - value of 
// sourse data area separator
// DestinationArea - Separator value type - value of 
// a destination data area separator
//
Procedure CopyAreaData(Val SourceArea, Val DestinationArea) Export
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to execute the action'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, SourceArea);
	
	ExportFileName = Undefined;
	
	BeginTransaction();
	Try
		LockCurrentDataArea(, True);
		ExportFileName = DataImportExport.ExportCurrentAreaToArchive();
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data area copying'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		If ExportFileName <> Undefined Then
			Try
				DeleteFiles(ExportFileName);
			Except
			EndTry;
		EndIf;
		Raise;
	EndTry;
	
	CommonUse.SetSessionSeparation(, DestinationArea);
	
	BeginTransaction();
	Try
		LockCurrentDataArea();
		DataImportExport.ImportCurrentAreaFromArchive(ExportFileName);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data area copying'"), 
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

// Clears all area data except predefined ones.
// Furthermore, clears data area users and shared information
// register data that is related to the area.
// 
// Parameters: 
// DataArea - Separator value type - separator
// value of data area to be cleared.
//
Procedure ClearDataArea(Val DataArea) Export
	
	If Not Users.InfoBaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to execute the action'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = InformationRegisters.DataAreas.CreateRecordKey(New Structure("DataArea", DataArea));
	LockDataForEdit(AreaKey);
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataArea", DataArea);
		Item.Mode = DataLockMode.Shared;
		DataLock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataArea = DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = '%1 data area is not found'");
			Raise(MessagePattern);
		ElsIf RecordManager.State <> Enums.DataAreaStates.ToDelete Then
			MessagePattern = NStr("en = '%1 data area is not marked for deletion'");
			Raise(MessagePattern);
		EndIf;
		
		CommonUse.SetSessionSeparation(True, DataArea);
		
		StandardSubsystemsOverridable.OnDeleteDataArea(DataArea);
		ServiceModeOverridable.OnDeleteDataArea(DataArea);
		
		CommonAttributeMD = Metadata.CommonAttributes.DataArea;
		
		// Going over all metadata
		
		// Constants
		For Each MetadataConstants In Metadata.Constants Do
			If Not CommonUse.IsSeparatedMetadataObject(MetadataConstants) Then
				Continue;
			EndIf;
			
			ValueManager = Constants[MetadataConstants.Name].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.Value = MetadataConstants.Type.AdjustValue();
			ValueManager.Write();
		EndDo;
		
		// Reference types
		
		ObjectKinds = New Array;
		ObjectKinds.Add("Catalogs");
		ObjectKinds.Add("Documents");
		ObjectKinds.Add("ChartsOfCharacteristicTypes");
		ObjectKinds.Add("ChartsOfAccounts");
		ObjectKinds.Add("ChartsOfCalculationTypes");
		ObjectKinds.Add("BusinessProcesses");
		ObjectKinds.Add("Tasks");
		
		For Each ObjectKind In ObjectKinds Do
			MetadataCollection = Metadata[ObjectKind];
			For Each ObjectMD In MetadataCollection Do
				If Not CommonUse.IsSeparatedMetadataObject(ObjectMD) Then
					Continue;
				EndIf;
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	_XMLExport_Table.Ref AS Ref
				|FROM
				|	" + ObjectMD.FullName() + " AS _XMLExport_Table";
				If ObjectKind = "Catalogs"
					Or ObjectKind = "ChartsOfCharacteristicTypes"
					Or ObjectKind = "ChartsOfAccounts"
					Or ObjectKind = "ChartsOfCalculationTypes" Then
					
					Query.Text = Query.Text + "
					|WHERE
					|	_XMLExport_Table.Predefined = FALSE";
				EndIf;
				
				QueryResult = Query.Execute();
				Selection = QueryResult.Choose();
				While Selection.Next() Do
					Delete = New ObjectDeletion(Selection.Ref);
					Delete.DataExchange.Load = True;
					Delete.Write();
				EndDo;
			EndDo;
		EndDo;
		
		// Registers and sequences except independent information registers
		TableKinds = New Array;
		TableKinds.Add("AccumulationRegisters");
		TableKinds.Add("CalculationRegisters");
		TableKinds.Add("AccountingRegisters");
		TableKinds.Add("InformationRegisters");
		TableKinds.Add("Sequences");
		For Each TableKind In TableKinds Do
			MetadataCollection = Metadata[TableKind];
			KindManager = Eval(TableKind);
			For Each RegisterMD In MetadataCollection Do
				If Not CommonUse.IsSeparatedMetadataObject(RegisterMD) Then
					Continue;
				EndIf;
				
				If TableKind = "InformationRegisters"
					And RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					Continue;
				EndIf;
				
				TypeManager = KindManager[RegisterMD.Name];
				
				Query = New Query;
				Query.Text =
				"SELECT DISTINCT
				|	_XMLExport_Table.Recorder AS Recorder
				|FROM
				|	" + RegisterMD.FullName() + " AS _XMLExport_Table";
				QueryResult = Query.Execute();
				Selection = QueryResult.Choose();
				While Selection.Next() Do
					RecordSet = TypeManager.CreateRecordSet();
					RecordSet.Filter.Recorder.Set(Selection.Recorder);
					RecordSet.DataExchange.Load = True;
					RecordSet.Write();
				EndDo; 
			EndDo;
		EndDo;
		
		// Independent information registers
		For Each RegisterMD In Metadata.InformationRegisters Do
			If Not CommonUse.IsSeparatedMetadataObject(RegisterMD) Then
				Continue;
			EndIf;
			
			If RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
				
				Continue;
			EndIf;
			
			TypeManager = InformationRegisters[RegisterMD.Name];
			
			RecordSet = TypeManager.CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			RecordSet.Write();
		EndDo;
		
		// Exchange plans
		
		For Each ExchangePlanMD In Metadata.ExchangePlans Do
			If Not CommonUse.IsSeparatedMetadataObject(ExchangePlanMD) Then
				Continue;
			EndIf;
			
			TypeManager = ExchangePlans[ExchangePlanMD.Name];
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + ExchangePlanMD.FullName() + " AS _XMLExport_Table
			|WHERE
			|	_XMLExport_Table.Ref <> &ThisNode";
			Query.SetParameter("ThisNode", TypeManager.ThisNode());
			QueryResult = Query.Execute();
			Selection = QueryResult.Choose();
			While Selection.Next() Do
				Delete = New ObjectDeletion(Selection.Ref);
				Delete.DataExchange.Load = True;
				Delete.Write();
			EndDo;
		EndDo;
		
		// Shared information registers with separated Data
		SharedRegisters = SharedInformationRegistersWithSeparatedData();
		
		For Each RegisterName In SharedRegisters Do
			TypeManager = InformationRegisters[RegisterName];
			
			RecordSet = TypeManager.CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			RecordSet.Filter.DataArea.Set(DataArea);
			RecordSet.Write();
		EndDo;
		
		// Users
		For Each InfoBaseUser In InfoBaseUsers.GetUsers() Do
			InfoBaseUser.Delete();
		EndDo;
		
		RecordManager.State = Enums.DataAreaStates.Deleted;
		
		// Sending a message to the service manager, that the data area is deleted
		Message = RemoteAdministrationMessages.NewMessage(
			RemoteAdministrationMessagesCached.MessageDataAreaDeleted());
		Message.DataArea = DataArea;
		RemoteAdministrationMessages.SendMessage(
			Message,
			ServiceModeCached.ServiceManagerEndPoint());
		
		RecordManager.Write();
		
		UnlockDataForEdit(AreaKey);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data area clearing'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// The procedure of the scheduled job with the same name.
// Finds all data areas with states, required to be processed
// by the application, and, if necessary, plans 
// a maintenance background job startup.
//
Procedure DataAreaMaintenance() Export
	
	MaxRetryCount = 3;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataArea AS DataArea,
	|	DataAreas.State AS State,
	|	DataAreas.ExportID AS ExportID
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.State IN (VALUE(Enumeration.DataAreaStates.New), VALUE(Enum.DataAreaStates.ToDelete))
	|	And DataAreas.ProcessingError = FALSE
	|
	|ORDER BY
	|	DataArea";
	Result = Query.Execute();
	Selection = Result.Choose();
	
	Executing = 0;
	
	While Selection.Next() Do
		
		CommonUse.SetSessionSeparation(True, Selection.DataArea);
		
		Key = InformationRegisters.DataAreas.CreateRecordKey(New Structure("DataArea", Selection.DataArea));
		
		Try
			LockDataForEdit(Key);
		Except
			Continue;
		EndTry;
		
		Manager = InformationRegisters.DataAreas.CreateRecordManager();
		Manager.DataArea = Selection.DataArea;
		Manager.Read();
		
		If Manager.State = Enums.DataAreaStates.New Then 
			MethodName = "ServiceMode.PrepareDataAreaToUse";
		ElsIf Manager.State = Enums.DataAreaStates.ToDelete Then 
			MethodName = "ServiceMode.ClearDataArea";
		Else
			UnlockDataForEdit(Key);
			Continue;
		EndIf;
		
		If Manager.Repeat < MaxRetryCount Then
		
			JobFilter = New Structure;
			JobFilter.Insert("MethodName", MethodName);
			JobFilter.Insert("Key" , "1");
			ScheduledJob = JobQueue.GetJob(JobFilter, Selection.DataArea);
			If ScheduledJob <> Undefined Then
				UnlockDataForEdit(Key);
				Continue;
			EndIf;
			
			Manager.Repeat = Manager.Repeat + 1;
			Manager.Write();

			MethodParameters = New Array;
			MethodParameters.Add(Selection.DataArea);
			
			If Selection.State = Enums.DataAreaStates.New
				And ValueIsFilled(Selection.ExportID) Then
				
				MethodParameters.Add(Selection.ExportID);
			EndIf;
			
			UnlockDataForEdit(Key);
			
			JobQueue.ScheduleJobExecution(MethodName, MethodParameters, "1",, Selection.DataArea);
		Else
			
			// Sending a message to the service manager, that the data area is prepared 
			If Manager.State = Enums.DataAreaStates.New Then
				Message = RemoteAdministrationMessages.NewMessage(
					RemoteAdministrationMessagesCached.MessageErrorPreparingDataArea());
			Else
				Message = RemoteAdministrationMessages.NewMessage(
					RemoteAdministrationMessagesCached.MessageErrorDeletingDataArea());
			EndIf;
			Message.DataArea = Manager.DataArea;
			Message.ErrorDescription = "";
			
			BeginTransaction();
			Try
				Manager.ProcessingError = True;
				Manager.Write();
				
				RemoteAdministrationMessages.SendMessage(
					Message,
					ServiceModeCached.ServiceManagerEndPoint());
					
				UnlockDataForEdit(Key);
					
				CommitTransaction();
			Except
				RollbackTransaction();
				WriteLogEvent(NStr("en = 'Data area maintenance'"), 
					EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
				Raise;
			EndTry;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns a web service proxy to synchronize administrative actions
// in service mode.
// 
// Returns: 
// WSProxy.
// Service manager proxy.
// 
Function GetServiceManagerProxy() Export
	
	ServiceManagerAddress = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en = 'Parameters of connection with service manager are not specified.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerAddress + "/ws/ManagementApplication?wsdl";
	UserName = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();
	
	Proxy = CommonUseCached.GetWSProxy(ServiceAddress, "http://1c-dn.com/SaaS/1.0/WS",
		"ManagementApplication", , UserName, UserPassword);
		
	Return Proxy;
	
EndFunction

// Sets session seperation.
//
// Parameters:
// Use - Boolean - usage of the DataArea separator in the session
// DataArea - Number - DataArea separator value
//
Procedure SetSessionSeparation(Val Use = Undefined, Val DataArea = Undefined) Export
	
	If Not CommonUseCached.SessionWithoutSeparator() Then
		Raise(NStr("en = 'Changing separation settings is only allowed from sessions started without separation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Use <> Undefined Then
		SessionParameters.UseDataArea = Use;
	EndIf;
	
	If DataArea <> Undefined Then
		SessionParameters.DataAreaValue = DataArea;
	EndIf;
	
	StandardSubsystemsOverridable.DataAreaOnChange();
	
EndProcedure

// Returns a value of the current data area separator.
// If the value is not set an error is raised.
// 
// Returns: 
// Separator value type.
// Value of the current data area separator.
// 
Function SessionSeparatorValue() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return 0;
	Else
		If Not CommonUse.UseSessionSeparator() Then
			Raise(NStr("en = 'Separator value is not specified.'"));
		EndIf;
		
		// Getting value of the current data area separator
		SetPrivilegedMode(True);
		Return SessionParameters.DataAreaValue;
	EndIf;
	
EndFunction

// Returns the flag that shows whether DataArea separator is used.
// 
// Returns: 
// Boolean - True if separation is used, otherwise returns False.
//
Function UseSessionSeparator() Export
	
	SetPrivilegedMode(True);
	Return SessionParameters.UseDataArea;
	
EndFunction

// Adds extra parameters to the client parameter structure 
// when runs is service mode.
//
// Parameters:
// Parameters - Structure - client parameter structure
//
Procedure AddClientParametersServiceMode(Val Parameters) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Parameters.Insert("ShowUpdateDetails", 
			InfoBaseUpdate.ShowUpdateDetails());
			
		Query = New Query;
		Query.Text =
		"SELECT
		|	DataAreas.Presentation AS Presentation
		|FROM
		|	InformationRegister.DataAreas AS DataAreas
		|WHERE
		|	DataAreas.DataArea = &DataArea";
		SetPrivilegedMode(True);
		Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
		Result = Query.Execute();
		SetPrivilegedMode(False);
		If Not Result.IsEmpty() Then
			Selection = Result.Choose();
			Selection.Next();
			If Not IsBlankString(Selection.Presentation) Then
				Parameters.Insert("DataAreaPresentation", Selection.Presentation);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Adds parameter details to the patameter table by the constant name.
// Returns the added parameter.
//
// Parameters: 
// ParameterTable - value table - Infobase parameter description table
// ConstantName - String - name of constant to be added to 
// the Infobase parameter table.
//
// Returns: 
// Value table row.
// Row that contains the added parameter details.
// 
Function AddConstantToInfoBaseParameterTable(Val ParameterTable, Val ConstantName) Export
	
	MetadataConstants = Metadata.Constants[ConstantName];
	
	ParameterRow = ParameterTable.Add();
	ParameterRow.Name = MetadataConstants.Name;
	ParameterRow.Details = MetadataConstants.Presentation();
	ParameterRow.Type = MetadataConstants.Type;
	
	Return ParameterRow;
	
EndFunction

// Returns the Infobase parameter description table
//
// Returns: 
// Value table.
// Table that describes Infobase parameters.
// Columns:
// Name - String - parameter name;
// Details - String - parameter description for displaying in the user interface
// ReadProhibition - Boolean - flag that shows whether reading of Infobase parameter is prohibited. Can be set,
// for example, for passwords.
// WriteProhibition - Boolean - flag that shows whether changing of Infobase parameter is prohibited.
// Type - Type details - parameter value type. It is allowed to use only primitive
// types and enums, that is in the configuration, used to manage this configuration.
//
Function GetInfoBaseParameterTable() Export
	
	ParameterTable = GetEmptyInfoBaseParameterTable();
	
	StandardSubsystemsOverridable.GetInfoBaseParameterTable(ParameterTable);
	
	ServiceModeOverridable.GetInfoBaseParameterTable(ParameterTable);
	
	Return ParameterTable;
	
EndFunction

// Gets file details by its ID in the Files register.
// If the file is stored on a hard disk and PathNotData = True, 
// then in the returned structure: Data = Undefined, FullName = full name of the file,
// else Data is a binary data of the file, FullName = Undefined.
// The Name key value always contains a name, that it is in the storage.
//
// Parameters:
// FileID - UUID.
// ConnectionParameters - Structure:
//							- URL - String - service URL. It must be supplied and cannot be empty.
//							- UserName - String - service user name.
//							- Password - String - service user password.
// PathNotData - Boolean - flag that shows what should be returned. 
//		
// Returns:
// FileDetails - Structure:
//	Name - String - file name in the storage.
//	Data - BinaryData - file data.
//	FullName - String - full name of the file.
//			 - The file will be automatically deleted at the expiration of the temporary file storing period.
//
Function GetFileFromStorage(Val FileID, Val ConnectionParameters, Val PathNotData = False) Export
	
	// Considering the versioning.
	SupportedVersionArray = CommonUse.GetInterfaceVersions(ConnectionParameters, "FileTransferServer");
	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
		HasVersion2Support = False;
		Proxy = GetServiceConnectionProxy(ConnectionParameters, "FilesTransfer", "1.0.1.1");
	Else
		HasVersion2Support = True;
		Proxy = GetServiceConnectionProxy(ConnectionParameters, "FilesTransfer", "1.0.2.1");
	EndIf;
	
	ExchangeOverFS = CanPassViaFSFromServer(Proxy, HasVersion2Support);
	
	If ExchangeOverFS Then
			
		Try
			FileName = Proxy.WriteFileToFS(FileID);
			FileProperties = New File(GetCommonTempFilesDir() + FileName);
			If FileProperties.Exist() Then
				FileDetails = CreateFileDetails();
				FileDetails.Name = FileProperties.Name;
				
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
				
				Return FileDetails;
			Else
				ExchangeOverFS = False;
			EndIf;
		Except
			WriteLogEvent(NStr("en = 'Getting file from storage'"),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
			
	EndIf; // ExchangeOverFS
	
	PartCount = Undefined;
	FileNameInCatalog = Undefined;
	FileTransferBlockSize = GetFileTransferBlockSize();
	If HasVersion2Support Then
		TransferID = Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, PartCount);
	Else
		TransferID = Undefined;
		Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, TransferID, PartCount);
	EndIf;
	
	FileNames = New Array;
	
	AssemblyDirectory = CreateAssemblyDirectory();
	
	If HasVersion2Support Then
		For PartNumber = 1 to PartCount Do
			PartData = Proxy.GetFilePart(TransferID, PartNumber, PartCount);
			FileNamePart = AssemblyDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	Else // Version 1.
		For PartNumber = 1 to PartCount Do
			PartData = Undefined;
			Proxy.GetFilePart(TransferID, PartNumber, PartData);
			FileNamePart = AssemblyDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	EndIf;
	PartData = Undefined;
	
	Proxy.ReleaseFile(TransferID);

	ArchiveName = GetTempFileName("zip");
	
	MergeFiles(FileNames, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	If Dearchiver.Items.Count() > 1 Then
		Raise(NStr("en = 'There is more than one file in the received archive'"));
	EndIf;
	
	FileName = AssemblyDirectory + Dearchiver.Items[0].Name;
	Dearchiver.Extract(Dearchiver.Items[0], AssemblyDirectory);
	Dearchiver.Close();
	
	ResultFile = New File(GetTempFileName());
	MoveFile(FileName, ResultFile.FullName);
	
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
	
	Return FileDetails;
	
EndFunction

// Gets the application name, as it has been specified by a subscriber.
//
// Returns - String - Application name.
//
Function GetApplicationName() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	 |	DataAreas.Presentation
	 |FROM
	 |	InformationRegister.DataAreas AS DataAreas
	 |WHERE
	 |	DataAreas.DataArea = &DataArea";
	Query.SetParameter("DataArea", SessionParameters.DataAreaValue);
	
	DataAreaTable = Query.Execute().Unload();
	
	Return ?(DataAreaTable.Count() = 0, "", DataAreaTable.Get(0).Get(0));
	
EndFunction

// Returns a full path to the temporary file directory.
//
// Returns:
// String - full path to the temporary file directory.
//
Function GetCommonTempFilesDir() Export
	
	SetPrivilegedMode(True);
	
	SystemInfo = New SystemInfo;
	If SystemInfo.PlatformType = PlatformType.Linux_x86
		or SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		
		CommonTempDirectory = Constants.CommonTempFilesDirLinux.Get();
		PathSeparator = "/";
	Else
		CommonTempDirectory = Constants.CommonTempFilesDir.Get();
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

// Returns the block size in MB to transfer a large file in parts.
//
Function	GetFileTransferBlockSize() Export
	
	SetPrivilegedMode(True);
	
	FileTransferBlockSize = Constants.FileTransferBlockSize.Get(); // MB
	If Not ValueIsFilled(FileTransferBlockSize) Then
		FileTransferBlockSize = 20;
	EndIf;
	Return FileTransferBlockSize;

EndFunction

// Returns the file system path separator, which depends on the operating system: Windows/Linux.
//
// Returns:
// String.
//
Function GetFileSystemPathSeparator() Export
	
	SystemInfo = New SystemInfo;
	
	If SystemInfo.PlatformType = PlatformType.Linux_x86
		or SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		
		Return "/";
	Else
		Return "\";
	EndIf;
	
EndFunction

// Gets the WSProxy object of the file transfer web service.
//
// Parameters:
// ConnectionParameters - Structure:
//							- URL - String - service URL. Required to be and to be filled.
//							- UserName - String - Name of a service user.
//							- Password - String - Password of aservice user.
// BaseServiceName - String - name of web service basic version. Examples: "FilesTransfer", "ManageAgent". 
// InterfaceVersioning - String - service version number, access to which is required.
//
// Returns:
// WSProxy.
//
Function GetServiceConnectionProxy(Val ConnectionParameters, Val BaseServiceName, Val InterfaceVersioning) Export
	
	If Not ConnectionParameters.Property("URL") 
		or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("en = 'Service agent address is not specified.'"));
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		And ValueIsFilled(ConnectionParameters.UserName) Then
		
		UserName = ConnectionParameters.UserName;
		UserPassword = ConnectionParameters.Password;
	Else
		UserName = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	If InterfaceVersioning = Undefined or InterfaceVersioning = "1.0.1.1" Then // Version 1.
		ServiceName = BaseServiceName;
	Else // Version 2 and later.
		ServiceName = BaseServiceName + "_" + StrReplace(InterfaceVersioning, ".", "_");
	EndIf;
	
	// Getting proxy of working with files.
	
	ServiceAddress = ConnectionParameters.URL + StringFunctionsClientServer.SubstituteParametersInString("/ws/%1?wsdl", ServiceName);
	
	Return CommonUseCached.GetWSProxy(ServiceAddress, 
		"http://1c-dn.com/SaaS/1.0/WS", ServiceName, , UserName, UserPassword);
		
EndFunction

// Serializes a structural type object.
//
// Parameters:
// StructuralTypeValue - Array, structure, map or their fixed analogues.
//
// Returns:
// String - serialized value of a structural type object.
//
Function WriteStructuralXDTOObjectToString(Val StructuralTypeValue) Export
	
	XDTODataObject = StructuralObjectToXDTOObject(StructuralTypeValue);
	
	Return WriteValueToString(XDTODataObject);
	
EndFunction

// Encodes a string value using the base64 algorithm
//
// Parameters:
// String - String.
//
// Returns:
// String - Base64 presentation.
Function StringToBase64(Val String) Export
	
	Storage = New ValueStorage(String, New Deflation(9));
	
	Return XMLString(Storage);
	
EndFunction

// Decodes Base64 presentation of the string into the original value.
//
// Parameters:
// Base64String - String.
//
// TheReturn Value:
// String.
//
Function Base64ToString(Val Base64String) Export
	
	Storage = XMLValue(Type("ValueStorage"), Base64String);
	
	Return Storage.Get();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Deletes selected sessions and terminates connections via service agent for the current Infobase.
// Sessions are set by numbers in the input array or by a single number.
//
// Parameters:
// SessionsToDelete - Array; Number - array of sessions numbers or a single number of a session.
// InfoBaseAdministrationParameters - Structure with the following fields:
// 	 InfoBaseAdministratorName - String.
//	 InfoBaseAdministratorPassword - String.
//	 ClusterAdministratorName - String.
//	 ClusterAdministratorPassword - String.
//	 ServerClusterPort - Number.
//	 ServerAgentPort - Number.
//
// Returns:
// Boolean - True, if sessions terminated successfully.
//
Function TerminateSessionsByListViaServiceAgent(Val SessionsToDelete, Val InfoBaseAdministrationParameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return False;
	EndIf;	
	
	If TypeOf(SessionsToDelete) = Type("Array") Then
		SessionList = SessionsToDelete;
	ElsIf TypeOf(SessionsToDelete) = Type("Number") Then
		SessionList = New Array;
		SessionList.Add(SessionsToDelete);
	Else
		Raise(NStr("en = 'Invalid type of SessionsToDelete parameter.'"));
	EndIf;
	
	If SessionList.Count() = 0 Then
		Return True;
	EndIf;
	
	// Creating a parameter structure of connection to the service agent.
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL", Constants.ServiceAgentAddress.Get());
	ConnectionParameters.Insert("UserName", Constants.ServiceAgentUserName.Get());
	ConnectionParameters.Insert("Password", Constants.ServiceAgentUserPassword.Get());
	
	// Checking by means of versioning, whether required interface is supported.
	SupportedVersionArray = CommonUse.GetInterfaceVersions(ConnectionParameters, "AgentManagement");
	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
		Raise(NStr("en = 'Service agent. Selective deletion of sessions is not supported in this version.'"));
	EndIf;
	
	// Generating input parameter XDTO string for service operation calling.
	
	ParameterValues = New Structure;
	
	// Getting connection parameters for the current Infobase.
	ConnectionParameters = StringFunctionsClientServer.GetParametersFromString(InfoBaseConnectionString());
	If Not ConnectionParameters.Property("Srvr") Or Not ConnectionParameters.Property("Ref") Then
		Raise(NStr("en = 'This action is not allowed for the file Infobase.'"));
	EndIf;
	ParameterValues.Insert("InfoBase", ConnectionParameters.Ref);
	
	AdministrationParameterType = XDTOFactory.Type("http://v8.1c.ru/agent/scripts/1.0", "ClusterAdministrationInfo");
	ClusterAdministrationParameters = XDTOFactory.Create(AdministrationParameterType);
	ClusterAdministrationParameters.AgentConnectionString = 
		"tcp://" + ConnectionParameters.Srvr + ":" 
		+ Format(InfoBaseAdministrationParameters.ServerAgentPort, "NG=");
	ClusterAdministrationParameters.WorkServerUserName = InfoBaseAdministrationParameters.ClusterAdministratorName;
	ClusterAdministrationParameters.WorkServerPassword = StringToBase64(InfoBaseAdministrationParameters.ClusterAdministratorPassword);
	ClusterAdministrationParameters.ClusterPort = InfoBaseAdministrationParameters.ServerClusterPort;
	ClusterAdministrationParameters.ClusterUserName = InfoBaseAdministrationParameters.ClusterAdministratorName;
	ClusterAdministrationParameters.ClusterPassword = StringToBase64(InfoBaseAdministrationParameters.ClusterAdministratorPassword);
	ClusterAdministrationParameters.IBUserName = InfoBaseAdministrationParameters.InfoBaseAdministratorName;
	ClusterAdministrationParameters.IBPassword = StringToBase64(InfoBaseAdministrationParameters.InfoBaseAdministratorPassword);
	
	ParameterValues.Insert("ClusterAdministrationParameters", ClusterAdministrationParameters);
	ParameterValues.Insert("SessionList", SessionList);
	
	XDTOParameters = WriteStructuralXDTOObjectToString(ParameterValues);
	
	// There are support of version 2, in which selective deletion of sessions has been implemented.
	Proxy = GetServiceConnectionProxy(ConnectionParameters, "ManageAgent", "1.0.2.1");
	// Executing the action by means of a web service operation.
	CompleteState = Undefined;
	Proxy.DoAction("TerminateSessionsByList", XDTOParameters, CompleteState);
	
	Return CompleteState = "ActionCompleted" or CompleteState = "True";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase parameter operations.

// Returns an empty infobase parameter table.
// 
Function GetEmptyInfoBaseParameterTable()
	
	Result = New ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Details", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("ReadProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("WriteProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File operations.

// Returns the full name of a file, received from the service manager file storage by the file ID.
//
// Parameters:
// FileID - UUID - file ID in the service manager file storage.
//
// Returns:
// String - full name of the file.
//
Function GetFileFromServiceManagerStorage(Val FileID) 
	
	ServiceManagerAddress = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en = 'Parameters of connection with service manager are not specified.'"));
	EndIf;
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", ServiceManagerAddress);
	StorageAccessParameters.Insert("UserName", Constants.AuxiliaryServiceManagerUserName.Get());
	StorageAccessParameters.Insert("Password", Constants.AuxiliaryServiceManagerUserPassword.Get());
	
	FileDetails = GetFileFromStorage(FileID, StorageAccessParameters, True);
	
	FileProperties = New File(FileDetails.FullName);
	If Not FileProperties.Exist() Then
		Raise(StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 file not found.'"), FileDetails.FullName));
	EndIf;
	
	Return FileProperties.FullName; 
		
EndFunction

// Checks whether file transfer from server to client via file system is possible.
//
// Parameters:
// Proxy - WSProxy - FilesTransfer* service proxy.
// HasVersion2Support - Boolean.
//
// Returns:
// Boolean.
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

// Creates a directory with a unique name to place there parts of file to split.
//
// Returns:
// String - Directory name.
//
Function CreateAssemblyDirectory()
	
	AssemblyDirectory = GetTempFileName();
	CreateDirectory(AssemblyDirectory);
	Return AssemblyDirectory + GetFileSystemPathSeparator();
	
EndFunction

// Reads a test file from a hard disk, comparing content and a name: they must be equal.
// The calling side must delete this file.
//
// Parameters:
// FileName - String - file name without a path.
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

// Creates an empty structure of a requied format.
//
// Returns:
// Structure:
// Name - String - name of file in store;
// Data - BinaryData - file data.
// 	 FullName - String - file name with path.
//
Function CreateFileDetails()
	
	FileDetails = New Structure;
	FileDetails.Insert("Name");
	FileDetails.Insert("Data");
	FileDetails.Insert("FullName");
	FileDetails.Insert("MandatoryParameters", "Name"); // parameters, the filling of which is mandatory.
	Return FileDetails;
	
EndFunction

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
// StructuralType - Type.
//
// Returns:
// Boolean.
//
Function StructuralTypeToSerialize(StructuralType);
	
	TypeToSerializeArray = ServiceModeCached.StructuralTypesToSerialize();
	
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
// StructuralTypeValue - Array, structure, map or their fixed analogues.
//
// Returns:
// Structural XDTO object - XDTO presentation of a structural type object.
//
Function StructuralObjectToXDTOObject(Val StructuralTypeValue)
	
	StructuralType = TypeOf(StructuralTypeValue);
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Type %1 is not a structural type or its serialization is not supported.'"),
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
			XDTOStructure.Pair.Add(StructuralObjectToXDTOObject(KeyAndValue));
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
// XDTODataObject - XDTO object.
//
// Returns:
// Structural type - array, structure, map or their fixed analogues. 
Function XDTOObjectToStructuralObject(XDTODataObject)
	
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
			NStr("en = '%1 type is not a structural type or its serialization is not supported now.'"),
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
			KeyAndValue = XDTOObjectToStructuralObject(KeyAndValueXDTO);
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
				IndexString = IndexString + IndexField + ", ";
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
// TypeValue - Any type value.
//
// Returns:
// Any type.
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
			Return StructuralObjectToXDTOObject(TypeValue);
		Else
			Return XDTOFactory.Create(XDTOType, TypeValue); // UUID, for example.
		EndIf;
		
	EndIf;
	
EndFunction

// Gets the platform type value by the XDTO type value.
//
// Parameters:
// XDTODataValue - Any XDTO type value.
//
// Returns:
// Any type.
// 
Function XDTOValueToTypeValue(XDTODataValue)
	
	If TypeOf(XDTODataValue) = Type("XDTODataValue") Then
		Return XDTODataValue.Value;
	ElsIf TypeOf(XDTODataValue) = Type("XDTODataObject") Then
		Return XDTOObjectToStructuralObject(XDTODataValue);
	Else
		Return XDTODataValue;
	EndIf;
	
EndFunction