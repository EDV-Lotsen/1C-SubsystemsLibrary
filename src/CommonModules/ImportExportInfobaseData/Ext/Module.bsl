////////////////////////////////////////////////////////////////////////////////
// Data import/export subsystem.
//
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

Procedure ExportInfobaseData(Container) Export
	
	TypesToExport = Container.ExportParameters().TypesToExport;
	ExcludedTypes = DataExportImportInternalEvents.GetTypesToExcludeFromExportImport();
	
	DataExportHandlers = DataExportImportInternalEvents.GetDataExportHandlers();
	
	Serializer = XDTOSerializerWithTypeAnnotation(TypesToExport);
	
	InitializeRefRecreation(Container, Serializer);
	
	For Each MetadataObject In TypesToExport Do
		
		If ExcludedTypes.Find(MetadataObject) <> Undefined Then
			
			WriteLogEvent(
				NStr("en = 'DataImportExport.ObjectExportSkipped'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Information,
				MetadataObject,
				,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Data export skipped for metadata object %1, as the
                          |object is in the list of metadata objects to be excluded from data import and export procedures'", Metadata.DefaultLanguage.LanguageCode),
					MetadataObject.FullName()
				)
			);
			
			Continue;
			
		EndIf;
		
		If DataExportImportInternal.IsRefData(MetadataObject) Then
			InitializeRefMapping(Container, Serializer, MetadataObject);
		EndIf;
		
		ExportInfobaseObjectData(Container, Serializer, MetadataObject,
			DataExportHandlers.Copy(New Structure("MetadataObject", MetadataObject))
		);
		
		If DataExportImportInternal.IsRefData(MetadataObject) Then
			FinalizeRefMapping(Container, MetadataObject);
		EndIf;
		
	EndDo;
	
	FinalizeRefRecreation(Container);
	
EndProcedure

Procedure RecreateRefOnImportRequired(Container, Val Ref) Export
	
	AccumulateRefsToRecreate(Container, Ref);
	
EndProcedure

Procedure MustMapRefOnImport(Container, Val Ref, Val NaturalKey) Export
	
	AccumulateRefsToMap(Container, Ref, NaturalKey);
	
EndProcedure

Procedure ImportInfobaseData(Container) Export
	
	TypesToImport = Container.ImportParameters().TypesToImport;
	TypesToImport = SortTypesToImport(TypesToImport);
	
	ExcludedTypes = DataExportImportInternalEvents.GetTypesToExcludeFromExportImport();
	
	Handlers = DataExportImportInternalEvents.GetDataImportHandlers();
	
	RecreateRefs(Container);
	MapRefs(Container, Handlers);
	
	For Each MetadataObject In TypesToImport Do
		
		If ExcludedTypes.Find(MetadataObject) = Undefined Then
			
			ImportImfobaseObjectData(Container, MetadataObject, Handlers.Copy(New Structure("MetadataObject", MetadataObject)));
			
		Else
			
			WriteLogEvent(
				NStr("en = 'DataImportExport.ObjectImportSkipped'", Metadata.DefaultLanguage.LanguageCode),
				EventLogLevel.Information,
				MetadataObject,
				,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Data import skipped for metadata object %1, as the
                          |object is in the list of metadata objects to be excluded from data import and export procedures'", Metadata.DefaultLanguage.LanguageCode),
					MetadataObject.FullName()
				)
			);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

//
// EXPORT
//

Procedure ExportInfobaseObjectData(Container, Serializer, Val MetadataObject, Val Handlers)
	
	Cancel = False;
	DataExportImportInternalEvents.ExecuteHandlersBeforeExportType(
		Handlers, Container, Serializer, MetadataObject, Cancel
	);
	If Cancel Then
		Return;
	EndIf;
	
	FileName = Container.CreateFile(DataExportImportInternal.InfobaseData(), MetadataObject.FullName());
	
	RecordStream = New XMLWriter();
	RecordStream.OpenFile(FileName);
	RecordStream.WriteXMLDeclaration();
	
	RecordStream.WriteStartElement("Data");
	
	NamespacePrefixes = DataExportImportInternal.NamespacePrefixes();
	
	RecordStream.WriteNamespaceMapping("", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	RecordStream.WriteNamespaceMapping(NamespacePrefixes.Get("http://www.w3.org/2001/XMLSchema"), "http://www.w3.org/2001/XMLSchema");
	RecordStream.WriteNamespaceMapping(NamespacePrefixes.Get("http://www.w3.org/2001/XMLSchema-instance"), "http://www.w3.org/2001/XMLSchema-instance");
	RecordStream.WriteNamespaceMapping(NamespacePrefixes.Get("http://v8.1c.ru/8.1/data/core"), "http://v8.1c.ru/8.1/data/core");
	RecordStream.WriteNamespaceMapping(NamespacePrefixes.Get("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1"), "http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1");
	
	ObjectCounter = 0;
	
	If DataExportImportInternal.IsConstant(MetadataObject) Then
		
		ExportConstant(MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter)
		
	ElsIf DataExportImportInternal.IsRefData(MetadataObject) Then
		
		ExportRefObject(MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter);
		
	ElsIf DataExportImportInternal.IsRecordSet(MetadataObject) Then
		
		If DataExportImportInternal.IsIndependentRecordSet(MetadataObject) Then
			
			ExportIndependentRecordSet(MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter);
			
		Else
			
			ExportRecordSetSubordinatedToRecorder(MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter);
			
		EndIf;
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Unexpected metadata object: %1'"),
			MetadataObject.FullName()
		);
		
	EndIf;
	
	RecordStream.WriteEndElement();
	RecordStream.Close();
	
	If ObjectCounter = 0 Then
		Container.ExcludeFile(FileName);
	Else
		Container.SetObjectAndRecordCount(FileName, ObjectCounter);
	EndIf;
	
	DataExportImportInternalEvents.ExecuteHandlersAfterExportType(
		Handlers, Container, Serializer, MetadataObject
	);
	
EndProcedure

Procedure ExportConstant(Val MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter)
	
	ValueManager = Constants[MetadataObject.Name].CreateValueManager();
	ValueManager.Read();
	
	If WriteObjectToXML(Container, RecordStream,Serializer, ValueManager, Handlers) Then
		ObjectCounter = ObjectCounter + 1;
	EndIf;
	
EndProcedure

Procedure ExportRefObject(Val MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter)
	
	IsExchangePlan = DataExportImportInternal.IsExchangePlan(MetadataObject);
	If IsExchangePlan Then
		Return;
	EndIf;
	
	ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	Selection = ObjectManager.Select();
	While Selection.Next() Do
		
		If IsExchangePlan And Selection.Ref = ObjectManager.ThisNode() Then
			Continue;
		EndIf;
		
		Object = Selection.Ref.GetObject();
		
		If WriteObjectToXML(Container, RecordStream, Serializer, Object, Handlers) Then
			ObjectCounter = ObjectCounter + 1;
		EndIf;
		
	EndDo;
	
EndProcedure


Procedure ExportIndependentRecordSet(Val MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter)
	
	State = Undefined;
	Filter = New Array;
	
	ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	While True Do
		
		TableArray = CloudTechnologyInternalQueries.GetDataPortionFromIndependentRecordSet(
			MetadataObject, Filter, 10000, False, State);
		If TableArray.Count() <> 0 Then
			
			FirstTable = TableArray.Get(0);
			
			RecordSet = ObjectManager.CreateRecordSet();
			RecordSet.Load(FirstTable);
			
			If WriteObjectToXML(Container, RecordStream, Serializer, RecordSet, Handlers) Then
				ObjectCounter = ObjectCounter + FirstTable.Count();
			EndIf;
			
			Continue;
			
		EndIf;
		
		Break;
		
	EndDo;
	
EndProcedure

Procedure ExportRecordSetSubordinatedToRecorder(Val MetadataObject, Container, RecordStream, Serializer, Handlers, ObjectCounter)
	
	If DataExportImportInternal.IsRecalculationRecordSet(MetadataObject) Then
		
		RecorderFieldName = "RecalculationObject";
		
		Substrings = StringFunctionsClientServer.SplitStringIntoSubstringArray(MetadataObject.FullName(), ".");
		TableName = Substrings[0] + "." + Substrings[1] + "." + Substrings[3];
		
	Else
		
		RecorderFieldName = "Recorder";
		TableName = MetadataObject.FullName();
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	_XMLExport_Table." + RecorderFieldName + " AS Recorder FROM
	|" + TableName + " AS _XMLData_Table";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	Selection = Result.Select();
	While Selection.Next() Do
		
		RecordSet = ObjectManager.CreateRecordSet();
		RecordSet.Filter[RecorderFieldName].Connect(Selection.Recorder);
		
		RecordSet.Read();
		
		If WriteObjectToXML(Container, RecordStream, Serializer, RecordSet, Handlers) Then
			ObjectCounter = ObjectCounter + RecordSet.Count();
		EndIf;
		
	EndDo;
	
EndProcedure

Function WriteObjectToXML(Container, RecordStream, Serializer, Object, Handlers)
	
	Cancel = False;
	Artifacts = New Array();
	DataExportImportInternalEvents.ExecuteHandlersBeforeExportObject(
		Handlers, Container, Serializer, Object, Artifacts, Cancel
	);
	If Cancel Then
		Return False;
	EndIf;
	
	RecordStream.WriteStartElement("DumpElement");
	
	If Artifacts.Count() > 0 Then
		
		RecordStream.WriteStartElement("Artefacts");
		For Each Artifact In Artifacts Do 
			
			XDTOFactory.WriteXML(RecordStream, Artifact);
			
		EndDo;
		RecordStream.WriteEndElement();
		
	EndIf;
	
	Try
		
		Serializer.WriteXML(RecordStream, Object);
		
	Except
		
		ErrorSourceText = DetailErrorDescription(ErrorInfo());
		ErrorSourceTextExcludingInvalidCharacters = CommonUseClientServer.ReplaceDisallowedXMLCharacters(
			ErrorSourceText,
			Char(65533)
		);
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error exporting object %1: %2'"),
			Object,
			ErrorSourceTextExcludingInvalidCharacters
		);
		
	EndTry;
	
	RecordStream.WriteEndElement();
	
	Return True;
	
EndFunction

// Reference annotation during export

Function XDTOSerializerWithTypeAnnotation(Val TypesToExport)
	
	TypesWithRefAnnotation = DataExportImportInternalEvents.GetTypesRequiringRefAnnotationOnExport();
	
	If TypesWithRefAnnotation.Count() > 0 Then
		
		Factory = GetFactoryWithTypes(TypesWithRefAnnotation);
		Return New XDTOSerializer(Factory);
		
	Else
		
		Return XDTOSerializer;
		
	EndIf;
	
EndFunction

Function GetFactoryWithTypes(Val Types)
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	SelectedTypes = New Map;
	For Each Type In Types Do
		SelectedTypes.Insert(DataExportImportInternal.XMLRefType(Type), True);
	EndDo;
	
	Namespace = New Map;
	Namespace.Insert("xs", "http://www.w3.org/2001/XMLSchema");
	DOMNamespaceResolver = New DOMNamespaceResolver(Namespace);
	XPathText = "/xs:schema/xs:complexType/xs:sequence/xs:element[starts-with(@type,'tns:')]";
	
	Request = Schema.DOMDocument.CreateXPathExpression(XPathText,
		DOMNamespaceResolver);
	Result = Request.Eval(Schema.DOMDocument);

	While True Do
		
		NodeFields = Result.IterateNext();
		If NodeFields = Undefined Then
			Break;
		EndIf;
		TypeAttribute = NodeFields.Attributes.GetNamedItem("type");
		TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
		
		If SelectedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
			Continue;
		EndIf;
		
		NodeFields.SetAttribute("nillable", "true");
		NodeFields.RemoveAttribute("type");
	EndDo;
	
	XMLWriter = New XMLWriter;
	SchemaFileName = GetTempFileName("xsd");
	XMLWriter.OpenFile(SchemaFileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	Factory = CreateXDTOFactory(SchemaFileName);
	
	Try
		DeleteFiles(SchemaFileName);
	Except
	EndTry;
	
	Return Factory;
	
EndFunction

// Reference replacement and recreation

Procedure InitializeRefRecreation(Container, Serializer)
	
	Container.AdditionalProperties.Insert("RefsToRecreate", New Array());
	Container.AdditionalProperties.Insert("RefToRecreateRecordSerializer", Serializer);
	
EndProcedure

Procedure InitializeRefMapping(Container, Serializer, MetadataObject)
	
	ColumnName = DataExportImportInternal.SourceURLColumnName(Container);
	
	Container.AdditionalProperties.Insert("RefsToMap", New ValueTable());
	
	ObjectManager = CTLAndSLIntegration.ObjectManagerByFullName(MetadataObject.FullName());
	RefType = TypeOf(ObjectManager.GetRef());
	TypeArrayForRefColumns = New Array();
	TypeArrayForRefColumns.Add(RefType);
	TypeDescriptionForRefColumns = New TypeDescription(TypeArrayForRefColumns);
	
	Container.AdditionalProperties.RefsToMap.Columns.Add(ColumnName, TypeDescriptionForRefColumns);
	
	Container.AdditionalProperties.Insert("RefToMapRecordSerializer", Serializer);
	
EndProcedure

Procedure AccumulateRefsToRecreate(Container, Val Ref)
	
	Container.AdditionalProperties.RefsToRecreate.Add(Ref);
	
	If Container.AdditionalProperties.RefsToRecreate.Count() > (MapTableItemCount()*2) Then
		WriteRefsToRecreate(Container);
	EndIf;
	
EndProcedure

Procedure AccumulateRefsToMap(Container, Val Ref, Val NaturalKey)
	
	ColumnName = DataExportImportInternal.SourceURLColumnName(Container);
	
	CommonDataTypes = DataExportImportInternalEvents.GetCommonDataTypesThatSupportRefMappingOnImport();
	
	Table = Container.AdditionalProperties.RefsToMap;
	
	RefToMap = Table.Add();
	RefToMap[ColumnName] = Ref;
	For Each KeyAndValue In NaturalKey Do
		
		If Table.Columns.Find(KeyAndValue.Key) = Undefined Then
			
			TypeDescription = Undefined;
			
			If CommonDataTypes.Find(Ref.Metadata()) <> Undefined Then
				
				NaturalKeyFields = CTLAndSLIntegration.ObjectManagerByFullName(Ref.Metadata().FullName()).NaturalKeyFields();
				If NaturalKeyFields.Find(KeyAndValue.Key) <> Undefined Then
					
					TypeDescription = ObjectFieldTypeDescription(Ref.Metadata(), KeyAndValue.Key);
					
				EndIf;
				
			EndIf;
			
			If TypeDescription = Undefined Then
				
				TypeArray = New Array();
				
				TypeArray.Add(TypeOf(KeyAndValue.Value));
				
				TypeDescription = New TypeDescription(TypeArray, , New StringQualifiers(1024));
				
			EndIf;
			
			Table.Columns.Add(KeyAndValue.Key,TypeDescription);
			
		EndIf;
		
		RefToMap[KeyAndValue.Key] = KeyAndValue.Value;
	EndDo;
	
	If Container.AdditionalProperties.RefsToMap.Count() > MapTableItemCount() Then 
		WriteRefsToMap(Container, Ref.Metadata());
	EndIf;
	
EndProcedure

Procedure WriteRefsToRecreate(Container)
	
	If Container.AdditionalProperties.RefsToRecreate.Count() > 0 Then
		
		FileName = Container.CreateFile(DataExportImportInternal.ReferenceRebuilding());
		
		DataExportImportInternal.WriteObjectToFile(
			Container.AdditionalProperties.RefsToRecreate,
			FileName,
			Container.AdditionalProperties.RefToRecreateRecordSerializer
		);
		
		Container.AdditionalProperties.RefsToRecreate.Clear();
		
	EndIf;
	
EndProcedure

Procedure WriteRefsToMap(Container, Val MetadataObject)
	
	If Container.AdditionalProperties.RefsToMap.Count() > 0 Then
		
		FileName = Container.CreateFile(DataExportImportInternal.ReferenceMapping(), MetadataObject.FullName());
		
		DataExportImportInternal.WriteObjectToFile(
			Container.AdditionalProperties.RefsToMap,
			FileName,
			Container.AdditionalProperties.RefToMapRecordSerializer
		);
		
		Container.AdditionalProperties.RefsToMap.Clear();
		
	EndIf;
	
EndProcedure

Procedure FinalizeRefRecreation(Container)
	
	WriteRefsToRecreate(Container);
	
EndProcedure

Procedure FinalizeRefMapping(Container, Val MetadataObject)
	
	WriteRefsToMap(Container, MetadataObject);
	
EndProcedure

//
// IMPORT
//

Procedure RecreateRefs(Container)
	
	Size = 0;
	RefArrays = New Array();
	
	RefsToRecreateFiles = Container.GetFilesFromDirectory(DataExportImportInternal.ReferenceRebuilding());
	For Each RefsToRecreateFile In RefsToRecreateFiles Do
		
		SourceRefs = DataExportImportInternal.ReadObjectFromFile(RefsToRecreateFile);
		ReadRefCount = SourceRefs.Count();
		
		If Size + ReadRefCount > RefMapItemCount() And RefArrays.Count() > 0 Then
			ReplacementDictionary = GenerateRefRecreationDictionary(RefArrays);
			ReplaceReferences(Container, ReplacementDictionary);
		EndIf;
		
		RefArrays.Add(SourceRefs);
		Size = Size + ReadRefCount;
		
	EndDo;
	
	If RefArrays.Count() > 0 Then
		ReplacementDictionary = GenerateRefRecreationDictionary(RefArrays);
		ReplaceReferences(Container, ReplacementDictionary);
	EndIf;
	
EndProcedure

// Map:
//  Key - String, Reference type XML name,
//  Value - Structure:
//    Key - String, source reference GUID as string. 
//    Value - String, new reference GUID as string.
Function GenerateRefRecreationDictionary(Val RefArrays)
	
	Result = New Map();
	
	For Each SourceRefs In RefArrays Do
		
		For Each SourceRef In SourceRefs Do
			
			XMLTypeName = DataExportImportInternal.XMLRefType(SourceRef);
			
			If Result.Get(XMLTypeName) = Undefined Then
				Result.Insert(XMLTypeName, New Structure());
			EndIf;
			
			NewRef = CTLAndSLIntegration.ObjectManagerByFullName(SourceRef.Metadata().FullName()).GetRef();
			
			Result.Get(XMLTypeName).Insert(
				String(SourceRef.UUID()),
				String(NewRef.UUID())
			);
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure MapRefs(Container, Handlers)
	
	FileDescriptionTable = Container.GetDescriptionOfFilesFromDirectory(DataExportImportInternal.ReferenceMapping());
	If FileDescriptionTable.Count() = 0 Then 
		Return;
	EndIf;
	SortRefMapFilesAdjustedForDependencies(FileDescriptionTable);
	
	Size = 0;
	RefTables = New Map;
	
	PreviousMetadataObject = Undefined;
	CurrentHandlerSet = Undefined;
	CurrentMetadataLevel = FileDescriptionTable.Get(0).Order;
	ReplacementDictionary = New Map;
	
	For Each FileDetails In FileDescriptionTable Do
		
		MetadataObject = Metadata.FindByFullName(FileDetails.DataType);
		
		SourceRefsAndNaturalKeys = DataExportImportInternal.ReadObjectFromFile(FileDetails.FullName);
		ReadRefCount = SourceRefsAndNaturalKeys.Count();
		
		If PreviousMetadataObject <> Undefined And PreviousMetadataObject <> MetadataObject Then 
			UpdateRefMapDictionary(ReplacementDictionary, Container, RefTables, PreviousMetadataObject, CurrentHandlerSet);
		EndIf;
		
		If CurrentMetadataLevel <> FileDetails.Order Then 
			ReplaceReferences(Container, ReplacementDictionary);
			ReplacementDictionary = New Map;
			RefTables.Clear();
		Else
			If Size + ReadRefCount > RefMapItemCount() And RefTables.Count() > 0 Then 
				UpdateRefMapDictionary(ReplacementDictionary, Container, RefTables, PreviousMetadataObject, CurrentHandlerSet);
				ReplaceReferences(Container, ReplacementDictionary);
				ReplacementDictionary = New Map;
				RefTables.Clear();
			EndIf;
		EndIf;
		
		MapItem = RefTables.Get(MetadataObject);
		If MapItem = Undefined Then 
			MapArray = New Array;
			MapArray.Add(SourceRefsAndNaturalKeys);
			RefTables.Insert(MetadataObject, MapArray);
		Else
			MapItem.Add(SourceRefsAndNaturalKeys);
		EndIf;
		Size = Size + ReadRefCount;
		PreviousMetadataObject = MetadataObject;
		CurrentHandlerSet = Handlers.Copy(New Structure("MetadataObject", PreviousMetadataObject));
		CurrentMetadataLevel = FileDetails.Order;
		
	EndDo;
	
	If RefTables.Count() > 0 Then
		UpdateRefMapDictionary(ReplacementDictionary, Container, RefTables, PreviousMetadataObject, CurrentHandlerSet);
		ReplaceReferences(Container, ReplacementDictionary);
	EndIf;
	
EndProcedure

Procedure SortRefMapFilesAdjustedForDependencies(FileDescriptionTable)
	
	TypeOrderAdjustedForDependencies = New Array();
	
	TypeDependencies = DataExportImportInternalEvents.GetTypeDependenciesOnRefReplacement();
	
	For Each TypeDependency In TypeDependencies Do
		
		If TypeOrderAdjustedForDependencies.Find(TypeDependency.Key) = Undefined Then
			TypeOrderAdjustedForDependencies.Add(TypeDependency.Key);
		EndIf;
		
		For Each DependencyObject In TypeDependency.Value Do
			
			If TypeOrderAdjustedForDependencies.Find(DependencyObject) = Undefined Then
				TypeOrderAdjustedForDependencies.Add(DependencyObject);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	For Each TypeDependency In TypeDependencies Do
		
		For Each DependentItem In TypeDependency.Value Do
			
			KeyPosition = TypeOrderAdjustedForDependencies.Find(TypeDependency.Key);
			
			DependentItemPosition = TypeOrderAdjustedForDependencies.Find(DependentItem);
			
			If DependentItemPosition > KeyPosition Then
				
				TypeOrderAdjustedForDependencies.Delete(KeyPosition);
				TypeOrderAdjustedForDependencies.Insert(DependentItemPosition, TypeDependency.Key);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	FileDescriptionTable.Columns.Add("Order", New TypeDescription("Number"));
	
	For Each FileDetails In FileDescriptionTable Do
		
		PostalCode = TypeOrderAdjustedForDependencies.Find(FileDetails.DataType);
		FileDetails.Order = PostalCode;
		
	EndDo;
	
	FileDescriptionTable.Sort("Order");
	
EndProcedure

Procedure UpdateRefMapDictionary(ReplacementDictionary, Container, Val RefTables, Val MetadataObject, Handlers)
	
	SourceRefTables = RefTables.Get(MetadataObject);
	
	ColumnName = DataExportImportInternal.SourceURLColumnName(Container);
	
	For Each SourceRefTable In SourceRefTables Do
		
		Cancel = False;
		StandardProcessing = True;
		RefMappingHandler = Undefined;
		
		DataExportImportInternalEvents.ExecuteHandlersBeforeRefMapping(
			Handlers, Container, MetadataObject, SourceRefTable, StandardProcessing, RefMappingHandler, Cancel
		);
		
		If Cancel Then
			Continue;
		EndIf;
		
		If StandardProcessing Then
			
			KeyFields = New Array();
			For Each KeyColumn In SourceRefTable.Columns Do
				If KeyColumn.Name <> ColumnName Then
					KeyFields.Add(KeyColumn.Name);
				EndIf;
			EndDo;
			
			MapQueryText = GenerateRefMapByNaturalKeysQueryText(
				MetadataObject, SourceRefTable.Columns, ColumnName);
			
			Query = New Query(MapQueryText);
			Query.SetParameter("SourceRefTable", SourceRefTable);
			Selection = Query.Execute().Select();
			
			DictionaryFragment = New Map();
			While Selection.Next() Do
				DictionaryFragment.Insert(
					String(Selection[ColumnName].UUID()),
					String(Selection.Ref.UUID())
				);
			EndDo;
			
		Else
			
			DictionaryFragment = New Map();
			
			ReferenceMap = RefMappingHandler.MapRefs(Container, SourceRefTable);
			For Each MapItem In ReferenceMap Do
				DictionaryFragment.Insert(
					String(MapItem[ColumnName].UUID()),
					String(MapItem.Ref.UUID())
				);
			EndDo;
			
			
		EndIf;
		
		XMLTypeName = DataExportImportInternal.XMLRefType(MetadataObject);
		SourceTable = ReplacementDictionary.Get(XMLTypeName);
		If SourceTable = Undefined Then
			ReplacementDictionary.Insert(XMLTypeName, DictionaryFragment);
		Else
			ReplacementDictionary.Insert(XMLTypeName, MergeTables(SourceTable, DictionaryFragment));
		EndIf;
		
	EndDo;
	
EndProcedure

Function ObjectFieldTypeDescription(MetadataObject, FieldName)
	
	// Check for standard attributes
	For Each StandardAttribute In MetadataObject.StandardAttributes Do 
		
		If StandardAttribute.Name = FieldName Then 
			 Return StandardAttribute.Type;
		EndIf;
		
	EndDo;
	
	// Check for attributes
	For Each Attribute In MetadataObject.Attributes Do 
		
		If Attribute.Name = FieldName Then 
			 Return Attribute.Type;
		EndIf;
		
	EndDo;
	
	// Check for common attributes
	CommonAttributeCount = Metadata.CommonAttributes.Count();
	For Iteration = 0 To CommonAttributeCount - 1 Do 
		
		CommonAttribute = Metadata.CommonAttributes.Get(Iteration);
		If CommonAttribute.Name <> FieldName Then 
			
			Continue;
			
		EndIf;
		
		CommonAttributeContent = CommonAttribute.Content;
		CommonAttributeFound = CommonAttributeContent.Find(MetadataObject);
		If CommonAttributeFound <> Undefined Then 
			
			Return CommonAttribute.Type;
			
		EndIf;
		
	EndDo;
	
EndFunction

// Generates a query to get shared data references in infobase
//
// Returns:
//  String
//
Function GenerateRefMapByNaturalKeysQueryText(Val MetadataObject, Val Columns, Val ColumnName)
	
	QueryText =
	"SELECT
	|	SourceRefTable.*
	|INTO SourceRefs
	|FROM
	|	&SourceRefTable AS SourceRefTable;
	|SELECT
	|	SourceRefs.%SourceRef AS %SourceRef,
	|	_XMLImport_Table.Ref AS Ref
	|FROM
	|	SourceRefs AS SourceRefs
	|	INNER JOIN " + MetadataObject.FullName() + " AS _XMLImport_Table ";
	
	Iteration = 1;
	For Each Column In Columns Do 
		
		If Column.Name = ColumnName Then 
			Continue;
		EndIf;
		
		QueryText = QueryText + "%LogicalFunction (SourceRefs.%KeyName = _XMLImport_Table.%KeyName) ";
		
		LogicalFunction = ?(Iteration = 1, "ON", "And");
		
		QueryText = StrReplace(QueryText, "%KeyName",          Column.Name);
		QueryText = StrReplace(QueryText, "%LogicalFunction", LogicalFunction);
		
		Iteration = Iteration + 1;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "%SourceRef", ColumnName);
	
	Return QueryText;
	
EndFunction

Function MergeTables(SourceTable, ResultTable)
	
	Query = New Query;
	Query.SetParameter("SourceTable", SourceTable);
	Query.SetParameter("ResultTable", ResultTable);
	QueryText =
	"SELECT *
	|INTO FirstTable
	|FROM
	|	&SourceTable AS SourceTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT *
	|INTO SECONDTable
	|FROM
	|	&ResultTable AS ResultTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT *
	|FROM
	|	FirstTable AS FirstTable
	|
	|UNION
	|
	|SELECT *
	|FROM
	|	SECONDTable AS SECONDTable";
	
	Table = Query.Execute().Unload();
	Return Table;
	
EndFunction

Procedure ReplaceReferences(Container, Val RefReplacementDictionary)
	
	FileTypes = DataExportImportInternal.FileTypesSupportingRefReplacement();
	
	FileDescriptions = Container.GetDescriptionOfFilesFromDirectory(FileTypes);
	For Each FileDetails In FileDescriptions Do
		
		ReplaceRefsInFile(Container, FileDetails, RefReplacementDictionary);
		
	EndDo;
	
	DataExportImportInternalEvents.ExecuteActionsOnRefReplacement(Container, RefReplacementDictionary);
	
EndProcedure

Procedure ReplaceRefsInFile(Container, Val FileDetails, Val RefReplacementsDictionary)
	
	ReaderStream = New TextReader(FileDetails.FullName);
	
	TempFile = Container.CreateFile(FileDetails.FileKind, FileDetails.DataType);
	
	RecordStream = New TextWriter(TempFile);
	
	// Text parsing constants.
	TypeBeginning = "xsi:type=""";
	TypeBeginningLength = StrLen(TypeBeginning);
	TypeEnd = """>";
	TypeEndLength = StrLen(TypeEnd);
	
	SourceString = ReaderStream.ReadLine();
	While SourceString <> Undefined Do
		
		RemainingString = Undefined;
		
		CurrentPosition = 1;
		TypePosition = Find(SourceString, TypeBeginning);
		While TypePosition > 0 Do
			
			RecordStream.Write(Mid(SourceString, CurrentPosition, TypePosition - 1 + TypeBeginningLength));
			
			RemainingString = Mid(SourceString, CurrentPosition + TypePosition + TypeBeginningLength - 1);
			CurrentPosition = CurrentPosition + TypePosition + TypeBeginningLength - 1;
			
			TypeEndPosition = Find(RemainingString, TypeEnd);
			If TypeEndPosition = 0 Then
				Break;
			EndIf;
			
			TypeName = Left(RemainingString, TypeEndPosition - 1);
			ReplacementMap = RefReplacementsDictionary.Get(TypeName);
			If ReplacementMap = Undefined Then
				TypePosition = Find(RemainingString, TypeBeginning);
				Continue;
			EndIf;
			
			RecordStream.Write(TypeName);
			RecordStream.Write(TypeEnd);
			
			SourceRefXML = Mid(RemainingString, TypeEndPosition + TypeEndLength, 36);
			
			FoundRefXML = ReplacementMap.Get(SourceRefXML);
			
			If FoundRefXML = Undefined Then
				RecordStream.Write(SourceRefXML);
			Else
				RecordStream.Write(FoundRefXML);
			EndIf;
			
			CurrentPosition = CurrentPosition + TypeEndPosition - 1 + TypeEndLength + 36;
			RemainingString = Mid(RemainingString, TypeEndPosition + TypeEndLength + 36);
			TypePosition = Find(RemainingString, TypeBeginning);
			
		EndDo;
		
		If RemainingString <> Undefined Then
			RecordStream.WriteLine(RemainingString);
		Else
			RecordStream.WriteLine(SourceString);
		EndIf;
		
		SourceString = ReaderStream.ReadLine();
		
	EndDo;
	
	ReaderStream.Close();
	RecordStream.Close();
	
	Container.ExcludeFile(FileDetails.FullName);
	
EndProcedure

Procedure ImportImfobaseObjectData(Container, Val MetadataObject, Handlers)
	
	Cancel = False;
	DataExportImportInternalEvents.ExecuteHandlersBeforeImportType(
		Handlers, Container, MetadataObject, Cancel
	);
	If Cancel Then
		Return;
	EndIf;
	
	FileName = Container.GetFileFromDirectory(DataExportImportInternal.InfobaseData(), MetadataObject.FullName());
	If FileName = Undefined Then 
		Return;
	EndIf;
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(FileName);
	ReaderStream.MoveToContent();
	
	If ReaderStream.NodeType <> XMLNodeType.StartElement
		Or ReaderStream.Name <> "Data" Then
		
		Raise(NStr("en = 'XML read error. Invalid file format. Beginning of Data item expected.'"));
	EndIf;
	
	If Not ReaderStream.Read() Then
		Raise(NStr("en = 'XML read error. End of file detected.'"));
	EndIf;
	
	While ReaderStream.NodeType = XMLNodeType.StartElement Do
		
		If ReaderStream.Name <> "DumpElement" Then
			Raise NStr("en = 'XML read error. Invalid file format. Beginning of DumpElement expected.'");
		EndIf;
		
		ReaderStream.Read(); // <DumpElement>
		
		ObjectArtifacts = New Array();
		Object = ReadObjectFromExportFile(ReaderStream, ObjectArtifacts, FileName);
		WriteObjectToInfobase(Container, Object, ObjectArtifacts, Handlers);
		
		ReaderStream.Read(); // </DumpElement>
		
	EndDo;
	
	DataExportImportInternalEvents.ExecuteHandlersAfterImportType(
		Handlers, Container, MetadataObject
	);
	
EndProcedure

Function ReadObjectFromExportFile(ReaderStream, ObjectArtifacts, Val FileName)
	
	ObjectArtifacts = ReadObjectArtifacts(ReaderStream);
	
	Try
		
		Object = XDTOSerializer.ReadXML(ReaderStream);
		
	Except
		
		SourceException = DetailErrorDescription(ErrorInfo());
		
		ErrorFragment = CopyXMLFragment(ReaderStream);
		
		ReadErrorFragment = New XMLReader();
		ReadErrorFragment.SetString(ErrorFragment);
		
		Try
			
			Object = XDTOSerializer.ReadXML(ReadErrorFragment);
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error reading data from file %1. When reading fragment
                      |
                      |%2
                      |
                      |object SerializerXDTO raised an exception:
                      |
                      |%3
                      |
                      |The error only occurs when reading data from the file; it is not reproduced when reading separate XML fragments.'"),
				FileName,
				ErrorFragment,
				SourceException
			);
			
		Except
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error reading data from file %1. When reading fragment 
                      |
                      |%2
                      |
                      |object SerializerXDTO raised an exception
                      |
                      |%3
                      |
                      |When reading a separate XML fragment, object SerializerXDTO raised an exception: 
                      |
                      |%4'"),
				FileName,
				ErrorFragment,
				SourceException,
				DetailErrorDescription(ErrorInfo())
			);
			
		EndTry;
		
	EndTry;
	
	Return Object;
	
EndFunction

Function ReadObjectArtifacts(ReaderStream)
	
	ObjectArtifacts = New Array();
	
	If ReaderStream.Name = "Artefacts" Then
		
		ReaderStream.Read(); // <Artefacts>
		While ReaderStream.NodeType <> XMLNodeType.EndElement Do
			ObjectArtifacts.Add(XDTOFactory.ReadXML(ReaderStream, XDTOFactory.Type(ReaderStream.NamespaceURI, ReaderStream.Name)));
		EndDo;
		ReaderStream.Read(); // </Artefacts>
		
	EndIf;
	
	Return ObjectArtifacts;
	
EndFunction

Procedure WriteObjectToInfobase(Container, Object, ObjectArtifacts, Handlers)
	
	Cancel = False;
	DataExportImportInternalEvents.ExecuteHandlersBeforeImportObject(
		Handlers, Container, Object, ObjectArtifacts, Cancel
	);
	If Cancel Then
		Return;
	EndIf;
	
	If DataExportImportInternal.IsConstant(Object.Metadata()) Then
		
		If Not ValueIsFilled(Object.Value) Then
			// As the constants are cleared beforehand, rewriting blank values is not required
			Return;
		EndIf;
		
	EndIf;
	
	Object.DataExchange.Load = True;
	
	If DataExportImportInternal.IsIndependentRecordSet(Object.Metadata()) Then
		
		// As independent record sets are exported by using cursor queries, writing
		// is performed without replacement
		Object.Write(False);
		
	Else
		
		Object.Write();
		
	EndIf;
	
	DataExportImportInternalEvents.ExecuteHandlersAfterImportObject(
		Handlers, Container, Object, ObjectArtifacts
	);
	
EndProcedure

Function CopyXMLFragment(Val ReaderStream)
	
	WriteFragment = New XMLWriter;
	WriteFragment.SetString();
	
	FragmentNodeName = ReaderStream.Name;
	
	RootNode = True;
	Try
		While Not (ReaderStream.NodeType = XMLNodeType.EndElement
				And ReaderStream.Name = FragmentNodeName) Do
				
			WriteFragment.WriteCurrent(ReaderStream);
			
			If RootNode Then
				NamespaceURI = ReaderStream.NamespaceContext.NamespaceURI();
				For Each URI In NamespaceURI Do
					WriteFragment.WriteNamespaceMapping(ReaderStream.NamespaceContext.LookupPrefix(URI), URI);
				EndDo;
				RootNode = False;
			EndIf;
			
			ReaderStream.Read();
		EndDo;
		WriteFragment.WriteCurrent(ReaderStream);
		ReaderStream.Read();
	Except
		EventLogText = CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'Source file fragment copy error. Partially copied
                  |fragment: %1'"),
				WriteFragment.Close());
		WriteLogEvent(NStr("en = 'Data import/export. XML read error'", 
			CTLAndSLIntegration.DefaultLanguageCode()), EventLogLevel.Error, , , EventLogText);
		Raise;
	EndTry;
	
	Particle = WriteFragment.Close();
	
	Return Particle;
	
EndFunction

//The types are sorted by descending priority and picked by serializers from the array in reverse order
//
Function SortTypesToImport(Val TypesToImport)
	
	Sort = New ValueTable();
	Sort.Columns.Add("MetadataObject", New TypeDescription("MetadataObject"));
	Sort.Columns.Add("Priority", New TypeDescription("Number"));
	
	For Each MetadataObject In TypesToImport Do
		
		Row = Sort.Add();
		Row.MetadataObject = MetadataObject;
		
		If DataExportImportInternal.IsConstant(MetadataObject) Then
			Row.Priority = 0;
		ElsIf DataExportImportInternal.IsRefData(MetadataObject) Then
			Row.Priority = 1;
		ElsIf Metadata.CalculationRegisters.Contains(MetadataObject.Parent()) Then
			Row.Priority = 3;
		ElsIf Metadata.Sequences.Contains(MetadataObject) Then
			Row.Priority = 4
		ElsIf DataExportImportInternal.IsRecordSet(MetadataObject) Then
			Row.Priority = 2;
		Else
			TextPattern = NStr("en = 'Metadata object %1 import not supported'");
			MessageText = CTLAndSLIntegration.SubstituteParametersInString(TextPattern, MetadataObject.FullName());
			Raise(MessageText);
		EndIf;
		
	EndDo;
	
	Sort.Sort("Priority");
	
	Return Sort.UnloadColumn("MetadataObject");
	
EndFunction

// Returns the number of items in a map that contains the reference map. 
// This number was determined by trial so that RAM usage would not exceed 10 MB.
//
// Returns:
// Number - number of items.
//
Function RefMapItemCount()
	
	Return 51000;
	
EndFunction

// Returns the number of items in a value table used to store the map between references and natural keys.
// This number was determined by trial so that average RAM usage would not exceed 10 MB.
//
// Returns:
// Number - number of items.
//
Function MapTableItemCount()
	
	Return 17000;
	
EndFunction


