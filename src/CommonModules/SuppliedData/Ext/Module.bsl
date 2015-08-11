///////////////////////////////////////////////////////////////////////////////////
// SuppliedData: the supplied data service mechanism.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns the web service proxy that is used for updating shared supplied data.
// 
// Returns: 
//  WSProxy - supplied data web service proxy.
//
Function GetSuppliedDataServiceProxy() Export
	
	SuppliedDataServiceAddress = Constants.SuppliedDataServiceAddress.Get();
	If Not ValueIsFilled(SuppliedDataServiceAddress) Then
		Raise(NStr("en = 'Connection parameters of the supplied data web service are not specified.'"));
	EndIf;
	
	ServiceAddress = SuppliedDataServiceAddress + "/ws/SuppliedData?wsdl";
	
	UserName = Constants.AuxiliarySuppliedDataServiceUserName.Get();
	UserPassword = Constants.AuxiliarySuppliedDataServiceUserPassword.Get();
	
	Proxy = CommonUseCached.GetWSProxy(ServiceAddress, "http://1c-dn.com/supplieddata",		"SuppliedData", , UserName, UserPassword);
	
	Return Proxy;
	
EndFunction

// Updates shared data of the supplied data service.
//
Procedure UpdateSharedSuppliedData() Export
	
	SetPrivilegedMode(True);
	
	Proxy = GetSuppliedDataServiceProxy();
	
	
FilterType = Proxy.XDTOFactory.Type("http://1c-dn.com/supplieddata", "Filter");
	Filter = Proxy.XDTOFactory.Create(FilterType);
	
	FilterItemType = Proxy.XDTOFactory.Type("http://1c-dn.com/supplieddata", "FilterItem");
	
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	For Each Row In MapTable Do
		Version = GetSuppliedDataVersion(Row.SharedDataType);
		
		FilterItem = Proxy.XDTOFactory.Create(FilterItemType);
		FilterItem.Type = XMLString(Row.SuppliedDataKind);
		FilterItem.Version = Version;
		Filter.FilterItem.Add(FilterItem);
		
	EndDo;
	
	Results = Proxy.GetSuppliedData(Filter);
	
	ImportNumber = Constants.SuppliedDataImportNumber.Get() + 1;
	
	ImportData(Results, ImportNumber);
	
	Constants.SuppliedDataImportNumber.Set(ImportNumber);
	
	SeparatedSuppliedDataUpdateControl();
	
EndProcedure

// Updates separated data from shared data. Is called from background jobs.
//
Procedure UpdateSuppliedData(DataArea, MessageNo) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Key = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordKey(
			New Structure("DataArea, MessageNo", DataArea, MessageNo));
		
		LockDataForEdit(Key);
		
		For Each ContentItem In Metadata.ExchangePlans.SuppliedDataChanges.Content Do
			
			MDObject = ContentItem.Metadata;
			
			If Metadata.InformationRegisters.Contains(MDObject) Then
				IsInformationRegister = True;
				SourceType = Type("InformationRegisterRecordKey." + MDObject.Name);
				TargetType = GetSeparatedDataTypeBySharedDataType(SourceType);
				TargetMD = Metadata.FindByType(TargetType);
				Manager = InformationRegisters[TargetMD.Name];
			Else
				IsInformationRegister = False;
				SourceType = Type("CatalogRef." + MDObject.Name);
				TargetType = GetSeparatedDataTypeBySharedDataType(SourceType);
				TargetMD = Metadata.FindByType(TargetType);
				Manager = Catalogs[TargetMD.Name];
			EndIf;
			
			ChangeSelection = ExchangePlans.SelectChanges(
				SuppliedDataCached.GetDataAreaNode(DataArea), 0, MDObject);
			
			While ChangeSelection.Next() Do
				
				TargetObject = Undefined;
				
				Prototype = ChangeSelection.Get();
				
				StandardProcessing = True;
				
				If IsInformationRegister Then
					
					StandardSubsystemsOverridable.BeforeCopyRecordSetFromPrototype(Prototype,
						MDObject, Manager, SourceType, TargetType, TargetObject, StandardProcessing);
						
					SuppliedDataOverridable.BeforeCopyRecordSetFromPrototype(Prototype,
						MDObject, Manager, SourceType, TargetType, TargetObject, StandardProcessing);
						
					If StandardProcessing Then
						CopyRecordSetFromPrototype(Prototype,
							MDObject, Manager, SourceType, TargetType, TargetObject);
					EndIf;
				Else
					
					StandardSubsystemsOverridable.BeforeCopyObjectFromPrototype(Prototype,
						MDObject, Manager, SourceType, TargetType, TargetObject, StandardProcessing);
						
					SuppliedDataOverridable.BeforeCopyObjectFromPrototype(Prototype,
						MDObject, Manager, SourceType, TargetType, TargetObject, StandardProcessing);
						
					If StandardProcessing Then
						ClonePrototype(Prototype,
							MDObject, Manager, SourceType, TargetType, TargetObject);
					EndIf;
				EndIf;
				TargetObject.Write();
			EndDo;
			
			ExchangePlans.DeleteChangeRecords(SuppliedDataCached.GetDataAreaNode(DataArea), 0);
			
		EndDo;
		
		Manager = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordManager();
		Manager.DataArea = DataArea;
		Manager.MessageNo = MessageNo;
		Manager.Delete();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Updating supplied data'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Controls the DataAreasForSuppliedDataUpdate information register and restarts background jobs if they finished abnormally.
//
Procedure SeparatedSuppliedDataUpdateControl() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreasForSuppliedDataUpdate.DataArea,
	|	DataAreasForSuppliedDataUpdate.MessageNo
	|FROM
	|	InformationRegister.DataAreasForSuppliedDataUpdate AS DataAreasForSuppliedDataUpdate";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Key = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordKey(
			New Structure("DataArea, MessageNo", Selection.DataArea, Selection.MessageNo));
		
		Try
			LockDataForEdit(Key);
		Except
			Continue;
		EndTry;
		
		Manager = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordManager();
		Manager.DataArea = Selection.DataArea;
		Manager.MessageNo = Selection.MessageNo;
		
		BeginTransaction();
		Try
			Manager.Read();
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Controlling supplied data update'", Metadata.DefaultLanguage.LanguageCode), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		
		If Not Manager.Selected() Then
			UnlockDataForEdit(Key);
			Continue;
		EndIf;
		
		JobFilter = New Structure;
		JobFilter.Insert("MethodName", "SuppliedData.UpdateSuppliedData");
		JobFilter.Insert("Key", Format(Selection.MessageNo, "NG="));
		ScheduledJob = JobQueue.GetJob(JobFilter, Selection.DataArea);
		If ScheduledJob <> Undefined Then
			UnlockDataForEdit(Key);
			Continue;
		EndIf;
		
		MethodParameters = New Array;
		MethodParameters.Add(Selection.DataArea);
		MethodParameters.Add(Selection.MessageNo);
		
		JobQueue.ScheduleJobExecution("SuppliedData.UpdateSuppliedData",
			MethodParameters, Format(Selection.MessageNo, "NG="),, Selection.DataArea); 
		
		UnlockDataForEdit(Key);
		
	EndDo;
	
EndProcedure

// The subscription handler of the Before write event of the shared data catalog.
// Registers recipients in the source exchange plan.
// Writes unique nodes to the DataAreasForSuppliedDataUpdate information register.
//
Procedure SharedSuppliedDataCatalogsBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	CurrentRef = Source.Ref;
	SourceType = TypeOf(Source.Ref);
	NodesSelection = Undefined;
	
	If Source.IsNew() Then
		
		If SuppliedDataCached.MustAddItemInDataArea(New(SourceType)) Then 
			
			CurrentRef = Source.GetNewObjectRef();
			
			If Not ValueIsFilled(CurrentRef) Then
				
				SourceObjectManager = SuppliedDataCached.GetManagerByTypeEmptyRef(New(SourceType));
				CurrentRef = SourceObjectManager.GetRef();
				Source.SetNewObjectRef(CurrentRef);
				
			EndIf;
			
			Parameters = New Array();
			Parameters.Add(CurrentRef.UUID());
			
			TargetType = GetSeparatedDataTypeBySharedDataType(SourceType);
			
			SeparatedRef = New(TargetType, Parameters);
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	SuppliedDataChanges.DataArea,
			|	SuppliedDataChanges.Ref AS Node
			|FROM
			|	ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
			|		INNER JOIN InformationRegister.DataAreas AS DataAreas
			|			ON SuppliedDataChanges.DataArea = DataAreas.DataArea
			|WHERE
			|	DataAreas.State IN (VALUE(Enum.DataAreaStates.Used))";
			
			NodesSelection = Query.Execute().Select();
			While NodesSelection.Next() Do
				
				RecordManager = InformationRegisters.SuppliedDataRelations.CreateRecordManager();
				RecordManager.DataArea = NodesSelection.DataArea;
				RecordManager.SharedDataItem = CurrentRef;
				RecordManager.SeparatedDataItem = SeparatedRef;
				RecordManager.ManualEdit = False;
				RecordManager.Write();
				
			EndDo;
			NodesSelection.Reset();
		EndIf;
		SuppliedDataOverridable.OnRecordNewSuppliedDataObjectChange(Source);
		
	EndIf;
	
	If NodesSelection = Undefined Then
		NodesSelection = GetUseDataItemNodeArray(CurrentRef);
	EndIf;
	
	If Source.AdditionalProperties.Property("ImportNumber") Then
		ImportNumber = Source.AdditionalProperties.ImportNumber;
	Else
		ImportNumber = Constants.SuppliedDataImportNumber.Get();
	EndIf;
	
	Source.DataExchange.Recipients.Clear();
	While NodesSelection.Next() Do
		Source.DataExchange.Recipients.Add(NodesSelection.Node);
		
		If AddDataAreaToNodeList(NodesSelection.DataArea, ImportNumber) Then
			Manager = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordManager();
			Manager.DataArea = NodesSelection.DataArea;
			Manager.MessageNo = ImportNumber;
			Manager.Write();
		EndIf;
	EndDo;
	
EndProcedure

// The subscription handler of the Before delete event of the separated data catalog.
// Deletes separated item relations in the current data area. 
//
Procedure SeparatedSuppliedDataCatalogsBeforeDelete(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataRelations.SharedDataItem AS Ref
	|FROM
	|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
	|WHERE
	|	SuppliedDataRelations.DataArea = &DataArea
	|	AND SuppliedDataRelations.SeparatedDataItem = &SeparatedDataItem";
	Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
	Query.SetParameter("SeparatedDataItem", Source.Ref);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Not Result.IsEmpty() Then
		Manager = InformationRegisters.SuppliedDataRelations.CreateRecordManager();
		Manager.DataArea = CommonUse.SessionSeparatorValue();
		Manager.SharedDataItem = Result.Unload()[0].Ref;
		Manager.SeparatedDataItem = Source.Ref;
		Manager.Delete();
	EndIf;
	
EndProcedure

// Copies shared data to separated data.
//
Procedure FillFromClassifier(Val Refs, Val IgnoreManualChanges = False) Export
	
	If Refs.Count() = 0 Then
		Return;
	EndIf;
	
	If Refs[0].Metadata().Hierarchical Then
		Refs = SupplementArrayWithRefParents(Refs);
	EndIf;
	
	Key = InformationRegisters.SuppliedDataRelations.CreateRecordKey(
		New Structure("DataArea", CommonUse.SessionSeparatorValue()));
	
	LockDataForEdit(Key);
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.Text =
		"SELECT
		|	SuppliedDataRelations.SharedDataItem,
		|	SuppliedDataRelations.SeparatedDataItem,
		|	SuppliedDataRelations.ManualEdit
		|FROM
		|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
		|WHERE
		|	SuppliedDataRelations.DataArea = &DataArea
		|	AND SuppliedDataRelations.SharedDataItem IN(&Refs)";
		Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
		Query.SetParameter("Refs", Refs);
		
		SetPrivilegedMode(True);
		MapTable = Query.Execute().Unload();
		SetPrivilegedMode(False);
		
		MapTable.Indexes.Add("SharedDataItem");
		For Each Ref In Refs Do
			
			TargetType = GetSeparatedDataTypeBySharedDataType(TypeOf(Ref));
			
			MapRow = MapTable.Find(Ref, "SharedDataItem");
			If MapRow = Undefined Then
				MapRow = MapTable.Add();
				MapRow.SharedDataItem = Ref;
			EndIf;
			If Not ValueIsFilled(MapRow.SeparatedDataItem) Then
				Parameters = New Array;
				Parameters.Add(Ref.UUID());
				MapRow.SeparatedDataItem = New(TargetType, Parameters);
			EndIf;
			
			If MapRow.ManualEdit = True
				And Not IgnoreManualChanges Then
				
				Continue;
			EndIf;
			
			SetPrivilegedMode(True);
			
			RecordManager = InformationRegisters.SuppliedDataRelations.CreateRecordManager();
			RecordManager.DataArea = CommonUse.SessionSeparatorValue();
			RecordManager.SharedDataItem = Ref;
			RecordManager.SeparatedDataItem = MapRow.SeparatedDataItem;
			RecordManager.ManualEdit = MapRow.ManualEdit;
			RecordManager.Write();
			
			ExchangePlans.RecordChanges(SuppliedDataCached.GetDataAreaNode(
				CommonUse.SessionSeparatorValue()), Ref);
				
			SetPrivilegedMode(False);
			
			StandardSubsystemsOverridable.OnFillDataAreaWithSuppliedData(Ref);
			SuppliedDataOverridable.OnFillDataAreaWithSuppliedData(Ref);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Filling from classifier'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	UnlockDataForEdit(Key);
	
	UpdateSuppliedData(CommonUse.SessionSeparatorValue(), 0);
	
EndProcedure

// Retrieves an exchange plan node list by shared reference.
//
// Parameters:
//  DataItemRef - reference what will be used to determine nodes. 
//
// Returns:
//  Query result selection - list of nodes and areas.
//
Function GetUseDataItemNodeArray(DataItemRef) Export
	
	// Defining a list of data arias where the data item is used
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataChanges.Ref AS Node,
	|	SuppliedDataChanges.DataArea
	|FROM
	|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
	|		INNER JOIN ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|			ON SuppliedDataRelations.DataArea = SuppliedDataChanges.DataArea
	|WHERE
	|	SuppliedDataRelations.SharedDataItem = &SharedDataItem
	|	AND SuppliedDataRelations.ManualEdit = FALSE";
	Query.SetParameter("SharedDataItem", DataItemRef);
	Selection = Query.Execute().Select();
	
	Return Selection;
	
EndFunction

// Retrieves an exchange plan node list by shared references.
//
// Parameters:
//  DataItemList - Array - list of items that will be used to determine nodes.
//
// Returns:
// Query result selection - list of nodes and areas.
//
Function GetNodeArrayWhereDataItemListUsed(DataItemList) Export
	
	// Defining a list of data arias where the data item is used
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	SuppliedDataChanges.Ref AS Node,
	|	SuppliedDataChanges.DataArea
	|FROM
	|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
	|		INNER JOIN ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|			ON SuppliedDataRelations.DataArea = SuppliedDataChanges.DataArea
	|WHERE
	|	SuppliedDataRelations.SharedDataItem IN(&DataItemList)
	|	AND SuppliedDataRelations.ManualEdit = FALSE";
	Query.SetParameter("DataItemList", DataItemList);
	Selection = Query.Execute().Select();
	
	Return Selection;
	
EndFunction

// Returns a shared reference that corresponds to the passed separated reference
//
// Parameters:
//  SeparatedRef - CatalogRef - separated reference whose correspondent shared
//                 reference will be retrieved.
//
// Returns:
//  CatalogRef - shared reference that corresponds to the separated reference.
//
Function SharedRefBySeparated(SeparatedRef) Export
	
	If SeparatedRef.IsEmpty() Then
		Return New(GetSharedDataTypeBySeparatedDataType(TypeOf(SeparatedRef)));
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataRelations.SharedDataItem AS Ref
	|FROM
	|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
	|WHERE
	|	SuppliedDataRelations.DataArea = &DataArea
	|	AND SuppliedDataRelations.SeparatedDataItem = &SeparatedDataItem";
	Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
	Query.SetParameter("SeparatedDataItem", SeparatedRef);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Text = NStr("en = 'The shared reference that corresponds to the %SeparatedRef% separated reference is not found.'");
		Text = StrReplace(Text, "%SeparatedRef%", SeparatedRef);
		Raise(Text);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

// Returns a separated reference from the current data area that corresponds to the
// shared reference.
//
// Parameters:
//  SharedRef - CatalogRef - shared reference whose correspondent separated
//              reference will be retrieved.
//
// Returns:
//  CatalogRef - separated reference that corresponds to the shared one.
//
Function SeparatedRefByShared(SharedRef) Export
	
	If SharedRef.IsEmpty() Then
		Return New(GetSeparatedDataTypeBySharedDataType(TypeOf(SharedRef)));
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataRelations.SeparatedDataItem AS Ref
	|FROM
	|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
	|WHERE
	|	SuppliedDataRelations.DataArea = &DataArea
	|	AND SuppliedDataRelations.SharedDataItem = &SharedDataItem";
	Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
	Query.SetParameter("SharedDataItem", SharedRef);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Text = NStr("en = 'The separated reference that corresponds to the %SharedRef% shared reference is not found.'");
		Text = StrReplace(Text, "%SharedRef%", SharedRef);
		Raise(Text);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

Function ConvertSharedValueToSeparated(Val SourceValue) Export
	
	SourceValuesType = TypeOf(SourceValue);
	
	MapTypes = SuppliedDataCached.SeparatedAndSharedDataTypeMap();
	If MapTypes.Get(SourceValuesType) <> Undefined Then
		Return SeparatedRefByShared(SourceValue);
	Else
		Return SourceValue;
	EndIf;
	
EndFunction

Function ReplaceSharedRefsWithSeparatedRefsInTable(Val SourceTable) Export
	
	ResultTable = New ValueTable;
	For Each TableColumn In SourceTable.Columns Do
		ResultTable.Columns.Add(TableColumn.Name);
	EndDo;
	
	For Each SourceRow In SourceTable Do
		ResultRow = ResultTable.Add();
		For Each TableColumn In SourceTable.Columns Do
			ResultRow[TableColumn.Name] = 
				ConvertSharedValueToSeparated(SourceRow[TableColumn.Name]);
		EndDo;
	EndDo;
	
	Return ResultTable;
	
EndFunction

// Checks whether the data aria must be added to the DataAreasForSuppliedDataUpdate
// information register for creating background jobs.
// 
// Parameters:
//  DataArea     - Number – data area to be added to the information register.
//  ImportNumber - Number - number of shared data import.
//
// Returns:
//  Boolean - flag that shows whether the node must be added.
//
Function AddDataAreaToNodeList(DataArea, ImportNumber) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordManager();
	RecordManager.DataArea = DataArea;
	RecordManager.MessageNo = ImportNumber;
	RecordManager.Read();
	
	Return Not RecordManager.Selected();
	
EndFunction

// Retrieves a supplied data kind by common data type.
//
// Parameters:
//  Type - type to determine the supplied data kind.
//
// Returns:
//  Supplied data kind. 
//
Function GetSuppliedDataKindBySharedDataType(Type) Export
	
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	
	FoundRow = MapTable.Find(Type, "SharedDataType");
	If FoundRow = Undefined Then
		MessagePattern = NStr("en = 'The map row for the %1 shared data type is not found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Type);
		Raise(MessageText);
	EndIf;
	
	SuppliedDataKind = FoundRow.SuppliedDataKind;
	
	Return SuppliedDataKind;
	
EndFunction

// Retrieves a separated data type by shared data type.
//
// Parameters:
//  Type - shared data type.
//
// Returns:
//  Type - separated data type.
//
Function GetSeparatedDataTypeBySharedDataType(Type) Export
	
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	
	FoundRow = MapTable.Find(Type, "SharedDataType");
	If FoundRow = Undefined Then
		MessagePattern = NStr("en = 'The map row for the %1 shared data type is not found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Type);
		Raise(MessageText);
	EndIf;
	
	TargetType = FoundRow.SeparatedDataType;
	
	Return TargetType;
	
EndFunction

// Retrieves a shared data type by separated data type.
//
// Parameters:
//  Type - type separated by Data
//
// Returns:
//  Type - type Common Data
//
Function GetSharedDataTypeBySeparatedDataType(Type) Export
	
	MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
	
	FoundRow = MapTable.Find(Type, "SeparatedDataType");
	If FoundRow = Undefined Then
		MessagePattern = NStr("en = 'The map row for the %1 separated data type is not found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Type);
		Raise(MessageText);
	EndIf;
	
	TargetType = FoundRow.SharedDataType;
	
	Return TargetType;
	
EndFunction

// Retrieves the supplied data version.
//
// Parameters:
//  Type - shared data type.
//
// Returns:
//  SuppliedDataVersion - supplied data version.
//
Function GetSuppliedDataVersion(Type) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SuppliedDataVersions.SuppliedDataVersion
	|FROM
	|	InformationRegister.SuppliedDataVersions AS SuppliedDataVersions
	|WHERE
	|	SuppliedDataVersions.SuppliedDataKind = &SuppliedDataKind";
	
	Query.SetParameter("SuppliedDataKind", GetSuppliedDataKindBySharedDataType(Type));
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	EndIf;
	
	Return QueryResult.Unload()[0].SuppliedDataVersion;
	
EndFunction

// Copies items of the shared catalog to the new data area by item code list.
//
// Parameters:
//  CatalogCodeList - Array - array of catalog item codes.
//  SourceType      - Type - type of shared catalog whose items will be copied.
//
Procedure CopyCatalogItems(CatalogCodeList, SourceType) Export
	
	ObjectMetadata = Metadata.FindByType(SourceType);
	
	If ObjectMetadata = Undefined Then
		MessagePattern = NStr("en = 'The metadata object is not found in the %1 catalog.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SourceType);
		Raise(MessageText);
	EndIf;
	
	Query = New Query;
	Text = 
	"SELECT
	|	SourceCatalog.Ref,
	|	SourceCatalog.Code
	|FROM
	|	Catalog." + ObjectMetadata.Name + " AS SourceCatalog";
	
	If ValueIsFilled(CatalogCodeList) Then
		Text = Text + "
		|WHERE
		|	SourceCatalog.Code In(&CatalogCodeList)";
		
		Query.SetParameter("CatalogCodeList", CatalogCodeList);
	EndIf;
	Query.Text = Text;
	QueryResult = Query.Execute().Unload();
	
	CatalogCodeArray = QueryResult.UnloadColumn("Code");
	
	If ValueIsFilled(CatalogCodeList)
		And CatalogCodeList.Count() <> CatalogCodeArray.Count() Then
		If Not ValueIsFilled(CatalogCodeArray) Then
			
			MessagePattern =
				NStr("en = 'Supplied data. No items were found in the %1 catalog during copy by catalog code list.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				MessagePattern, ObjectMetadata.Presentation());
			Raise(MessageText);
			
		Else
			NotFoundCatalogCodeArray = New Array;
			Counter = 0;
			For Each Code In CatalogCodeList Do
				If CatalogCodeArray.Find(Code) = Undefined Then
					If Counter <= 20 Then
						NotFoundCatalogCodeArray.Add(Code);
					EndIf;
					Counter = Counter + 1;
				EndIf;
			EndDo;
			If Counter > 20 Then
				NotFoundCatalogCodeArray.Add("...");
			EndIf;
			
			ResultString = StringFunctionsClientServer.GetStringFromSubstringArray(NotFoundCatalogCodeArray);
			
			MessagePattern =
				NStr("en = 'Supplied data. %3 items with the %2 codes were not found in the %1 catalog during copy by catalog code list.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				MessagePattern, ObjectMetadata.Presentation(), ResultString, Counter);
			Raise(MessageText);
		EndIf;
	EndIf;
	
	CatalogItemArray = QueryResult.UnloadColumn("Ref");
	FillFromClassifier(CatalogItemArray);
	
EndProcedure

// Creates a node for the data area with the passed separator value, if necessary.
//
// Parameters:
//  DataArea - Number - data area separator value for which the node will be created.
//
Procedure CreateDataAreaNode(Val DataArea) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataChanges.Ref AS Ref
	|FROM
	|	ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|WHERE
	|	SuppliedDataChanges.DataArea = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		NodeObject = ExchangePlans.SuppliedDataChanges.CreateNode();
		NodeObject.DataArea = DataArea;
		NodeObject.Code = Format(DataArea, "NZ=0; NG=");
		NodeObject.Write();
	EndIf;
	
EndProcedure

// Registers information register data changes in the exchange plan.
// 
// Parameters: 
// SharedDataItem          - shared data item whose changes will be registered.
// InformationRegisterName - name of the information register that contains changed
//                           data.
// SharedDataItemName      - name of the field that contains the shared data reference.
// KeyString               - record set keys, separated by commas.
//
Procedure RegisterInformationRegisterDataChanges(SharedDataItem, InformationRegisterName, SharedDataItemName, KeyString = "") Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	" + KeyString + "
	|FROM
	|	InformationRegister." + InformationRegisterName + "
	|WHERE
	|	" + SharedDataItemName + " = &" + SharedDataItemName;
	
	Query.SetParameter(SharedDataItemName, SharedDataItem);
	Result = Query.Execute();
	
	RecordSet = InformationRegisters[InformationRegisterName].CreateRecordSet();
	RecordSet.Filter[SharedDataItemName].Set(SharedDataItem);
	
	Selection = Result.Select();
	
	KeyNames = StringFunctionsClientServer.SplitStringIntoSubstringArray(KeyString);
	
	While Selection.Next() Do
		For Each KeyName In KeyNames Do
			RecordSet.Filter[KeyName].Set(Selection[KeyName]);
		EndDo;
		ExchangePlans.RecordChanges(SuppliedDataCached.GetDataAreaNode(
			CommonUse.SessionSeparatorValue()), RecordSet);
	EndDo;
	
EndProcedure

// Updates the manual change flag in the SuppliedDataRelations information register.
//
Procedure UpdateManualItemChangeRecord(Ref, Flag) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.SuppliedDataRelations.CreateRecordManager();
	RecordManager.DataArea = CommonUse.SessionSeparatorValue();
	RecordManager.SharedDataItem = SharedRefBySeparated(Ref);
	RecordManager.SeparatedDataItem = Ref;
	RecordManager.ManualEdit = Flag;
	RecordManager.Write();
	
EndProcedure

// Forcibly updates separated catalog item from shared data.
// 
// Parameters: 
//  Ref - reference to the separated catalog item to be updated.
//
Procedure UpdateCatalogItemFromSharedData(Ref) Export
	
	SetPrivilegedMode(True);
	
	ExchangePlans.RecordChanges(
		SuppliedDataCached.GetDataAreaNode(CommonUse.SessionSeparatorValue()),
		SharedRefBySeparated(Ref));
	
	UpdateSuppliedData(CommonUse.SessionSeparatorValue(), 0);
	
EndProcedure

// Generates in the passed Query object the TT_OldKeys temporary table that contains
// record set data. 
//
// Parameters:
//  Query     - query object in whose temporary table manager the register data table
//              will be generated.  
//  RecordSet - information register record set.
//  KeyString - record set keys, separated by commas.
//
Procedure GenerateRecordSetTempDataTable(Query, RecordSet, KeyString = "") Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text =
	"SELECT
	|	" + KeyString + "
	|INTO TT_OldKeys
	|FROM
	|	InformationRegister." + RecordSet.Metadata().Name;
	
	ConditionText = "";
	For Each FilterItem In RecordSet.Filter Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		
		If Not IsBlankString(ConditionText) Then
			ConditionText = ConditionText + Chars.LF + Chars.Tab + "AND ";
		EndIf;
		
		ConditionText = ConditionText + FilterItem.Name + " = &" + FilterItem.Name;
		Query.SetParameter(FilterItem.Name, FilterItem.Value);
	EndDo;
	
	If Not IsBlankString(ConditionText) Then
		Query.Text = Query.Text + "
		|WHERE
		|	" + ConditionText;
	EndIf;
	
	Query.Execute();
	
EndProcedure

// Registers information register record set in the exchange plan.
//
// Parameters:
//  Query               - query object whose temporary table manager includes the
//                        register data table that was generated before register data 
//                        was changed.
//  RecordSet           - information register record set.
//  SharedDataItemName  - name of the field that contains the shared data item
//                        reference.
//  KeyString           - record set keys, separated by commas.
//  IgnoreManualChanges - flag that shows whether manually changed data must be
//                        ignored.
//
Procedure RegisterRecordSetDataChanges(Query, RecordSet, SharedDataItemName, KeyString = "", IgnoreManualChanges = False) Export
	
	Query.Text = StrReplace(Query.Text, "TT_OldKeys", "TT_NewKeys");
	Query.Execute();
	
	Query.Text = 
	"SELECT DISTINCT
	|	" + KeyString + "
	|INTO Keys
	|FROM
	|	TT_OldKeys
	|
	|UNION
	|
	|SELECT DISTINCT
	|	" + KeyString + "
	|FROM
	|	TT_NewKeys
	|
	|INDEX BY
	|	" + KeyString + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Keys.*,
	|	SuppliedDataChanges.Ref AS Node,
	|	SuppliedDataRelations.DataArea AS DataArea
	|FROM
	|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
	|		INNER Connection Keys AS Keys
	|		to SuppliedDataRelations.SharedDataItem = Keys." + SharedDataItemName + "
	|			AND (&IgnoreManualChanges OR NOT SuppliedDataRelations.ManualEdit)
	|		INNER Connection ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|		to SuppliedDataRelations.DataArea = SuppliedDataChanges.DataArea
	|
	|ORDER BY
	|	" + KeyString;
	
	If RecordSet.AdditionalProperties.Property("ImportNumber") Then
		ImportNumber = RecordSet.AdditionalProperties.ImportNumber;
	Else
		ImportNumber = Constants.SuppliedDataImportNumber.Get();
	EndIf;
	
	Areas = New Map;
	
	Query.SetParameter("IgnoreManualChanges", IgnoreManualChanges);
	
	Result = Query.Execute();
	Selection = Result.Choose();
	
	CurrentKey = New Structure(KeyString);
	AccumulatedNodes = New Array;
	
	SetForRegistration = InformationRegisters[RecordSet.Metadata().Name].CreateRecordSet();
	
	While Selection.Next() Do
		If Areas.Get(Selection.DataArea) = Undefined Then
			Areas.Insert(Selection.DataArea, True);
			
			If AddDataAreaToNodeList(Selection.DataArea, ImportNumber) Then
				Manager = InformationRegisters.DataAreasForSuppliedDataUpdate.CreateRecordManager();
				Manager.DataArea = Selection.DataArea;
				Manager.MessageNo = ImportNumber;
				Manager.Write();
			EndIf;
		EndIf;
		
		DifferentKey = False;
		For Each KeyAndValue In CurrentKey Do
			If Selection[KeyAndValue.Key] <> KeyAndValue.Value Then
				DifferentKey = True;
				Break;
			EndIf;
		EndDo;
		
		If DifferentKey Then
			If AccumulatedNodes.Count() > 0 Then
				For Each KeyAndValue In CurrentKey Do
					SetForRegistration.Filter[KeyAndValue.Key].Set(KeyAndValue.Value);
				EndDo;
				ExchangePlans.RecordChanges(AccumulatedNodes, SetForRegistration);
			EndIf;
			FillPropertyValues(CurrentKey, Selection);
			AccumulatedNodes = New Array;
		EndIf;
		
		AccumulatedNodes.Add(Selection.Node);
		
	EndDo;
	
	If AccumulatedNodes.Count() > 0 Then
		For Each KeyAndValue In CurrentKey Do
			SetForRegistration.Filter[KeyAndValue.Key].Set(KeyAndValue.Value);
		EndDo;
		ExchangePlans.RecordChanges(AccumulatedNodes, SetForRegistration);
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////////////
// ManualEdit flag event handlers.
// This flag is used on separated supplied data forms. 
//
// All procedures that provide ManualEdit flag event processing contain only one
// parameter: 
//  Form           - item ManagedForm. 
// The form must contain the following attributes:
//  Object         - object of separated supplied data.
//  ManualEdit     - Arbitrary - state of the separated object relative to the shared
//                   one. This attribute must not be displayed on the form.
//  ManualEditText - String, 0 - inscription that describes the state of the separated 
//                   object relative to the shared one.
//
// The form must contain the following buttons:
//  UpdateFromClassifier,
//  Change.
//

// Reads the current state of the separated object and updates the form accordingly.
//
Procedure ReadManualEditFlag(Val Form) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	SuppliedDataRelations.ManualEdit
		|FROM
		|	InformationRegister.SuppliedDataRelations AS SuppliedDataRelations
		|WHERE
		|	SuppliedDataRelations.DataArea = &DataArea
		|	AND SuppliedDataRelations.SeparatedDataItem = &SeparatedDataItem";
		Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
		Query.SetParameter("SeparatedDataItem", Form.Object.Ref);
		
		SetPrivilegedMode(True);
		QueryResult = Query.Execute();
		SetPrivilegedMode(False);
		
		If QueryResult.IsEmpty() Then
			
			Form.ManualEdit = Undefined;
			
		Else
			
			Selection = QueryResult.Select();
			Selection.Next();
			Form.ManualEdit = Selection.ManualEdit;
			
		EndIf;
		
		SuppliedDataClientServer.ProcessManualEditFlag(Form);
		
	EndIf;
	
EndProcedure

// Writes the shared object state.
//
Procedure WriteManualChangeFlag(Val Form) Export
	
	If Form.ManualEdit = True Then
		UpdateManualItemChangeRecord(Form.Object.Ref, True);
	EndIf;
	
EndProcedure

// Copies shared object data to the separated object and changes the separated object state.
//
Procedure RestoreItemFromSharedData(Val Form) Export
	
	BeginTransaction();
	Try
		Refs = New Array;
		Refs.Add(SharedRefBySeparated(Form.Object.Ref));
		FillFromClassifier(Refs, True);
		
		UpdateManualItemChangeRecord(Form.Object.Ref, False);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Restoring from shared data.'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Form.Read();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function SupplementArrayWithRefParents(Val Refs)
	
	TableName = Refs[0].Metadata().FullName();
	
	RefArray = New Array;
	For Each Ref In Refs Do
		RefArray.Add(Ref);
	EndDo;
	
	CurrentRefs = Refs;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Table.Parent AS Ref
	|FROM
	|	" + TableName + " AS Table
	|WHERE
	|	Table.Ref In (&Refs) 
	|	And Table.Parent <> VALUE(" + TableName + ".EmptyRef)";
	
	While True Do
		Query.SetParameter("Refs", CurrentRefs);
		Result = Query.Execute();
		If Result.IsEmpty() Then
			Break;
		EndIf;
		
		CurrentRefs = New Array;
		Selection = Result.Select();
		While Selection.Next() Do
			CurrentRefs.Add(Selection.Ref);
			RefArray.Add(Selection.Ref);
		EndDo;
	EndDo;
	
	Return RefArray;
	
EndFunction

Procedure ClonePrototype(Prototype, SourceMetadata, Manager, SourceType, TargetType, TargetObject)
	
	ResultRef = SeparatedRefByShared(Prototype.Ref);
	
	TargetMetadata = ResultRef.Metadata();
	
	HierarchicalCatalog = TargetMetadata.Hierarchical And SourceMetadata.Hierarchical;
	
	Result = ResultRef.GetObject();
	If Result = Undefined Then
		If HierarchicalCatalog And Prototype.IsFolder Then
			Result = Manager.CreateFolder();
		Else
			Result = Manager.CreateItem();
		EndIf;
		Result.SetNewObjectRef(ResultRef);
	EndIf;
	Result.DataExchange.Load = True;
	
	If TargetMetadata.DescriptionLength > 0 
		And SourceMetadata.DescriptionLength > 0 Then
		Result.Description = Prototype.Description;
	EndIf;
	
	If TargetMetadata.CodeLength > 0
		And SourceMetadata.CodeLength > 0 Then
		Result.Code = Prototype.Code;
	EndIf;
	
	If HierarchicalCatalog Then
		Result.Parent = ConvertSharedValueToSeparated(Prototype.Parent);
	EndIf;
	
	FolderHierarchy = TargetMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems;
	
	For Each AttributeMD In TargetMetadata.Attributes Do
		If Not FolderHierarchy
			Or AttributeMD.Use = Metadata.ObjectProperties.AttributeUse.ForFolderAndItem
			Or AttributeMD.Use = Metadata.ObjectProperties.AttributeUse.ForFolder
			And Prototype.IsFolder
			Or AttributeMD.Use = Metadata.ObjectProperties.AttributeUse.ForItem
			And Not Prototype.IsFolder Then
			
			If SourceMetadata.Attributes.Find(AttributeMD.Name) <> Undefined Then
				Result[AttributeMD.Name] = ConvertSharedValueToSeparated(Prototype[AttributeMD.Name]);
			Else
				Result[AttributeMD.Name] = Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	For Each TabularSectionMD In TargetMetadata.TabularSections Do
		If Not FolderHierarchy
			Or TabularSectionMD.Use = Metadata.ObjectProperties.AttributeUse.ForFolderAndItem
			Or TabularSectionMD.Use = Metadata.ObjectProperties.AttributeUse.ForFolder
			And Prototype.IsFolder
			Or TabularSectionMD.Use = Metadata.ObjectProperties.AttributeUse.ForItem
			And Not Prototype.IsFolder Then
			
			If SourceMetadata.TabularSections.Find(TabularSectionMD.Name) <> Undefined Then
				Result[TabularSectionMD.Name].Load(
					ReplaceSharedRefsWithSeparatedRefsInTable(Prototype[TabularSectionMD.Name].Unload()));
			Else
				Result[TabularSectionMD.Name].Clear();
			EndIf;
		EndIf;
	EndDo;
	
	TargetObject = Result;
	
EndProcedure

Procedure CopyRecordSetFromPrototype(Prototype, ObjectMetadata, Manager, SourceType, TargetType, TargetObject)
	
	Result = Manager.CreateRecordSet();
	
	For Each FilterItem In Prototype.Filter Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		
		Result.Filter[FilterItem.Name].Set(ConvertSharedValueToSeparated(FilterItem.Value));
	EndDo;
	
	Result.DataExchange.Load = True;
	
	Result.Load(ReplaceSharedRefsWithSeparatedRefsInTable(Prototype.Unload()));
	
	TargetObject = Result;
	
EndProcedure

Procedure ImportData(Results, ImportNumber)
	
	BinaryData = Results.Data;
	SuppliedDataVersionMap = GetSuppliedDataVersionMap(Results.SuppliedData);
	
	ArchiveName = GetTempFileName("zip");
	BinaryData.Write(ArchiveName);
	
	PathToFile = GetTempFileName();
	CreateDirectory(PathToFile);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	Dearchiver.Extract(Dearchiver.Items[0], PathToFile);
	Dearchiver.Close();
	
	Files = FindFiles(PathToFile, "*");
	If Files.Count() > 0 Then
		XMLReader = New FastInfosetReader;
		Try
			XMLReader.OpenFile(Files[0].FullName);
			
			OldNodeName = "";
			While XMLReader.Read() Do
				NodeName = XMLReader.LocalName;
				
				If Find(NodeName, "CatalogObject.") = 1 Then
					ImportCatalogItem(XMLReader, ImportNumber);
				ElsIf Find(NodeName, "InformationRegisterRecordSet.") = 1 Then
					ImportInformationRegisterRecordSet(XMLReader, ImportNumber);
				EndIf;
				
				If Find(NodeName, "CatalogObject.") = 1 Or Find(NodeName, "InformationRegisterRecordSet.") = 1 Then
					If NodeName <> OldNodeName Then
						WriteSuppliedDataVersion(OldNodeName, SuppliedDataVersionMap);
						OldNodeName = NodeName;
					EndIf;
				EndIf;
			EndDo;
			
			WriteSuppliedDataVersion(OldNodeName, SuppliedDataVersionMap);
			
			XMLReader.Close();
		Except
			WriteLogEvent(NStr("en = 'Importing supplied data'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			ErrorText = BriefErrorDescription(ErrorInfo());
			Try
				XMLReader.Close();
				DeleteFiles(ArchiveName);
				DeleteFiles(PathToFile);
			Except
			EndTry;
			Raise(ErrorText);
		EndTry;
	EndIf;
	
	Try
		DeleteFiles(ArchiveName);
		DeleteFiles(PathToFile);
	Except
	EndTry;
	
EndProcedure

Procedure ImportCatalogItem(DataForReading, ImportNumber)
	
	NodeName = DataForReading.LocalName;
	
	CatalogName = SuppliedDataCached.GetCatalogNameByNodeName(NodeName);
	
	AttributeValues = New Structure;
	AttributeTypes = SuppliedDataCached.GetCatalogAttributeTypesByNodeName(NodeName);
	For Each ListRow In AttributeTypes Do
		If TypeOf(ListRow.Value.Type) = Type("Map") Then
			NestedAttributeValueTable = New ValueTable;
			For Each NestedListRow In ListRow.Value.Type Do 
				NestedAttributeValueTable.Columns.Add(NestedListRow.Key);
			EndDo;
			AttributeValues.Insert(ListRow.Key, NestedAttributeValueTable);
		Else
			AttributeValues.Insert(ListRow.Key);
		EndIf;
	EndDo;
	
	DataForReading.Read();
	While DataForReading.LocalName <> NodeName Do
		If DataForReading.NodeType = XMLNodeType.StartElement Then
			ValueType = DataForReading.AttributeValue("xsi:type");
			LocalName = DataForReading.LocalName;
			
			DataForReading.Read();
			If AttributeValues.Property(LocalName) Then
				If TypeOf(AttributeValues[LocalName]) <> Type("ValueTable") Then
					If DataForReading.HasValue Then
						If AttributeValues.Property(LocalName) Then
							If ValueType = Undefined Then
								Value = XMLValue(AttributeTypes[LocalName].Type, DataForReading.Value);
							Else
								Value = XMLValue(FromXMLType(ValueType), DataForReading.Value);
							EndIf;
							AttributeValues[LocalName] = Value;
						EndIf;
					EndIf;
				Else
					TableName = LocalName;
					While DataForReading.LocalName <> TableName Do
						If DataForReading.NodeType = XMLNodeType.StartElement 
							And DataForReading.LocalName = "Row" Then
							NewRow = AttributeValues[TableName].Add();
							DataForReading.Read();
						EndIf;
						While DataForReading.LocalName <> "Row" Do
							ValueType = DataForReading.AttributeValue("xsi:type");							
							LocalName = DataForReading.LocalName;
							
							DataForReading.Read();
							If DataForReading.NodeType = XMLNodeType.EndElement Then
								DataForReading.Read();
								Continue;								
							EndIf;
							If ValueType = Undefined Then
								Value = XMLValue(AttributeTypes[TableName].Type[LocalName], DataForReading.Value);
							Else
								Value = XMLValue(FromXMLType(ValueType), DataForReading.Value);
							EndIf;
							NewRow[LocalName] = Value;	
							DataForReading.Read();
							DataForReading.Read();
						EndDo;		
						DataForReading.Read();
					EndDo;
				EndIf;
			EndIf;
		EndIf;
		DataForReading.Read();
	EndDo;
	
	CatalogObject = AttributeValues["Ref"].GetObject();
	If CatalogObject = Undefined Then
		If AttributeValues.Property("IsFolder") And AttributeValues.IsFolder Then
			CatalogObject = Catalogs[CatalogName].CreateFolder();
		Else
			CatalogObject = Catalogs[CatalogName].CreateItem();
		EndIf;
		CatalogObject.SetNewObjectRef(AttributeValues["Ref"]);
	EndIf;
	For Each AttributeValue In AttributeValues Do
		If AttributeValue.Key = "IsFolder"
			Or AttributeValue.Key = "Predefined"
			Or AttributeValue.Key = "Ref" Then
			Continue;
		EndIf;	
		If TypeOf(AttributeValue.Value) = Type("ValueTable") Then
			If AttributeTypes[AttributeValue.Key].AttributeUse = Metadata.ObjectProperties.AttributeUse.ForFolderAndItem
				Or AttributeValues.IsFolder
				And AttributeTypes[AttributeValue.Key].AttributeUse = Metadata.ObjectProperties.AttributeUse.ForFolder
				Or Not AttributeValues.IsFolder
				And AttributeTypes[AttributeValue.Key].AttributeUse = Metadata.ObjectProperties.AttributeUse.ForItem Then
				CatalogObject[AttributeValue.Key].Load(AttributeValue.Value);
			EndIf;
		Else
			If Not AttributeValues.Property("IsFolder") Then
				CatalogObject[AttributeValue.Key] = AttributeValue.Value;
			Else
				If AttributeTypes[AttributeValue.Key].AttributeUse = Metadata.ObjectProperties.AttributeUse.ForFolderAndItem
					Or AttributeValues.IsFolder
					And AttributeTypes[AttributeValue.Key].AttributeUse = Metadata.ObjectProperties.AttributeUse.ForFolder
					Or Not AttributeValues.IsFolder
					And AttributeTypes[AttributeValue.Key].AttributeUse = Metadata.ObjectProperties.AttributeUse.ForItem Then
					CatalogObject[AttributeValue.Key] = AttributeValue.Value;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	CatalogObject.AdditionalProperties.Insert("ImportNumber", ImportNumber);
	CatalogObject.Write();
	
EndProcedure

Procedure ImportInformationRegisterRecordSet(DataForReading, ImportNumber)
	
	SetNodeName = DataForReading.LocalName;
	
	RegisterName = SuppliedDataCached.GetInformationRegisterNameByNodeName(SetNodeName);
	AttributeValues = New Structure;
	AttributeTypes = SuppliedDataCached.GetInformationRegisterAttributeTypesByNodeName(SetNodeName);
	For Each ListRow In AttributeTypes Do
		AttributeValues.Insert(ListRow.Key);
		AttributeTypes.Insert(ListRow.Key, ListRow.Value);
	EndDo;
	
	DataForReading.Read();
	NewRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	While DataForReading.LocalName <> SetNodeName Do
		If DataForReading.LocalName = "Filter" Then
			NodeName = DataForReading.LocalName;
			DataForReading.Read();
			While DataForReading.LocalName <> NodeName Do
				If DataForReading.NodeType = XMLNodeType.StartElement Then
					ValueType  = DataForReading.AttributeValue("xsi:type");
					LocalName = DataForReading.LocalName;
					DataForReading.Read();
					If ValueType = Undefined Then
						Value = XMLValue(AttributeTypes[LocalName], DataForReading.Value);
					Else
						Value = XMLValue(FromXMLType(ValueType), DataForReading.Value);
					EndIf;
					If NewRecordSet.Filter.Find(LocalName) <> Undefined Then
						NewRecordSet.Filter[LocalName].Set(Value);
					EndIf;
				EndIf;
				DataForReading.Read();
			EndDo;
			DataForReading.Read();
		EndIf;
		If Find(DataForReading.LocalName, "InformationRegisterRecord.") = 1 Then
			NodeName = DataForReading.LocalName;
			DataForReading.Read();
			While DataForReading.LocalName <> NodeName Do
				If DataForReading.NodeType = XMLNodeType.StartElement Then
					ValueType  = DataForReading.AttributeValue("xsi:type");
					LocalName = DataForReading.LocalName;
					DataForReading.Read();
					If ValueType = Undefined Then
						DataType = AttributeTypes[LocalName];
						Value = XMLValue(DataType, DataForReading.Value);
					Else
						Value = XMLValue(FromXMLType(ValueType), DataForReading.Value);
					EndIf;
					If AttributeValues.Property(LocalName) Then
						AttributeValues[LocalName] = Value;
					EndIf;
				EndIf;
				DataForReading.Read();
			EndDo;
			DataForReading.Read();
			
			NewRecord = NewRecordSet.Add();
			FillPropertyValues(NewRecord, AttributeValues);
		Else
			DataForReading.Read();
		EndIf;
	EndDo;
	
	NewRecordSet.AdditionalProperties.Insert("ImportNumber", ImportNumber);
	NewRecordSet.Write();
	
EndProcedure

Function GetSuppliedDataVersionMap(TableSuppliedData)
	
	SuppliedDataVersionMap = New Map;
	
	For Each SuppliedData In TableSuppliedData Do
		SuppliedDataVersionMap.Insert(SuppliedData.Type, SuppliedData.Version);
	EndDo;
	
	Return SuppliedDataVersionMap;
	
EndFunction

Procedure WriteSuppliedDataVersion(OldNodeName, SuppliedDataVersionMap)
	
	If OldNodeName = "" Then
		Return;
	EndIf;
	
	SplittedNodeName = StringFunctionsClientServer.SplitStringIntoSubstringArray(OldNodeName, ".");
	
	If SplittedNodeName[0] = "CatalogObject" Then
		SuppliedDataKind = "Catalog_" + SplittedNodeName[1];
	ElsIf SplittedNodeName[0] = "InformationRegisterRecordSet" Then
		SuppliedDataKind = "InformationRegister_" + SplittedNodeName[1];
	EndIf;
	
	If SuppliedDataKind = Undefined Then
		MessagePattern = NStr("en = 'The kind of the %1 object is not defined during supplied data import.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, SplittedNodeName[1]);
		Raise(MessageText);
	EndIf;
	
	RecordManager                          = InformationRegisters.SuppliedDataVersions.CreateRecordManager();
	RecordManager.SuppliedDataKind    = Enums.SuppliedDataTypes[SuppliedDataKind];
	RecordManager.SuppliedDataVersion = SuppliedDataVersionMap.Get(SuppliedDataKind);
	RecordManager.Write();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see InfoBaseUpdate.NewUpdateHandlerTable function for details.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.3.6";
	Handler.Procedure = "SuppliedData.SuppliedDataInitializationSharedData";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.3.6";
	Handler.Procedure = "SuppliedData.SuppliedDataInitialization";
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.10";
	Handler.Procedure = "SuppliedData.FillDescriptionsByCodes";
	Handler.SharedData = True;
	
EndProcedure	

// Initializes supplied data.
//
Procedure SuppliedDataInitialization() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		DataArea = CommonUse.SessionSeparatorValue();
		
		CreateDataAreaNode(DataArea);
		
		MapTable = CommonUse.GetSeparatedAndSharedDataMapTable();
		For Each String In MapTable Do
			
			If String.CopyToAllDataAreas = True Then
				ItemList = New Array;
				CopyCatalogItems(ItemList, String.SharedDataType);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Initializes supplied data.
//
Procedure SuppliedDataInitializationSharedData() Export
	
	ThisNode = ExchangePlans.SuppliedDataChanges.ThisNode().GetObject();
	ThisNode.DataArea = -1;
	ThisNode.Code = "-1";
	ThisNode.Write();
	
EndProcedure

// The SuppliedDataChanges exchange plan update handler.
// Copies the Code standard attribute value to Description if Description is not filled.
// 
Procedure FillDescriptionsByCodes() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SuppliedDataChanges.Ref,
		|	SuppliedDataChanges.Code
		|FROM
		|	ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
		|WHERE
		|	SuppliedDataChanges.Description = """"";
	Selection = Query.Execute().Select();

	While Selection.Next() Do
		ExchangePlanObject = Selection.Ref.GetObject();
		ExchangePlanObject.Description = ExchangePlanObject.Code;
		ExchangePlanObject.Write();
	EndDo;

EndProcedure	

// Internal use only.
Procedure InternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	ServerEvents.Add(
		"StandardSubsystems.ServiceMode.SuppliedData\OnGetSuppliedDataHandlers");
	
EndProcedure

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
EndProcedure
