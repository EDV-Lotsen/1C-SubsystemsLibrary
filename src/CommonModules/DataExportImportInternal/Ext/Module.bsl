// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	ServerHandlers["CloudTechnology\NamespacePrefixRegistration"].Add(
		"DataExportImportInternal");
	
EndProcedure

// Returns an array with all metadata items contained in the configuration.
//  Used to start data export and data import procedures
//  in configurations that do not include SL.
//
// Usage examples:
//
//  ExportParameters = New Structure();
//  ExportParameters.Insert("TypesToExport", DataExportImportInternal.GetAllConfigurationTypes());
//  ExportParameters.Insert("ExportUsers", True);
//  ExportParameters.Insert("ExportUserSettings", True);
//  FileName = DataImportExport.ExportDataToArchive(ExportParameters);
//
//  ImportParameters = New Structure();
//  ImportParameters.Insert("TypesToImport", DataExportImportInternal.GetAllConfigurationTypes());
//  ImportParameters.Insert("ImportUsers", True);
//  ImportParameters.Insert("ImportUserSettings", True);
//  DataImportExport.ImportDataFromArchive(FileName, ImportParameters);
//
// Returns: Array (MetadataObject).
//
Function GetAllConfigurationTypes() Export
	
	MetadataCollectionArray = New Array();
	
	FillConstantCollections(MetadataCollectionArray);
	FillRefObjectCollections(MetadataCollectionArray);
	FillRecordSetCollections(MetadataCollectionArray);
	
EndFunction

// Exports data to a directory.
//
// Parameters:
//  ExportParameters - Structure containing data export parameters.
//    Keys:
//      TypesToExport - Array of MetadataObject - array of metadata
//        objects whose data must be exported to archive. 
//      ExportUsers - Boolean - export information on infobase users. 
//      ExportUserSettings - Boolean. If ExportUsers = False, this parameter is ignored.
//    The structure can also contain additional keys intended to
//      be processed by arbitrary data export handlers.
//
Procedure ExportDataToDirectory(Val ExportDirectory, Val ExportParameters) Export
	
	Container = DataProcessors.ImportExportContainerManagerData.Create();
	Container.InitializeExport(ExportDirectory, ExportParameters);
	
	DataExportImportInternalEvents.ExecuteActionsBeforeDataExport(Container);
	
	SaveExportDescription(Container);
	ImportExportInfobaseData.ExportInfobaseData(Container);
	
	If ExportParameters.ExportUsers Then
		
		ImportExportInfobaseUsers.ExportInfobaseUsers(Container);
		
		If ExportParameters.ExportUserSettings Then
			
			ImportExportUserSettings.ExportInfobaseUserSettings(Container);
			
		EndIf;
		
	EndIf;
	
	DataExportImportInternalEvents.ExecuteActionsAfterDataExport(Container);
	
	Container.FinalizeExport();
	
EndProcedure

Procedure ImportDataFromDirectory(Val Directory, Val ImportParameters) Export
	
	SystemInfo = New SystemInfo();
	PlatformVersion = SystemInfo.AppVersion;
	
	If CommonUseClientServer.CompareVersions(PlatformVersion, "8.2.19.0") < 0
		Or (CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.1.0") > 0
		And CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.4.0") < 0) Then
		
		Raise
			NStr("en = '1C:Enterprise technological platform must be updated before data can be imported.
                  |For version 8.2, use release 8.2.19 (or later).
                  |For version 8.3, use release 8.3.4 (or later).'");
		
	EndIf;
	
	If Right(Directory, 1) <> "\" Then
		Directory = Directory + "\";
	EndIf;
	
	Container = DataProcessors.ImportExportContainerManagerData.Create();
	Container.InitializeImport(Directory, ImportParameters);
	
	ExportInfo = ReadExportInformation(Container);
	
	If Not DataInArchiveCompatibleWithCurrentConfiguration(ExportInfo) Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Data exported from configuration %1 cannot be imported to configuration %2.'"),
			ExportInfo.Configuration.Name,
			Metadata.Name
		);
		
	EndIf;
	
	If Not ExportArchiveFileCompatibleWithCurrentConfigurationVersion(ExportInfo) Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Data exported from version %1 cannot be imported to version %2.'"),
			ExportInfo.Configuration.Version,
			Metadata.Version
		);
		
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then 
		SaasOperationsModule = CTLAndSLIntegration.CommonModule("SaaSOperations");
		SaasOperationsModule.ClearAreaData(ImportParameters.ImportUsers);
	Else
		EraseInfobaseData();
	EndIf;
	
	If CommonUseClientServer.IsPlatform83WithoutCompatibilityMode() Then
		Execute("InitializePredefinedData();");
	EndIf;
	
	DataExportImportInternalEvents.ExecuteActionsBeforeDataImport(Container);
	
	ImportExportInfobaseData.ImportInfobaseData(Container);
	
	If ImportParameters.ImportUsers Then
		
		ImportExportInfobaseUsers.ImportInfobaseUsers(Container);
		
		If ImportParameters.ImportUserSettings Then
			
			ImportExportUserSettings.ImportInfobaseUserSettings(Container);
			
		EndIf;
		
	EndIf;
	
	DataExportImportInternalEvents.ExecuteActionsAfterDataImport(Container);
	
EndProcedure

Function DataInArchiveCompatibleWithCurrentConfiguration(Val ExportInfo) Export
	
	Return ExportInfo.Configuration.Name = Metadata.Name;
	
EndFunction

Function ExportArchiveFileCompatibleWithCurrentConfigurationVersion(Val ExportInfo) Export
	
	Return ExportInfo.Configuration.Version = Metadata.Version;
	
EndFunction

// Writes configuration description.
//
// Parameters:
//  FileName - String - full path to the file where the description must be stored.
//
Procedure SaveExportDescription(Val Container)
	
	DumpInfoType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "DumpInfo");
	ConfigurationInfoType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "ConfigurationInfo");
	
	ExportInfo = XDTOFactory.Create(DumpInfoType);
	ExportInfo.Created = CurrentSessionDate();
	
	ConfigurationInfo = XDTOFactory.Create(ConfigurationInfoType);
	ConfigurationInfo.Name = Metadata.Name;
	ConfigurationInfo.Version = Metadata.Version;
	ConfigurationInfo.Vendor = Metadata.Vendor;
	ConfigurationInfo.Presentation = Metadata.Presentation();
	
	ExportInfo.Configuration = ConfigurationInfo;
	
	FileName = Container.CreateFile(DataExportImportInternal.DumpInfo());
	DataExportImportInternal.WriteXDTOObjectToFile(ExportInfo, FileName);
	
EndProcedure

Function ReadExportInformation(Container)
	
	FileName = Container.GetFileFromDirectory(DataExportImportInternal.DumpInfo());
	
	Return DataExportImportInternal.ReadXDTOObjectFromFile(
		FileName, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "DumpInfo"));
	
EndFunction

// Called for registration of prefixes that must be used 
// to specify object types in XML files (instead of specifying full package namespace URI).
//
// Parameters:
//  Result - Structure where package namespace prefixes and URI must be added in the handler.
//
Procedure NamespacePrefixRegistration(Result) Export
	
	Result.Insert("dump", "http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1");
	
EndProcedure

Procedure BeforeDataExport(Container) Export
	
	FileName = Container.CreateArbitraryFile("xml", DataTypeForValueTableColumnName());
	
	ColumnName = New UUID();
	ColumnName = String(ColumnName);
	ColumnName = "a" + StrReplace(ColumnName, "-", "");
	
	DataExportImportInternal.WriteObjectToFile(ColumnName, FileName);
	
	Container.AdditionalProperties.Insert("SourceURLColumnName", ColumnName);
	
EndProcedure

Procedure BeforeDataImport(Container) Export
	
	FileName = Container.GetArbitraryFile(DataTypeForValueTableColumnName());
	
	ColumnName = DataExportImportInternal.ReadObjectFromFile(FileName);
	
	If ColumnName = Undefined Or IsBlankString(ColumnName) Then 
		
		Raise NStr("en = 'Name of column with source URL is not found'");
		
	EndIf;
	
	Container.AdditionalProperties.Insert("SourceURLColumnName", ColumnName);
	
EndProcedure

Function SourceURLColumnName(Container) Export
	
	If Container.AdditionalProperties.Property("SourceURLColumnName") Then 
		Return Container.AdditionalProperties["SourceURLColumnName"];
	EndIf;
	
	Raise NStr("en = 'SourceURLColumnName container property not found'");
	
EndFunction

Function DataTypeForValueTableColumnName()
	
	Return "1cfresh\ReferenceMapping\ValueTableColumnName";
	
EndFunction

Function GetIntegratedDataSchema() Export
	
	
	
EndFunction

Function DumpInfo() Export
	Return "DumpInfo";
EndFunction

Function PackageContents() Export
	Return "PackageContents";
EndFunction

Function ReferenceMapping() Export
	Return "ReferenceMapping";
EndFunction

Function ReferenceRebuilding() Export
	Return "ReferenceRebuilding";
EndFunction

Function InfobaseData() Export
	Return "InfobaseData";
EndFunction

Function SequenceBoundary() Export
	Return "SequenceBoundary";
EndFunction

Function UserSettings() Export
	Return "UserSettings";
EndFunction

Function Users() Export
	Return "Users";
EndFunction

Function CustomData() Export
	Return "CustomData";
EndFunction

Function DirectoryStructureCreationRules() Export
	
	RootDirectory = "";
	DataDirectory = "Data";
	
	Result = New Structure();
	Result.Insert(DumpInfo(), RootDirectory);
	Result.Insert(PackageContents(), RootDirectory);
	Result.Insert(ReferenceMapping(), ReferenceMapping());
	Result.Insert(ReferenceRebuilding(), ReferenceRebuilding());
	Result.Insert(InfobaseData(), DataDirectory);
	Result.Insert(SequenceBoundary(), DataDirectory);
	Result.Insert(Users(), RootDirectory);
	Result.Insert(UserSettings(), UserSettings());
	Result.Insert(CustomData(), CustomData());
	
	Return New FixedStructure(Result);
	
	
EndFunction

Function FileTypesSupportingRefReplacement() Export
	
	Result = New Array();
	
	Result.Add(ReferenceMapping());
	Result.Add(InfobaseData());
	Result.Add(SequenceBoundary());
	Result.Add(UserSettings());
	
	Return Result;
	
EndFunction

// Returns the name of a type to be used in XML file for the specified metadata object. 
// Used for reference search and replacement during import, 
// and for current-config schema editing during writing.
// 
// Parameters:
//  Value - Metadata object or Ref.
//
// Returns:
//  String - String that describes a metadata object (in format similar to AccountingRegisterRecordSet.ChartOfAccounts).
//
Function XMLRefType(Val Value) Export
	
	If TypeOf(Value) = Type("MetadataObject") Then
		MetadataObject = Value;
		ObjectManager = CTLAndSLIntegration.ObjectManagerByFullName(MetadataObject.FullName());
		Ref = ObjectManager.GetRef();
	Else
		MetadataObject = Value.Metadata();
		Ref = Value;
	EndIf;
	
	If IsRefData(MetadataObject) Then
		
		Return XDTOSerializer.XMLTypeOf(Ref).TypeName;
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Error determining XML Ref type for object %1: this is not a reference object.'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndFunction

// Checks whether the specified type is a constant.
//
// Parameters:
//  MetadataObject - Metadata object - Object.
//
// Returns:
//  Boolean - True in case of success.
// 
Function IsConstant(Val MetadataObject) Export
	
	Return Metadata.Constants.Contains(MetadataObject);
	
EndFunction

Function IsEnum(Val MetadataObject) Export
	
	Return Metadata.Enums.Contains(MetadataObject);
	
EndFunction

// Checks whether the specified type is reference data.
//
// Parameters:
//  MetadataObject - Metadata object - Object.
//
// Returns:
//  Boolean - True in case of success.
// 
Function IsRefData(Val MetadataObject) Export
	
	Return Metadata.Catalogs.Contains(MetadataObject) 
		Or Metadata.Documents.Contains(MetadataObject) 
		Or Metadata.BusinessProcesses.Contains(MetadataObject) 
		Or Metadata.Tasks.Contains(MetadataObject) 
		Or Metadata.ChartsOfAccounts.Contains(MetadataObject) 
		Or Metadata.ExchangePlans.Contains(MetadataObject) 
		Or Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) 
		Or Metadata.ChartsOfCalculationTypes.Contains(MetadataObject);
		
EndFunction

Function IsRefDataSupportingPredefinedItems(Val MetadataObject) Export
	
	Return Metadata.Catalogs.Contains(MetadataObject)
		Or Metadata.ChartsOfAccounts.Contains(MetadataObject)
		Or Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject)
		Or Metadata.ChartsOfCalculationTypes.Contains(MetadataObject);
	
EndFunction

Function IsBusinessProcess(Val MetadataObject) Export
	
	Return Metadata.BusinessProcesses.Contains(MetadataObject);
	
EndFunction

Function IsExchangePlan(Val MetadataObject) Export
	
	Return Metadata.ExchangePlans.Contains(MetadataObject);
	
EndFunction

// Checks whether the specified type is a record set.
//
// Parameters:
//  MetadataObject - Metadata object - Object
//
// Returns:
//  Boolean - True in case of success.
// 
Function IsRecordSet(Val MetadataObject) Export
	Return Metadata.InformationRegisters.Contains(MetadataObject) 
			Or Metadata.AccumulationRegisters.Contains(MetadataObject) 
			Or Metadata.AccountingRegisters.Contains(MetadataObject) 
			Or Metadata.CalculationRegisters.Contains(MetadataObject) 
			Or Metadata.Sequences.Contains(MetadataObject) 
			Or Metadata.CalculationRegisters.Contains(MetadataObject.Parent());
EndFunction

Function IsIndependentRecordSet(Val MetadataObject) Export
	
	Return Metadata.InformationRegisters.Contains(MetadataObject)
		And MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent;
	
EndFunction

Function IsRecalculationRecordSet(Val MetadataObject) Export
	
	Return Metadata.CalculationRegisters.Contains(MetadataObject.Parent());
	
EndFunction

Function IsSequenceRecordSet(Val MetadataObject) Export
	
	Return Metadata.Sequences.Contains(MetadataObject);
	
EndFunction

Function IsDocumentJournal(Val MetadataObject) Export
	
	Return Metadata.DocumentJournals.Contains(MetadataObject);
	
EndFunction

Function IsScheduledJob(Val MetadataObject) Export
	
	Return Metadata.ScheduledJobs.Contains(MetadataObject);
	
EndFunction

Function MetadataObjectByRefType(Val FieldType) Export
	
	BusinessProcessRoutePointRefs = BusinessProcessRoutePointRefs();
	
	BusinessProcess = BusinessProcessRoutePointRefs.Get(FieldType);
	If BusinessProcess = Undefined Then
		Ref = New(FieldType);
		RefMetadata = Ref.Metadata();
	Else
		RefMetadata = BusinessProcess;
	EndIf;
	
	Return RefMetadata;
	
EndFunction

Procedure WriteObjectToFile(Val Object, Val FileName, Serializer = Undefined) Export
	
	RecordStream = New XMLWriter();
	RecordStream.OpenFile(FileName);
	
	WriteObjectToStream(Object, RecordStream, Serializer);
	
	RecordStream.Close();
	
EndProcedure

Procedure WriteObjectToStream(Val Object, RecordStream, Serializer = Undefined) Export
	
	If Serializer = Undefined Then
		Serializer = XDTOSerializer;
	EndIf;
	
	RecordStream.WriteStartElement(NameOfItemContainingObject());
	
	NamespacePrefixes = NamespacePrefixes();
	For Each NamespacePrefix In NamespacePrefixes Do
		RecordStream.WriteNamespaceMapping(NamespacePrefix.Value, NamespacePrefix.Key);
	EndDo;
	
	Serializer.WriteXML(RecordStream, Object, XMLTypeAssignment.Explicit);
	
	RecordStream.WriteEndElement();
	
EndProcedure

Function ReadObjectFromFile(Val FileName) Export
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(FileName);
	ReaderStream.MoveToContent();
	
	Object = ReadObjectFromStream(ReaderStream);
	
	ReaderStream.Close();
	
	Return Object;
	
EndFunction

Function ReadObjectFromStream(ReaderStream) Export
	
	If ReaderStream.NodeType <> XMLNodeType.StartElement
			Or ReaderStream.Name <> NameOfItemContainingObject() Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'XML read error. Invalid file format. Expecting beginning of item %1.'"),
			NameOfItemContainingObject()
		);
		
	EndIf;
	
	If Not ReaderStream.Read() Then
		Raise NStr("en = 'XML read error. End of file detected.'");
	EndIf;
	
	Object = XDTOSerializer.ReadXML(ReaderStream);
	
	Return Object;
	
EndFunction

Procedure WriteXDTOObjectToFile(Val XDTODataObject, Val FileName, Val DefaultNamespacePrefix = "") Export
	
	RecordStream = New XMLWriter();
	RecordStream.OpenFile(FileName);
	
	NamespacePrefixes = NamespacePrefixes();
	ObjectNamespace = XDTODataObject.Type().NamespaceURI;
	If IsBlankString(DefaultNamespacePrefix) Then
		DefaultNamespacePrefix = NamespacePrefixes.Get(ObjectNamespace);
	EndIf;
	UsedNamespaced = GetNamespacesToWritePackage(ObjectNamespace);
	
	RecordStream.WriteStartElement(NameOfItemContainingXDTOObject());
	
	For Each UsedNamespace In UsedNamespaced Do
		NamespacePrefix = NamespacePrefixes.Get(UsedNamespace);
		If NamespacePrefix = DefaultNamespacePrefix Then
			RecordStream.WriteNamespaceMapping("", UsedNamespace);
		Else
			RecordStream.WriteNamespaceMapping(NamespacePrefix, UsedNamespace);
		EndIf;
	EndDo;
	
	XDTOFactory.WriteXML(RecordStream, XDTODataObject);
	
	RecordStream.WriteEndElement();
	
	RecordStream.Close();
	
EndProcedure

Function ReadXDTOObjectFromFile(Val FileName, Val XDTOType) Export
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(FileName);
	ReaderStream.MoveToContent();
	
	If ReaderStream.NodeType <> XMLNodeType.StartElement
			Or ReaderStream.Name <> NameOfItemContainingXDTOObject() Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'XML read error. Invalid file format. Expecting beginning of item %1.'"),
			NameOfItemContainingXDTOObject()
		);
		
	EndIf;
	
	If Not ReaderStream.Read() Then
		Raise NStr("en = 'XML read error. End of file detected.'");
	EndIf;
	
	XDTODataObject = XDTOFactory.ReadXML(ReaderStream, XDTOType);
	
	ReaderStream.Close();
	
	Return XDTODataObject;
	
EndFunction

Function NameOfItemContainingXDTOObject()
	
	Return "XDTODataObject";
	
EndFunction

Function NameOfItemContainingObject()
	
	Return "Data";
	
EndFunction

Function GetNamespacesToWritePackage(Val NamespaceURI)
	
	Result = New Array();
	Result.Add(NamespaceURI);
	
	Dependencies = XDTOFactory.Packages.Get(NamespaceURI).Dependencies;
	For Each Relation In Dependencies Do
		DependentNamespaces = GetNamespacesToWritePackage(Relation.NamespaceURI);
		CommonUseClientServer.SupplementArray(Result, DependentNamespaces, True);
	EndDo;
	
	Return Result;
	
EndFunction

Function NamespacePrefixes() Export
	
	Result = New Map();
	
	Result.Insert("http://www.w3.org/2001/XMLSchema", "xs");
	Result.Insert("http://www.w3.org/2001/XMLSchema-instance", "xsi");
	Result.Insert("http://v8.1c.ru/8.1/data/core", "core");
	Result.Insert("http://v8.1c.ru/8.1/data/enterprise/current-config", "v8");
	Result.Insert("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "dump");
	
	Return New FixedMap(Result);
	
EndFunction

// Adds update handler procedures required by the subsystem to the Handlers list.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function 
//              in the InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	ImportExportDataStorageData.RegisterUpdateHandlers(Handlers);
	ImportExportCommonSeparatedData.RegisterUpdateHandlers(Handlers);
	ImportExportPredefinedData.RegisterUpdateHandlers(Handlers);
	ImportExportSharedData.RegisterUpdateHandlers(Handlers);
	
EndProcedure


// Returns a full list of configuration constants.
//
// Returns:
//  Array - Array of metadata objects.
//
Function AllConstants() Export
	
	ObjectMetadata = New Array;
	FillConstantCollections(ObjectMetadata);
	Return AllCollectionMetadata(ObjectMetadata);
	
EndFunction

Procedure FillConstantCollections(MetadataCollectionArray)
	
	MetadataCollectionArray.Add(Metadata.Constants);
	
EndProcedure

// Returns a full list of configuration reference types.
//
// Returns:
//  Array - Array of metadata objects.
//
Function AllRefData() Export
	
	ObjectMetadata = New Array;
	FillRefObjectCollections(ObjectMetadata);
	Return AllCollectionMetadata(ObjectMetadata);
	
EndFunction

Procedure FillRefObjectCollections(MetadataCollectionArray)
	
	MetadataCollectionArray.Add(Metadata.Catalogs);
	MetadataCollectionArray.Add(Metadata.Documents);
	MetadataCollectionArray.Add(Metadata.BusinessProcesses);
	MetadataCollectionArray.Add(Metadata.Tasks);
	MetadataCollectionArray.Add(Metadata.ChartsOfAccounts);
	MetadataCollectionArray.Add(Metadata.ExchangePlans);
	MetadataCollectionArray.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollectionArray.Add(Metadata.ChartsOfCalculationTypes);
	
EndProcedure

// Returns a full list of configuration record sets.
//
// Returns:
//  Array - Array of metadata objects.
//
Function AllRecordsSets() Export
	
	ObjectMetadata = New Array;
	FillRecordSetCollections(ObjectMetadata);
	Return AllCollectionMetadata(ObjectMetadata);
	
EndFunction

Procedure FillRecordSetCollections(MetadataCollectionArray)
	
	MetadataCollectionArray.Add(Metadata.InformationRegisters);
	MetadataCollectionArray.Add(Metadata.AccumulationRegisters);
	MetadataCollectionArray.Add(Metadata.AccountingRegisters);
	MetadataCollectionArray.Add(Metadata.Sequences);
	MetadataCollectionArray.Add(Metadata.CalculationRegisters);
	For Each CalculationRegister In Metadata.CalculationRegisters Do
		MetadataCollectionArray.Add(CalculationRegister.Recalculations);
	EndDo;
	
EndProcedure

// Returns a full list of objects in the specified collections.
//
// Parameters:
//  Collections - Array - Collections.
//
// Returns:
//  Array - Array of metadata objects.
//
Function AllCollectionMetadata(Val Collections)
	
	Result = New Array;
	For Each Collection In Collections Do
		
		For Each Object In Collection Do
			Result.Add(Object);
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function BusinessProcessRoutePointRefs()
	
	Result = New Map();
	
	For Each BusinessProcess In Metadata.BusinessProcesses Do
		
		Result.Insert(Type("BusinessProcessRoutePointRef." + BusinessProcess.Name), BusinessProcess);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function IsPrimitiveType(Val TypeToCheck) Export
	
	Return TypeToCheck = Type("String") Or TypeToCheck = Type("Number") Or TypeToCheck = Type("Date") Or TypeToCheck = Type("Boolean") Or TypeToCheck = Type("UUID");
	
EndFunction
