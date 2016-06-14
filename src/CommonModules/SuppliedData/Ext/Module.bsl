///////////////////////////////////////////////////////////////////////////////////
// SuppliedData: Supplied data service mechanism.
//
///////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Initiate notification about all available supplied data in Service manager (except those 
// that have the Notification prohibition mark)
//
Procedure RequestAllData() Export
	
	MessageExchange.SendMessage("SuppliedData\QueryAllData", Undefined, 
		SaaSOperationsCached.ServiceManagerEndpoint());
		
EndProcedure

// Get data descriptors by the specified conditions
//
// Parameters
//  DataKind - String. 
//  Filter - Collection. The items should contain the following fields: 
//                       Code (string) and Value (string).
//
// Returns:
//    XDTODataObject of the ArrayOfDescriptor type
//
Function SuppliedDataDescriptorsFromManager(Val DataKind, Val Filter = Undefined) Export  
	Var Proxy, Conditions, FilterType;
	Proxy = NewProxyOnServiceManager();
	
	If Filter <> Undefined Then
			
		FilterType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfProperty");
		ConditionType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Property");
		Conditions = Proxy.XDTOFactory.Create(FilterType);
		For Each FilterString In Filter Do
			Where = Conditions.Property.Add(Proxy.XDTOFactory.Create(ConditionType));
			Where.Code = FilterString.Code;
			Where.Value = FilterString.Value;
		EndDo;
	EndIf;
	
	//Convert to standard type
	Result = Proxy.GetData(DataKind, Conditions);
	Write = New XMLWriter;
	Write.SetString();
	Proxy.XDTOFactory.WriteXML(Write, Result, , , , XMLTypeAssignment.Explicit);
	SerializedResult = Write.Close();
	
	Read = New XMLReader;
	Read.SetString(SerializedResult);
	Result = XDTOFactory.ReadXML(Read);
	Read.Close();
	Return Result;

EndFunction

// Initiates data processing 
//
// May be used in conjunction with SuppliedDataDescriptorsFromManager for 
// manual initiation of the data processing. After method raise the system will act 
// as if it has only received a notice about the availability of new data with the
// specified descriptor - NewDataAvailable will be raised then, if necessary, 
// ProcessNewData for relevant handlers.
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//
Procedure ImportAndProcessData(Val Descriptor) Export
	
	SuppliedDataMessagesMessageHandler.HandleNewDescriptor(Descriptor);
	
EndProcedure
	
// Moves the data into the SuppliedData catalog
//
// Data is stored either in a volume on the disk or in the SuppliedData table field 
// depending on the StoreFilesInVolumesOnHardDisk constants and existence of free  
// volumes. Data can be later retrieved by search by attributes or by specifying 
// a unique ID, which one was passed to the Descriptor.FileGUID field. If the base 
// already has data with the same data kind and set of key characteristics - new data 
// replaces the old one. In this case update of the existing catalog item is used 
// rather than deletion and creating a new one.
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor or a structure with the following fields 
//     "DataKind, AddedAt, FileID, Characteristics", 
//     where Characteristics - the array of structures with the following fields 
//     "Code, Value, Key" 
//   PathToFile   - string. Extracted file full name.
//
Procedure SaveSuppliedDataInCache(Val Descriptor, Val PathToFile) Export
	
	//Handle the descriptor to the accepted kind
	If TypeOf(Descriptor) = Type("Structure") Then
		InEnglish = New Structure("DataType, CreationDate, FileGUID, Properties", 
			Descriptor.DataKind, Descriptor.AddedAt, Descriptor.FileID,
			New Structure("Property", New Array));
		If TypeOf(Descriptor.Characteristics) = Type("Array") Then
			For Each Characteristic In Descriptor.Characteristics Do
				InEnglish.Properties.Property.Add(New Structure("Code, Value, IsKey",
				Characteristic.Code, Characteristic.Value, Characteristic.Key));
			EndDo; 
		EndIf;
		Descriptor = InEnglish;			
	EndIf;
	
	Filter = New Array;
	For Each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.IsKey Then
			Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
		EndIf;
	EndDo;
	
	SourceAreaData = Undefined;
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		SourceAreaData = CommonUse.SessionSeparatorValue();
		CommonUse.SetSessionSeparation(False);
	EndIf;
	
	BeginTransaction();
	Try
	
		Query = QueryDataByNames(Descriptor.DataType, Filter);
		Result = Query.Execute();
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("Catalog.SuppliedData");
		LockItem.DataSource = Result;
		LockItem.UseFromDataSource("Ref", "SuppliedData");
		DataLock.Lock();
		
		Selection = Result.Select();
		
		Data = Undefined;
		PathToOldFile = Undefined;
		
		While Selection.Next() Do
			If Data = Undefined Then
				Data = Selection.SuppliedData.GetObject();
				If Data.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk Then
					PathToOldFile = FileFunctionsInternal.VolumeFullPath(Data.Volume) + Data.PathToFile;
				EndIf;
			Else
				DeleteSuppliedDataFromCache(Selection.SuppliedData);
			EndIf;
		EndDo;		
		
		If Data = Undefined Then
			Data = Catalogs.SuppliedData.CreateItem();
		EndIf;
			
		Data.DataKind =  Descriptor.DataType;
		Data.AddedAt = Descriptor.CreationDate;
		Data.FileID = Descriptor.FileGUID;
		Data.DataCharacteristics.Clear();
		For Each Property In Descriptor.Properties.Property Do
			Characteristic = Data.DataCharacteristics.Add();
			Characteristic.Characteristic = Property.Code;
			Characteristic.Value = Property.Value;
		EndDo; 
		Data.FileStorageType = FileFunctionsInternal.FileStorageType();

		If Data.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			Data.StoredFile = New ValueStorage(New BinaryData(PathToFile));
			Data.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			Data.PathToFile = "";
		Else
			// Add to one of the volumes (that has enough space).
			FileFunctionsInternal.AddOnHardDisk(
				PathToFile,
				Data.PathToFile,
				Data.Volume,
				Data.AddedAt,
				"",
				String(Data.FileID),
				"");
			Data.StoredFile = Undefined;
		EndIf;
		
		Data.Write();
		If PathToOldFile <> Undefined Then
			DeleteFiles(PathToOldFile);
		EndIf;
		
		CommitTransaction();
		
		If SourceAreaData <> Undefined Then
			CommonUse.SetSessionSeparation(True, SourceAreaData);
		EndIf;
	Except
		RollbackTransaction();
		
		If SourceAreaData <> Undefined Then
			CommonUse.SetSessionSeparation(True, SourceAreaData);
		EndIf;
		
		Raise;
	EndTry;
		
EndProcedure

// Removes file from cache.
//
// Parameters:
//  RefOrID - CatalogRef.SuppliedData or UUID
//
Procedure DeleteSuppliedDataFromCache(Val RefOrID) Export
	Var Data, FullPath;
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrID) = Type("UUID") Then
		RefOrID = Catalogs.SuppliedData.FindByAttribute("FileID", RefOrID);
		If RefOrID.IsEmpty() Then
			Return;
		EndIf;
	EndIf;
	
	Data = RefOrID.GetObject();
	If Data = Undefined Then 
		Return;
	EndIf;
	
	If Data.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDisk Then
		FullPath = FileFunctionsInternal.VolumeFullPath(Data.Volume) + Data.PathToFile;
		DeleteFiles(FullPath);
	EndIf;
	
	Delete = New ObjectDeletion(RefOrID);
	Delete.DataExchange.Load = True;
	Delete.Write();
	
EndProcedure

// Gets a data descriptor from the cache
//
// Parameters:
//  RefOrID - CatalogRef.SuppliedData or UUID
//  AsXDTO - Boolean. In what form to return values
//
Function DescriptorSuppliedDataInCache(Val RefOrID, Val AsXDTO = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	If TypeOf(RefOrID) = Type("UUID") Then
		Suffix = "SuppliedDataCatalog.FileID = &FileID";
		Query.SetParameter("FileID", RefOrID);
	Else
		Suffix = "SuppliedDataCatalog.Ref = &Ref";
		Query.SetParameter("Ref", RefOrID);
	EndIf;
	
	Query.Text = "SELECT
    |	SuppliedDataCatalog.FileID,
    |	SuppliedDataCatalog.AddedAt,
    |	SuppliedDataCatalog.DataKind,
    |	SuppliedDataCatalog.DataCharacteristics.(
    |		Value,
    |		Characteristic)
    |FROM
  	|	Catalog.SuppliedData AS SuppliedDataCatalog
  	|	WHERE " + Suffix;
	 
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Return ?(AsXDTO, GetXDTODescriptor(Selection), GetDescriptor(Selection));
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns binary data of the attached file.
//
// Parameters:
//  RefOrID - CatalogRef.SuppliedData or UUID - File ID
//
// Returns:
//  BinaryData.
//
Function SuppliedDataFromCache(Val RefOrID) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrID) = Type("UUID") Then
		RefOrID = Catalogs.SuppliedData.FindByAttribute("FileID", RefOrID);
		If RefOrID.IsEmpty() Then
			Return Undefined;
		EndIf;
	EndIf;
	
	FileObject = RefOrID.GetObject();
	If FileObject = Undefined Then
		Return Undefined;
	EndIf;
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Return FileObject.StoredFile.Get();
	Else
		FullPath = FileFunctionsInternal.VolumeFullPath(FileObject.Volume) + FileObject.PathToFile;
		
		Try
			Return New BinaryData(FullPath)
		Except
			// Record into the registration log.
			ErrorMessage = ErrorTextWhenYouReceiveFile(ErrorInfo(), RefOrID);
			WriteLogEvent(
				NStr("en = 'SuppliedData.Receive the file from the volume'", 
				CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.SuppliedData,
				RefOrID,
				ErrorMessage);
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Open file error: the file not found on the server.
				           |Contact the application administrator.
				           |
				           |File: ""%1.%2"".'"),
				FileObject.Description,
				FileObject.Extension);
		EndTry;
	EndIf;
	
EndFunction

// Checks whether there is data with the specified key characteristics in the cache.
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//
// Returns:
//  Boolean.
//
Function IsInCache(Val Descriptor) Export
	
	Filter = New Array;
	For Each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.IsKey Then
			Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
		EndIf;
	EndDo;
	
	Query = QueryDataByNames(Descriptor.DataType, Filter);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns the array of references for the data that meets the specified conditions
//
// Parameters
//  DataKind - String. 
//  Filter - Collection. The items should contain the following fields: Code (string) 
//                       and Value (string).
//
// Returns:
//    Array.
//
Function SuppliedDataReferencesFromCache(Val DataKind, Val Filter = Undefined) Export
	
	Query = QueryDataByNames(DataKind, Filter);
	Return Query.Execute().Unload().UnloadColumn("SuppliedData");
	
EndFunction

// Get data by the specified conditions
//
// Parameters
//  DataKind - String. 
//  Filter - Collection. The items should contain the following fields: Code (string) and Value (string).
//  AsXDTO - boolean. In what form to return values
//
// Returns: 
//    XDTODataObject of the ArrayOfDescriptor type or 
//    Array of structures with the following fields "DataKind, AddedAt, FileID, Characteristics" 
//    where Characteristics - array of structures with the following fields "Code, Value, Key" 
//    To get the file call GetSuppliedDataFromCache
//
//
Function SuppliedDataFromCacheDescriptors(Val DataKind, Val Filter = Undefined, Val AsXDTO = False) Export
	Var Query, QueryResult, Selection, Descriptors, Result;
	
	Query = QueryDataByNames(DataKind, Filter);
		
	Query.Text = "SELECT
    |	SuppliedDataCatalog.FileID,
    |	SuppliedDataCatalog.AddedAt,
    |	SuppliedDataCatalog.DataKind,
    |	SuppliedDataCatalog.DataCharacteristics.(
    |		Value,
    |		Characteristic)
  |FROM
  |  Catalog.SuppliedData AS SuppliedDataCatalog
  |	WHERE SuppliedDataCatalog.Ref IN (" + Query.Text + ")";
	 
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If AsXDTO Then
		Result = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfDescriptor"));
		Descriptors = Result.Descriptor;
	Else
		Result = New Array();
		Descriptors = Result;
	EndIf;

	While Selection.Next() Do
		Message = ?(AsXDTO, GetXDTODescriptor(Selection), GetDescriptor(Selection));
		Descriptors.Add(Message);
	EndDo;		
	
	Return Result;
	
EndFunction	

// Returns a custom supplied data descriptor presentation 
// Can be used to output messages to the event log
//
// Parameters
//  XDTODescriptor - XDTODataObject of the Descriptor type or a structure with the following fields
//   "DataKind, AddedAt, FileID, Characteristics" 
//   where Characteristics - array of structures with the following fields "Code, Value"
//
// Returns:
//  String
//
Function GetDataDescription(Val Descriptor) Export
	Var Details, Characteristic;
	
	If Descriptor = Undefined Then
		Return "";
	EndIf;
	
	If TypeOf(Descriptor) = Type("XDTODataObject") Then
		Details = Descriptor.DataType;
		For Each Characteristic In Descriptor.Properties.Property Do
			Details = Details
				+ ", " + Characteristic.Code + ": " + Characteristic.Value;
		EndDo; 
		
		Details = Details + 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = ', added: %1 (%2), recommended to import: %3 (%2)'"), 
			ToLocalTime(Descriptor.CreationDate, SessionTimeZone()), TimeZonePresentation(SessionTimeZone()), 
			ToLocalTime(Descriptor.RecommendedUpdateDate));
	Else
		Details = Descriptor.DataKind;
		For Each Characteristic In Descriptor.Characteristics Do
			Details = Details
				+ ", " + Characteristic.Code + ": " + Characteristic.Value;
		EndDo; 
		
		Details = Details + 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = ', added: %1 (%2)'"), 
			ToLocalTime(Descriptor.AddedAt, SessionTimeZone()), TimeZonePresentation(SessionTimeZone()));
	EndIf;
		
	Return Details;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////////
// Update information in data areas

// Returns the list of data areas where the supplied data have not been copied yet
//
// In case of the first raise of the function the full set of available areas returned  
// In case of subsequent raise, when recovering from a failure, only the raw area will be returned. 
// After copying the data to the region you should raise AreaProcessed
//
// Parameters
//  FileID - UUID of the supplied data file 
//  HandlerCode - String
//  IncludingShared - Boolean, if True, the area with code -1 will be added to to all available areas
// 
Function AreasRequireProcessing(Val FileID, Val HandlerCode, Val IncludingShared = False) Export
	
	RecordSet = InformationRegisters.AreasRequireSuppliedDataProcessing.CreateRecordSet();
	RecordSet.Filter.FileID.Set(FileID);
	RecordSet.Filter.HandlerCode.Set(HandlerCode);
	RecordSet.Read();
	If RecordSet.Count() = 0 Then
		Query = New Query;
		Query.Text = "SELECT
		               |	&FileID AS FileID,
		               |	&HandlerCode AS HandlerCode,
		               |	DataAreas.DataAreaAuxiliaryData AS DataArea
		               |FROM
		               |	InformationRegister.DataAreas AS DataAreas
		               |WHERE
		               |	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
		Query.SetParameter("FileID", FileID);
		Query.SetParameter("HandlerCode", HandlerCode);
		RecordSet.Load(Query.Execute().Unload());
		
		If IncludingShared Then
			CommonCourses = RecordSet.Add();
			CommonCourses.FileID = FileID;
			CommonCourses.HandlerCode = HandlerCode;
			CommonCourses.DataArea = -1;
		EndIf;
		
		RecordSet.Write();
	EndIf;
	Return RecordSet.UnloadColumn("DataArea");
EndFunction	

// Removes the area from the list of unprocessed ones. Disables the session separation (if 
// it was enabled) because with enabled separation writing in the notseparated register 
// is prohibited
//
// Parameters
//  FileID - UUID of the supplied data file 
//  HandlerCode - String
//  DataArea - Number - the ID of the processed area
// 
Procedure AreaProcessed(Val FileID, Val HandlerCode, Val DataArea) Export
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		CommonUse.SetSessionSeparation(False);
	EndIf;
	
	RecordSet = InformationRegisters.AreasRequireSuppliedDataProcessing.CreateRecordSet();
	RecordSet.Filter.FileID.Set(FileID);
	If DataArea <> Undefined Then
		RecordSet.Filter.DataArea.Set(DataArea);
	EndIf;
	RecordSet.Filter.HandlerCode.Set(HandlerCode);
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region InternalInterface

// Declares events of the SuppliedData subsystem:
//
// Server events:
//   OnDefineSuppliedDataHandlers.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// Registers supplied data handlers
	//
	// When a new shared data notification is received, 
	// NewDataAvailable procedures from modules registered with GetSuppliedDataHandlers are called.
	// The descriptor passed to the procedure is XDTODataObject Descriptor.
	// 
	// If NewDataAvailable sets Load to True, 
	// the data is imported, and the descriptor and the path to the data file are passed to 
	// ProcessNewData procedure. The file is automatically deleted once the procedure is executed.
	// If the file is not specified in Service Manager, the parameter value is Undefined.
	//
	// Parameters: 
	//   Handlers - ValueTable - table for adding handlers. 
	//      Columns:
	//        DataKind - String - code of the data kind processed by the handler. 
	//        HandlerCode - Sting(20) - used for recovery after a data processing error. 
	//        Handler, CommonModule - module that contains the following procedures:
	//          NewDataAvailable(Descriptor, Import) Export 
	//          ProcessNewData(Descriptor, Import) Export 
	//          DataProcessingCanceled(Descriptor) Export
	//
	// Syntax:
	// Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	//
	// For use in other libraries.
	//
	// (The same as SuppliedDataOverridable.GetSuppliedDataHandlers).
	//
	ServerEvents.Add("StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers");
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.MessageExchange") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.MessageExchange\MessageChannelHandlersOnDefine"].Add(
				"SuppliedData");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
				"SuppliedData");
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function NewProxyOnServiceManager()
	
	URL = Constants.InternalServiceManagerURL.Get();
	UserName = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();

	ServiceURL = URL + "/ws/SuppliedData?wsdl";
	
	Return CommonUseCached.WSProxy(ServiceURL, 
		"http://www.1c.ru/SaaS/1.0/WS", "SuppliedData", , UserName, UserPassword);
		
EndFunction

//Get the query that returns references to the data with the specified characteristics
//
// Parameters
//  DataKind        - string.
//  Characteristics - the collection that
//                   contains the Code(string) structure 
//                   and the Value(string)
//
// Returns:
//   Query
Function QueryDataByNames(Val DataKind, Val Characteristics)
	If Characteristics = Undefined Or Characteristics.Count() = 0 Then
		Return QueryByDataKind(DataKind);
	Else
		Return QueryByCharacteristicNames(DataKind, Characteristics);
	EndIf;
EndFunction

Function QueryByDataKind(Val DataKind)
	Query = New Query();
	Query.Text = "SELECT
	|	SuppliedData.Ref AS SuppliedData
	|FROM
	|	Catalog.SuppliedData AS SuppliedData
	|WHERE
	|	SuppliedData.DataKind = &DataKind";
	Query.SetParameter("DataKind", DataKind);
	Return Query;
	
EndFunction

Function QueryByCharacteristicNames(Val DataKind, Val Characteristics)
//SELECT Ref 
//FROM Characteristics 
//WHERE (CharacteristicsName = '' And CharacteristicValue = '') Or ..(N)
//GROUP BY DataId
//HAVING Count(*) = N	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	DataCharacteristicsSuppliedData.Ref AS SuppliedData
	|FROM
	|	Catalog.SuppliedData.DataCharacteristics AS DataCharacteristicsSuppliedData
	|WHERE 
	|	DataCharacteristicsSuppliedData.Ref.DataKind = &DataKind AND (";
	Counter = 0;
	For Each Characteristic In Characteristics Do
		If Counter > 0 Then
			Query.Text = Query.Text + " OR ";
		EndIf; 
		
		Query.Text = Query.Text + "( 
   | CAST(DataCharacteristicsSuppliedData.Value AS String(150)) = &Value" + Counter + "
		| And DataCharacteristicsSuppliedData.Characteristic = &Code" + Counter + ")";
		Query.SetParameter("Value" + Counter, Characteristic.Value);
		Query.SetParameter("Code" + Counter, Characteristic.Code);
		Counter = Counter + 1;
	EndDo;
	Query.Text = Query.Text + ")
	|Group By
	|  DataCharacteristicsSuppliedData.Ref
	|HAVING
	|Count(*) = &Quantity";
	Query.SetParameter("Quantity", Counter);
	Query.SetParameter("DataKind", DataKind);
	Return Query;
	
EndFunction

// Transformation of the selection results into an XDTO object
//
// Parameters
//  Selection      - SelectionFromQueryResult. Query selection that contains
//                   information about data updating 
//
Function GetXDTODescriptor(Selection)
	Descriptor = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Descriptor"));
	Descriptor.DataType = Selection.DataKind;
	Descriptor.CreationDate = Selection.AddedAt;
	Descriptor.FileGUID = Selection.FileID;
	Descriptor.Properties = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfProperty"));
	CharacteristicsSelection = Selection.DataCharacteristics.Select();
	While CharacteristicsSelection.Next() Do
		Characteristic = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Property"));
		Characteristic.Code = CharacteristicsSelection.Characteristic;
		Characteristic.Value = CharacteristicsSelection.Value;
		Characteristic.IsKey = True;
		Descriptor.Properties.Property.Add(Characteristic);
	EndDo; 
	Return Descriptor;
	
EndFunction

Function GetDescriptor(Val Selection)
	Var Descriptor, CharacteristicsSelection, Characteristic;
	
	Descriptor = New Structure("DataKind, AddedAt, FileID, Characteristics");
	Descriptor.DataKind = Selection.DataKind;
	Descriptor.AddedAt = Selection.AddedAt;
	Descriptor.FileID = Selection.FileID;
	Descriptor.Characteristics = New Array();
	
	CharacteristicsSelection = Selection.DataCharacteristics.Select();
	While CharacteristicsSelection.Next() Do
		Characteristic = New Structure("Code, Value, Key");
		Characteristic.Code = CharacteristicsSelection.Characteristic;
		Characteristic.Value = CharacteristicsSelection.Value;
		Characteristic.Key = True;
		Descriptor.Characteristics.Add(Characteristic);
	EndDo; 
	
	Return Descriptor;
	
EndFunction

Function CreateObject(Val MessageType)
	
	Return XDTOFactory.Create(MessageType);
	
EndFunction

Function ErrorTextWhenYouReceiveFile(Val ErrorInfo, Val File)
	
	ErrorMessage = BriefErrorDescription(ErrorInfo);
	
	If File <> Undefined Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1
			           |
			           |File reference: %2.'"),
			ErrorMessage,
			GetURL(File) );
	EndIf;
	
	Return ErrorMessage;
	
EndFunction

// Compares if the set of characteristics got from the descriptor meets the filter conditions
//
// Parameters:
//  Filter - The collection of objects with the Code and Value fields 
//  Characteristics - The collection of objects with the Code and Value fields
//
// Returns:
//   Boolean
//
Function CharacteristicsCoincide(Val Filter, Val Characteristics) Export

	For Each FilterString In Filter Do
		StringFound = False;
		For Each Characteristic In Characteristics Do 
			If Characteristic.Code = FilterString.Code Then
				If Characteristic.Value = FilterString.Value Then
					StringFound = True;
				Else 
					Return False;
				EndIf;
			EndIf;
		EndDo;
		If Not StringFound Then
			Return False;
		EndIf;
	EndDo;
		
	Return True;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Fills a map of method names and their aliases for calling from a job queue
//
// Parameters:
//  NameAndAliasMap - Map
//   Key - method alias, example: ClearDataArea. 
//   Value - method name, example: SaaSOperations.ClearDataArea. 
//   You can pass Undefined if the name is identical to the alias
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("SuppliedDataMessagesMessageHandler.ImportData");
	
EndProcedure

// Gets the list of message handlers that are processed by the library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable
// 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
	
	SuppliedDataMessagesMessageHandler.GetMessageChannelHandlers(Handlers);
	
EndProcedure

#EndRegion