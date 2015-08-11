////////////////////////////////////////////////////////////////////////////////
// DataImportExport: Exporting the data area to a file/Importing data from a file into the data area.
//						 Available only for the infobase or data area administrator.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Exports data from the current data area to a zip archive with XML files.
//
// Parameters:
// NoSeparationByFiles - Boolean - if it is True, all data will be exported to a single file,
// if it is False, data that requires reference replacement during import will be exported separately;
// SaveUserPasswords - Boolean - flag that shows wheter users will be exported with their passwords.
//
// Returns:
// String - full name of the exported file.
//
Function ExportCurrentAreaToArchive(Val NoSeparationByFiles = False, Val SaveUserPasswords = False) Export
	
	ExportDirectory = GetTempFileName();
	CreateDirectory(ExportDirectory);
	
	ExportDirectory = ExportDirectory + "/";
	
	WriteInformationAboutExportToXML(ExportDirectory, NoSeparationByFiles);
	
	If NoSeparationByFiles Then
		ExportFileName = ExportDirectory + "data_misc.xml";
		Writer = New XMLWriter;
		Writer.OpenFile(ExportFileName);
		Writer.WriteXMLDeclaration();
		WriteAreaDataToXML(Writer, True);
		Writer.Close();
	Else
		WriteDataToXMLWithTypes(ExportDirectory, GetSuppliedCatalogTypeArray());
	EndIf;
	
	WriteUsersToXML(ExportDirectory, SaveUserPasswords);
	
	DataImportExportOverridable.ExportBeforeComplete(ExportDirectory);
	
	ArchiveName = GetTempFileName("zip");
	
	Archiver = New ZipFileWriter(ArchiveName, , , , ZIPCompressionLevel.Maximum);
	Archiver.Add(ExportDirectory + "*");
	Archiver.Write();
	
	Try
		DeleteFiles(ExportDirectory);
	Except
		
	EndTry;
	
	Return ArchiveName;
	
EndFunction

// Imports data into the current data area from the zip archive with XML files.
//
// Parameters:
// ArchiveName - String - full name of the archive file that contains data;
// NoSeparationByFiles - Boolean - must be set to True if all data in the archive is contained in a single file,
// must be set to False if data that requires reference replacement is stored to a separate file;
// ImportUsers - Boolean - flag that shows whether details of all infobase users will be imported;
// DebugMode - Boolean - if it is True, a fragment of the XML file will be recorded to the event log
// in case of deserialization error. This action slows down the import.
//
Procedure ImportCurrentAreaFromArchive(Val ArchiveName, Val NoSeparationByFiles = False, Val ImportUsers = False, Val DebugMode = False) Export
	
	ExportDirectory = GetTempFileName();
	CreateDirectory(ExportDirectory);
	
	ExportDirectory = ExportDirectory + "/";
	
	Dearchiver = New ZipFileReader(ArchiveName);
	Dearchiver.ExtractAll(ExportDirectory, ZIPRestoreFilePathsMode.DontRestore);
	
	If NoSeparationByFiles Then
		ImportDataViaXDTOSerializer(ExportDirectory, , DebugMode);
	Else
		StandardSubsystemsOverridable.CreateDataAreaNode(CommonUse.SessionSeparatorValue());
		
		ImportDataSubstitutingRefs(ExportDirectory, DebugMode);
	EndIf;
	
	StandardSubsystemsOverridable.AfterDataImportFromOtherMode();
	
	If ImportUsers Then
		IDMapping = CreateUsersFromXML(ExportDirectory);
		ProcessUsersAfterImportFromOtherModel(IDMapping);
	EndIf;
	
	Try
		DeleteFiles(ExportDirectory);
	Except
		
	EndTry;
	
EndProcedure

// Writes area data to the passed XMLWriter object.
//
// Parameters:
// Writer - XMLWriter;
// FastInfosetWriter - initialized object for writing XML file;
// ExportSharedSuppliedData - Boolean - flag that shows whether shared supplied data
// will be exported.
//
Procedure WriteAreaDataToXML(Val Writer, Val ExportSharedSuppliedData = False) Export
	
	NonExportableTypes = New Array;
	StandardSubsystemsOverridable.GetNonExportableFromInfoBaseTypes(NonExportableTypes);
	
	NonExportableTypeNames= New Map;
	For Each Type In NonExportableTypes Do
		NonExportableTypeNames.Insert(Metadata.FindByType(Type), True);
	EndDo;
	NonExportableTypeNames = New FixedMap(NonExportableTypeNames);
	
	SharedDataToExportNames = New Map;
	If ExportSharedSuppliedData Then
		
		For Each MapRow In CommonUse.GetSeparatedAndSharedDataMapTable() Do
			If MapRow.SeparatedDataType <> Undefined Then
				Continue;
			EndIf;
			
			SharedDataFullName = Metadata.FindByType(MapRow.SharedDataType);
			If NonExportableTypeNames .Get(SharedDataFullName) = Undefined Then
				SharedDataToExportNames.Insert(SharedDataFullName, True);
			EndIf;
		EndDo;
	EndIf;
	SharedDataToExportNames = New FixedMap(SharedDataToExportNames);
	
	Writer.WriteStartElement("Data");
	Writer.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	Writer.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Writer.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
	
	CommonAttributeMD = Metadata.CommonAttributes.DataArea;
	
	// Going over all metadata
	
	// Constants
	For Each MetadataConstants In Metadata.Constants Do
		MetadataObjectFullName = MetadataConstants.FullName();
		
		If NonExportableTypeNames.Get(MetadataObjectFullName) <> Undefined Then
			Continue;
		EndIf;
		
		If Not CommonUse.IsSeparatedMetadataObject(MetadataConstants) Then
			If SharedDataToExportNames.Get(MetadataObjectFullName) = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		ValueManager = Constants[MetadataConstants.Name].CreateValueManager();
		ValueManager.Read();
		Try
			DataImportExportOverridable.BeforeDataExport(ValueManager);
			WriteXML(Writer, ValueManager);
		Except
			RaiseWithClarifyingText(Constants[MetadataConstants.Name], ErrorInfo());
		EndTry;
	EndDo;
	
	// Independent information registers
	For Each RegisterMD In Metadata.InformationRegisters Do
		MetadataObjectFullName = RegisterMD.FullName();
		
		If NonExportableTypeNames.Get(MetadataObjectFullName) <> Undefined Then
			Continue;
		EndIf;
		
		If Not CommonUse.IsSeparatedMetadataObject(RegisterMD) Then
			If SharedDataToExportNames.Get(MetadataObjectFullName) = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		If RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
			
			Continue;
		EndIf;
		
		TypeManager = InformationRegisters[RegisterMD.Name];
		
		RecordSet = TypeManager.CreateRecordSet();
		RecordSet.Read();
		Try
			DataImportExportOverridable.BeforeDataExport(RecordSet);
			WriteXML(Writer, RecordSet);
		Except
			RaiseWithClarifyingText(TypeManager, ErrorInfo());
		EndTry;
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
			MetadataObjectFullName = ObjectMD.FullName();
			
			If NonExportableTypeNames.Get(MetadataObjectFullName) <> Undefined Then
				Continue;
			EndIf;
			
			If Not CommonUse.IsSeparatedMetadataObject(ObjectMD) Then
				If SharedDataToExportNames.Get(MetadataObjectFullName) = Undefined Then
					Continue;
				EndIf;
			EndIf;
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + MetadataObjectFullName + " AS _XMLExport_Table";
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Object = Selection.Ref.GetObject();
				Try
					DataImportExportOverridable.BeforeDataExport(Object);
					WriteXML(Writer, Object);
				Except
					RaiseWithClarifyingText(MetadataObjectFullName, ErrorInfo(), "Ref: " + Selection.Ref);
				EndTry;
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
			MetadataObjectFullName = RegisterMD.FullName();
			
			If NonExportableTypeNames.Get(MetadataObjectFullName) <> Undefined Then
				Continue;
			EndIf;
			
			If Not CommonUse.IsSeparatedMetadataObject(RegisterMD) Then
				If SharedDataToExportNames.Get(MetadataObjectFullName) = Undefined Then
					Continue;
				EndIf;
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
			|	" + MetadataObjectFullName + " AS _XMLExport_Table";
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				RecordSet = TypeManager.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(Selection.Recorder);
				RecordSet.Read();
				Try
					DataImportExportOverridable.BeforeDataExport(RecordSet);
					WriteXML(Writer, RecordSet);
				Except
					RaiseWithClarifyingText(TypeManager, ErrorInfo(), "Recorder: " + Selection.Recorder);
				EndTry;
			EndDo;
		EndDo;
	EndDo;
	
	Writer.WriteEndElement();
	
EndProcedure

// Reads data from the passed XMLReader object and writes it to the infobase.
// Parameters:
// Reader - XMLReader, FastInfoSetReader - initialized object for reading the XML file.
//
Procedure ReadAreaDataFromXML(Val Reader) Export
	
	Types = New Array;
	StandardSubsystemsOverridable.GetNonImportableToDataAreaTypes(Types);
	ServiceModeOverridable.GetNonImportableToDataAreaTypes(Types);
	ExcludedTypes = New Map;
	For Each Type In Types Do
		ExcludedTypes.Insert(Type, True);
	EndDo;
	
	While Reader.NodeType = XMLNodeType.StartElement Do
		If Not CanReadXML(Reader) Then
			TypeDefinitionOnReadError(Reader);
		EndIf;
		
		Data = ReadXML(Reader);
		
		If ExcludedTypes.Get(TypeOf(Data)) <> Undefined Then
			Continue;
		EndIf;
		
		Data.AdditionalProperties.Insert("DontCheckEditProhibitionDates", True);
		Data.DataExchange.Load = True;
		Data.Write();
	EndDo;
	
EndProcedure

// Exports data from the current data area to a temporary storage.
// Parameters:
// StorageAddress - String - address of a storage where data will be exported.
//
Procedure ExportCurrentAreaToTempStorage(Val StorageAddress) Export
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		
		Raise(NStr("en = 'Only the data area administrator has the right to execute this operation.'"));
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	ArchiveName = ExportCurrentAreaToArchive();
		
	ExportData = New BinaryData(ArchiveName);
	
	PutToTempStorage(ExportData, StorageAddress);
	
	ExportData = Undefined;
	Try
		DeleteFiles(ArchiveName);
	Except
		// If deletion failed, the system will delete the temporary file automatically
		WriteLogEvent(NStr("en = 'Deleting the femporary file'", Metadata.DefaultLanguage.LanguageCode),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Exports data from the specified data area to a temporary storage by the passed address.
//
// Parameters:
// DataArea - Number - separator value of the data area to be exported;
// StorageAddress - String - address of a storage where data will be exported.
//
Procedure ExportAreaToTempStorage(Val DataArea, Val StorageAddress) Export
	
	If Not CommonUseCached.SessionWithoutSeparator()
		Or Not Users.InfoBaseUserWithFullAccess(, True) Then
		
		Raise(NStr("en = 'Only the infobase administrator has the right to execute this operation.'"));
	EndIf;
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
	ExportCurrentAreaToTempStorage(StorageAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure TypeDefinitionOnReadError(Val Reader)
	
	Writer = New XMLWriter;
	Writer.SetString();
	Writer.WriteCurrent(Reader);
	CurrentElement = Writer.Close();
	
	TextPattern = NStr("en = 'Error reading the XML file. The data type cannot be determinated
		|based on the %1 element.'");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(TextPattern, CurrentElement);
	Raise(MessageText);
	
EndProcedure

Function GetFactoryWithTypes(Val Types = Undefined)
	
	SchemaFileName = GetTempFileName("xsd");
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	DOMWriter = New DOMWriter;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(SchemaFileName);
	
	RootNode = Schema.DOMDocument.ChildNodes[0];
	
	IgnoreTypes = New Array;
	IgnoreTypes.Add("AccountingRegisterExtDimensions");
	IgnoreTypes.Add("CatalogTabularSectionRow");
	IgnoreTypes.Add("ChartOfAccountsExtDimensionTypesRow");
	IgnoreTypes.Add("LeadingCalculationTypesRow");
	IgnoreTypes.Add("DocumentTabularSectionRow");
	IgnoreTypes.Add("AccountingRegisterRecord");
	IgnoreTypes.Add("AccumulationRegisterRecord");
	IgnoreTypes.Add("InformationRegisterRecord");
	IgnoreTypes.Add("EnumRef");
	
	If Types = Undefined Then
		SelectedTypesOnly = False;
	Else
		SelectedTypesOnly = True;
		
		SelectedTypes = New Map;
		For Each Type In Types Do
			SelectedTypes.Insert(XDTOSerializer.XMLType(Type).TypeName, True);
		EndDo;
	EndIf;
	
	For Each Node In RootNode.ChildNodes Do
		AddTypeToCode = False;
		
		If Node.LocalName <> "complexType" Then
			Continue;
		EndIf;
		
		If Node.ChildNodes.Count() = 0 Then
			Continue;
		EndIf;
		
		NodeContent = Node.ChildNodes[0];
		
		If NodeContent.LocalName <> "sequence" Then
			Continue;
		EndIf;
		
		For Each NodeFields In NodeContent.ChildNodes Do
			If NodeFields.LocalName <> "element" Then
				Continue;
			EndIf;
			
			NameAttribute = NodeFields.Attributes.GetNamedItem("name");
			If AddTypeToCode
				And NameAttribute <> Undefined And NameAttribute.TextContent = "Code" Then
				NodeFields.SetAttribute("nillable", "true");
				NodeFields.RemoveAttribute("type");
				Continue;
			EndIf;
			
			TypeAttribute = NodeFields.Attributes.GetNamedItem("type");
			If TypeAttribute <> Undefined Then
				If Find(TypeAttribute.TextContent, "tns:") = 1 Then
					
					TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
					
					If SelectedTypesOnly Then
						If SelectedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
							Continue;
						EndIf;
					Else
						Skip = False;
						For Each TypePrefix In IgnoreTypes Do
							If Find(TypeWithoutNSPrefix, TypePrefix) = 1 Then
								Skip = True;
								Break;
							EndIf;
						EndDo;
						If Skip Then
							Continue;
						EndIf;
					EndIf;
					
					If NameAttribute <> Undefined And NameAttribute.TextContent = "Ref" Then
						AddTypeToCode = True;
					EndIf;
					
					NodeFields.SetAttribute("nillable", "true");
					NodeFields.RemoveAttribute("type");
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	
	XMLWriter.Close();
	
	Factory = CreateXDTOFactory(SchemaFileName);
	
	Try
		DeleteFiles(SchemaFileName);
	Except
		
	EndTry;
	
	Return Factory;
	
EndFunction

Procedure WriteUsersToXML(ExportDirectory, StorePasswords)
	
	Writer = New XMLWriter;
	Writer.OpenFile(ExportDirectory + "users.xml");
	Writer.WriteXMLDeclaration();
	
	Writer.WriteStartElement("Users");
	Writer.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	Writer.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Writer.WriteNamespaceMapping("ns1", "http://v8.1c.ru/8.1/data/core");
	Writer.WriteNamespaceMapping("ns2", "http://v8.1c.ru/8.1/data/enterprise");
	Writer.WriteNamespaceMapping("v8", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	
	For Each User In InfoBaseUsers.GetUsers() Do
		XDTOFactory.WriteXML(Writer, WriteUserToXDTO(User, StorePasswords));
	EndDo;
	
	Writer.WriteEndElement();
	
	Writer.Close();
	
EndProcedure

Procedure WriteInformationAboutExportToXML(ExportDirectory, NoSeparationByFiles)
	
	Writer= New XMLWriter;
	Writer.OpenFile(ExportDirectory + "dumpinfo.xml");
	Writer.WriteXMLDeclaration();
	
	Writer.WriteStartElement("Info");
	Writer.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	Writer.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Writer.WriteNamespaceMapping("ns1", "http://v8.1c.ru/8.1/data/core");
	Writer.WriteNamespaceMapping("ns2", "http://v8.1c.ru/8.1/data/enterprise");
	Writer.WriteNamespaceMapping("v8", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	
	DumpInfoType = XDTOFactory.Type("http://v8.1c.ru/misc/datadump", "DumpInfo");
	ConfigurationInfoType = XDTOFactory.Type("http://v8.1c.ru/misc/datadump", "ConfigurationInfo");
	
	ExportInfo = XDTOFactory.Create(DumpInfoType);
	If NoSeparationByFiles Then
		ExportInfo.Type = "ServiceToBox";
	Else
		ExportInfo.Type = "BoxToService";
	EndIf;
	ExportInfo.Created = CurrentDate();
	
	ConfigurationInfo = XDTOFactory.Create(ConfigurationInfoType);
	ConfigurationInfo.Name = Metadata.Name;
	ConfigurationInfo.Version = Metadata.Version;
	ConfigurationInfo.Presentation = Metadata.Presentation();
	
	ExportInfo.Configuration = ConfigurationInfo;
	
	XDTOFactory.WriteXML(Writer, ExportInfo);
	
	Writer.WriteEndElement();
	
	Writer.Close();
	
EndProcedure

Function GetSuppliedCatalogTypeArray()
	
	Types = New Array;
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	For Each MapRow In MapTable Do
		If Not Catalogs.AllRefsType().ContainsType(MapRow.SharedDataType) Then
			Continue;
		EndIf;
		
		If MapRow.SeparatedDataType = Undefined Then
			Type = MapRow.SharedDataType;
		Else
			Type = MapRow.SeparatedDataType;
		EndIf;
		Types.Add(Type);
	EndDo;
	
	Return Types;
	
EndFunction

Function NumberFormat(Val Value)
	
	Return Format(Value, "ND=4; NZ=0000; NLZ=;NG=");
	
EndFunction

Procedure OpenXMLWriter(WriteParameters)
	
	WriteParameters.Writer = New XMLWriter;
	If WriteParameters.PartNumber = Undefined Then
		WriteParameters.PartNumber = 1;
	Else
		WriteParameters.PartNumber = WriteParameters.PartNumber + 1;
	EndIf;
	WriteParameters.PartSize = 0;
	
	PartNumberString = NumberFormat(WriteParameters.PartNumber);
	ExportFileName = 
		StringFunctionsClientServer.SubstituteParametersInString(WriteParameters.NamePattern, PartNumberString);
		
	WriteParameters.Writer.OpenFile(ExportFileName);
	WriteParameters.Writer.WriteXMLDeclaration();
	
	WriteParameters.Writer.WriteStartElement("DataDumpPart");
	WriteParameters.Writer.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	WriteParameters.Writer.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	WriteParameters.Writer.WriteNamespaceMapping("ns1", "http://v8.1c.ru/8.1/data/core");
	WriteParameters.Writer.WriteNamespaceMapping("ns2", "http://v8.1c.ru/8.1/data/enterprise");
	WriteParameters.Writer.WriteNamespaceMapping("v8", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	
	WriteParameters.Writer.WriteStartElement("Data");
	
EndProcedure

Procedure CloseXMLWriter(WriteParameters, HasContinuation = False)
	
	WriteParameters.Writer.WriteEndElement();
	
	WriteParameters.Writer.WriteStartElement("PartInfo");
	WriteParameters.Writer.WriteAttribute("LastPart", XMLString(Not HasContinuation));
	WriteParameters.Writer.WriteEndElement();
	
	WriteParameters.Writer.WriteEndElement();
	WriteParameters.Writer.Close();
	
EndProcedure

Procedure WriteToXML(Value, ValueMetadata, Size, Serializer, WriteParameters_TypesToReplace,
	WriteParameters_OtherData, TypeToReplaceMetadataNames, MaxSizePart)
	
	If TypeToReplaceMetadataNames.Get(ValueMetadata.FullName()) = Undefined Then
		WriteParameters = WriteParameters_OtherData;
	Else
		WriteParameters = WriteParameters_TypesToReplace;
	EndIf;
		
	If WriteParameters.PartSize >= MaxSizePart Then
		CloseXMLWriter(WriteParameters, True);
		OpenXMLWriter(WriteParameters);
	EndIf;
	
	WriteParameters.PartSize = WriteParameters.PartSize + Size;
	
	DataImportExportOverridable.BeforeDataExport(Value);
	Serializer.WriteXML(WriteParameters.Writer, Value);
	
EndProcedure

Function EstimateObjectSize(ObjectMD, Object)
	
	Size = 1;
	For Each TabularSectionMD In ObjectMD.TabularSections Do
		Size = Size + Object[TabularSectionMD.Name].Count();
	EndDo;
	
	Return Size;
	
EndFunction

Function EstimateRecordSetSize(SetMD, Set)
	
	Return Set.Count();
	
EndFunction

Procedure WriteDataToXMLWithTypes(ExportDirectory, TypesForReplacement = Undefined, MaxSizePart = 100000, 
	ExportExchangePlans = False)
	
	TypeToReplaceMetadataNames = New Map;
	If TypesForReplacement <> Undefined Then
		For Each TypeForReplacement In TypesForReplacement Do
			TypeToReplaceMetadataNames.Insert(Metadata.FindByType(TypeForReplacement).FullName(), True);
		EndDo;
		
		Factory = GetFactoryWithTypes(TypesForReplacement);
		Serializer = New XDTOSerializer(Factory);
	Else
		Serializer = XDTOSerializer;
	EndIf;
	
	CurrentPartSize = Undefined;
	CurrentPartNumber = 0;
	
	WriteParameters_TypesToReplace = New Structure("Writer, PartSize, NamePattern, PartNumber");
	WriteParameters_TypesToReplace.NamePattern = ExportDirectory + "data_shared%1.xml";
	
	OpenXMLWriter(WriteParameters_TypesToReplace);
	
	WriteParameters_OtherData = New Structure("Writer, PartSize, NamePattern, PartNumber");
	WriteParameters_OtherData.NamePattern = ExportDirectory + "data_misc%1.xml";
	
	OpenXMLWriter(WriteParameters_OtherData);
	
	CommonAttributeMD = Metadata.CommonAttributes.DataArea;
	
	// Going over all metadata
	
	// Constants
	For Each MetadataConstants In Metadata.Constants Do
		If Not CommonUse.IsSeparatedMetadataObject(MetadataConstants) Then
			Continue;
		EndIf;
		
		ValueManager = Constants[MetadataConstants.Name].CreateValueManager();
		ValueManager.Read();
		WriteToXML(ValueManager, MetadataConstants, 1, Serializer, WriteParameters_TypesToReplace,
			WriteParameters_OtherData, TypeToReplaceMetadataNames, MaxSizePart)
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
				If TypeToReplaceMetadataNames.Get(ObjectMD.FullName()) = Undefined Then
					Continue;
				EndIf;
			EndIf;
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + ObjectMD.FullName() + " AS _XMLExport_Table";
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Object = Selection.Ref.GetObject();
				
				Size = EstimateObjectSize(ObjectMD, Object);
				WriteToXML(Object, ObjectMD, Size, Serializer, WriteParameters_TypesToReplace,
					WriteParameters_OtherData, TypeToReplaceMetadataNames, MaxSizePart)
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
			Selection = QueryResult.Select();
			While Selection.Next() Do
				RecordSet = TypeManager.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(Selection.Recorder);
				RecordSet.Read();
				
				Size = EstimateRecordSetSize(RegisterMD, RecordSet);
				WriteToXML(RecordSet, RegisterMD, Size, Serializer, WriteParameters_TypesToReplace,
					WriteParameters_OtherData, TypeToReplaceMetadataNames, MaxSizePart)
			EndDo;
		EndDo;
	EndDo;
	
	SharedInformationRegisters = ServiceMode.SharedInformationRegistersWithSeparatedData();
	DataArea = CommonUse.SessionSeparatorValue();
	// Independent information registers
	For Each RegisterMD In Metadata.InformationRegisters Do
		
		If RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
			Continue;
		EndIf;
		
		If Not CommonUse.IsSeparatedMetadataObject(RegisterMD) Then
			If SharedInformationRegisters.Find(RegisterMD.Name) = Undefined Then
				Continue;
			EndIf;
			SharedRegister = True;
		Else
			SharedRegister = False;
		EndIf;
		
		TypeManager = InformationRegisters[RegisterMD.Name];
		
		RecordSet = TypeManager.CreateRecordSet();
		If SharedRegister Then
			RecordSet.Filter.DataArea.Set(DataArea);
		EndIf;
		RecordSet.Read();
		
		Size = EstimateRecordSetSize(RegisterMD, RecordSet);
		WriteToXML(RecordSet, RegisterMD, Size, Serializer, WriteParameters_TypesToReplace,
			WriteParameters_OtherData, TypeToReplaceMetadataNames, MaxSizePart)
	EndDo;
		
	If ExportExchangePlans Then
		For Each ObjectMD In Metadata.ExchangePlans Do
			If Not CommonUse.IsSeparatedMetadataObject(ObjectMD) Then
				Continue;
			EndIf;
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + ObjectMD.FullName() + " AS _XMLExport_Table
			|WHERE
			|	_XMLExport_Table.Ref <> &ThisNode";
			Query.SetParameter("ThisNode", ExchangePlans[ObjectMD.Name].ThisNode());
			
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Object = Selection.Ref.GetObject();
				
				Size = EstimateObjectSize(ObjectMD, Object);
				WriteToXML(Object, ObjectMD, Size, Serializer, WriteParameters_TypesToReplace,
				WriteParameters_OtherData, TypeToReplaceMetadataNames, MaxSizePart)
			EndDo;
		EndDo;
	EndIf;
		
	CloseXMLWriter(WriteParameters_TypesToReplace);
	CloseXMLWriter(WriteParameters_OtherData);
	
EndProcedure

Function PrepareReplacementDictionary()
	
	ReplacementDictionary = New ValueTable;
	ReplacementDictionary.Columns.Add("XMLTypeName", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
	ReplacementDictionary.Columns.Add("Type", New TypeDescription("Type"));
	ReplacementDictionary.Columns.Add("SharedData", New TypeDescription("Boolean"));
	ReplacementDictionary.Columns.Add("ReferenceMap", New TypeDescription("Map"));
	ReplacementDictionary.Columns.Add("InverseMap", New TypeDescription("Map"));
	ReplacementDictionary.Columns.Add("QueryText", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	ReplacementDictionary.Columns.Add("SharedRefs", New TypeDescription("Array"));
	For Each MapRow In CommonUse.GetSeparatedAndSharedDataMapTable() Do
		If Not Catalogs.AllRefsType().ContainsType(MapRow.SharedDataType) Then
			Continue;
		EndIf;
		
		ReplacementTypeDescription = ReplacementDictionary.Add();
		
		If MapRow.SeparatedDataType = Undefined Then
			ReplacementTypeDescription.SharedData = True;
			ReplacementTypeDescription.Type = MapRow.SharedDataType;
		Else
			ReplacementTypeDescription.SharedData = False;
			ReplacementTypeDescription.Type = MapRow.SeparatedDataType;
		EndIf;
		
		ReplacementTypeDescription.XMLTypeName = XDTOSerializer.XMLType(ReplacementTypeDescription.Type).TypeName;
		
		TypeMetadata = Metadata.FindByType(ReplacementTypeDescription.Type);
		SharedTypeMetadata = Metadata.FindByType(MapRow.SharedDataType);
		
		If SharedTypeMetadata.Hierarchical 
			And SharedTypeMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			FoldersCondition = Chars.LF + Chars.Tab + Chars.Tab + "AND Codes.IsFolder = CatalogTable.IsFolder";
			
		Else
			
			FoldersCondition = "";
			
		EndIf;
		
		ReplacementTypeDescription.QueryText = 
		"SELECT
		|	Codes.Ref AS SourceRef,
		|	Codes.Code AS Code,
		|	CatalogTable.Ref AS SharedRef
		|FROM
		|	Codes AS Codes
		|		LEFT JOIN " + SharedTypeMetadata.FullName() + " AS CatalogTable
		|		ON Codes.Code = CatalogTable.Code" + FoldersCondition + "
		|WHERE
		|	Codes.Ref REFS " + TypeMetadata.FullName();
		
	EndDo;
	
	Return ReplacementDictionary;
	
EndFunction

Function PrepareReplacementDictionaryFragment()
	
	Result = New ValueTable;
	Result.Columns.Add("Type", New TypeDescription("Type"));
	Result.Columns.Add("ReferenceMap", New TypeDescription("Map"));
	
	Return Result;
	
EndFunction

Procedure AddFragmentToReplacementDictionary(Val ReplacementDictionary, Val Fragment)
	
	EmptyUUID = XDTOSerializer.XMLString(New UUID("00000000-0000-0000-0000-000000000000"));
	
	For Each FragmentRow In Fragment Do
		DictionaryRow = ReplacementDictionary.Find(FragmentRow.Type, "Type");
		If DictionaryRow = Undefined Then
			DictionaryRow = ReplacementDictionary.Add();
			DictionaryRow.Type = FragmentRow.Type;
			DictionaryRow.XMLTypeName = XDTOSerializer.XMLType(DictionaryRow.Type).TypeName;
			DictionaryRow.SharedData = True;
		EndIf;
		
		DictionaryRow.ReferenceMap = FragmentRow.ReferenceMap;
			
		DictionaryRow.InverseMap = New Map;
		DictionaryRow.InverseMap.Insert(EmptyUUID, EmptyUUID);
		
		For Each KeyAndValue In DictionaryRow.ReferenceMap Do
			SourceRefXML = XDTOSerializer.XMLString(KeyAndValue.Value.UUID());
			FoundRefXML = XDTOSerializer.XMLString(KeyAndValue.Key.UUID());
			DictionaryRow.InverseMap.Insert(SourceRefXML, FoundRefXML);
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure ImportDataSubstitutingRefs(Val ExportDirectory, Val DebugMode)
	
	ReplacementDictionary = PrepareReplacementDictionary();
	
	ReplacementDictionaryFragment = PrepareReplacementDictionaryFragment();
	DataImportExportOverridable.SupplementReplacementDictionaryByExportCatalog(ReplacementDictionaryFragment, ExportDirectory);
	AddFragmentToReplacementDictionary(ReplacementDictionary, ReplacementDictionaryFragment);
	
	EmptyUUID = XDTOSerializer.XMLString(New UUID("00000000-0000-0000-0000-000000000000"));
	
	Conflicts = New ValueTable;
	Conflicts.Columns.Add("SourceRef", Catalogs.AllRefsType());
	Conflicts.Columns.Add("Code", New TypeDescription("Number, String", 
		New NumberQualifiers(20, 0, AllowedSign.Nonnegative), New StringQualifiers(50, AllowedLength.Variable)));
	Conflicts.Columns.Add("FoundReference", Catalogs.AllRefsType());
	Conflicts.Indexes.Add("SourceRef, FoundReference");
	
	BrokenReferences = New ValueTable;
	BrokenReferences.Columns.Add("SourceRef", Catalogs.AllRefsType());
	BrokenReferences.Columns.Add("Code", New TypeDescription("Number, String", 
		New NumberQualifiers(20, 0, AllowedSign.Nonnegative), New StringQualifiers(50, AllowedLength.Variable)));
		
	CodeTableCreateQueryText =
	"SELECT
	|	Codes.Ref AS Ref,
	|	Codes.Code AS Code,
	|	Codes.IsFolder AS IsFolder
	|INTO Codes
	|FROM
	|	&CodeTable AS Codes
	|
	|INDEX BY
	|	Ref";
	
	SharedDataFiles = FindFiles(ExportDirectory, "data_shared*.xml", False);
	For Each SharedDataFile In SharedDataFiles Do
		
		CodeTable = GetSharedDataCodeTable(SharedDataFile.FullName);
		
		TTManager = New TempTablesManager;
		
		Query = New Query;
		Query.TempTablesManager = TTManager;
		Query.Text = CodeTableCreateQueryText;
		Query.SetParameter("CodeTable", CodeTable);
		Query.Execute();
		
		For Each ReplacementTypeDescription In ReplacementDictionary Do
			If IsBlankString(ReplacementTypeDescription.QueryText) Then
				Continue;
			EndIf;
			
			ReplacementTypeDescription.ReferenceMap = New Map;
			
			ReplacementTypeDescription.InverseMap = New Map;
			ReplacementTypeDescription.InverseMap.Insert(EmptyUUID, EmptyUUID);
			
			RefsForFilling = New Array;
			
			Query.Text = ReplacementTypeDescription.QueryText;
			Result = Query.Execute();
			Selection = Result.Select();
			While Selection.Next() Do
				SourceRefXML = XDTOSerializer.XMLString(Selection.SourceRef.UUID());
				
				If Selection.SharedRef = NULL Then
					ErrorString = BrokenReferences.Add();
					ErrorString.SourceRef = Selection.SourceRef;
					ErrorString.Code = Selection.Code;
					
					ReplacementTypeDescription.InverseMap.Insert(
						SourceRefXML, SourceRefXML);
				Else
					FoundRefXML = XDTOSerializer.XMLString(Selection.SharedRef.UUID());
					
					ExistingValue = ReplacementTypeDescription.ReferenceMap.Get(Selection.SharedRef);
					If ExistingValue <> Undefined Then
						If Conflicts.FindRows(New Structure("SourceRef, FoundReference", 
							ExistingValue, Selection.SharedRef)).Count() = 0 Then
							
							Conflict = Conflicts.Add();
							Conflict.SourceRef = ExistingValue;
							Conflict.Code = Selection.Code;
							Conflict.FoundReference = Selection.SharedRef;
						EndIf;
						
						Conflict = Conflicts.Add();
						Conflict.SourceRef = Selection.SourceRef;
						Conflict.Code = Selection.Code;
						Conflict.FoundReference = Selection.SharedRef;
					Else
						ReplacementTypeDescription.ReferenceMap.Insert(Selection.SharedRef, Selection.SourceRef);
						ReplacementTypeDescription.InverseMap.Insert(SourceRefXML, FoundRefXML);
						
						ReplacementTypeDescription.SharedRefs.Add(Selection.SharedRef);
					EndIf;
				EndIf;
			EndDo;
			
		EndDo;
		
		ReplacementDictionaryFragment = PrepareReplacementDictionaryFragment();
		DataImportExportOverridable.SupplementReplacementDictionaryForSharedData(ReplacementDictionaryFragment, SharedDataFile.FullName);
		AddFragmentToReplacementDictionary(ReplacementDictionary, ReplacementDictionaryFragment);
		
		SearchMask = "data_*.xml";
		AllDataFiles = FindFiles(ExportDirectory, SearchMask, False);
		For Each DataFile In AllDataFiles Do
			
			// Replacing references
			Reader = New TextReader(DataFile.FullName);
			ProcessedFileName = GetTempFileName();
			Writer = New TextWriter(ProcessedFileName);
			
			// Constants for parsing a text
			TypeBeginning = "xsi:type=""v8:";
			TypeBeginningLength = StrLen(TypeBeginning);
			TypeEnd = """>";
			TypeEndLength = StrLen(TypeEnd);
			
			SourceLine = Reader.ReadLine();
			While SourceLine <> Undefined Do
				
				RemainingString = Undefined;
				
				CurrentPosition = 1;
				TypePosition = Find(SourceLine, TypeBeginning);
				While TypePosition > 0 Do
					
					Writer.Write(Mid(SourceLine, CurrentPosition, TypePosition - 1 + TypeBeginningLength));
					
					CurrentPosition = CurrentPosition + TypePosition + TypeBeginningLength;
					
					If RemainingString = Undefined Then
						RemainingString = Mid(SourceLine, TypePosition + TypeBeginningLength);
					Else
						RemainingString = Mid(RemainingString, TypePosition + TypeBeginningLength);
					EndIf;
					TypePosition = Find(RemainingString, TypeBeginning);
					
					TypeEndPosition = Find(RemainingString, TypeEnd);
					If TypeEndPosition = 0 Then
						Break;
					EndIf;
					
					TypeName = Left(RemainingString, TypeEndPosition - 1);
					ReplacementTypeDescription = ReplacementDictionary.Find(TypeName, "XMLTypeName");
					If ReplacementTypeDescription = Undefined Then
						Continue;
					EndIf;
					
					Writer.Write(TypeName);
					Writer.Write(TypeEnd);
					
					SourceRefXML = Mid(RemainingString, TypeEndPosition + TypeEndLength, 36);
					FoundRefXML = ReplacementTypeDescription.InverseMap.Get(SourceRefXML);
					If FoundRefXML = Undefined Then
						Writer.Write(SourceRefXML);
					Else
						Writer.Write(FoundRefXML);
					EndIf;
					
					CurrentPosition = CurrentPosition + TypeEndPosition - 1 + TypeEndLength + 36;
					RemainingString = Mid(RemainingString, TypeEndPosition + TypeEndLength + 36);
					TypePosition = Find(RemainingString, TypeBeginning);
					
				EndDo;
				
				If RemainingString <> Undefined Then
					Writer.WriteLine(RemainingString);
				Else
					Writer.WriteLine(Mid(SourceLine, CurrentPosition));
				EndIf;
				
				SourceLine = Reader.ReadLine();
			EndDo;
			
			Reader.Close();
			
			Writer.Close();
			
			DeleteFiles(DataFile.FullName);
			MoveFile(ProcessedFileName, DataFile.FullName);
			
		EndDo;
		
	EndDo;
	
	// Importing data
	ImportDataViaXDTOSerializer(ExportDirectory, , DebugMode);
	
	For Each ReplacementTypeDescription In ReplacementDictionary Do
		If ReplacementTypeDescription.SharedData Then
			Continue;
		EndIf;
		
		//StandardSubsystemsServerCallOverridable.FillSuppliedDataFromClassifier(ReplacementTypeDescription.SharedRefs);
	EndDo;
	
EndProcedure

Procedure ImportDataViaXDTOSerializer(Val ExportDirectory, Val SearchMask = Undefined, Val DebugMode = False)

	Types = New Array;
	StandardSubsystemsOverridable.GetNonImportableToDataAreaTypes(Types);
	ServiceModeOverridable.GetNonImportableToDataAreaTypes(Types);
	ExcludedTypes = New Map;
	For Each Type In Types Do
		ExcludedTypes.Insert(Type, True);
	EndDo;
	
	If SearchMask = Undefined Then
		SearchMask = "data_*.xml";
	EndIf;
	
	CommonAttributeMD = Metadata.CommonAttributes.DataArea;
	
	ExchangePlanTypes = New Map;
	For Each ExchangePlanMetadata In Metadata.ExchangePlans Do
		If Not CommonUse.IsSeparatedMetadataObject(ExchangePlanMetadata) Then
			Continue;
		EndIf;
		
		ExchangePlanTypes.Insert(Type("ExchangePlanObject." + ExchangePlanMetadata.Name), True);
	EndDo;
	
	SharedInformationRegisterTypes = New Map;
	For Each RegisterName In ServiceMode.SharedInformationRegistersWithSeparatedData() Do
		SharedInformationRegisterTypes.Insert(Type("InformationRegisterRecordSet." + RegisterName), True);
	EndDo;
	
	// Adding all shared data except shared information registers to the list of excluded types.
	For Each ContentItem In CommonAttributeMD.Content Do
		If CommonUse.CommonAttributeContentItemUsed(ContentItem, CommonAttributeMD) Then
			Continue;
		EndIf;
		
		If Metadata.ScheduledJobs.Contains(ContentItem.Metadata) Then
			Continue;
		ElsIf Metadata.Constants.Contains(ContentItem.Metadata) Then
			TypeName = "ConstantValueManager";
		ElsIf Metadata.Catalogs.Contains(ContentItem.Metadata) Then
			TypeName = "CatalogObject";
		ElsIf Metadata.Documents.Contains(ContentItem.Metadata) Then
			TypeName = "DocumentObject";
		ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(ContentItem.Metadata) Then
			TypeName = "ChartOfCharacteristicTypesObject";
		ElsIf Metadata.ChartsOfAccounts.Contains(ContentItem.Metadata) Then
			TypeName = "ChartOfAccountsObject";
		ElsIf Metadata.ChartsOfCalculationTypes.Contains(ContentItem.Metadata) Then
			TypeName = "ChartOfCalculationTypesObject";
		ElsIf Metadata.BusinessProcesses.Contains(ContentItem.Metadata) Then
			TypeName = "BusinessProcessObject";
		ElsIf Metadata.Tasks.Contains(ContentItem.Metadata) Then
			TypeName = "TaskObject";
		ElsIf Metadata.ExchangePlans.Contains(ContentItem.Metadata) Then
			TypeName = "ExchangePlanObject";
		ElsIf Metadata.AccumulationRegisters.Contains(ContentItem.Metadata) Then
			TypeName = "AccumulationRegisterRecordSet";
		ElsIf Metadata.AccountingRegisters.Contains(ContentItem.Metadata) Then
			TypeName = "AccountingRegisterRecordSet";
		ElsIf Metadata.Sequences.Contains(ContentItem.Metadata) Then
			TypeName = "SequenceRecordSet";
		Else
			TypeName = Undefined;
			// Information and calculation registers are processed separately
			If Metadata.InformationRegisters.Contains(ContentItem.Metadata) Then
				DataType = Type("InformationRegisterRecordSet." + ContentItem.Metadata.Name);
				If SharedInformationRegisterTypes.Get(DataType) = Undefined Then
					ExcludedTypes.Insert(DataType, True);
				EndIf;
			ElsIf Metadata.CalculationRegisters.Contains(ContentItem.Metadata) Then
				ExcludedTypes.Insert(Type("CalculationRegisterRecordSet." + ContentItem.Metadata.Name), True);
				For Each RecalculationMetadata In ContentItem.Metadata.Recalculations Do
					ExcludedTypes.Insert(Type("RecalculationRecordSet." + RecalculationMetadata.Name), True);
				EndDo;
			Else
				MessagePattern = NStr("en = 'An unexpected metadata object is found in the composition of the common attibute %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
					ContentItem.Metadata.FullName());
				Raise(MessageText);
			EndIf;
		EndIf;
		
		If TypeName <> Undefined Then
			ExcludedTypes.Insert(Type(TypeName + "." + ContentItem.Metadata.Name), True);
		EndIf;
	EndDo;
	
	DataArea = CommonUse.SessionSeparatorValue();
	
	AllDataFiles = FindFiles(ExportDirectory, SearchMask, False);
	
	While True Do
		
		Try
		
			For Each DataFile In AllDataFiles Do
				Reader = New XMLReader;
				Reader.OpenFile(DataFile.FullName);
				Reader.MoveToContent();
				
				If Reader.NodeType <> XMLNodeType.StartElement
					Or Reader.Name <> "DataDumpPart" Then
					
					Raise(NStr("en = 'Error reading the XML file. The file format is not valid. The Data element start tag is expected.'"));
				EndIf;
				
				If DebugMode Then
					NamespaceMappings = Reader.NamespaceContext.NamespaceMappings();
				EndIf;
				
				If Not Reader.Read() Then
					Raise(NStr("en = 'Error reading the XML file. The end of the file is detected.'"));
				EndIf;
				
				If Reader.NodeType <> XMLNodeType.StartElement
					Or Reader.Name <> "Data" Then
					
					Raise(NStr("en = 'Error reading the XML file. The file format is not valid. The Data element start tag is expected.'"));
				EndIf;
				
				If Not Reader.Read() Then
					Raise(NStr("en = 'Error reading the XML file. The end of the file is detected.'"));
				EndIf;
				
				While Reader.NodeType = XMLNodeType.StartElement Do
					If Not XDTOSerializer.CanReadXML(Reader) Then
						TypeDefinitionOnReadError(Reader);
					EndIf;
					
					If DebugMode Then
						WriteFragment = New XMLWriter;
						WriteFragment.SetString();
						
						FragmentNodeName = Reader.Name;
						
						RootNode = True;
						
						While Not (Reader.NodeType = XMLNodeType.EndElement
								And Reader.Name = FragmentNodeName) Do
								
							WriteFragment.WriteCurrent(Reader);
							
							If RootNode Then
								FragmentPrefixes = WriteFragment.NamespaceContext.NamespaceMappings();
								For Each PrefixAndNamespace In NamespaceMappings Do
									If FragmentPrefixes.Get(PrefixAndNamespace.Key) = Undefined Then
										WriteFragment.WriteNamespaceMapping(PrefixAndNamespace.Key, PrefixAndNamespace.Value);
									EndIf;
								EndDo;
								RootNode = False;
							EndIf;
							
							Reader.Read();
						EndDo;
						WriteFragment.WriteCurrent(Reader);
						Reader.Read();
						
						Fragment = WriteFragment.Close();
						
						FragmentReading = New XMLReader;
						FragmentReading.SetString(Fragment);
						Try
							Data = XDTOSerializer.ReadXML(FragmentReading);
						Except
							WriteLogEvent(NStr("en = 'DataImportExport.ErrorReadingXML'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, ,
								Fragment, DetailErrorDescription(ErrorInfo()));
							Raise;
						EndTry;
					Else
						Data = XDTOSerializer.ReadXML(Reader);
					EndIf;
					
					ImportedValueType = TypeOf(Data);
					
					If ExcludedTypes.Get(ImportedValueType) <> Undefined Then
						Continue;
					EndIf;
					
					IsExchangePlan = False;
					If ExchangePlanTypes.Get(ImportedValueType) <> Undefined Then
						IsExchangePlan = True;
						Data.DataArea = DataArea;
					ElsIf SharedInformationRegisterTypes.Get(ImportedValueType) <> Undefined Then
						Data.Filter.DataArea.Set(DataArea);
						
						For Each Record In Data Do
							Record.DataArea = DataArea;
						EndDo;
					EndIf;
					
					Data.AdditionalProperties.Insert("DontCheckEditProhibitionDates", True);
					If Not IsExchangePlan Then
						Data.DataExchange.Load = True;
					EndIf;
					DataImportExportOverridable.BeforeDataImport(Data);
					Data.Write();
				EndDo;
			EndDo;
			
		Except
			WriteLogEvent(NStr("en = 'DataImportExport.ErrorReadingXML'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
				DetailErrorDescription(ErrorInfo()));
			
			If Not DebugMode Then
				DebugMode = True;
				Continue;
			EndIf;
			
			Raise;
		EndTry;
		
		Break;
		
	EndDo;
	
EndProcedure

Function GetSharedDataCodeTable(Val SharedDataFileName)
	
	CodeTableNameFile = GetTempFileName("xml");
	
	WritingTable = New XMLWriter;
	WritingTable.OpenFile(CodeTableNameFile);
	
	Transform = CommonUseCached.GetXSLTransformFromCommonTemplate("SharedDataCodeExtraction");
	Transform.TransformFromFile(SharedDataFileName, WritingTable);
	
	WritingTable.Close();
	
	Reader = New XMLReader;
	Reader.OpenFile(CodeTableNameFile);
	Reader.MoveToContent();
	
	If Reader.NodeType <> XMLNodeType.StartElement
		Or Reader.Name <> "Data" Then
		
		Raise(NStr("en = 'Error reading the XML file. The file format is not valid. The Data element start tag is expected.'"));
	EndIf;
	
	If Not Reader.Read() Then
		Raise(NStr("en = 'Error reading the XML file. The end of the file is detected.'"));
	EndIf;
	
	CodeTable = XDTOSerializer.ReadXML(Reader);
	
	Reader.Close();
	
	Try
		DeleteFiles(CodeTableNameFile);
	Except
		
	EndTry;
	
	Return CodeTable;
	
EndFunction

Function WriteUserToXDTO(Val User, Val StorePassword = False, Val StoreSeparation = False)
	
	InfoBaseUserType = XDTOFactory.Type("http://v8.1c.ru/misc/datadump", "InfoBaseUser");
	UserRolesType = XDTOFactory.Type("http://v8.1c.ru/misc/datadump", "UserRoles");
	
	XDTOUser = XDTOFactory.Create(InfoBaseUserType);
	XDTOUser.OSAuthentication = User.OSAuthentication;
	XDTOUser.StandardAuthentication = User.StandardAuthentication;
	XDTOUser.CannotChangePassword = User.CannotChangePassword;
	XDTOUser.Name = User.Name;
	If User.DefaultInterface <> Undefined Then
		XDTOUser.DefaultInterface = User.DefaultInterface.Name;
	Else
		XDTOUser.DefaultInterface = "";
	EndIf;
	XDTOUser.PasswordIsSet = User.PasswordIsSet;
	XDTOUser.ShowInList = User.ShowInList;
	XDTOUser.FullName = User.FullName;
	XDTOUser.OSUser = User.OSUser;
	If StoreSeparation Then
		XDTOUser.DataSeparation = XDTOSerializer.WriteXDTO(User.DataSeparation);
	Else
		XDTOUser.DataSeparation = Undefined;
	EndIf;
	XDTOUser.RunMode = RunModeString(User.RunMode);
	XDTOUser.Roles = XDTOFactory.Create(UserRolesType);
	For Each Role In User.Roles Do
		XDTOUser.Roles.Role.Add(Role.Name);
	EndDo;
	If StorePassword Then
		XDTOUser.StoredPasswordValue = User.StoredPasswordValue;
	Else
		XDTOUser.StoredPasswordValue = Undefined;
	EndIf;
	XDTOUser.UUID = User.UUID;
	If User.Language <> Undefined Then
		XDTOUser.Language = User.Language.Name;
	Else
		XDTOUser.Language = "";
	EndIf;
	
	Return XDTOUser;
	
EndFunction

Function UpdateUserFromXDTO(Val XDTOUser, Val RestorePassword = False, Val RestoreSeparation = False)
	
	User = InfoBaseUsers.FindByUUID(XDTOUser.UUID);
	If User = Undefined Then
		User = InfoBaseUsers.CreateUser();
	EndIf;
	
	User.OSAuthentication = XDTOUser.OSAuthentication;
	User.StandardAuthentication = XDTOUser.StandardAuthentication;
	User.CannotChangePassword = XDTOUser.CannotChangePassword;
	User.Name = XDTOUser.Name;
	If IsBlankString(XDTOUser.DefaultInterface) Then
		User.DefaultInterface = Undefined;
	Else
		User.DefaultInterface = Metadata.Interfaces.Find(XDTOUser.DefaultInterface);
	EndIf;
	User.ShowInList = XDTOUser.ShowInList;
	User.FullName = XDTOUser.FullName;
	User.OSUser = XDTOUser.OSUser;
	If RestoreSeparation Then
		If XDTOUser.DataSeparation = Undefined Then
			User.DataSeparation = New Structure;
		Else
			User.DataSeparation = XDTOSerializer.ReadXDTO(XDTOUser.DataSeparation);
		EndIf;
	Else
		User.DataSeparation = New Structure;
	EndIf;
	User.RunMode = ClientRunMode[XDTOUser.RunMode];
	User.Roles.Clear();
	For Each RoleName In XDTOUser.Roles.Role Do
		Role = Metadata.Roles.Find(RoleName);
		If Role <> Undefined Then
			User.Roles.Add(Role);
		EndIf;
	EndDo;
	If RestorePassword Then
		User.StoredPasswordValue = XDTOUser.StoredPasswordValue;
	Else
		User.StoredPasswordValue = "";
	EndIf;
	If IsBlankString(XDTOUser.Language) Then
		User.Language = Undefined;
	Else
		User.Language = Metadata.Languages[XDTOUser.Language];
	EndIf;
	
	Return User;
	
EndFunction

Function RunModeString(Val RunMode)
	
	If RunMode = Undefined Then
		Return "";
	ElsIf RunMode = ClientRunMode.Auto Then
		Return "Auto";
	ElsIf RunMode = ClientRunMode.OrdinaryApplication Then
		Return "OrdinaryApplication";
	ElsIf RunMode = ClientRunMode.ManagedApplication Then
		Return "ManagedApplication";
	Else
		MessagePattern = NStr("en = 'Unknown client run mode is detected (%1)'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, RunMode);
		Raise(MessageText);
	EndIf;
	
EndFunction

Function CreateUsersFromXML(Val ExportDirectory)
	
	Reader = New XMLReader;
	Reader.OpenFile(ExportDirectory + "users.xml");
	Reader.MoveToContent();
		
	If Reader.NodeType <> XMLNodeType.StartElement
		Or Reader.Name <> "Users" Then
		
		Raise(NStr("en = 'Error reading the XML file. The file format is not valid. The Data element start tag is expected.'"));
	EndIf;
	
	If Not Reader.Read() Then
		Raise(NStr("en = 'Error reading the XML file. The end of the file is detected.'"));
	EndIf;
	
	InfoBaseUserType = XDTOFactory.Type("http://v8.1c.ru/misc/datadump", "InfoBaseUser");
	
	IDMapping = New Map;
	
	UserTable = New ValueTable;
	UserTable.Columns.Add("User");
	UserTable.Columns.Add("Administrator", New TypeDescription("Boolean"));
	UserTable.Columns.Add("XDTOUser");
	
	While Reader.NodeType = XMLNodeType.StartElement Do
		XDTOUser = XDTOFactory.ReadXML(Reader, InfoBaseUserType);
		
		User = UpdateUserFromXDTO(XDTOUser);
		
		ProcessUserRolesOnImportFromOtherModel(User);
		
		UserRow = UserTable.Add();
		UserRow.User = User;
		UserRow.Administrator = User.Roles.Contains(Metadata.Roles.FullAccess);
		UserRow.XDTOUser = XDTOUser;
	EndDo;
	
	Reader.Close();
	
	UserTable.Sort("Administrator DESC");
	If UserTable.Count() > 0 Then
		If Not CommonUseCached.DataSeparationEnabled()
			And Not UserTable[0].Administrator Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'There is no administrator in the user list. User list import did not complete successfully.'"));
		Else
				
			For Each UserRow In UserTable Do
				Users.WriteInfoBaseUser(UserRow.User);
				IDMapping.Insert(UserRow.XDTOUser.UUID,
					UserRow.User.UUID);
			EndDo;
		EndIf;
	EndIf;
	
	Return IDMapping;
	
EndFunction

Procedure ProcessUserRolesOnImportFromOtherModel(User)
	
	If CommonUseCached.DataSeparationEnabled() Then
		// Deleting inaccessible roles
		InaccessibleRoles = 
			UsersServerCached.InaccessibleRolesByUserType(Enums.UserTypes.DataAreaUser);
		For Each Role In InaccessibleRoles Do
			If User.Roles.Contains(Role) Then
				User.Roles.Delete(Role);
			EndIf;
		EndDo;
	Else
		// Adding FullAdministrator to the FullAccess role
		If User.Roles.Contains(Metadata.Roles.FullAccess) Then
			User.Roles.Add(Metadata.Roles.FullAdministrator);
		EndIf;
	EndIf;
	
EndProcedure

Procedure ProcessUsersAfterImportFromOtherModel(Val IDMapping)
	
	OldIDs = New Array;
	For Each KeyAndValue In IDMapping Do
		OldIDs.Add(KeyAndValue.Key);
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfoBaseUserID AS InfoBaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfoBaseUserID In(&OldIDs)";
	Query.SetParameter("OldIDs", OldIDs);
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		UserObject = Selection.Ref.GetObject();
		UserObject.ServiceUserID = Undefined;
		UserObject.InfoBaseUserID = IDMapping.Get(Selection.InfoBaseUserID);
		UserObject.Write();
	EndDo;
	
EndProcedure

Procedure RaiseWithClarifyingText(Val RecordObject, Val ErrorInfo, Val AdditionalText = "")
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'The %1 object contains disallowed characters.
|'"), "" + RecordObject);
	If AdditionalText <> "" Then
		ErrorText = ErrorText + AdditionalText + Chars.LF;
	EndIf;
	WriteLogEvent(NStr("en = 'Data export'", Metadata.DefaultLanguage.LanguageCode),
		EventLogLevel.Error, , ,
		ErrorText + DetailErrorDescription(ErrorInfo));
	Raise(ErrorText);
	
EndProcedure