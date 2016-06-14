////////////////////////////////////////////////////////////////////////////////
// Object versioning subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// This procedure is executed during configuration update.
// 1. Clears versioning settings for objects that cannot be versioned.
// 2. Enables the default versioning settings.
//
Procedure UpdateObjectVersioningSettings() Export
	
	VersionedObjects = GetVersionedObjects();
	
	RecordSelection = InformationRegisters.ObjectVersioningSettings.Select();
	
	While RecordSelection.Next() Do
		If VersionedObjects.Find(RecordSelection.ObjectType) = Undefined Then
			RecordManager = RecordSelection.GetRecordManager();
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	// Composite type that includes string and reference to the Products and services catalog
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	
	VersionedObjectsVT = New ValueTable;
	VersionedObjectsVT.Columns.Add("ObjectType", 
				New TypeDescription(TypeArray, , Metadata.InformationRegisters.ObjectVersioningSettings.Dimensions.ObjectType.Type.StringQualifiers) );
	For Each ObjectType In VersionedObjects Do
		VersionedObjectsVT.Add();
	EndDo;
	VersionedObjectsVT.LoadColumn(VersionedObjects, "ObjectType");
	
	Query = New Query;
	Query.Text =
			"SELECT
			|	VersionedObjects.ObjectType
			|INTO VersionedObjectTable
			|FROM
			|	&VersionedObjects AS VersionedObjects
			|;
			|////////////////////////////////////////////////////////////
			|SELECT
			|	VersionedObjectTable.ObjectType
			|FROM
			|	VersionedObjectTable AS VersionedObjectTable
			|		LEFT JOIN InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
			|			ON ObjectVersioningSettings.ObjectType = VersionedObjectTable.ObjectType
			|WHERE
			|	ObjectVersioningSettings.Mode IS NULL ";
			
	Query.Parameters.Insert("VersionedObjects", VersionedObjectsVT);
	VersionedObjectsNoSettings = Query.Execute().Unload().UnloadColumn("ObjectType");
	
	SettingRecordSet = InformationRegisters.ObjectVersioningSettings.CreateRecordSet();
	SettingRecordSet.Read();
	For Each VersionedObject In VersionedObjectsNoSettings Do
		NewRecord = SettingRecordSet.Add();
		NewRecord.ObjectType = VersionedObject;
		NewRecord.Mode = Enums.ObjectVersioningModes.DontVersionize;
		NewRecord.Use = ? (NewRecord.Mode = Enums.ObjectVersioningModes.DontVersionize, False, True);
	EndDo;
	
	SettingRecordSet.Write(True);
	
EndProcedure

// Saves the object versioning settings to information register.
//
// Parameters:
//  MetadataObjectName - String - full name of a metadata object.
//  VersioningMode     - Enum.ObjectVersioningModes.
//
Procedure SaveObjectVersioningConfiguration(MetadataObjectName, VersioningMode) Export
	
	Settings = InformationRegisters.ObjectVersioningSettings.CreateRecordManager();
	Settings.ObjectType = MetadataObjectName;
	Settings.Mode = VersioningMode;
	Settings.Write();
	
EndProcedure

// Executes form actions necessary to enable the versioning subsystem.
//
// Parameters:
//  Form - ManagedForm - form used to enable the versioning mechanism.
//
Procedure OnCreateAtServer(Form) Export
	
	If Users.RolesAvailable("ReadObjectVersions") And GetFunctionalOption("UseObjectVersioning") Then
		FormNameArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(Form.FormName, ".");
		FullMetadataName = FormNameArray[0] + "." + FormNameArray[1];
	Else
		FullMetadataName = Undefined;
	EndIf;
	
	Form.SetFormFunctionalOptionParameters(New Structure("VersionizedObjectType", FullMetadataName));
	
EndProcedure

// Returns a spreadsheet document filled with the object data.
// 
// Parameters:
//  ObjectRef - AnyRef.
//
// Returns:
//  SpreadsheetDocument - object print form.
//
Function ReportOnObjectVersion(ObjectRef) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	GenerateReportOnTransmittedVersion(SpreadsheetDocument, SerializeObject(ObjectRef.GetObject()), ObjectRef);
	Return SpreadsheetDocument;
	
EndFunction

// Obsolete. Use ReportOnObjectVersion instead.
//
Function GetObjectPrintForm(ObjectRef) Export
	
	Return ReportOnObjectVersion(ObjectRef);
	
EndFunction

#EndRegion

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnAddReferenceSearchException"].Add(
		"ObjectVersioning");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromSlave"].Add(
		"ObjectVersioning");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromMaster"].Add(
		"ObjectVersioning");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\OnFillToDoList"].Add(
			"ObjectVersioning");
	EndIf;
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"ObjectVersioning");
	
EndProcedure

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.8";
	Handler.Procedure = "ObjectVersioning.UpdateObjectVersionInformation";
	Handler.ExecutionMode = "Deferred";
	Handler.Comment = NStr("en = 'Updating informating on the saved object versions.'");
	
EndProcedure

// Fills empty attributes for the version information register.
Procedure UpdateObjectVersionInformation(Parameters) Export
	
	QueryText =
	"SELECT TOP 10000
	|	ObjectVersions.Object,
	|	ObjectVersions.VersionNumber
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.DataSize = 0";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	ProcessedRecords = 0;
	While Selection.Next() Do
		RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.Object);
		RecordSet.Filter.VersionNumber.Set(Selection.VersionNumber);
		RecordSet.Read();
		Try
			RecordSet.Write();
			ProcessedRecords = ProcessedRecords + 1;
		Except
			WriteLogEvent(
				NStr("en = 'Versioning'", CommonUseClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, RecordSet.Metadata(),
				,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot update information on object %2 version
						|%1: %3'", CommonUseClientServer.DefaultLanguageCode()),
					Selection.VersionNumber,
					CommonUse.SubjectString(Selection.Object),
					DetailErrorDescription(ErrorInfo())));
		EndTry;
	EndDo;
	
	If Selection.Count() > 0 Then
		If ProcessedRecords = 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'UpdateObjectVersionInformation procedure was unable to process some records from the ObjectVersions register: %1'"), 
					Selection.Count());
			Raise MessageText;
		EndIf;
		Parameters.ProcessingCompleted = False;
	EndIf;
	
EndProcedure

// Writes version of an object to the infobase.
//
// Parameters:
//  Object - object whose version is to be saved.
//
Procedure OnCreateObjectVersion(Object, WriteModePosting) Export
	
	Var LastVersionNumber, Comment;
	
	If Not VersionedObject(Object, LastVersionNumber, WriteModePosting) Then
		Return;
	EndIf;
	
	If Not Object.AdditionalProperties.Property("ObjectVersioningVersionComment", Comment) Then
		Comment = "";
	EndIf;
	
	ObjectVersionDetails = New Structure;
	ObjectVersionDetails.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	ObjectVersionDetails.Insert("Comment", Comment);
	
	CreateObjectVersion(Object, ObjectVersionDetails);
	
EndProcedure

// Writes version of an object received from data exchange to the infobase.
// For object versions with no conflicts, checks whether versioning is enabled.
//
// Parameters
// Object - object whose version is to be saved.
//
Procedure OnCreateObjectVersionOnDataExchange(Object) Export
	
	Var LastVersionNumber;
	
	If Not CommonUse.IsReferenceTypeObject(Object.Metadata()) Then
		
		Return;
		
	EndIf;
	
	Ref = Object.Ref;
	
	ObjectVersionDetails = CommonUseClientServer.CopyStructure(
		Object.AdditionalProperties.ObjectVersionDetails);
	
	If ObjectVersionDetails.ObjectVersionType = "DataAcceptedDuringConflict" Then
		
		LastVersionNumber = LastVersionNumber(Ref);
		
		ObjectVersionDetails.Insert("Object", Ref);
		ObjectVersionDetails.Insert("VersionNumber", Number(LastVersionNumber) + 1);
		ObjectVersionDetails.ObjectVersionType = Enums.ObjectVersionTypes[ObjectVersionDetails.ObjectVersionType];
		
		CreateObjectVersion(Object, ObjectVersionDetails, False);
		
	ElsIf VersionedObject(Object, LastVersionNumber) Then
		
		If ObjectVersionDetails.DeferredProcessing Then
			
			LastVersionNumber = LastVersionNumber(Ref);
			OverwritePreviousVersion(Ref, Object, LastVersionNumber, ObjectVersionDetails);
			
		Else
			
			ObjectVersionDetails.Insert("Object", Ref);
			ObjectVersionDetails.Insert("VersionNumber", Number(LastVersionNumber) + 1);
			ObjectVersionDetails.ObjectVersionType = Enums.ObjectVersionTypes[ObjectVersionDetails.ObjectVersionType];
			
			CreateObjectVersion(Object, ObjectVersionDetails, False);
			
		EndIf;
		
	EndIf;
	
	Object.AdditionalProperties.Delete("ObjectVersionDetails");
	
EndProcedure

// Fills a user's to-do list.
//
// Parameters:
//  ToDoList - ValueTable - value table with the following columns:
//    * ID             - String  - internal user task ID used by the To-do list algorithm.
//    * HasUserTasks   - Boolean - if True, the user task is displayed in the user's to-do list.
//    * Important      - Boolean - If True, the user task is outlined in red.
//    * Presentation   - String  - user task presentation displayed to the user.
//    * Quantity          - Number  - quantitative indicator of the user task, displayed in the title of the user task.
//    * Form           - String  - full path to the form that is displayed by a click on the task hyperlink in the To-do list panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner          - String, metadata object - string ID of the user task that is the owner of the current user task, or a subsystem metadata object.
//    * Hint           - String - hint text
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.ObjectVersioningSettings) Then
		Return;
	EndIf;
	
	// This procedure is only called when To-do list subsystem is available. 
	// Therefore, the subsystem availability check is redundant.
	ToDoListInternalCachedModule = CommonUse.CommonModule("ToDoListInternalCached");
	
	ObjectsBelonging = ToDoListInternalCachedModule.ObjectsBelongingToCommandInterfaceSections();
	Sections = ObjectsBelonging[Metadata.InformationRegisters.ObjectVersioningSettings.FullName()];
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	ObsoleteVersionsInfo = ObsoleteVersionsInfo();
	ObsoleteDataSize = DataSizeString(ObsoleteVersionsInfo.DataSize);
	Tooltip = NStr("en = 'Obsolete versions: %1 (%2)'");
	
	For Each Section In Sections Do
		
		ObsoleteObjectsID = "ObsoleteObjectVersions" + StrReplace(Section.FullName(), ".", "");
		// Adding a user task
		UserTask = ToDoList.Add();
		UserTask.ID = ObsoleteObjectsID;
		// Displaying a user task if the obsolete data exceeds 1 Gb
		UserTask.HasUserTasks      = ObsoleteVersionsInfo.DataSize > (1024 * 1024 * 1024);
		UserTask.Presentation = NStr("en = 'Obsolete object versions'");
		UserTask.Form         = "InformationRegister.ObjectVersioningSettings.Form.ObjectVersioning";
		UserTask.Tooltip     = StringFunctionsClientServer.SubstituteParametersInString(Tooltip, ObsoleteVersionsInfo.VersionCount, ObsoleteDataSize);
		UserTask.Owner      = Section;
		
	EndDo;
	
EndProcedure

// Creates an object version and writes it to the infobase.
//
Procedure CreateObjectVersion(Object, ObjectVersionDetails, NormalVersionRecord = True)
	
	CheckObjectEditRights(Object.Metadata());
	
	SetPrivilegedMode(True);
	
	If NormalVersionRecord Then
		// Saving data from the previous version
		If Not Object.IsNew() And CurrentAndPreviousVersionMismatch(Object) Then
			RecordManager = InformationRegisters.ObjectVersions.CreateRecordManager();
			RecordManager.Object = Object.Ref;
			RecordManager.VersionNumber = ObjectVersionDetails.VersionNumber - 1;
			RecordManager.Read();
			If RecordManager.Selected() Then
				BinaryData = SerializeObject(Object.Ref.GetObject());
				DataStorage = New ValueStorage(BinaryData, New Deflation(9));
				RecordManager.ObjectVersion = DataStorage;
				RecordManager.Write();
			EndIf;
		EndIf;
		
		ObjectRef = Object.Ref;;
		If ObjectRef.IsEmpty() Then
			ObjectRef = Object.GetNewObjectRef();
			If ObjectRef.IsEmpty() Then
				ObjectRef = CommonUse.ObjectManagerByRef(Object.Ref).GetRef();
				Object.SetNewObjectRef(ObjectRef);
			EndIf;
		EndIf;
		
		// Saving current version with no data
		RecordManager = InformationRegisters.ObjectVersions.CreateRecordManager();
		RecordManager.Object = ObjectRef;
		RecordManager.VersionNumber = ObjectVersionDetails.VersionNumber;
		RecordManager.VersionDate = CurrentSessionDate();
		
		VersionAuthor = Undefined;
		If Not Object.AdditionalProperties.Property("VersionAuthor", VersionAuthor) Then
			VersionAuthor = Users.AuthorizedUser();
		EndIf;
		RecordManager.VersionAuthor = VersionAuthor;
		
		RecordManager.ObjectVersionType = Enums.ObjectVersionTypes.ChangedByUser;
	Else
		BinaryData = SerializeObject(Object);
		DataStorage = New ValueStorage(BinaryData, New Deflation(9));
		
		RecordManager = InformationRegisters.ObjectVersions.CreateRecordManager();
		RecordManager.VersionDate = CurrentSessionDate();
		RecordManager.ObjectVersion = DataStorage;
		FillPropertyValues(RecordManager, ObjectVersionDetails);
	EndIf;
	
	RecordManager.Write();
	
EndProcedure

// Writes a version of an object received from data exchange to the infobase.
//
// Parameters
//  Object - object to be versionized.
//  ObjectVersionInformation - Structure - contains object version information.
//  RefExists - Boolean - flag specifying whether the referenced object exists in the infobase.
//
Procedure CreateObjectVersionByDataExchange(Object, ObjectVersionDetails, RefExists = Undefined) Export
	
	Ref = Object.Ref;
	
	If Not ValueIsFilled(RefExists) Then
		RefExists = CommonUse.RefExists(Ref);
	EndIf;
		
	If RefExists Then
		
		LastVersionNumber = LastVersionNumber(Ref);
		
	Else
		
		Ref = CommonUse.ObjectManagerByRef(Ref).GetRef(Object.GetNewObjectRef().UUID());
		LastVersionNumber = 0;
		
	EndIf;
	
	ObjectVersionDetails.Insert("Object", Ref);
	ObjectVersionDetails.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	ObjectVersionDetails.ObjectVersionType = Enums.ObjectVersionTypes[ObjectVersionDetails.ObjectVersionType];
	
	If Not ValueIsFilled(ObjectVersionDetails.VersionAuthor) Then
		ObjectVersionDetails.VersionAuthor = Users.AuthorizedUser();
	EndIf;
	
	CreateObjectVersion(Object, ObjectVersionDetails, False);
	
EndProcedure

// Sets the flag that shows whether the object version is ignored.
//
// Parameters:
//  Ref           - reference to an object whose version is to be ignored.
//  VersionNumber - Number - version number of the object to be ignored.
//  Ignore        - Boolean - flag that shows whether the version is ignored.
//
Procedure IgnoreObjectVersion(Ref, VersionNumber, Ignore) Export
	
	CheckObjectEditRights(Ref.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Ref);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Write = RecordSet[0];
	
	Write.VersionIgnored = Ignore;
	
	RecordSet.Write();
	
EndProcedure

// Returns the number of conflicts and declined objects
//
// Parameters:
//  ExchangeNodes   - ExchangePlanRef, Array, ValueList, Undefined - filter used to display the number of conflicts.
//  IsConflictCount - Boolean - if True, returns the number of conflicts. 
//                              If False, returns the number of rejected objects. 
//  DisplayIgnored  - Boolean - flag specifying whether the ignored objects are counted.
//  InfobaseNode    - ExchangePlanRef - total count for a specific node.
//  Period          - Standard period - total count for a specific period.
//  SearchString    - String - number of objects that contain SearchString in their comments.
//
Function ConflictOrRejectedItemCount(ExchangeNodes = Undefined, IsConflictCount = Undefined,
	DisplayIgnored = False, Period = Undefined, SearchString = "") Export
	
	Quantity = 0;
	
	If Not HasRightToReadObjectVersions() Then
		Return Quantity;
	EndIf;
	
	QueryText = "SELECT ALLOWED
	|	COUNT(ObjectVersions.Object) AS Quantity
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.VersionIgnored <> &FilterBySkipped
	|	AND (ObjectVersions.ObjectVersionType IN (&VersionTypes))
	|	[FilterByNode]
	|	[FilterByPeriod]
	|	[FilterByReason]";
	
	Query = New Query;
	
	FilterBySkipped = ?(DisplayIgnored, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If ExchangeNodes = Undefined Then
		FilterRow = "";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FilterRow = "AND ObjectVersions.VersionAuthor = &ExchangeNodes";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	Else
		FilterRow = "AND ObjectVersions.VersionAuthor IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByNode]", FilterRow);
	
	If ValueIsFilled(Period) Then
		
		FilterRow = "AND (ObjectVersions.VersionDate >= &StartDate AND ObjectVersions.VersionDate <= &EndDate)";
		Query.SetParameter("StartDate", Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
		
	Else
		
		FilterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByPeriod]", FilterRow);
	
	VersionTypes = New ValueList;
	If ValueIsFilled(IsConflictCount) Then
		
		If IsConflictCount Then
			
			VersionTypes.Add(Enums.ObjectVersionTypes.DataAcceptedDuringConflict);
			VersionTypes.Add(Enums.ObjectVersionTypes.DataNotAcceptedDuringConflict);
			
			FilterRow = "";
			
		Else
			
			VersionTypes.Add(Enums.ObjectVersionTypes.DataDeclinedByEditProhibitionDateExistsInInfobase);
			VersionTypes.Add(Enums.ObjectVersionTypes.DataDeclinedByEditProhibitionDateNotExistInInfobase);
			
			If ValueIsFilled(SearchString) Then
				
				FilterRow = "AND ObjectVersions.Comment LIKE &Comment";
				Query.SetParameter("Comment", "%" + SearchString + "%");
				
			Else
				
				FilterRow = "";
				
			EndIf;
			
		EndIf;
		
	Else // Filtering by comment is not supported
		
		VersionTypes.Add(Enums.ObjectVersionTypes.DataAcceptedDuringConflict);
		VersionTypes.Add(Enums.ObjectVersionTypes.DataNotAcceptedDuringConflict);
		VersionTypes.Add(Enums.ObjectVersionTypes.DataDeclinedByEditProhibitionDateExistsInInfobase);
		VersionTypes.Add(Enums.ObjectVersionTypes.DataDeclinedByEditProhibitionDateNotExistInInfobase);
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByReason]", FilterRow);
	Query.SetParameter("VersionTypes", VersionTypes);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Quantity = Selection.Quantity;
	EndIf;
	
	Return Quantity;
	
EndFunction

Function ObjectFromBinaryData(Write)
	
	BinaryData = Write.ObjectVersion.Get();
	
	XMLReader = New FastInfosetReader;
	XMLReader.SetBinaryData(BinaryData);
	If XMLReader.Read() Then
		If CanReadXML(XMLReader) Then
			Object = ReadXML(XMLReader);
			XMLReader.Close();
			Return Object;
		Else
			XMLReader.Close();
			Raise NStr("en = 'Object restoration error'");
		EndIf;
	Else
		XMLReader.Close();
		Raise NStr("en = 'Data reading error'");
	EndIf;

EndFunction

Function ObjectVersionRecord(ObjectRef, VersionNumber)
	
	RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectRef);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

Procedure OverwritePreviousVersion(Ref, Object, VersionNumber, ObjectVersionDetails)
	
	SetPrivilegedMode(True);
	
	RecordSet = ObjectVersionRecord(Ref, VersionNumber);
	
	If RecordSet.Count() = 0 Then
		
		VersionData = New Structure;
		VersionData.Insert("Object", Ref);
		VersionData.Insert("VersionNumber", Number(VersionNumber) + 1);
		VersionData.Insert("VersionAuthor", ObjectVersionDetails.VersionAuthor);
		VersionData.Insert("Comment", NStr("en = 'The object version is created during the data synchronization.'"));
		VersionData.Insert("ObjectVersionType", Enums.ObjectVersionTypes[ObjectVersionDetails.ObjectVersionType]);
		
		CreateObjectVersion(Object, VersionData, False);
		
	Else
		
		VersionRecord = RecordSet[0];
		
		XMLWriter = New FastInfosetWriter;
		XMLWriter.SetBinaryData();
		XMLWriter.WriteXMLDeclaration();
		WriteXML(XMLWriter, Object, XMLTypeAssignment.Explicit);
		BinaryData = XMLWriter.Close();
		DataStorage = New ValueStorage(BinaryData, New Deflation(9));
		
		VersionRecord.VersionDate	= CurrentSessionDate();
		VersionRecord.ObjectVersion = DataStorage;
		
		RecordSet.Write();
		
	EndIf;
	
EndProcedure

Procedure CheckObjectEditRights(MetadataObject)
	
	If Not PrivilegedMode() And Not AccessRight("Update", MetadataObject)Then
		MessageText = NStr("en = 'Insufficient rights to modify %1.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, MetadataObject.Presentation());
		Raise MessageText;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional subsystem calls

// Object version update handler.
//
// Parameters:
//  ObjectRef                    - Ref     - reference to the object to be updated.
//  NewVersionNumber             - Number  - version number to migrate.
//  IgnoredVersionNumber         - Number  - version number to ignore.
//  IgnoreChangeProhibitionCheck - Boolean - flag that shows whether the import prohibition date checking is skipped.
//
Procedure OnStartUsingNewObjectVersion(ObjectRef, Val VersionNumber) Export
	
	CheckObjectEditRights(ObjectRef.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = ObjectVersionRecord(ObjectRef, VersionNumber);
	Write = RecordSet[0];
	
	If Write.ObjectVersionType = Enums.ObjectVersionTypes.DataAcceptedDuringConflict Then
		
		VersionNumber = VersionNumber - 1;
		
		If VersionNumber <> 0 Then
			
			PreviousRecord = ObjectVersionRecord(ObjectRef, VersionNumber)[0];
			Object = ObjectFromBinaryData(PreviousRecord);
			VersionDate = PreviousRecord.VersionDate;
			
		EndIf;
		
	Else
		
		Object = ObjectFromBinaryData(Write);
		VersionDate = Write.VersionDate;
		
	EndIf;
	
	Object.AdditionalProperties.Insert("ObjectVersioningVersionComment",
		StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Transition to version #%1 from version %2 is executed'"),
		String(VersionNumber), Format(VersionDate, "DLF=DT")));
	Object.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
	Object.Write();
	
	Write.VersionIgnored = True;
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Returns number of the last saved object version.
//
// Parameters:
//  Ref - AnyRef - infobase object reference.
//
// Returns:
//  Number - object version number.
//
Function LastVersionNumber(Ref) Export
	
	If Ref.IsEmpty() Then
		Return 0;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(MAX(ObjectVersions.VersionNumber), 0) AS VersionNumber
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.Object = &Ref";
	Query.SetParameter("Ref", Ref);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.VersionNumber;
	
EndFunction

// Returns full names of metadata objects with versioning mechanism enabled.
//
// Returns:
//  Row array - metadata object names.
//
Function GetVersionedObjects()
	
	Result = New Array;
	
	For Each MetadataItem In Metadata.Catalogs Do
		If Metadata.CommonCommands.ChangeHistory.CommandParameterType.ContainsType(
					Type("CatalogRef."+MetadataItem.Name)) Then
			Result.Add(MetadataItem.FullName());
		EndIf;
	EndDo;
	
	For Each MetadataItem In Metadata.Documents Do
		If Metadata.CommonCommands.ChangeHistory.CommandParameterType.ContainsType(
					Type("DocumentRef."+MetadataItem.Name)) Then
			Result.Add(MetadataItem.FullName());
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a versioning mode enabled for the specified metadata object.
//
// Parameters:
//  FullObjectName - String - full path to the metadata object. Example: Catalog.ProductsAndServices.
//
// Returns:
//  Enum.ObjectVersioningModes.
//
Function ObjectVersioningOption(FullObjectName)
	
	Return GetFunctionalOption("ObjectVersioningModes",
		New Structure("VersionizedObjectType", FullObjectName));
		
EndFunction	

// Gets an object by its serialized XML presentation.
//
// Parameters:
//  AddressInTempStorage - String - binary data address in the temporary storage.
//  ErrorMessageText     - String - error text (return value) when the object cannot be restored.
//
// Returns:
//  Object or Undefined.
//
Function RestoreObjectByXML(Val AddressInTempStorage = "", ErrorMessageText = "") Export
	
	SetPrivilegedMode(True);
	
	BinaryData = GetFromTempStorage(AddressInTempStorage);
	
	FastInfosetReader = New FastInfosetReader;
	FastInfosetReader.SetBinaryData(BinaryData);
	
	Try
		Object = ReadXML(FastInfosetReader);
	Except
		WriteLogEvent(NStr("en = 'Versioning'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		ErrorMessageText = NStr("en = 'Cannot migrate to the selected version.
											|Possible reason: object versions are saved under different application versions.
											|Error technical details: %1'");
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageText, BriefErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
	Return Object;
	
EndFunction

// Returns a structure containing object version and additional information.
// 
// Parameters:
//  Ref           - Ref     - reference to the versioned object;
//  VersionNumber - Number  - object version number.
// 
// Returns: 
//   Structure:
//        ObjectVersion - BinaryData - saved version of the infobase object.
//        VersionAuthor - CatalogUsers, Catalog.ExternalUsers - user that saved the object version.
//        VersionDate   - Date - object version write date.
// 
// Comment:
//  This function can raise an exception if a record contains no data.
//  The function must be called in privileged mode.
//
Function ObjectVersionDetails(Val Ref, Val VersionNumber) Export
	MessageCannotGetVersion = NStr("en = 'Cannot get previous version of the object.'");
	If Not HasRightToReadObjectVersions() Then
		Raise MessageCannotGetVersion;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ObjectVersions.VersionAuthor AS VersionAuthor,
	|	ObjectVersions.VersionDate AS VersionDate,
	|	ObjectVersions.Comment AS Comment,
	|	ObjectVersions.ObjectVersion
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.Object = &Ref
	|	AND ObjectVersions.VersionNumber = &VersionNumber";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VersionNumber", Number(VersionNumber));
	
	Result = New Structure("ObjectVersion, VersionAuthor, VersionDate, Comment");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
		Result.ObjectVersion = Result.ObjectVersion.Get();
		If Result.ObjectVersion = Undefined Then
			Result.ObjectVersion = ObjectVersionData(Ref, VersionNumber);
		EndIf;
	EndIf;

	
	If Result.ObjectVersion = Undefined Then
		Raise NStr("en = 'Selected object version is not available in the application.'");
	EndIf;
	
	Return Result;
		
EndFunction

// Checks versioning settings for the passed object and returns the versioning mode.
// If versioning is not enabled for the object, the default versioning rules apply.
//
Function VersionedObject(Val Source, LastVersionNumber, WriteModePosting = False, Started = False) Export
	
	// Making sure that versioning subsystem is active
	If Not GetFunctionalOption("UseObjectVersioning") Then
		Return False;
	EndIf;
	
	VersioningMode = ObjectVersioningOption(Source.Metadata().FullName());
	If VersioningMode = False Then
		VersioningMode = Enums.ObjectVersioningModes.DontVersionize;
	EndIf;
	
	LastVersionNumber = LastVersionNumber(Source.Ref);
	
	Return 
		VersioningMode = Enums.ObjectVersioningModes.VersionizeOnWrite 
			Or VersioningMode = Enums.ObjectVersioningModes.VersionizeOnPost 
			And (LastVersionNumber > 0 Or WriteModePosting) Or VersioningMode = Enums.ObjectVersioningModes.VersionizeOnStart
	
EndFunction

// Adds information required for saving data exchange object version to the additional properties.
//
Procedure AddObjectVersionDataForDataExchange(Object, VersionAuthor)
	
	If TypeOf(Object) <> Type("ObjectDeletion") And CommonUse.IsReferenceTypeObject(Object.Metadata()) Then
		
		ObjectVersionDetails = New Structure;
		ObjectVersionDetails.Insert("VersionAuthor", VersionAuthor);
		ObjectVersionDetails.Insert("ObjectVersionType", "ChangedByUser");
		ObjectVersionDetails.Insert("Comment", NStr("en = 'Version is received during data synchronization.'"));
		ObjectVersionDetails.Insert("DeferredProcessing", False);
		Object.AdditionalProperties.Insert("ObjectVersionDetails", New FixedStructure(ObjectVersionDetails));
		
	EndIf;
	
EndProcedure

// Validates user rights to read version information.
//
Function HasRightToReadObjectVersions() Export
	Return Users.RolesAvailable("ReadObjectVersions, ReadObjectVersionInfo");
EndFunction

// Writes an object version to the infobase.
//
// Parameters:
//  Source - Object  - infobase object to write.
//  Cancel - Boolean - сancellation flag.
//
Procedure WriteObjectVersion(Source, WriteModePosting = False) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("ObjectVersionDetails") Then
		Return;
	EndIf;
	
	OnCreateObjectVersion(Source, WriteModePosting);
	
EndProcedure

// MD5 checksum
Function CheckSum(Data) Export
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(Data);
	Return StrReplace(DataHashing.HashSum, " ", "");
EndFunction

Function ObjectVersionData(ObjectRef, VersionNumber)
	
	QueryText = 
	"SELECT TOP 1
	|	ObjectVersions.ObjectVersion
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.Object = &Object
	|	AND ObjectVersions.VersionNumber >= &VersionNumber
	|	AND ObjectVersions.CheckSum <> """"
	|
	|ORDER BY
	|	ObjectVersions.VersionNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", ObjectRef);
	Query.SetParameter("VersionNumber", VersionNumber);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ObjectVersion.Get();
	EndIf;
	
	Return SerializeObject(ObjectRef.GetObject());
	
EndFunction
	
Function CurrentAndPreviousVersionMismatch(Object)
	
	QueryText = 
	"SELECT TOP 1
	|	ObjectVersions.CheckSum
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.Object = &Object
	|	AND ObjectVersions.HasVersionData
	|
	|ORDER BY
	|	ObjectVersions.VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object.Ref);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.CheckSum <> CheckSum(SerializeObject(Object));
	EndIf;
	
	Return Object.IsNew() Or CheckSum(SerializeObject(Object)) <> CheckSum(SerializeObject(Object.Ref.GetObject()));
	
EndFunction

// For internal use only
Procedure ClearObsoleteObjectVersions() Export
	
	SetPrivilegedMode(True);
	
	ObjectDeletionBoundaries = ObjectDeletionBoundaries();
	
	QueryText =
	"SELECT
	|	ObjectVersions.Object,
	|	ObjectVersions.VersionNumber
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE False";
	
	Query = New Query;
	For Index = 0 To ObjectDeletionBoundaries.Count() - 1 Do
		IndexString = Format(Index, "NZ=0; NG=0");
		QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
			"
			|	OR VALUETYPE(ObjectVersions.Object) IN (&TypeList%1) AND ObjectVersions.VersionDate < &DeletionBoundary%1",
			IndexString);
		Query.SetParameter("TypeList" + IndexString, ObjectDeletionBoundaries[Index].TypeList);
		Query.SetParameter("DeletionBoundary" + IndexString, ObjectDeletionBoundaries[Index].DeletionBoundary);
	EndDo;
	
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordManager = InformationRegisters.ObjectVersions.CreateRecordManager();
		RecordManager.Object = Selection.Object;
		RecordManager.VersionNumber = Selection.VersionNumber;
		RecordManager.Read();
		RecordManager.ObjectVersion = Undefined;
		RecordManager.Write();
	EndDo;
	
EndProcedure

Function ObjectDeletionBoundaries() Export
	
	Result = New ValueTable;
	Result.Columns.Add("TypeList", New TypeDescription("Array"));
	Result.Columns.Add("DeletionBoundary", New TypeDescription("Date"));
	
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType,
	|	ObjectVersioningSettings.VersionLifetime AS VersionLifetime
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|
	|ORDER BY
	|	VersionLifetime
	|TOTALS BY
	|	VersionLifetime";
	
	Query = New Query(QueryText);
	LifetimeSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While LifetimeSelection.Next() Do
		ObjectSelection = LifetimeSelection.Select();
		TypeList = New Array;
		While ObjectSelection.Next() Do
			TypeList.Add(Type(StrReplace(ObjectSelection.ObjectType, ".", "Ref.")));
		EndDo;
		BoundaryAndObjectTypesMap = Result.Add();
		BoundaryAndObjectTypesMap.DeletionBoundary = DeletionBoundary(LifetimeSelection.VersionLifetime);
		BoundaryAndObjectTypesMap.TypeList = TypeList;
	EndDo;
	
	Return Result;
	
EndFunction
	
Function DeletionBoundary(VersionLifetime)
	If VersionLifetime = Enums.VersionLifetimes.LastYear Then
		Return AddMonth(CurrentSessionDate(), -12);
	ElsIf VersionLifetime = Enums.VersionLifetimes.LastSixMonths Then
		Return AddMonth(CurrentSessionDate(), -6);
	ElsIf VersionLifetime = Enums.VersionLifetimes.LastThreeMonths Then
		Return AddMonth(CurrentSessionDate(), -3);
	ElsIf VersionLifetime = Enums.VersionLifetimes.LastMonth Then
		Return AddMonth(CurrentSessionDate(), -1);
	ElsIf VersionLifetime = Enums.VersionLifetimes.LastWeek Then
		Return CurrentSessionDate() - 7*24*60*60;
	Else // VersionLifetime = Enums.VersionLifetimes.Infinite
		Return '000101010000';
	EndIf;
EndFunction

// For internal use only.
// The comment is only saved when the user is either version author or administrator.
Procedure AddCommentToVersion(ObjectRef, VersionNumber, Comment) Export
	
	If Not HasRightToReadObjectVersions() Then
		Return;
	EndIf;
	
	RecordManager = InformationRegisters.ObjectVersions.CreateRecordManager();
	RecordManager.Object = ObjectRef;
	RecordManager.VersionNumber = VersionNumber;
	RecordManager.Read();
	If RecordManager.Selected() Then
		If RecordManager.VersionAuthor = Users.CurrentUser() Or Users.InfobaseUserWithFullAccess() Then
			RecordManager.Comment = Comment;
			RecordManager.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Provides information on the number and size of outdated object versions.
Function ObsoleteVersionsInfo() Export
	
	SetPrivilegedMode(True);
	
	ObjectDeletionBoundaries = ObjectDeletionBoundaries();
	
	Query = New Query;
	QueryText =
	"SELECT
	|	ISNULL(SUM(ObjectVersions.DataSize), 0) AS DataSize,
	|	ISNULL(SUM(1), 0) AS VersionCount
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.HasVersionData
	|	AND &AdditionalConditions";
	
	AdditionalConditions = "";
	For Index = 0 To ObjectDeletionBoundaries.Count() - 1 Do
		If Not IsBlankString(AdditionalConditions) Then
			AdditionalConditions = AdditionalConditions + "
			|	OR";
		EndIf;
		IndexString = Format(Index, "NZ=0; NG=0");
		AdditionalConditions = AdditionalConditions + StringFunctionsClientServer.SubstituteParametersInString(
			"
			|	VALUETYPE(ObjectVersions.Object) IN (&TypeList%1) AND ObjectVersions.VersionDate < &DeletionBoundary%1",
			IndexString);
		Query.SetParameter("TypeList" + IndexString, ObjectDeletionBoundaries[Index].TypeList);
		Query.SetParameter("DeletionBoundary" + IndexString, ObjectDeletionBoundaries[Index].DeletionBoundary);
	EndDo;
	If IsBlankString(AdditionalConditions) Then
		AdditionalConditions = "FALSE";
	Else
		AdditionalConditions = "(" + AdditionalConditions + ")";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	VersionCount = 0;
	DataSize = 0;
	If Selection.Next() Then
		DataSize = Selection.DataSize;
		VersionCount = Selection.VersionCount;
	EndIf;
	
	Result = New Structure;
	Result.Insert("VersionCount", VersionCount);
	Result.Insert("DataSize", DataSize);
	
	Return Result;
	
EndFunction

// String presentation of data volume. For example: "1.23 GB".
Function DataSizeString(Val DataSize) Export
	
	UnitOfMeasurement = NStr("en = 'byte'");
	If 1024 <= DataSize And DataSize < 1024 * 1024 Then
		DataSize = DataSize / 1024;
		UnitOfMeasurement = NStr("en = 'KB'");
	ElsIf 1024 * 1024 <= DataSize And  DataSize < 1024 * 1024 * 1024 Then
		DataSize = DataSize / 1024 / 1024;
		UnitOfMeasurement = NStr("en = 'MB'");
	ElsIf 1024 * 1024 * 1024 <= DataSize Then
		DataSize = DataSize / 1024 / 1024 / 1024;
		UnitOfMeasurement = NStr("en = 'GB'");
	EndIf;
	
	If DataSize < 10 Then
		DataSize = Round(DataSize, 2);
	ElsIf DataSize < 100 Then
		DataSize = Round(DataSize, 1);
	Else
		DataSize = Round(DataSize, 0);
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2'"), DataSize, UnitOfMeasurement);
	
EndFunction
	
////////////////////////////////////////////////////////////////////////////////
// Functions used to generate object reports

// Returns a serialized object in the binary data format.
//
// Parameters:
//  Object - Any - object to serialize.
//
// Returns:
//  BinaryData - serialized object.
Function SerializeObject(Object) Export
	
	XMLWriter = New FastInfosetWriter;
	XMLWriter.SetBinaryData();
	XMLWriter.WriteXMLDeclaration();
	
	WriteXML(XMLWriter, Object, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();

EndFunction

// Reads XML data from file and fills data structures
//
// Returns:
//  Structure containing two maps: TabularSections and Attributes.
//  Data storage structure:
//    Map TabularSections containing the tabular section values in format:
//          MapName1 -> ValueTable1
//                   |      |     ... |
//                   Field1 Field2    FieldM1
//
//          MapName2 -> ValueTable2
//                   |      |     ... |
//                   Field1 Field2    FieldM2
//
//          MapNameN -> ValueTableN
//                   |      |     ... |
//                   Field1 Field2    FieldM3
//
//    Map AttributeValues
//          AttributeName1 > Value1
//          AttributeName2 > Value2 
//          ...
//          AttributeNameN > ValueN
//
Function XMLObjectPresentationParsing(BinaryData, Ref) Export
	
	// Contains the modified object metadata name
	Var ObjectName;
	
	// Contains marker position in an XML tree.
	// Required to identify the current item.
	Var ReadingLevel;
	
	// Contains catalog/document attribute values
	AttributeValues = New ValueTable;
	
	AttributeValues.Columns.Add("AttributeDescription");
	AttributeValues.Columns.Add("AttributeValue");
	AttributeValues.Columns.Add("AttributeType");
	AttributeValues.Columns.Add("Type");
	
	TabularSections = New Map;
	
	XMLReader = New FastInfosetReader;
	
	XMLReader.SetBinaryData(BinaryData);
	
	// Marker position level in XML hierarchy:
	// 0 - level not set
	// 1 - first element (object name)
	// 2 - attribute or tabular section description
	// 3 - tabular section string description
	// 4 - tabular section string field description
	ReadingLevel = 0;
	
	ObjectMetadata = Ref.Metadata();
	MTDTabularSections = ObjectMetadata.TabularSections;
	
	ValueType = "";
	
	TSFieldValueType = "";
	
	// Main XML parsing cycle
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ReadingLevel = ReadingLevel + 1;
			If ReadingLevel = 1 Then // Pointer is set to the first XML element (XML root)
				ObjectName = XMLReader.Name;
			ElsIf ReadingLevel = 2 Then // Pointer is set to level 2 (an attribute or tabular section name)
				AttributeName = XMLReader.Name;
				
				// Saving the attribute against a possible case that it may be a tabular section
				TabularSectionName = AttributeName;
				If ObjectMetadata.TabularSections.Find(TabularSectionName) <> Undefined And TabularSections[TabularSectionName] = Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				
				NewAV = AttributeValues.Add();
				NewAV.AttributeDescription = AttributeName;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
						   And XMLReader.Name = "xsi:type" Then
							NewAV.AttributeType = XMLReader.Value;
							
							XMLType = XMLReader.Value;
							
							If Left(XMLType, 3) = "xs:" Then
								NewAV.Type = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
							Else
								NewAV.Type = FromXMLType(New XMLDataType(XMLType, ""));
							EndIf;
							
						EndIf;
					EndDo;
				EndIf;
				
				If Not ValueIsFilled(NewAV.Type) Then
					
					AttributeDetails = ObjectMetadata.Attributes.Find(NewAV.AttributeDescription);
					
					If AttributeDetails = Undefined Then
						
						AttributeDescription = GetAttributePresentationInLanguage(NewAV.AttributeDescription);
						
						If CommonUse.IsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeDescription) Then
							
							AttributeDetails = ObjectMetadata.StandardAttributes[AttributeDescription];
							
						EndIf;
						
					EndIf;
					
					If AttributeDetails <> Undefined
						And AttributeDetails.Type.Types().Count() = 1 Then
						NewAV.Type = AttributeDetails.Type.Types()[0];
					EndIf;
					
				EndIf;
				
			ElsIf (ReadingLevel = 3) and (XMLReader.Name = "Row") Then // pointer to tabular section field
				If TabularSections[TabularSectionName] = Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				
				TabularSections[TabularSectionName].Add();
			ElsIf ReadingLevel = 4 Then // Pointer is set to a tabular section field
				
				TSFieldValueType = "";
				
				TSFieldName = XMLReader.Name; // 
				Table   = TabularSections[TabularSectionName];
				If Table.Columns.Find(TSFieldName)= Undefined Then
					Table.Columns.Add(TSFieldName);
				EndIf;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
						   And XMLReader.Name = "xsi:type" Then
							XMLType = XMLReader.Value;
							
							If Left(XMLType, 3) = "xs:" Then
								TSFieldValueType = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
							Else
								TSFieldValueType = FromXMLType(New XMLDataType(XMLType, ""));
							EndIf;
							
						EndIf;
					EndDo;
				EndIf;
				
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			ReadingLevel = ReadingLevel - 1;
			ValueType = "";
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			If (ReadingLevel = 2) Then // Attribute value
				Try
					NewAV.AttributeValue = ?(ValueIsFilled(NewAV.Type), XMLValue(NewAV.Type, XMLReader.Value), XMLReader.Value);
				Except
					NewAV.AttributeValue = XMLReader.Value;
				EndTry;
			ElsIf (ReadingLevel = 4) Then // Attribute value
				LastRow = TabularSections[TabularSectionName].Get(TabularSections[TabularSectionName].Count()-1);
				
				If TSFieldValueType = "" Then
					TSADetails = Undefined;
					If MTDTabularSections.Find(TabularSectionName) <> Undefined Then
						TSADetails = MTDTabularSections[TabularSectionName].Attributes.Find(TSFieldName);
						
						If TSADetails <> Undefined
						   And TSADetails.Type.Types().Count() = 1 Then
							TSFieldValueType = TSADetails.Type.Types()[0];
						EndIf;
					EndIf;					
				EndIf;
				
				LastRow[TSFieldName] = ?(ValueIsFilled(TSFieldValueType), XMLValue(TSFieldValueType, XMLReader.Value), XMLReader.Value);
				
			EndIf;
		EndIf;
	EndDo;
	
	// Step 2: removing tabular sections from the attribute list
	For Each Item In TabularSections Do
		AttributeValues.Delete(AttributeValues.Find(Item.Key));
	EndDo;
	// MTDTabularSections
	For Each MapItem In TabularSections Do
		Table = MapItem.Value;
		If Table.Columns.Count() = 0 Then
			MTDTable = MTDTabularSections.Find(MapItem.Key);
			If MTDTable <> Undefined Then
				For Each ColumnDetails In MTDTable.Attributes Do
					If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
						Table.Columns.Add(ColumnDetails.Name);
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("Attributes", AttributeValues);
	Result.Insert("TabularSections", TabularSections);
	
	Return Result;
	
EndFunction

// Gets presentation of a system attribute name.
//
Function GetAttributePresentationInLanguage(Val AttributeName) Export
	
	If      AttributeName = "Number" Then
		Return NStr("en = 'Number'; en='Number'");
	ElsIf AttributeName = "Name" Then
		Return NStr("en = 'Description'; en='Name'");
	ElsIf AttributeName = "Code" Then
		Return NStr("en = 'Code'; en='Code'");
	ElsIf AttributeName = "IsFolder" Then
		Return NStr("en = 'IsFolder'; en='Is folder'");
	ElsIf AttributeName = "Description" Then
		Return NStr("en = 'Description'; en='Description'");
	ElsIf AttributeName = "Date" Then
		Return NStr("en = 'Date'; en='Date'");
	ElsIf AttributeName = "Posted" Then
		Return NStr("en = 'Posted'; en='Posted'");
	ElsIf AttributeName = "DeletionMark" Then
		Return NStr("en = 'DeletionMark'; en='Deletion mark'");
	ElsIf AttributeName = "Ref" Then
		Return NStr("en = 'Ref'; en='Ref'");
	ElsIf AttributeName = "Parent" Then
		Return NStr("en = 'Parent'; en='Parent'");
	ElsIf AttributeName = "Owner" Then
		Return NStr("en = 'Owner'; en='Owner'");
	Else
		Return AttributeName;
	EndIf;
	
EndFunction

Procedure GenerateReportOnTransmittedVersion(ReportTS, SerializedXML, ObjectRef)
	
	If ObjectRef.Metadata().Templates.Find("ObjectTemplate") <> Undefined Then
		Template = CommonUse.ObjectManagerByRef(ObjectRef).GetTemplate("ObjectTemplate");
	Else
		Template = Undefined;
	EndIf;
	
	If Template = Undefined Then
		
		ObjectVersion = XMLObjectPresentationParsing(SerializedXML, ObjectRef);
		ObjectVersion.Insert("ObjectName",     String(ObjectRef));
		ObjectVersion.Insert("ChangeAuthor", "");
		ObjectVersion.Insert("ChangeDate",  CurrentSessionDate());
		
		Section = ReportTS.GetArea("R2");
		PutTextToReport(ReportTS, Section, "R2C2", ObjectRef.Metadata().Synonym,,,16, True);
		
		///////////////////////////////////////////////////////////////////////////////
		// Displaying the list of modified attributes
		
		ReportTS.Area("C2").ColumnWidth = 30;
		ReportTS.Area("C3").ColumnWidth = 50;
		
		DisplayedRowNumber = DisplayParsedObjectAttributes(ReportTS, ObjectVersion, ObjectRef);
		DisplayedRowNumber = DisplayParsedObjectTabularSections(ReportTS, ObjectVersion, DisplayedRowNumber+7, ObjectRef);
	Else
		GenerateByStandardTemplate(ReportTS,
										 Template,
										 ObjectRef.GetObject(),
										 "",
										 ObjectRef);
	EndIf;
	
EndProcedure

// Generates an object report using a standard template.
//
// Parameters:
//   ReportTS          - SpreadsheetDocument          - spreadsheet document used to display the report.
//   ObjectVersion     - CatalogObject,DocumentObject - object to be displayed in the report.
//   ObjectDescription - String                       - object name.
//
Procedure GenerateByStandardTemplate(ReportTS, Template, ObjectVersion, Val VersionDetails, ObjectRef)
	
	ObjectMetadata = ObjectRef.Metadata();
	
	ObjectDescription = ObjectMetadata.Name;
	
	ReportTS = New SpreadsheetDocument;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectRef)) Then
		Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
	Else
		Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
	EndIf;
	
	// Title
	Area = Template.GetArea("Title");
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R3");
	SetTextProperties(Area.Area("R1C2"), VersionDetails, , , , True);
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R5");
	ReportTS.Put(Area);
	
	// Header
	Header = Template.GetArea("Header");
	Header.Parameters.Fill(ObjectVersion);
	ReportTS.Put(Header);
	
	For Each PMMetadata In ObjectMetadata.TabularSections Do
		If ObjectVersion[PMMetadata.Name].Count() > 0 Then
			Region = Template.GetArea(PMMetadata.Name+"Header");
			ReportTS.Put(Area);
			
			GoodsReceiptDetailsArea = Template.GetArea(PMMetadata.Name);
			For Each CurRowGoodsReceiptDetails In ObjectVersion[PMMetadata.Name] Do
				GoodsReceiptDetailsArea.Parameters.Fill(CurRowGoodsReceiptDetails);
				ReportTS.Put(GoodsReceiptDetailsArea);
			EndDo;
		EndIf;
	EndDo;
	
	ReportTS.ShowGrid = False;
	ReportTS.Protection = True;
	ReportTS.ReadOnly = True;
	ReportTS.ShowHeaders = False;
	
EndProcedure

// Displays the modified attributes in report, and gets their presentation.
//
Function DisplayParsedObjectAttributes(ReportTS, ObjectVersion, ObjectRef)
	
	Section = ReportTS.GetArea("R6");
	PutTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	PutTextToReport(ReportTS, Section, "R1C2", "Attributes", , , 11, True);
	ReportTS.StartRowGroup("AttributeGroup");
	PutTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	
	OutputRowNumber = 0;
	
	For Each AttributeItem In ObjectVersion.Attributes Do
		
		AttributeDescription = GetAttributePresentationInLanguage(AttributeItem.AttributeDescription);
		
		AttributeDescription = ObjectRef.Metadata().Attributes.Find(AttributeDescription);
		
		If AttributeDescription = Undefined Then
			For Each StandardAttributeDescription In ObjectRef.Metadata().StandardAttributes Do
				If StandardAttributeDescription.Name = AttributeDescription Then
					AttributeDescription = StandardAttributeDescription;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		AttributeValue = ?(AttributeItem.AttributeValue = Undefined, "", AttributeItem.AttributeValue);
		
		DisplayedDescription = AttributeDescription;
		ValuePresentation = String(AttributeValue);
		
		SetTextProperties(Section.Area("R1C2"), DisplayedDescription, , , , True);
		SetTextProperties(Section.Area("R1C3"), ValuePresentation);
		Section.Area("R1C2:R1C3").BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 1, 0);
		Section.Area("R1C2:R1C3").BorderColor = StyleColors.InaccessibleDataColor;
		
		ReportTS.Put(Section);
		
		OutputRowNumber = OutputRowNumber + 1;
	EndDo;
	
	ReportTS.EndRowGroup();
	
	Return OutputRowNumber;
	
EndFunction

// Displays tabular sections of the parsed object (when displaying a single object).
//
Function DisplayParsedObjectTabularSections(ReportTS, ObjectVersion, OutputLineNumber, ObjectRef);
	
	OutputRowNumber = 0;
	
	If ObjectVersion.TabularSections.Count() <> 0 Then
		
		For Each StringTabularSection In ObjectVersion.TabularSections Do
			TabularSectionDescription = StringTabularSection.Key;
			TabularSection             = StringTabularSection.Value;
			If TabularSection.Count() > 0 Then
				
				PMMetadata = ObjectRef.Metadata().TabularSections.Find(TabularSectionDescription);
				
				TSSynonym = Undefined;
				If PMMetadata <> Undefined Then
					TSSynonym = PMMetadata.Synonym;
				EndIf;
				TSSynonym = ?(ValueIsFilled(TSSynonym), TSSynonym, TabularSectionDescription);
				
				Section = ReportTS.GetArea("R" + String(OutputLineNumber));
				PutTextToReport(ReportTS, Section, "R1C1:R1C100", " ");
				OutputArea = PutTextToReport(ReportTS, Section, "R1C2", TSSynonym, , , 11, True);
				ReportTS.Area("R"+OutputArea.Top+"C2").CreateFormatOfRows();
				ReportTS.Area("R"+OutputArea.Top+"C2").ColumnWidth = Round(StrLen(TSSynonym)*2, 0, RoundMode.Round15as20);
				ReportTS.StartRowGroup("RowGroup");
				
				PutTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
				
				OutputRowNumber = OutputRowNumber + 1;
				
				OutputLineNumber = OutputLineNumber + 3;
				
				AddedTS = New SpreadsheetDocument;
				
				AddedTS.Join(GenerateEmptySector(TabularSection.Count()+1));
				
				ColumnNumber = 2;
				
				ColumnDimensionMap = New Map;
				
				Section = New SpreadsheetDocument;
				
				SetTextProperties(Section.Area("R1C1"),"N", , StyleColors.InaccessibleDataColor, , True, True);
				
				LineNumber = 1;
				For Each TabularSectionRow In TabularSection Do
					LineNumber = LineNumber + 1;
					SetTextProperties(Section.Area("R" + LineNumber + "C1"), String(LineNumber-1), , , , , True);
				EndDo;
				AddedTS.Join(Section);
				
				ColumnNumber = 3;
				
				For Each TabularSectionColumn In TabularSection.Columns Do
					Section = New SpreadsheetDocument;
					FieldDescription = TabularSectionColumn.Name;
					
					FieldDetails = Undefined;
					If PMMetadata <> Undefined Then
						FieldDetails = PMMetadata.Attributes.Find(FieldDescription);
					EndIf;
					
					If FieldDetails = Undefined Or Not ValueIsFilled(FieldDetails.Synonym) Then
						DisplayedFieldDescription = FieldDescription;
					Else
						DisplayedFieldDescription = FieldDetails.Synonym;
					EndIf;
					ColumnHeaderColor = ?(FieldDetails = Undefined, StyleColors.DeletedAttributeTitleBackground, StyleColors.InaccessibleDataColor);
					SetTextProperties(Section.Area("R1C1"),
											 DisplayedFieldDescription, ,ColumnHeaderColor, , True, True);
					ColumnDimensionMap.Insert(ColumnNumber, StrLen(FieldDescription) + 4);
					LineNumber = 1;
					For Each TabularSectionRow In TabularSection Do
						LineNumber = LineNumber + 1;
						Value = ?(TabularSectionRow[FieldDescription] = Undefined, "", TabularSectionRow[FieldDescription]);
						ValuePresentation = String(Value);
						
						SetTextProperties(Section.Area("R" + LineNumber + "C1"), ValuePresentation, , , , , True);
						If StrLen(ValuePresentation) > (ColumnDimensionMap[ColumnNumber] - 4) Then
							ColumnDimensionMap[ColumnNumber] = StrLen(ValuePresentation) + 4;
						EndIf;
					EndDo; // For Each TabularSectionRow From TabularSection Do
					
					AddedTS.Join(Section);
					ColumnNumber = ColumnNumber + 1;
				EndDo; // For Each TabularSectionColumn From TabularSection.Columns Do
				
				OutputArea = ReportTS.Put(AddedTS);
				ReportTS.Area("R"+OutputArea.Top+"C1:R"+OutputArea.Bottom+"C"+ColumnNumber).CreateFormatOfRows();
				ReportTS.Area("R"+OutputArea.Top+"C2").ColumnWidth = 7;
				For CurrentColumnNumber = 3 To ColumnNumber-1 Do
					ReportTS.Area("R"+OutputArea.Top+"C"+CurrentColumnNumber).ColumnWidth = ColumnDimensionMap[CurrentColumnNumber];
				EndDo;
				ReportTS.EndRowGroup();
				
			EndIf; // If TabularSection.Number.() > 0 Then
		EndDo; // For Each StringTabularSection From ObjectVersion.TabularSections Do
		
	EndIf;
	
EndFunction

// Displays text in the spreadsheet document area using specific appearance.
//
Function PutTextToReport(ReportTS,
                             Val Section,
                             Val State,
                             Val Text,
                             Val TextColor = Undefined,
                             Val BackColor   = Undefined,
                             Val Size     = 9,
                             Val Bold     = False)
	
	SectionArea = Section.Area(State);
	
	If TextColor <> Undefined Then
		SectionArea.TextColor = TextColor;
	EndIf;
	
	If BackColor <> Undefined Then
		SectionArea.BackColor = BackColor;
	EndIf;
	
	SectionArea.Text      = Text;
	SectionArea.Font      = New Font(, Size, Bold, , , );
	SectionArea.HorizontalAlign = HorizontalAlign.Left;
	
	SectionArea.TopBorder    = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.BottomBorder = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.LeftBorder   = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.RightBorder  = New Line(SpreadsheetDocumentCellLineType.None);
	
	Return ReportTS.Put(Section);
	
EndFunction

// Used to display text in the spreadsheet document area with conditional appearance.
//
Procedure SetTextProperties(SectionArea, Text,
                                   Val TextColor = Undefined,
                                   Val BackColor = Undefined,
                                   Val Size = 9,
                                   Val Bold = False,
                                   Val ShowBorders = False)
	
	SectionArea.Text = Text;
	
	If TextColor <> Undefined Then
		SectionArea.TextColor = TextColor;
	EndIf;
	
	If BackColor <> Undefined Then
		SectionArea.BackColor = BackColor;
	EndIf;
	
	SectionArea.Font = New Font(, Size, Bold, , , );
	
	If ShowBorders Then
		SectionArea.TopBorder    = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.LeftBorder   = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.RightBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.HorizontalAlign = HorizontalAlign.Center;
	EndIf;
	
EndProcedure

// Generates an empty sector for report output.
// Can only be used if the string was not modified in any version.
//
Function GenerateEmptySector(Val RowCount, Val OutputType = "")
	
	FillingValue = New Array;
	
	For Index = 1 To RowCount Do
		FillingValue.Add(" ");
	EndDo;
	
	Return GenerateSectorPMRows(FillingValue, OutputType);
	
EndFunction

// FillingValue - Array of String
// OutputType - string:
//               "M" - change
//               "A" - add
//               "D" - delete
//               ""  - regular output
Function GenerateSectorPMRows(Val FillingValue,Val OutputType = "")
	
	CommonTemplate = InformationRegisters.ObjectVersions.GetTemplate("StandardObjectPresentationTemplate");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If      OutputType = ""  Then
		Template = CommonTemplate.GetArea("InitialAttributeValue");
	ElsIf OutputType = "M" Then
		Template = CommonTemplate.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "A" Then
		Template = CommonTemplate.GetArea("AddedAttribute");
	ElsIf OutputType = "D" Then
		Template = CommonTemplate.GetArea("DeletedAttribute");
	EndIf;
	
	For Each NextValue In FillingValue Do
		Template.Parameters.AttributeValue = NextValue;
		SpreadsheetDocument.Put(Template);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Fills the array with the list of names of metadata objects that might include references to
// other metadata objects, but these references are ignored in the business logic of the
// application.
//
// Parameters:
//  Array       - array of strings, for example, "InformationRegister.ObjectVersions".
//
Procedure OnAddReferenceSearchException(Array) Export
	
	Array.Add(Metadata.InformationRegisters.ObjectVersions.FullName());
	
EndProcedure

// Handler of the event that has the same name, which occurs during data exchange in a distributed infobase.
//
// Parameters:
//   see the OnReceiveDataFromSlave() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlave(DataItem, ItemReceive, SendBack, Sender) Export
	
	AddObjectVersionDataForDataExchange(DataItem, Sender);
	
EndProcedure

// Handler of the event that has the same name, which occurs during data exchange in a distributed infobase.
//
// Parameters:
//   see OnReceiveDataFromMaster() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	AddObjectVersionDataForDataExchange(DataItem, Sender);
	
EndProcedure

#EndRegion