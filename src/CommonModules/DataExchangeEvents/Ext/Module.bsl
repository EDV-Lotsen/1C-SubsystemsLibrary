////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// BeforeWrite event handler for documents, it is used in the object registration mechanism.
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan where objects are registered. 
//  Source           - DocumentObject - event source.
//  Cancel           - Boolean - cancellation flag.
//  WriteMode        - see DocumentWriteMode in the Syntax Assistant.
//  PostingMode      - see DocumentPostingMode in the Syntax Assistant.
// 
Procedure ObjectChangeRecordMechanismBeforeWriteDocument(ExchangePlanName, Source, Cancel, WriteMode, PostingMode) Export
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel, WriteMode);
	
EndProcedure

// BeforeWrite event handler for all objects of reference types (except documents), 
// it is used in the object registration mechanism.
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan where objects are registered. 
//  Source           - event source (except the DocumentObject type). 
//  Cancel           - Boolean - cancellation flag.
// 
Procedure ObjectChangeRecordMechanismBeforeWrite(ExchangePlanName, Source, Cancel) Export
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel);
	
EndProcedure

// BeforeWrite event handler for registers, it is used in the object registration mechanism.
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan where objects are registered.
//  Source           - RegisterRecordSet - event source.
//  Cancel           - Boolean - cancellation flag.
//  Replacing        - Boolean - flag that shows whether the existing record set is replaced.
// 
Procedure ObjectChangeRecordMechanismBeforeWriteRegister(ExchangePlanName, Source, Cancel, Replacing) Export
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel,, Replacing, True);
	
EndProcedure

// BeforeWrite event handler for constants. It is used in the object registration mechanism.
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan where objects are registered. 
//  Source           - ConstantValueManager - event source. 
//  Cancel           - Boolean - cancellation flag.
// 
Procedure ObjectChangeRecordMechanismBeforeWriteConstant(ExchangePlanName, Source, Cancel) Export
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel,,,,, True);
	
EndProcedure

// BeforeDelete event handler for all objects of reference types, it is used in the object registration mechanism.
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan where objects are registered.
//  Source           - event source.
//  Cancel           - Boolean - cancellation flag.
// 
Procedure ObjectChangeRecordMechanismBeforeDelete(ExchangePlanName, Source, Cancel) Export
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel,,,, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to be used in the registration rule event handlers.

// Supplements the object recipient node list with the passed values.
//
// Parameters:
//  Object - object for which the registration rule must be executed.
//  Nodes  - Array - exchange plan nodes to be added to the object recipient node list.
//
Procedure SupplementRecipients(Object, Nodes) Export
	
	For Each Item In Nodes Do
		
		Try
			Object.DataExchange.Recipients.Add(Item);
		Except
			ExchangePlanName = Item.Metadata().Name;
			MetadataObject   = Object.Metadata();
			MessageString    = NStr("en = 'The [FullName] object registration is not specified for the [ExchangePlanName] exchange plan content.'");
			MessageString    = StrReplace(MessageString, "[ExchangePlanName]", ExchangePlanName);
			MessageString    = StrReplace(MessageString, "[FullName]",      MetadataObject.FullName());
			Raise MessageString;
		EndTry;
		
	EndDo;
	
EndProcedure

// Deletes the passed values from the object recipient node list.
//
// Parameters:
//  Object - object for which the registration rule must be executed. 
//  Nodes  - Array - exchange plan nodes to be deleted from the object recipient node list.
// 
Procedure ReduceRecipients(Object, Nodes) Export
	
	Recipients = ReduceArray(Object.DataExchange.Recipients, Nodes);
	
	// Clearing the recipient list and filling it over again
	Object.DataExchange.Recipients.Clear();
	
	// Adding nodes for the object registration
	SupplementRecipients(Object, Recipients);
	
EndProcedure

// Generates an array of recipient nodes for the object of the specified exchange plan and registers an object in these nodes.
//
// Parameters:
//  Object            - object to be registered in nodes. 
//  ExchangePlanName  - String - exchange plan name as it is set in Designer mode.
//  Sender (Optional) - ExchangePlanRef - exchange plan node that sends the exchange message.
//                      Objects are not registered in this node if it is set.
// 
Procedure ExecuteChangeRecordRulesForObject(Object, ExchangePlanName, From = Undefined) Export
	
	Recipients = GetRecipients(Object, ExchangePlanName);
	
	CommonUseClientServer.DeleteValueFromArray(Recipients, From);
	
	If Recipients.Count() > 0 Then
		
		ExchangePlans.RecordChanges(Recipients, Object);
		
	EndIf;
	
EndProcedure

// Subtracts one array of elements from another. Returns the result of subtraction.
//
// Parameters:
// Array             - Array - source array.
// SubstractionArray - Array - contains data that must be deleted from the source array.
//
Function ReduceArray(Array, SubstractionArray) Export
	
	Return CommonUseClientServer.ReduceArray(Array, SubstractionArray);
	
EndFunction

// Returns the list of all exchange plan nodes except the predefined node.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as it is set in Designer used to obtain the node list.
//
//  Returns:
//   Array - list of exchange plan nodes.
//
Function AllExchangePlanNodes(ExchangePlanName) Export
	
	#If ExternalConnection Or ThickClientOrdinaryApplication Then
		
		Return DataExchangeServerCall.AllExchangePlanNodes(ExchangePlanName);
		
	#Else
		
		SetPrivilegedMode(True);
		Return DataExchangeCached.GetExchangePlanNodeArray(ExchangePlanName);
		
	#EndIf
	
EndFunction

// Retrieves an array of recipient nodes for the object from the specified exchange plan.
// 
// Parameters:
//  Object           - object whose recipient node list will be returned.
//  ExchangePlanName - String - exchange plan name as it is set in Designer mode.
// 
// Returns:
//  NodeArrayResult - Array - array of target nodes for the object.
//
Function GetRecipients(Object, ExchangePlanName) Export
	
	NodeArrayResult = New Array;
	
	MetadataObject = Object.Metadata();
	
	IsRegister = CommonUse.IsRegister(MetadataObject);
	
	ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName, MetadataObject, False, IsRegister);
	
	Return NodeArrayResult;
	
EndFunction

// Determines whether automatic registration is allowed.
//
// Parameters:
// MetadataObject (mandatory)   - metadata object whose AutoChangeRecord flag will be checked.
// ExchangePlanName (mandatory) - String - name as it is set in Designer mode. 
//                                The name of the exchange plan that contains the metadata object.
//
// Returns:
//  True if metadata object auto registration is allowed in the exchange plan.
//  False if metadata object auto registration is denied in
//  the exchange plan or the exchange plan does not include the metadata object.
//
Function AutoChangeRecordAllowed(MetadataObject, ExchangePlanName) Export
	
	Return DataExchangeCached.AutoChangeRecordAllowed(ExchangePlanName, MetadataObject.FullName());
	
EndFunction

// Checks whether item import is prohibited.
// This function requires a setup: before executing it, call the DataForEditProhibitionCheck procedure 
// from the EditProhibitionDatesOverridable module.
//
// Parameters:
//  Data                 - CatalogObject.<Name>,
//                         DocumentObject.<Name>,
//                         ChartOfCharacteristicTypesObject.<Name>,
//                         ChartOfAccountsObject.<Name>,
//                         ChartOfCalculationTypesObject.<Name>,
//                         BusinessProcessObject.<Name>,
//                         TaskObject.<Name>,
//                         ExchangePlanObject.<Name>,
//                         ObjectDeletion - data object,
//                         InformationRegisterRecordSet.<Name>,
//                         AccumulationRegisterRecordSet.<Name>,
//                         AccountingRegisterRecordSet.<Name>,
//                         CalculationRegisterRecordSet.<Name> - record set.
//
//  ExchangePlanNode     - ExchangePlansRef.<Exchange plan name> - node that is checked.
//
// Returns:
//  Boolean. If True, data import is prohibited.
//
Function ImportProhibited(Data, Val ExchangePlanNode) Export
	
	If Data.AdditionalProperties.Property("DataImportProhibitionFound") Then
		Return True;
	EndIf;
	
	ItemReceive = DataItemReceive.Auto;
	CheckImportProhibitedByDate(Data, ItemReceive, ExchangePlanNode);
	
	Return ItemReceive = DataItemReceive.Ignore;
	
EndFunction

#EndRegion

#Region InternalInterface

// Determines a dispatch type for the data item to be exported.
// The procedure is called from the OnReceiveDataFromMaster() and OnReceiveDataFromSlave() exchange node handlers.
//
// Parameters:
//  DataItem, ItemSend - see details of the OnSendDataToMaster()
//                       and OnSendDataToSlave() methods in the Syntax Assistant.
//
Procedure DataOnSendToRecipient(DataItem,
										ItemSend,
										Val InitialImageCreating = False,
										Val Recipient = Undefined,
										Val Analysis = True
	) Export
	
	If Recipient = Undefined Then
		
	ElsIf ItemSend = DataItemSend.Delete
		Or ItemSend = DataItemSend.Ignore Then
		
		// No overriding for standard processing
		
	ElsIf DataExchangeCached.IsSLDataExchangeNode(Recipient.Ref) Then
		
		OnSendData(DataItem, ItemSend, Recipient.Ref, InitialImageCreating, Analysis);
		
	EndIf;
	
	If Analysis Then
		Return;
	EndIf;
	
	// Recording exported predefined data (only for DIB)
	If Not InitialImageCreating
		And ItemSend <> DataItemSend.Ignore
		And DataExchangeCached.IsDistributedInfobaseNode(Recipient.Ref)
		And TypeOf(DataItem) <> Type("ObjectDeletion")
		Then
		
		BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(DataItem.Metadata());
		
		If BaseTypeName  = CommonUse.TypeNameCatalogs()
			Or BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes()
			Or BaseTypeName = CommonUse.TypeNameChartsOfAccounts()
			Or BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes() Then
			
			If DataItem.Predefined Then
				
				DataExchangeServerCall.SupplementPriorityExchangeData(DataItem.Ref);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler of the event that has the same name, which occurs during data exchange in a distributed infobase.
//
// Parameters:
// See the OnReceiveDataFromMaster() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromMasterInBeginning(DataItem, ItemReceive, SendBack, From) Export
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"ApplicationRunParameterImport") Then
		
		// If application parameters are imported, all data must be ignored
		ItemReceive = DataItemReceive.Ignore;
		
	EndIf;
	
EndProcedure

// Detects import prohibition and data modification conflicts.
// The procedure is called from the OnReceiveDataFromMaster exchange plan handler.
//
// Parameters:
// See the OnReceiveDataFromMaster() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromMasterInEnd(DataItem, ItemReceive, Val From) Export
	
	// Checking whether the data import is prohibited (by prohibition date)
	CheckImportProhibitedByDate(DataItem, ItemReceive, From);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Checking for data modification conflict
	CheckDataModificationConflict(DataItem, ItemReceive, From, True);
	
EndProcedure

// Detects import prohibition and data modification conflicts.
// The procedure is called from the OnReceiveDataFromSlave exchange plan handler.
//
// Parameters:
// See the OnReceiveDataFromSlave() event handler description in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlaveInEnd(DataItem, ItemReceive, Val From) Export
	
	// Checking whether the data import is prohibited (by prohibition date)
	CheckImportProhibitedByDate(DataItem, ItemReceive, From);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Checking for data modification conflict
	CheckDataModificationConflict(DataItem, ItemReceive, From, False);
	
EndProcedure

// Registers a change for a single data item to send it to the target node address.
// A data item can be registered if it matches object registration rule filters 
// that are set in the target node properties.
// Data items that are imported when needed are registered unconditionally.
// ObjectDeletion is registered unconditionally.
//
// Parameters:
//     Recipient             - ExchangePlanRef - exchange plan where data changes are registered.
//     Data                  - <Data>, ObjectDeletion - object that represents data stored in the infobase, such
//                             as a document, a catalog item, an account from the chart of accounts,
//                             a constant record manager, a register record set, and so on.
//     CheckExportPermission - Boolean - optional flag. If it is set to False, an additional check for the compliance 
//                             to the common node settings is not performed during the registration.
//
Procedure RecordDataChanges(Val Recipient, Val Data, Val CheckExportPermission=True) Export
	
	If TypeOf(Data) = Type("ObjectDeletion") Then
		// Registering object deletion unconditionally
		ExchangePlans.RecordChanges(Recipient, Data);
		
	Else
		ObjectExportMode = DataExchangeCached.ObjectExportMode(Data.Metadata().FullName(), Recipient);
		
		If ObjectExportMode = Enums.ExchangeObjectExportModes.ExportIfNecessary Then
			
			If CommonUse.ReferenceTypeValue(Data) Then
				IsNewObject = Data.IsEmpty();
			Else
				IsNewObject = Data.IsNew(); 
			EndIf;
			
			If IsNewObject Then
				Raise NStr("en = 'Objects that are not written and are exported by reference cannot be registered.'");
			EndIf;
			
			BeginTransaction();
			Try
				// Registering data for the target node
				ExchangePlans.RecordChanges(Recipient, Data);
				
				// If an object is exported by its reference, adding information about this object to the allowed objects filter.
				// This ensures that the data items pass the filter, so that they can be exported to the exchange message.
				StandardProcessing = True;
				If CommonUse.SubsystemExists("DataExchangeXDTO") Then
					
					DataExchangeXDTOCachedModule = CommonUse.CommonModule("DataExchangeXDTOCached");
					DataExchangeXDTOServerModule = CommonUse.CommonModule("DataExchangeXDTOServer");
					
					If DataExchangeXDTOCachedModule.IsXDTOExchangePlan(Recipient) Then
						DataExchangeXDTOServerModule.AddObjectToAllowedObjectFilter(Data.Ref, Recipient);
						StandardProcessing = False;
					EndIf;
				EndIf;
				
				If StandardProcessing Then
					InformationRegisters.InfobaseObjectMappings.AddObjectToAllowedObjectFilter(Data.Ref, Recipient);
				EndIf;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		ElsIf Not CheckExportPermission Then
			// Registering data unconditionally
			ExchangePlans.RecordChanges(Recipient, Data);
			
		ElsIf ObjectExportAllowed(Recipient, Data) Then
			// Registering the object if it matches common restrictions
			ExchangePlans.RecordChanges(Recipient, Data);
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// For internal use only.
//
Procedure RecordDataMigrationRestrictionFilterChanges(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("Import") Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // writing the node when receiving the exchange message (universal data exchange)
	ElsIf Not DataExchangeCached.IsSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf DataExchangeCached.IsPredefinedExchangePlanNode(Source.Ref) Then
		Return;
	EndIf;
	
	SourceRef = CommonUse.ObjectAttributeValues(Source.Ref, "SentNo, ReceivedNo");
	
	If SourceRef.SentNo <> Source.SentNo Then
		Return; // writing the node when sending the exchange message
	ElsIf SourceRef.ReceivedNo <> Source.ReceivedNo Then
		Return; // writing the node when receiving the exchange message
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Source.Ref);
	
	// Getting reference type attributes that are presumably used as registration rule filter filters.
	ReferenceTypeAttributeTable = GetReferenceTypeObjectAttributes(Source, ExchangePlanName);
	
	// Checking whether the node was modified by attributes
	ObjectModified = ObjectModifiedByAttributes(Source, ReferenceTypeAttributeTable);
	
	If ObjectModified Then
		
		Source.AdditionalProperties.Insert("NodeAttributeTable", ReferenceTypeAttributeTable);
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure CheckDataMigrationRestrictionFilterChangesOnWrite(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("Import") Then
		Return;
	EndIf;
	
	RegisteredForExportObjects = Undefined;
	If Source.AdditionalProperties.Property("RegisteredForExportObjects", RegisteredForExportObjects) Then
		
		DataExchangeServerCall.UpdateObjectChangeRecordMechanismCache();
		
		For Each Object In RegisteredForExportObjects Do
			
			If Not ObjectExportAllowed(Source.Ref, Object) Then
				
				ExchangePlans.DeleteChangeRecords(Source.Ref, Object);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ReferenceTypeAttributeTable = Undefined;
	If Source.AdditionalProperties.Property("NodeAttributeTable", ReferenceTypeAttributeTable) Then
		
		// Registering selected objects of reference types on the current node using no object registration rules
		RecordReferenceTypeObjectChangesByNodeProperties(Source, ReferenceTypeAttributeTable);
		
		// Updating cached values of the mechanism
		DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure EnableUseExchangePlan(Source, Cancel) Export
	
	If Source.IsNew() And DataExchangeCached.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		
		// The open session cache became obsolete for the object registration mechanism
		DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure DisableUseExchangePlan(Source, Cancel) Export
	
	If DataExchangeCached.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		
		// The open session cache became obsolete for the object registration mechanism
		DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure CanChangeDataExchangeSettings(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("Import") Then
		Return;
	EndIf;
	
	If  Not Source.AdditionalProperties.Property("GettingExchangeMessage")
		And Not Source.IsNew()
		And Not DataExchangeCached.IsPredefinedExchangePlanNode(Source.Ref)
		And DataExchangeCached.IsSLDataExchangeNode(Source.Ref)
		And DataDifferent(Source, Source.Ref.GetObject(),, "SentNo, ReceivedNo, DeletionMark, Code, Description")
		And DataExchangeServerCall.ChangesRegistered(Source.Ref)
		Then
		
		SaveAvailableForExportObjects(Source);
		
	EndIf;
	
	// Code and description of a node cannot be changed in SaaS
	If CommonUseCached.DataSeparationEnabled()
		And Not CommonUseCached.SessionWithoutSeparators()
		And Not Source.IsNew()
		And DataDifferent(Source, Source.Ref.GetObject(), "Code, Description") Then
		
		Raise NStr("en = 'The synchronization description and code cannot be changed.'");
		
	EndIf;
	
EndProcedure

Procedure SaveAvailableForExportObjects(NodeObject)
	
	SetPrivilegedMode(True);
	
	RegisteredData = New Array;
	ExchangePlanContent = NodeObject.Metadata().Content;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	*
	|FROM
	|	[Table].Changes AS ChangeTable
	|WHERE
	|	ChangeTable.Node = &Node";
	Query.SetParameter("Node", NodeObject.Ref);
	
	For Each ContentItem In ExchangePlanContent Do
		
		If ContentItem.AutoRecord = AutoChangeRecord.Allow Then
			Continue;
		EndIf;
		
		ItemMetadata = ContentItem.Metadata;
		MetadataObjectFullName = ItemMetadata.FullName();
		
		Query.Text = StrReplace(QueryText, "[Table]", MetadataObjectFullName);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			
			RegisteredDataOfSingleType = Result.Unload();
			
			If CommonUse.IsReferenceTypeObject(ItemMetadata) Then
				
				For Each Row In RegisteredDataOfSingleType Do
					
					If CommonUse.RefExists(Row.Ref) Then
						
						LinkObject = Row.Ref.GetObject();
						
						If ObjectExportAllowed(NodeObject.Ref, LinkObject) Then
							RegisteredData.Add(LinkObject);
						EndIf;
						
					EndIf;
					
				EndDo;
				
			ElsIf CommonUse.IsConstant(ItemMetadata) Then
				
				ConstantValueManager = Constants[ItemMetadata.Name].CreateValueManager();
				If ObjectExportAllowed(NodeObject.Ref, ConstantValueManager) Then
					RegisteredData.Add(ConstantValueManager);
				EndIf;
				
			Else //Processing a register or a sequence
				
				For Each Row In RegisteredDataOfSingleType Do
					
					RecordSet = CommonUse.ObjectManagerByFullName(MetadataObjectFullName).CreateRecordSet();
					
					For Each FilterItem In RecordSet.Filter Do
						
						If RegisteredDataOfSingleType.Columns.Find(FilterItem.Name) <> Undefined Then
							
							RecordSet.Filter[FilterItem.Name].Set(Row[FilterItem.Name]);
							
						EndIf;
						
					EndDo;
					
					RecordSet.Read();
					
					If ObjectExportAllowed(NodeObject.Ref, RecordSet) Then
						RegisteredData.Add(RecordSet);
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	NodeObject.AdditionalProperties.Insert("RegisteredForExportObjects", RegisteredData);
	
EndProcedure

Function ObjectExportAllowed(ExchangeNode, Object)
	
	If CommonUse.ReferenceTypeValue(Object) Then
		Return DataExchangeServer.RefExportAllowed(ExchangeNode, Object);
	EndIf;
	
	Sending = DataItemSend.Auto;
	DataOnSendToRecipient(Object, Sending, , ExchangeNode);
	Return Sending = DataItemSend.Auto;
EndFunction

// For internal use only.
//
Procedure CancelSendNodeDataInDistributedInfobase(Source, DataItem, Ignore) Export
	
	Ignore = True;
	
EndProcedure

// For internal use only.
//
Procedure RegisterCommonNodeDataChanges(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("Import") Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // writing the node when receiving the exchange message (universal data exchange)
	ElsIf Not DataExchangeCached.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	CommonNodeData = DataExchangeCached.CommonNodeData(Source.Ref);
	
	If IsBlankString(CommonNodeData) Then
		Return;
	EndIf;
	
	If DataExchangeCached.IsDistributedInfobaseNode(Source.Ref) Then
		Return;
	ElsIf DataExchangeCached.IsPredefinedExchangePlanNode(Source.Ref) Then
		Return;
	EndIf;
	
	If DataDifferent(Source, Source.Ref.GetObject(), CommonNodeData) Then
		
		InformationRegisters.CommonNodeDataChanges.RecordChanges(Source.Ref);
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure ClearReferencesToInfobaseNode(Source, Cancel) Export
	
	InformationRegisters.DataExchangeResults.ClearReferencesToInfobaseNode(Source.Ref);
	
	Catalogs.DataExchangeScenarios.ClearReferencesToInfobaseNode(Source.Ref);
	
EndProcedure

// Gets the current record set value from the infobase.
// 
// Parameters:
// Data - register record set.
// 
// Returns:
// RecordSet - contains the current value that is stored in the infobase.
// 
Function GetRecordSet(Val Data) Export
	
	MetadataObject = Data.Metadata();
	
	RecordSet = RecordSetByType(MetadataObject);
	
	For Each SelectValue In Data.Filter Do
		
		If SelectValue.Use = False Then
			Continue;
		EndIf;
		
		FilterRow = RecordSet.Filter.Find(SelectValue.Name);
		FilterRow.Value = SelectValue.Value;
		FilterRow.Use = True;
		
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism (ORM).
 
// Determines the list of exchange plan target nodes where the object must be registered for future exporting.
// First, using the mechanism of selective object registration (SOR),
// the procedure determines the exchange plans where the object must be registered.
// Then, using the object registration mechanism (ORR, registration rules), 
// the procedure determines nodes of each exchange plan for which the object must be registered.
//
// Parameters:
// Object - Arbitrary - an object, a record set, a constant, or an object deletion.
// Cancel - Boolean - flag that shows whether an error occurred during the object registration for nodes.
//          If errors occur during the object registration, this flag is set to True.
//
Procedure RegisterObjectChange(ExchangePlanName, Object, Cancel,
	WriteMode = Undefined,	Replacing = False, IsRegister = False, IsObjectDeletion = False,	IsConstant = False)
	
	Try
		
		If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
			Return;
		EndIf;
		
		SetPrivilegedMode(True);
		
		MetadataObject = Object.Metadata();
		
		If CommonUseCached.DataSeparationEnabled() Then
			
			If Not SeparatedExchangePlan(ExchangePlanName) Then
				Raise NStr("en = 'Change registration for shared exchange plans is not supported.'");
			EndIf;
			
			If CommonUseCached.CanUseSeparatedData() Then
				
				If Not SeparatedData(MetadataObject) Then
					Raise NStr("en = 'Registering changes of shared data in the separated mode.'");
				EndIf;
				
			Else
				
				If SeparatedData(MetadataObject) Then
					Raise NStr("en = 'Registering changes of separated data in the shared mode.'");
				EndIf;
					
				// Registering shared data changes for all nodes of separated
				// exchange plans in the shared mode.
				// The registration rule mechanism is not supported in the current mode.
				RegisterChangesForAllSeparatedExchangePlanNodes(ExchangePlanName, Object);
				Return;
				
			EndIf;
			
		EndIf;
		
		DataExchangeServerCall.CheckObjectChangeRecordMechanismCache();
		
		// Checking whether the object must be registered in the sender node
		If Object.AdditionalProperties.Property("RecordObjectChangeAtSenderNode") Then
			Object.DataExchange.Sender = Undefined;
		EndIf;
		
		If Not DataExchangeServerCall.DataExchangeEnabled(ExchangePlanName, Object.DataExchange.Sender) Then
			Return;
		EndIf;
		
		// Ignoring objects that are registered for the initial image of a DIB node
		If StandardSubsystemsServer.IsDIBModeInitialImageObject(MetadataObject) Then
			Return;
		EndIf;
		
		// Skipping SOR if the object has been deleted physically
		RecordObjectChangeToExport = IsRegister Or IsObjectDeletion Or IsConstant;
		
		ObjectModified = Object.AdditionalProperties.Property("DeferredWriting")
			Or Object.AdditionalProperties.Property("DeferredPosting")
			Or ObjectModifiedForExchangePlan(
				Object, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport
			);
		
		If Not ObjectModified Then
			
			If DataExchangeCached.AutoChangeRecordAllowed(ExchangePlanName, MetadataObject.FullName()) Then
				
				// Deleting all nodes where the object was registered automatically from the recipient list
				// if the object was not modified and it is registered automatically.
				ReduceRecipients(Object, AllExchangePlanNodes(ExchangePlanName));
				
			EndIf;
			
			// Skipping the registration in the node if the object has not been modified
			// relative to the current exchange plan.
			Return;
			
		EndIf;
		
		If Not DataExchangeCached.AutoChangeRecordAllowed(ExchangePlanName, MetadataObject.FullName()) Then
			
			CheckRef = ?(IsRegister Or IsConstant, False, Not Object.IsNew() And Not IsObjectDeletion);
			
			NodeArrayResult = New Array;
			
			ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName,
				MetadataObject, CheckRef, IsRegister, IsObjectDeletion, Replacing, WriteMode);
			
			// After define recipients event handler
			DataExchangeServer.AfterGetRecipients(Object, NodeArrayResult, ExchangePlanName);
			
			SupplementRecipients(Object, NodeArrayResult);
			
		EndIf;
		
	Except
		WriteLogEvent(NStr("en = 'Data exchange.Object registration rules'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		ProcessRegistrationRuleError(ExchangePlanName);
		Cancel = True;
	EndTry;
	
EndProcedure

Procedure RegisterChangesForAllSeparatedExchangePlanNodes(ExchangePlanName, Object)
	
	QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.RegisterChanges
		|	AND Not ExchangePlan.DeletionMark";

	Query = New Query;
	Query.Text = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
	Recipients = Query.Execute().Unload().UnloadColumn("Recipient");

	For Each Recipient In Recipients Do
		Object.DataExchange.Recipients.Add(Recipient);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Selective object registration (SOR).

Function ObjectModifiedForExchangePlan(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	Try
		ObjectModified = ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error determining whether the object has been modified: %1'"),
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return ObjectModified;
EndFunction

Function ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	If RecordObjectChangeToExport Or Source.IsNew() Or Source.DataExchange.Load Then
		// Changes of the following objects are always registered:
		// - register record sets,
		// - objects that were physically deleted,
		// - new objects,
		// - objects written with the data exchange.
		Return True;
		
	ElsIf WriteMode <> Undefined And DocumentPostingChanged(Source, WriteMode) Then
		// If the Posted flag has been changed, the document is considered modified
		Return True;
		
	EndIf;
	
	ObjectName = MetadataObject.FullName();
	
	ChangeRecordAttributeTable = DataExchangeCached.GetChangeRecordAttributeTable(ObjectName, ExchangePlanName);
	
	If ChangeRecordAttributeTable.Count() = 0 Then
		// If no SOR rules are set, considering that there is no SOR filter and the object is always modified
		Return True;
	EndIf;
	
	For Each ChangeRecordAttributeTableRow In ChangeRecordAttributeTable Do
		
		HasObjectVersionChanges = GetObjectVersionChanges(Source, ChangeRecordAttributeTableRow);
		
		If HasObjectVersionChanges Then
			Return True;
		EndIf;
		
	EndDo;
	
  // The object has not been changed relative to registration details, the registration is not required
	Return False;
EndFunction

Function ObjectModifiedByAttributes(Source, ReferenceTypeAttributeTable)
	
	For Each TableRow In ReferenceTypeAttributeTable Do
		
		HasObjectVersionChanges = GetObjectVersionChanges(Source, TableRow);
		
		If HasObjectVersionChanges Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Function GetObjectVersionChanges(Object, ChangeRecordAttributeTableRow)
	
	If IsBlankString(ChangeRecordAttributeTableRow.TabularSectionName) Then // object header attributes
		
		ChangeRecordAttributeTableObjectVersionBeforeChanges = GetHeaderChangeRecordAttributeTableBeforeChange(Object, ChangeRecordAttributeTableRow);
		
		ChangeRecordAttributeTableObjectVersionAfterChange = GetHeaderChangeRecordAttributeTableAfterChange(Object, ChangeRecordAttributeTableRow);
		
	Else // object tabular section attributes
		
		ChangeRecordAttributeTableObjectVersionBeforeChanges = GetTabularSectionChangeRecordAttributeTableBeforeChange(Object, ChangeRecordAttributeTableRow);
		
		ChangeRecordAttributeTableObjectVersionAfterChange = GetTabularSectionChangeRecordAttributeTableAfterChange(Object, ChangeRecordAttributeTableRow);
		
	EndIf;
	
	Return Not ChangeRecordAttributeTablesEqual(ChangeRecordAttributeTableObjectVersionBeforeChanges, ChangeRecordAttributeTableObjectVersionAfterChange, ChangeRecordAttributeTableRow);
	
EndFunction

Function GetHeaderChangeRecordAttributeTableBeforeChange(Object, ChangeRecordAttributeTableRow)
	
	QueryText = "
	|SELECT " + ChangeRecordAttributeTableRow.ChangeRecordAttributes 
	  + " FROM " + ChangeRecordAttributeTableRow.ObjectName + " AS
	|CurrentObject
	|WHERE CurrentObject.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetTabularSectionChangeRecordAttributeTableBeforeChange(Object, ChangeRecordAttributeTableRow)
	
	QueryText = "
	|SELECT "+ ChangeRecordAttributeTableRow.ChangeRecordAttributes
	+ " FROM " + ChangeRecordAttributeTableRow.ObjectName 
	+ "." + ChangeRecordAttributeTableRow.TabularSectionName + " AS
	|TabularSectionNameCurrentObject
	|WHERE TabularSectionNameCurrentObject.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetHeaderChangeRecordAttributeTableAfterChange(Object, ChangeRecordAttributeTableRow)
	
	ChangeRecordAttributeStructure = ChangeRecordAttributeTableRow.ChangeRecordAttributeStructure;
	
	ChangeRecordAttributeTable = New ValueTable;
	
	For Each ChangeRecordAttribute In ChangeRecordAttributeStructure Do
		
		ChangeRecordAttributeTable.Columns.Add(ChangeRecordAttribute.Key);
		
	EndDo;
	
	TableRow = ChangeRecordAttributeTable.Add();
	
	For Each ChangeRecordAttribute In ChangeRecordAttributeStructure Do
		
		TableRow[ChangeRecordAttribute.Key] = Object[ChangeRecordAttribute.Key];
		
	EndDo;
	
	Return ChangeRecordAttributeTable;
EndFunction

Function GetTabularSectionChangeRecordAttributeTableAfterChange(Object, ChangeRecordAttributeTableRow)
	
	ChangeRecordAttributeTable = Object[ChangeRecordAttributeTableRow.TabularSectionName].Unload(, ChangeRecordAttributeTableRow.ChangeRecordAttributes);
	
	Return ChangeRecordAttributeTable;
	
EndFunction

Function ChangeRecordAttributeTablesEqual(Table1, Table2, ChangeRecordAttributeTableRow)
	
	AddColumnWithValueToTable(Table1, +1);
	AddColumnWithValueToTable(Table2, -1);
	
	ResultTable = Table1.Copy();
	
	CommonUseClientServer.SupplementTable(Table2, ResultTable);
	
	ResultTable.Collapse(ChangeRecordAttributeTableRow.ChangeRecordAttributes, "ChangeRecordAttributeTableIterator");
	
	SameRowCount = ResultTable.FindRows(New Structure ("ChangeRecordAttributeTableIterator", 0)).Count();
	
	TableRowCount = ResultTable.Count();
	
	Return SameRowCount = TableRowCount;
	
EndFunction

Function DocumentPostingChanged(Source, WriteMode)
	
	Return (Source.Posted And WriteMode = DocumentWriteMode.UndoPosting)
	 Or (Not Source.Posted And WriteMode = DocumentWriteMode.Posting);
	
EndFunction

Procedure AddColumnWithValueToTable(Table, IteratorValue)
	
	Table.Columns.Add("ChangeRecordAttributeTableIterator");
	
	Table.FillValues(IteratorValue, "ChangeRecordAttributeTableIterator");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object registration rules (PRO).

Procedure ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayResult,
															Object,
															ExchangePlanName,
															MetadataObject,
															CheckRef = False,
															IsRegister = False,
															IsObjectDeletion = False,
															Replacing = False,
															WriteMode = Undefined,
															Data = False)
	Try
		ExecuteObjectChangeRecordRulesForExchangePlanTryExcept(NodeArrayResult,
															Object,
															ExchangePlanName,
															MetadataObject,
															CheckRef,
															IsRegister,
															IsObjectDeletion,
															Replacing,
															WriteMode,
															Data);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error executing object registration rules for the %1 exchange plan.
			|Error details:
			|%2'"),
			ExchangePlanName,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Procedure ExecuteObjectChangeRecordRulesForExchangePlanTryExcept(NodeArrayResult,
															Object,
															ExchangePlanName,
															MetadataObject,
															CheckRef,
															IsRegister,
															IsObjectDeletion,
															Replacing,
															WriteMode,
															Data)
	
	ObjectChangeRecordRules = New Array;
	
	SecurityProfileName = DataExchangeCached.SecurityProfileName(ExchangePlanName);
	If SecurityProfileName <> Undefined Then
		SetSafeMode(SecurityProfileName);
	EndIf;
	
	Rules = ObjectChangeRecordRules(ExchangePlanName, MetadataObject.FullName());
	
	For Each Rule In Rules Do
		
		ObjectChangeRecordRules.Add(ChangeRecordRuleStructure(Rule, Rules.Columns));
		
	EndDo;
	
	If ObjectChangeRecordRules.Count() = 0 Then // Registration rules are not set
		
		// Registering the object in all exchange plan nodes except the predefined one
		// if the ORR for the object are not specified and the automatic registration is disabled.
		Recipients = AllExchangePlanNodes(ExchangePlanName);
		
		CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
		
	Else // Executing registration rules sequentially
		
		If IsRegister Then // for the register
			
			For Each ORR In ObjectChangeRecordRules Do
				
				// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "BY CONDITION"
				
				GetRecipientsByConditionForRecordSet(NodeArrayResult, ORR, Object, MetadataObject, ExchangePlanName, Replacing, Data);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "ALWAYS"
					
					#If ExternalConnection Or ThickClientOrdinaryApplication Then
						
						Recipients = DataExchangeServerCall.GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, ORR.FlagAttributeName);
						
					#Else
						
						SetPrivilegedMode(True);
						Recipients = GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, ORR.FlagAttributeName);
						SetPrivilegedMode(False);
						
					#EndIf
					
					CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "IF NECESSARY"
					// There is no point in the "If necessary" registration execution for record sets
					
				EndIf;
				
			EndDo;
			
		Else // for the reference type
			
			For Each ORR In ObjectChangeRecordRules Do
				
				// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "BY CONDITION"
				
				GetRecipientsByCondition(NodeArrayResult, ORR, Object, MetadataObject, ExchangePlanName, CheckRef, IsObjectDeletion, WriteMode, Data);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "ALWAYS"
					
					#If ExternalConnection Or ThickClientOrdinaryApplication Then
						
						Recipients = DataExchangeServerCall.GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, ORR.FlagAttributeName);
						
					#Else
						
						SetPrivilegedMode(True);
						Recipients = GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, ORR.FlagAttributeName);
						SetPrivilegedMode(False);
						
					#EndIf
					
					CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "IF NECESSARY"
					
					If Not Object.IsNew() Then
						
						#If ExternalConnection Or ThickClientOrdinaryApplication Then
							
							Recipients = DataExchangeServerCall.GetNodeArrayForChangeRecordExportIfNecessary(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
							
						#Else
							
							SetPrivilegedMode(True);
							Recipients = GetNodeArrayForChangeRecordExportIfNecessary(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
							SetPrivilegedMode(False);
							
						#EndIf
						
						CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Returns the array of exchange plan nodes with "Always export" flag value set to True.
//
// Parameters:
//  ExchangePlanName  - String - name of the exchange plan used to determine exchange plan nodes
//                      (as it is specified in Designer mode).
//  FlagAttributeName - String - name of the exchange plan attribute used to create a node selection filter.
//
// Returns:
//  Array - array that contains exchange plan nodes with "Export always" flag set to True.
//
Function GetNodeArrayForChangeRecordExportAlways(Val ExchangePlanName, Val FlagAttributeName) Export
	
	QueryText = "
	|SELECT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
	|WHERE
	|	  ExchangePlanHeader.Ref <> &ThisNode
	|	AND ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.UnloadAlways)
	|	AND Not ExchangePlanHeader.DeletionMark
	|";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]",  ExchangePlanName);
	QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
	
	Query = New Query;
	Query.SetParameter("ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Node");
EndFunction

// Returns the array of exchange plan nodes with "Export when needed" flag set to True.
//
// Parameters:
//  Ref               - infobase object reference. 
//                      The function returns the array of nodes where this object was exported earlier.
//  ExchangePlanName  - String - name of the exchange plan used to determine exchange plan nodes 
//                      (as it is specified in Designer mode).
//  FlagAttributeName - String - name of the exchange plan attribute used to create a node selection filter. 
//
// Returns:
//  Array - array that contains exchange plan nodes with "Export when needed" flag set to True.
//
Function GetNodeArrayForChangeRecordExportIfNecessary(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	NodeArray = New Array;
	
	StandardProcessing = True;
	If CommonUse.SubsystemExists("DataExchangeXDTO") Then
		
		DataExchangeXDTOCachedModule = CommonUse.CommonModule("DataExchangeXDTOCached");
		DataExchangeXDTOServerModule = CommonUse.CommonModule("DataExchangeXDTOServer");
		
		If DataExchangeXDTOCachedModule.IsXDTOExchangePlan(ExchangePlanName) Then
			StandardProcessing = False;
			NodeArray = DataExchangeXDTOServerModule.ExportIfNecessaryNodeArrayToRegister(
				Ref, ExchangePlanName, FlagAttributeName);
		EndIf;
	EndIf;
	
	If StandardProcessing Then
		
		QueryText = "
		|SELECT DISTINCT
		|	ExchangePlanHeader.Ref AS Node
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
		|LEFT JOIN
		|	InformationRegister.InfobaseObjectMappings AS InfobaseObjectMappings
		|ON
		|	ExchangePlanHeader.Ref = InfobaseObjectMappings.InfobaseNode
		|	AND InfobaseObjectMappings.SourceUUID = &Object
		|WHERE
		|	     ExchangePlanHeader.Ref <> &ThisNode
		|	AND    ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportIfNecessary)
		|	AND Not ExchangePlanHeader.DeletionMark
		|	AND    InfobaseObjectMappings.SourceUUID = &Object
		|";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]",  ExchangePlanName);
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
		Query = New Query;
		Query.Text = QueryText;
		Query.SetParameter("ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
		Query.SetParameter("Object",   Ref);
		
		NodeArray = Query.Execute().Unload().UnloadColumn("Node");
		
	EndIf;
	
	Return NodeArray;
	
EndFunction

Procedure ExecuteObjectChangeRecordRuleForRecordSet(NodeArrayResult,
															ORR,
															Object,
															MetadataObject,
															ExchangePlanName,
															Replacing,
															Data)
	
	// Getting the array of recipient nodes by the current record set
	GetRecipientArrayByRecordSet(NodeArrayResult, Object, ORR, MetadataObject, ExchangePlanName, False, Data);
	
	If Replacing And Not Data Then
		
		OldRecordSet = GetRecordSet(Object);
		
		// Getting the array of recipient nodes by the old record set
		GetRecipientArrayByRecordSet(NodeArrayResult, OldRecordSet, ORR, MetadataObject, ExchangePlanName, True, False);
		
	EndIf;
	
EndProcedure

Procedure ExecuteObjectChangeRecordRuleForReferenceType(NodeArrayResult,
															ORR,
															Object,
															ExchangePlanName,
															CheckRef,
															IsObjectDeletion,
															WriteMode,
															Data)
	
	// ORRO   - registration rules by object properties
	// ORREPP - registration rules by exchange plan properties
	// PRO = ORROP <And> ORREPP
	
	// ORRO
	If  Not ORR.RuleByObjectPropertiesEmpty
		And Not ObjectPassedChangeRecordRuleFilterByProperties(ORR, Object, CheckRef, WriteMode) Then
		
		Return;
		
	EndIf;
	
	// ORREPP
	// Defining nodes for registering the object
	GetNodeArrayForObject(NodeArrayResult, Object, ExchangePlanName, ORR, IsObjectDeletion, CheckRef, Data);
	
EndProcedure

Procedure GetRecipientsByCondition(NodeArrayResult,
										ORR,
										Object,
										MetadataObject,
										ExchangePlanName,
										CheckRef,
										IsObjectDeletion,
										WriteMode,
										Data)
	
	// {HANDLER: before processing} Start
	Cancel = False;
	
	ExecuteORRBeforeProcessHandler(ORR, Cancel, Object, MetadataObject, Data);
	
	If Cancel Then
		Return;
	EndIf;
	// {HANDLER: before processing} End
	
	Recipients = New Array;
	
	ExecuteObjectChangeRecordRuleForReferenceType(Recipients, ORR, Object, ExchangePlanName, CheckRef, IsObjectDeletion, WriteMode, Data);
	
	// {HANDLER: After processing} Start
	Cancel = False;
	
	ExecuteORRAfterProcessHandler(ORR, Cancel, Object, MetadataObject, Recipients, Data);
	
	If Cancel Then
		Return;
	EndIf;
	// {HANDLER: After processing} End
	
	CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
	
EndProcedure

Procedure GetRecipientsByConditionForRecordSet(NodeArrayResult,
														ORR,
														Object,
														MetadataObject,
														ExchangePlanName,
														Replacing,
														Data)
	
	// {HANDLER: before processing} Start
	Cancel = False;
	
	ExecuteORRBeforeProcessHandler(ORR, Cancel, Object, MetadataObject, Data);
	
	If Cancel Then
		Return;
	EndIf;
	// {HANDLER: before processing} End
	
	Recipients = New Array;
	
	ExecuteObjectChangeRecordRuleForRecordSet(Recipients, ORR, Object, MetadataObject, ExchangePlanName, Replacing, Data);
	
	// {HANDLER: After processing} Start
	Cancel = False;
	
	ExecuteORRAfterProcessHandler(ORR, Cancel, Object, MetadataObject, Recipients, Data);
	
	If Cancel Then
		Return;
	EndIf;
	// {HANDLER: After processing} End
	
	CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
	
EndProcedure

Procedure GetNodeArrayForObject(NodeArrayResult,
										Source,
										ExchangePlanName,
										ORR,
										IsObjectDeletion,
										CheckRef,
										Data)
	
	// Getting property value structure for the object
	ObjectPropertyValues = GetPropertyValuesForObject(Source, ORR);
	
	// Defining an array of nodes for the object registration
	NodeArray = GetNodeArrayByPropertyValues(ObjectPropertyValues, ORR, ExchangePlanName, Source, Data);
	
	// Adding nodes for the registration
	CommonUse.FillArrayWithUniqueValues(NodeArrayResult, NodeArray);
	
	If CheckRef Then
		
		// Getting the property value structure for the reference
		#If ExternalConnection Or ThickClientOrdinaryApplication Then
			
			RefPropertyValues = DataExchangeServerCall.GetPropertyValuesForRef(Source.Ref, ORR.ObjectProperties, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
			
		#Else
			
			SetPrivilegedMode(True);
			RefPropertyValues = GetPropertyValuesForRef(Source.Ref, ORR.ObjectProperties, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
			SetPrivilegedMode(False);
			
		#EndIf
		
		// Defining an array of nodes for registering the reference
		NodeArray = GetNodeArrayByPropertyValuesAdditional(RefPropertyValues, ORR, ExchangePlanName, Source);
		
		// Adding nodes for the registration
		CommonUse.FillArrayWithUniqueValues(NodeArrayResult, NodeArray);
		
	EndIf;
	
EndProcedure

Procedure GetRecipientArrayByRecordSet(NodeArrayResult,
													RecordSet,
													ORR,
													MetadataObject,
													ExchangePlanName,
													IsObjectVersionBeforeChanges,
													Data)
	
	// Getting the value of the recorder from the filter for the record set
	Recorder = Undefined;
	
	FilterItem = RecordSet.Filter.Find("Recorder");
	
	HasRecorder = FilterItem <> Undefined;
	
	If HasRecorder Then
		
		Recorder = FilterItem.Value;
		
	EndIf;
	
	For Each SetRow In RecordSet Do
		
		ORR_SetStrings = CopyStructure(ORR);
		
		If HasRecorder And SetRow["Recorder"] = Undefined Then
			
			If Recorder <> Undefined Then
				
				SetRow["Recorder"] = Recorder;
				
			EndIf;
			
		EndIf;
		
		// ORRO
		If Not ObjectPassedChangeRecordRuleFilterByProperties(ORR_SetStrings, SetRow, False) Then
			
			Continue;
			
		EndIf;
		
		// ORRP
		
		// Getting property value structure for the object
		ObjectPropertyValues = GetPropertyValuesForObject(SetRow, ORR_SetStrings);
		
		If IsObjectVersionBeforeChanges Then
			
			// Defining an array of nodes for the object registration
			NodeArray = GetNodeArrayByPropertyValuesAdditional(ObjectPropertyValues,
				ORR_SetStrings, ExchangePlanName, SetRow, RecordSet.AdditionalProperties);
			
		Else
			
			// Defining an array of nodes for the object registration
			NodeArray = GetNodeArrayByPropertyValues(ObjectPropertyValues, ORR_SetStrings,
				ExchangePlanName, SetRow, Data, RecordSet.AdditionalProperties);
			
		EndIf;
		
		// Adding nodes for the registration
		CommonUse.FillArrayWithUniqueValues(NodeArrayResult, NodeArray);
		
	EndDo;
	
EndProcedure

// Returns the structure that stores object property values. 
// The structure is generated using a query to an infobase.
// Structure key - property name; Value - object property value.
//
// Parameters:
//  Ref - reference to an infobase object whose property values are retrieved.
//
// Returns:
//  Structure - structure that contains object properties.
//
Function GetPropertyValuesForRef(Ref, ObjectProperties, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	PropertyValues = CopyStructure(ObjectProperties);
	
	If PropertyValues.Count() = 0 Then
		
		Return PropertyValues; // Returning an empty structure
		
	EndIf;
	
	QueryText = "
	|SELECT
	|	[ObjectPropertiesString]
	|FROM
	|	[MetadataObjectName] AS Table
	|WHERE
	|	Table.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[ObjectPropertiesString]", ObjectPropertiesString);
	QueryText = StrReplace(QueryText, "[MetadataObjectName]",     MetadataObjectName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	
	Try
		
		Selection = Query.Execute().Select();
		
	Except
		MessageString = NStr("en = 'Error getting reference properties. Query execution error: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", DetailErrorDescription(ErrorInfo()));
		Raise MessageString;
	EndTry;
	
	If Selection.Next() Then
		
		For Each Item In PropertyValues Do
			
			PropertyValues[Item.Key] = Selection[Item.Key];
			
		EndDo;
		
	EndIf;
	
	Return PropertyValues;
EndFunction

Function GetNodeArrayByPropertyValues(PropertyValues, ORR, Val ExchangePlanName, Object, Val Data, AdditionalProperties = Undefined)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {HANDLER: On processing} Start
	Cancel = False;
	
	ExecuteORRHandlerOnProcess(Cancel, ORR, Object, QueryText, PropertyValues, UseCache, Data, AdditionalProperties);
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {HANDLER: On processing} End
	
	If UseCache Then
		
		Return DataExchangeCached.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, Data);
		
	Else
		
		#If ExternalConnection Or ThickClientOrdinaryApplication Then
			
			Return DataExchangeServerCall.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, Data);
			
		#Else
			
			SetPrivilegedMode(True);
			Return NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, Data);
			
		#EndIf
		
	EndIf;
	
EndFunction

Function GetNodeArrayByPropertyValuesAdditional(PropertyValues, ORR, Val ExchangePlanName, Object, AdditionalProperties = Undefined)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {HANDLER: On processing (additional)} Start
	Cancel = False;
	
	ExecuteORRHandlerOnProcessAdditional(Cancel, ORR, Object, QueryText, PropertyValues, UseCache, AdditionalProperties);
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {HANDLER: On processing (additional)} End
	
	If UseCache Then
		
		Return DataExchangeCached.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	Else
		
		#If ExternalConnection Or ThickClientOrdinaryApplication Then
			
			Return DataExchangeServerCall.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
			
		#Else
			
			SetPrivilegedMode(True);
			Return NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
			
		#EndIf
		
	EndIf;
	
EndFunction

// Returns an array of exchange plan nodes based on a query to an exchange plan table.
//
//
Function NodeArrayByPropertyValues(PropertyValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName, Val Data = False) Export
	
	// Return value
	NodeArrayResult = New Array;
	
	// Preparing a query for getting exchange plan nodes
	Query = New Query;
	
	QueryText = StrReplace(QueryText, "[RequiredConditions]",
				"AND    ExchangePlanMainTable.Ref <> &" + ExchangePlanName + "ThisNode
				|AND
				|NOT ExchangePlanMainTable.DeletionMark [FilterConditionByFlagAttribute]
				|");
	If IsBlankString(FlagAttributeName) Then
		
		QueryText = StrReplace(QueryText, "[FilterConditionByFlagAttribute]", "");
		
	Else
		
		If Data Then
			QueryText = StrReplace(QueryText, "[FilterConditionByFlagAttribute]",
				"AND (ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportByCondition) OR 
				|ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ManualExport) OR 
				|ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.EmptyRef))"
			);
		Else
			QueryText = StrReplace(QueryText, "[FilterConditionByFlagAttribute]",
				"AND (ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportByCondition) OR 
				|ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.EmptyRef))"
			);
		EndIf;
		
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
	EndIf;
	
	// Query text
	Query.Text = QueryText;
	
	Query.SetParameter(ExchangePlanName + "ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
	
	// Filling query parameters with object properties
	For Each Item In PropertyValues Do
		
		Query.SetParameter("ObjectProperty_" + Item.Key, Item.Value);
		
	EndDo;
	
	Try
		
		NodeArrayResult = Query.Execute().Unload().UnloadColumn("Ref");
		
	Except
		MessageString = NStr("en = 'Error getting target node list. Query execution error: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", DetailErrorDescription(ErrorInfo()));
		Raise MessageString;
	EndTry;
	
	Return NodeArrayResult;
EndFunction

Function GetPropertyValuesForObject(Object, ORR)
	
	PropertyValues = New Structure;
	
	For Each Item In ORR.ObjectProperties Do
		
		PropertyValues.Insert(Item.Key, GetObjectPropertyValue(Object, Item.Value));
		
	EndDo;
	
	Return PropertyValues;
	
EndFunction

Function GetObjectPropertyValue(Object, ObjectPropertyRow)
	
	Value = Object;
	
	SubstringArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(ObjectPropertyRow, ".");
	
	// Getting the value considering the possibility of property dereferencing
	For Each PropertyName In SubstringArray Do
		
		Value = Value[PropertyName];
		
	EndDo;
	
	Return Value;
	
EndFunction

// For internal use only.
//
Function ExchangePlanObjectChangeRecordRules(Val ExchangePlanName) Export
	
	Return DataExchangeCached.ExchangePlanObjectChangeRecordRules(ExchangePlanName);
	
EndFunction

// For internal use only.
//
Function ObjectChangeRecordRules(Val ExchangePlanName, Val FullObjectName) Export
	
	Return DataExchangeCached.ObjectChangeRecordRules(ExchangePlanName, FullObjectName);
	
EndFunction

Function ChangeRecordRuleStructure(Rule, Columns)
	
	Result = New Structure;
	
	For Each Column In Columns Do
		
		Key = Column.Name;
		Value = Rule[Key];
		
		If TypeOf(Value) = Type("ValueTable") Then
			
			Result.Insert(Key, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("ValueTree") Then
			
			Result.Insert(Key, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			Result.Insert(Key, CopyStructure(Value));
			
		Else
			
			Result.Insert(Key, Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function SeparatedExchangePlan(Val ExchangePlanName)
	
	Return CommonUseCached.IsSeparatedMetadataObject(
		"ExchangePlan." + ExchangePlanName,
		CommonUseCached.MainDataSeparator());
	
EndFunction

Function SeparatedData(MetadataObject)
	
	Return CommonUseCached.IsSeparatedMetadataObject(
		MetadataObject.FullName(),
		CommonUseCached.MainDataSeparator());
	
EndFunction

// Creates a record set for a register.
//
// Parameters:
//  MetadataObject - register metadata object for getting a record set.
//
// Returns:
//  RecordSet. If a record set cannot be created for the
//  metadata object, an exception is raised.
//
Function RecordSetByType(MetadataObject)
	
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
	
	If BaseTypeName = CommonUse.TypeNameInformationRegisters() Then
		
		Result = InformationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameAccumulationRegisters() Then
		
		Result = AccumulationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameAccountingRegisters() Then
		
		Result = AccountingRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameCalculationRegisters() Then
		
		Result = CalculationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.SequenceTypeName() Then
		
		Result = Sequences[MetadataObject.Name].CreateRecordSet();
		
	Else
		
		MessageString = NStr("en = 'A record set is not available for the %1 metadata object.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, MetadataObject.FullName());
		Raise MessageString;
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Registration rules by objects properties.

Procedure FillPropertyValuesFromObject(ValueTree, Object)
	
	For Each TreeRow In ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillPropertyValuesFromObject(TreeRow, Object);
			
		Else
			
			TreeRow.PropertyValue = GetObjectPropertyValue(Object, TreeRow.ObjectProperty);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CreateValidFilterByProperties(Object, TargetValueTree, SourceValueTree)
	
	For Each SourceTreeRow In SourceValueTree.Rows Do
		
		If SourceTreeRow.IsFolder Then
			
			TargetTreeRow = TargetValueTree.Rows.Add();
			
			FillPropertyValues(TargetTreeRow, SourceTreeRow);
			
			CreateValidFilterByProperties(Object, TargetTreeRow, SourceTreeRow);
			
		Else
			
			If ObjectHasProperties(Object, SourceTreeRow.ObjectProperty) Then
				
				TargetTreeRow = TargetValueTree.Rows.Add();
				
				FillPropertyValues(TargetTreeRow, SourceTreeRow);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Retrieving constant values that are calculated using custom expressions.
// The values are calculated in privileged mode.
//
Procedure GetConstantAlgorithmValues(ORR, ValueTree)
	
	For Each TreeRow In ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			GetConstantAlgorithmValues(ORR, TreeRow);
			
		Else
			
			If TreeRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				Value = Undefined;
				
				Try
					
					#If ExternalConnection Or ThickClientOrdinaryApplication Then
						
						DataExchangeServerCall.ExecuteHandlerInPrivilegedMode(Value, TreeRow.ConstantValue);
						
					#Else
						
						SetPrivilegedMode(True);
						Execute(TreeRow.ConstantValue);
						SetPrivilegedMode(False);
						
					#EndIf
					
				Except
					
					MessageString = NStr("en = 'Error determining the constant value:
											 |Exchange plan: [ExchangePlanName]
											 |Metadata object: [MetadataObjectName] 
                   |Error details: [Details]
											 |Algorithm:
											 |// {Algorithm start} 
											 |[ConstantValue]
                   |// {Algorithm end}
											 |'");
					MessageString = StrReplace(MessageString, "[ExchangePlanName]",   ORR.ExchangePlanName);
					MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
					MessageString = StrReplace(MessageString, "[Description]",        ErrorInfo().Description);
					MessageString = StrReplace(MessageString, "[ConstantValue]",      String(TreeRow.ConstantValue));
					
					Raise MessageString;
					
				EndTry;
				
				TreeRow.ConstantValue = Value;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ObjectHasProperties(Object, Val ObjectPropertyRow)
	
	Value = Object;
	
	SubstringArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(ObjectPropertyRow, ".");
	
	// Getting the value considering the possibility of property dereferencing
	For Each PropertyName In SubstringArray Do
		
		Try
			Value = Value[PropertyName];
		Except
			Return False;
		EndTry;
		
	EndDo;
	
	Return True;
EndFunction
 
// Executing ORROP for the reference and for the object. 
// The result is taken into account with the OR condition.
// If the object passed the ORROP filter by the reference value, skipping ORROP for object values.
//
Function ObjectPassedChangeRecordRuleFilterByProperties(ORR, Object, CheckRef, WriteMode = Undefined)
	
	PostedPropertyInitialValue = Undefined;
	
	GetConstantAlgorithmValues(ORR, ORR.FilterByObjectProperties);
	
	If WriteMode <> Undefined Then
		
		PostedPropertyInitialValue = Object.Posted;
		
		If WriteMode = DocumentWriteMode.UndoPosting Then
			
			Object.Posted = False;
			
		ElsIf WriteMode = DocumentWriteMode.Posting Then
			
			Object.Posted = True;
			
		EndIf;
		
	EndIf;
	
	// ORROP by the object property value
	If ObjectPassesORROFilter(ORR, Object) Then
		
		If PostedPropertyInitialValue <> Undefined Then
			
			Object.Posted = PostedPropertyInitialValue;
			
		EndIf;
		
		Return True;
		
	EndIf;
	
	If PostedPropertyInitialValue <> Undefined Then
		
		Object.Posted = PostedPropertyInitialValue;
		
	EndIf;
	
	If CheckRef Then
		
		// ORROP by the reference property value
		If ObjectPassesORROFilter(ORR, Object.Ref) Then
			
			Return True;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function ObjectPassesORROFilter(ORR, Object)
	
	ORR.FilterByProperties = DataProcessors.ObjectChangeRecordRuleImport.FilterByObjectPropertiesTableInitialization();
	
	CreateValidFilterByProperties(Object, ORR.FilterByProperties, ORR.FilterByObjectProperties);
	
	FillPropertyValuesFromObject(ORR.FilterByProperties, Object);
	
	Return ConditionIsTrueForValueTreeBranch(ORR.FilterByProperties);
	
EndFunction

// By default, filter items of the root group are compared with the AND condition
// (The IsAndOperator parameter is True).
//
Function ConditionIsTrueForValueTreeBranch(ValueTree, Val IsAndOperator = True)
	
	// Initializing
	If IsAndOperator Then // AND
		Result = True;
	Else // OR
		Result = False;
	EndIf;
	
	For Each TreeRow In ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			ItemResult = ConditionIsTrueForValueTreeBranch(TreeRow, TreeRow.IsAndOperator);
		Else
			
			ItemResult = IsConditionTrueForItem(TreeRow, IsAndOperator);
		EndIf;
		
		If IsAndOperator Then // AND
			
			Result = Result And ItemResult;
			
			If Not Result Then
				Return False;
			EndIf;
			
		Else // OR
			
			Result = Result Or ItemResult;
			
			If Result Then
				Return True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function IsConditionTrueForItem(TreeRow, IsAndOperator)
	
	Var ComparisonType;
	
	ComparisonType = TreeRow.ComparisonType;
	
	Try
		
		If    ComparisonType = "Equal"          Then Return TreeRow.PropertyValue =  TreeRow.ConstantValue;
		ElsIf ComparisonType = "NotEqual"       Then Return TreeRow.PropertyValue <> TreeRow.ConstantValue;
		ElsIf ComparisonType = "Greater"        Then Return TreeRow.PropertyValue >  TreeRow.ConstantValue;
		ElsIf ComparisonType = "GreaterOrEqual" Then Return TreeRow.PropertyValue >= TreeRow.ConstantValue;
		ElsIf ComparisonType = "Less"           Then Return TreeRow.PropertyValue <  TreeRow.ConstantValue;
		ElsIf ComparisonType = "LessOrEqual"    Then Return TreeRow.PropertyValue <= TreeRow.ConstantValue;
		EndIf;
		
	Except
		
		Return False;
		
	EndTry;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Object registration rule events (ORR events).

Procedure ExecuteORRBeforeProcessHandler(ORR, Cancel, Object, MetadataObject, Val Data)
	
	If ORR.HasBeforeProcessHandler Then
		
		Try
			Execute(ORR.BeforeProcess);
		Except
			MessageString = NStr("en = 'Error executing the [HandlerName] handler;
			  |Exchange plan: [ExchangePlanName]; 
       |Metadata object: [MetadataObjectName]; 
       |Error details: [Details].'");
			MessageString = StrReplace(MessageString, "[HandlerName]",        NStr("en = 'Before processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",   ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Description]",        DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcess(Cancel, ORR, Object, QueryText, QueryOptions,
	UseCache, Val Data, AdditionalProperties = Undefined)
	
	If ORR.HasOnProcessHandler Then
		
		Try
			Execute(ORR.OnProcess);
		Except
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			MessageString = StrReplace(MessageString, "[HandlerName]",        NStr("en = 'On processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",   ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Description]",        DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcessAdditional(Cancel, ORR, Object, QueryText, QueryOptions, UseCache, AdditionalProperties = Undefined)
	
	If ORR.HasOnProcessHandlerAdditional Then
		
		Try
			Execute(ORR.OnProcessAdditional);
		Except
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			MessageString = StrReplace(MessageString, "[HandlerName]",        NStr("en = 'On processing (additional)'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",   ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Description]",        DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRAfterProcessHandler(ORR, Cancel, Object, MetadataObject, Recipients, Val Data)
	
	If ORR.HasAfterProcessHandler Then
		
		Try
			Execute(ORR.AfterProcess);
		Except
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			MessageString = StrReplace(MessageString, "[HandlerName]",        NStr("en = 'After processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",   ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Description]",        DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure OnSendData(DataItem, ItemSend, Val Recipient, Val InitialImageCreating, Val Analysis)
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return;
	EndIf;
	
	// Checking whether registration mechanism cached data is up-to-date
	DataExchangeServerCall.CheckObjectChangeRecordMechanismCache();
	
	ObjectExportMode = DataExchangeCached.ObjectExportMode(DataItem.Metadata().FullName(), Recipient);
	
	If ObjectExportMode = Enums.ExchangeObjectExportModes.UnloadAlways Then
		
		// Exporting data item
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectExportModes.ExportByCondition
		Or ObjectExportMode = Enums.ExchangeObjectExportModes.ExportIfNecessary Then
		
		If Not DataMatchRegistrationRuleFilter(DataItem, Recipient) Then
			
			If InitialImageCreating Then
				
				ItemSend = DataItemSend.Ignore;
				
			Else
				
				ItemSend = DataItemSend.Delete;
				
			EndIf;
			
		EndIf;
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectExportModes.ManualExport Then
		
		If InitialImageCreating Then
			
			ItemSend = DataItemSend.Ignore;
			
		Else
			
			If DataMatchRegistrationRuleFilter(DataItem, Recipient) Then
				
				If Not Analysis Then
					
					// Deleting change registrations for data that is exported manually
					ExchangePlans.DeleteChangeRecords(Recipient, DataItem);
					
				EndIf;
				
			Else
				
				ItemSend = DataItemSend.Ignore;
				
			EndIf;
			
		EndIf;
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectExportModes.NotExport Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

Function DataMatchRegistrationRuleFilter(DataItem, Val Recipient)
	
	Result = True;
	
	ExchangePlanName = Recipient.Metadata().Name;
	
	MetadataObject = DataItem.Metadata();
	
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
	
	If   BaseTypeName = CommonUse.TypeNameCatalogs()
		Or BaseTypeName = CommonUse.TypeNameDocuments()
		Or BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes()
		Or BaseTypeName = CommonUse.TypeNameChartsOfAccounts()
		Or BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes()
		Or BaseTypeName = CommonUse.TypeNameBusinessProcesses()
		Or BaseTypeName = CommonUse.TypeNameTasks() Then
		
		// Defining an array of nodes for the object registration
		NodeArrayForObjectChangeRecord = New Array;
		
		ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayForObjectChangeRecord,
														DataItem,
														ExchangePlanName,
														MetadataObject,
														False,
														,
														,
														,
														,
														True);
		
		// Sending object deletion if the current node is absent from the array
		If NodeArrayForObjectChangeRecord.Find(Recipient) = Undefined Then
			
			Result = False;
			
		EndIf;
		
	ElsIf BaseTypeName = CommonUse.TypeNameInformationRegisters()
		Or BaseTypeName  = CommonUse.TypeNameAccumulationRegisters()
		Or BaseTypeName  = CommonUse.TypeNameAccountingRegisters()
		Or BaseTypeName  = CommonUse.TypeNameCalculationRegisters() Then
		
		ExcludeProperties = ?(BaseTypeName = CommonUse.TypeNameAccumulationRegisters(), "RecordType", "");
		
		DataToCheck = RecordSetByType(MetadataObject);
		
		For Each SourceFilterItem In DataItem.Filter Do
			
			TargetFilterItem = DataToCheck.Filter.Find(SourceFilterItem.Name);
			
			FillPropertyValues(TargetFilterItem, SourceFilterItem);
			
		EndDo;
		
		DataToCheck.Add();
		
		ReverseIndex = DataItem.Count() - 1;
		
		While ReverseIndex >= 0 Do
			
			FillPropertyValues(DataToCheck[0], DataItem[ReverseIndex],, ExcludeProperties);
			
			// Defining an array of nodes for the object registration
			NodeArrayForObjectChangeRecord = New Array;
			
			ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayForObjectChangeRecord,
															DataToCheck,
															ExchangePlanName,
															MetadataObject,
															,
															True,
															,
															,
															,
															True);
			
			// Deleting the row from the set if the current node is absent from the array
			If NodeArrayForObjectChangeRecord.Find(Recipient) = Undefined Then
				
				DataItem.Delete(ReverseIndex);
				
			EndIf;
			
			ReverseIndex = ReverseIndex - 1;
			
		EndDo;
		
		If DataItem.Count() = 0 Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Fills values of attributes and tabular sections of infobase objects of the same type.
//
// Parameters:
//  Source -             infobase object (CatalogObject, DocumentObject, ChartOfCharacteristicTypesObject,
//                       and so on) that is the data source.
//
//  Target (mandatory) - infobase object (CatalogObject, DocumentObject, ChartOfCharacteristicTypesObject
//                       and so on) that will be filled with source data.
//
//  ListOfProperties   - String - comma-separated properties of the object and its tabular sections.
//                       If this parameter is passed, object properties
//                       will be filled according to the specified
//                       properties and the ExcludingProperties parameter will be ignored.
//
//  ExcludeProperties  - String -  comma-separated properties of the object and its tabular sections.
//                       If this parameter is passed, all properties
//                       and tabular sections will be filled, except the specified properties.
//
Procedure FillObjectPropertyValues(Target, Source, Val ListOfProperties = Undefined, Val ExcludeProperties = Undefined) Export
	
	If ListOfProperties <> Undefined Then
		
		ListOfProperties = StrReplace(ListOfProperties, " ", "");
		
		ListOfProperties = StringFunctionsClientServer.SplitStringIntoSubstringArray(ListOfProperties);
		
		MetadataObject = Target.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		HeaderPropertyList  = New Array;
		UsedTabularSections = New Array;
		
		For Each Property In ListOfProperties Do
			
			If TabularSections.Find(Property) <> Undefined Then
				
				UsedTabularSections.Add(Property);
				
			Else
				
				HeaderPropertyList.Add(Property);
				
			EndIf;
			
		EndDo;
		
		HeaderPropertyList = StringFunctionsClientServer.StringFromSubstringArray(HeaderPropertyList);
		
		FillPropertyValues(Target, Source, HeaderPropertyList);
		
		For Each TabularSection In UsedTabularSections Do
			
			Target[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	ElsIf ExcludeProperties <> Undefined Then
		
		FillPropertyValues(Target, Source,, ExcludeProperties);
		
		MetadataObject = Target.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection In TabularSections Do
			
			If Find(ExcludeProperties, TabularSection) <> 0 Then
				Continue;
			EndIf;
			
			Target[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	Else
		
		FillPropertyValues(Target, Source);
		
		MetadataObject = Target.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection In TabularSections Do
			
			Target[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure RecordReferenceTypeObjectChangesByNodeProperties(Object, ReferenceTypeAttributeTable)
	
	InfobaseNode = Object.Ref;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	For Each TableRow In ReferenceTypeAttributeTable Do
		
		If IsBlankString(TableRow.TabularSectionName) Then // header attributes
			
			For Each Item In TableRow.ChangeRecordAttributeStructure Do
				
				Ref = Object[Item.Key];
				
				If Not Ref.IsEmpty()
					And ExchangePlanContentContainsType(ExchangePlanName, TypeOf(Ref)) Then
					
					ExchangePlans.RecordChanges(InfobaseNode, Ref);
					
				EndIf;
				
			EndDo;
			
		Else // Tabular section attributes
			
			TabularSection = Object[TableRow.TabularSectionName];
			
			For Each TabularSectionRow In TabularSection Do
				
				For Each Item In TableRow.ChangeRecordAttributeStructure Do
					
					Ref = TabularSectionRow[Item.Key];
					
					If Not Ref.IsEmpty()
						And ExchangePlanContentContainsType(ExchangePlanName, TypeOf(Ref)) Then
						
						ExchangePlans.RecordChanges(InfobaseNode, Ref);
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetReferenceTypeObjectAttributes(Object, ExchangePlanName)
	
	// Initializing the table
	Result = DataExchangeServer.SelectiveObjectChangeRecordRuleTableInitialization();
	
	MetadataObject = Object.Metadata();
	MetadataObjectFullName = MetadataObject.FullName();
	
	// Getting header attributes
	Attributes = GetReferenceTypeAttributes(MetadataObject.Attributes, ExchangePlanName);
	
	If Attributes.Count() > 0 Then
		
		TableRow = Result.Add();
		TableRow.ObjectName                     = MetadataObjectFullName;
		TableRow.TabularSectionName             = "";
		TableRow.ChangeRecordAttributes         = StructureKeysToString(Attributes);
		TableRow.ChangeRecordAttributeStructure = CopyStructure(Attributes);
		
	EndIf;
	
	// Getting tabular section attributes
	For Each TabularSection In MetadataObject.TabularSections Do
		
		Attributes = GetReferenceTypeAttributes(TabularSection.Attributes, ExchangePlanName);
		
		If Attributes.Count() > 0 Then
			
			TableRow = Result.Add();
			TableRow.ObjectName                     = MetadataObjectFullName;
			TableRow.TabularSectionName             = TabularSection.Name;
			TableRow.ChangeRecordAttributes         = StructureKeysToString(Attributes);
			TableRow.ChangeRecordAttributeStructure = CopyStructure(Attributes);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function GetReferenceTypeAttributes(Attributes, ExchangePlanName)
	
	// Return value
	Result = New Structure;
	
	For Each Attribute In Attributes Do
		
		TypeArray = Attribute.Type.Types();
		
		IsReference = False;
		
		For Each Type In TypeArray Do
			
			If  CommonUse.IsReference(Type)
				And ExchangePlanContentContainsType(ExchangePlanName, Type) Then
				
				IsReference = True;
				
				Break;
				
			EndIf;
			
		EndDo;
		
		If IsReference Then
			
			Result.Insert(Attribute.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function ExchangePlanContentContainsType(ExchangePlanName, Type)
	
	Return Metadata.ExchangePlans[ExchangePlanName].Content.Contains(Metadata.FindByType(Type));
	
EndFunction

Procedure ProcessRegistrationRuleError(ExchangePlanName)
	
	If InfobaseUpdate.ExecutingInfobaseUpdate()
		And InformationRegisters.DataExchangeRules.RulesFromFileUsed(ExchangePlanName) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString("DataExchange=%1", ExchangePlanName);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Creates a new instance of the Structure object. 
// Fills the object with data of the specified structure.
//
// Parameters:
//  SourceStructure - Structure - structure whose copy will be retrieved.
//
// Returns:
//  Structure - copy of the passed structure.
//
Function CopyStructure(SourceStructure) Export
	
	ResultStructure = New Structure;
	
	For Each Item In SourceStructure Do
		
		If TypeOf(Item.Value) = Type("ValueTable") Then
			
			ResultStructure.Insert(Item.Key, Item.Value.Copy());
			
		ElsIf TypeOf(Item.Value) = Type("ValueTree") Then
			
			ResultStructure.Insert(Item.Key, Item.Value.Copy());
			
		ElsIf TypeOf(Item.Value) = Type("Structure") Then
			
			ResultStructure.Insert(Item.Key, CopyStructure(Item.Value));
			
		ElsIf TypeOf(Item.Value) = Type("ValueList") Then
			
			ResultStructure.Insert(Item.Key, Item.Value.Copy());
			
		Else
			
			ResultStructure.Insert(Item.Key, Item.Value);
			
		EndIf;
		
	EndDo;
	
	Return ResultStructure;
EndFunction

// Retrieves the string that contains structure keys separated by the separator character.
//
// Parameters:
//  Structure - Structure - structure whose keys are converted to a string.
//  Separator - String - separator that is inserted to the string between the structure keys.
//
// Returns:
//  String - string with the separated structure keys.
//
Function StructureKeysToString(Structure, Separator = ",") Export
	
	Result = "";
	
	For Each Item In Structure Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
EndFunction

// Compares two versions of objects of the same type.
//
// Parameters:
//  Data1             - CatalogObject,
//                      DocumentObject,
//                      ChartOfCharacteristicTypesObject,
//                      ChartOfCalculationTypesObject,
//                      ChartOfAccountsObject,
//                      ExchangePlanObject,
//                      BusinessProcessObject,
//                      TaskObject - first version of data to be compared.
//  Data2             - CatalogObject,
//                      DocumentObject,
//                      ChartOfCharacteristicTypesObject,
//                      ChartOfCalculationTypesObject,
//                      ChartOfAccountsObject,
//                      ExchangePlanObject,
//                      BusinessProcessObject,
//                      TaskObject - second version of data to be compared.
//  ListOfProperties  - String - comma-separated properties of the object and its tabular sections.
//                      If this parameter is passed, object properties
//                      will be filled according to the specified
//                      properties and the ExcludingProperties parameter will be ignored.
//  ExcludeProperties - String -  comma-separated properties of the object and its tabular sections.
//                      If this parameter is passed, all properties
//                      and tabular sections will be filled, except the specified properties.
//
// Returns:
//  True if data versions have differences, False otherwise.
//
Function DataDifferent(Data1, Data2, ListOfProperties = Undefined, ExcludeProperties = Undefined) Export
	
	If TypeOf(Data1) <> TypeOf(Data2) Then
		Return True;
	EndIf;
	
	MetadataObject = Data1.Metadata();
	
	If CommonUse.IsCatalog(MetadataObject) Then
		
		If Data1.IsFolder Then
			Object1 = Catalogs[MetadataObject.Name].CreateFolder();
		Else
			Object1 = Catalogs[MetadataObject.Name].CreateItem();
		EndIf;
		
		If Data2.IsFolder Then
			Object2 = Catalogs[MetadataObject.Name].CreateFolder();
		Else
			Object2 = Catalogs[MetadataObject.Name].CreateItem();
		EndIf;
		
	ElsIf CommonUse.IsDocument(MetadataObject) Then
		
		Object1 = Documents[MetadataObject.Name].CreateDocument();
		Object2 = Documents[MetadataObject.Name].CreateDocument();
		
	ElsIf CommonUse.IsChartOfCharacteristicTypes(MetadataObject) Then
		
		If Data1.IsFolder Then
			Object1 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateFolder();
		Else
			Object1 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateItem();
		EndIf;
		
		If Data2.IsFolder Then
			Object2 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateFolder();
		Else
			Object2 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateItem();
		EndIf;
		
	ElsIf CommonUse.IsChartOfCalculationTypes(MetadataObject) Then
		
		Object1 = ChartsOfCalculationTypes[MetadataObject.Name].CreateCalculationType();
		Object2 = ChartsOfCalculationTypes[MetadataObject.Name].CreateCalculationType();
		
	ElsIf CommonUse.IsChartOfAccounts(MetadataObject) Then
		
		Object1 = ChartsOfAccounts[MetadataObject.Name].CreateAccount();
		Object2 = ChartsOfAccounts[MetadataObject.Name].CreateAccount();
		
	ElsIf CommonUse.IsExchangePlan(MetadataObject) Then
		
		Object1 = ExchangePlans[MetadataObject.Name].CreateNode();
		Object2 = ExchangePlans[MetadataObject.Name].CreateNode();
		
	ElsIf CommonUse.IsBusinessProcess(MetadataObject) Then
		
		Object1 = BusinessProcesses[MetadataObject.Name].CreateBusinessProcess();
		Object2 = BusinessProcesses[MetadataObject.Name].CreateBusinessProcess();
		
	ElsIf CommonUse.IsTask(MetadataObject) Then
		
		Object1 = Tasks[MetadataObject.Name].CreateTask();
		Object2 = Tasks[MetadataObject.Name].CreateTask();
		
	Else
		
		Raise NStr("en = 'The value of the [1] parameter for the CommonUse.PropertyValuesChanged method is not valid.'");
		
	EndIf;
	
	FillObjectPropertyValues(Object1, Data1, ListOfProperties, ExcludeProperties);
	FillObjectPropertyValues(Object2, Data2, ListOfProperties, ExcludeProperties);
	
	Return InfobaseDataString(Object1) <> InfobaseDataString(Object2);
	
EndFunction

Function InfobaseDataString(Data)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	WriteXML(XMLWriter, Data, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
	
EndFunction

// Returns an array that contains object tabular sections.
//
Function ObjectTabularSections(MetadataObject) Export
	
	Result = New Array;
	
	For Each TabularSection In MetadataObject.TabularSections Do
		
		Result.Add(TabularSection.Name);
		
	EndDo;
	
	Return Result;
EndFunction
 

// For internal use only.
//
Procedure SetNodeFilterValues(ExchangePlanNode, Settings) Export
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	SetValueOnNode(ExchangePlanNode, Settings);
	
EndProcedure

// For internal use only.
//
Procedure SetNodeDefaultValues(ExchangePlanNode, Settings) Export
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	SetValueOnNode(ExchangePlanNode, Settings);
	
EndProcedure

Procedure SetValueOnNode(ExchangePlanNode, Settings)
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	For Each Item In Settings Do
		
		Key = Item.Key;
		Value = Item.Value;
		
		If ExchangePlanNode.Metadata().Attributes.Find(Key) = Undefined
			And ExchangePlanNode.Metadata().TabularSections.Find(Key) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Value) = Type("Array") Then
			
			AttributeData = GetReferenceTypeFromFirstExchangePlanTabularSectionAttribute(ExchangePlanName, Key);
			
			If AttributeData = Undefined Then
				Continue;
			EndIf;
			
			NodeTable = ExchangePlanNode[Key];
			
			NodeTable.Clear();
			
			For Each TableRow In Value Do
				
				If TableRow.Use Then
					
					ObjectManager = CommonUse.ObjectManagerByRef(AttributeData.Type.AdjustValue());
					
					AttributeValue = ObjectManager.GetRef(New UUID(TableRow.RefUUID));
					
					NodeTable.Add()[AttributeData.Name] = AttributeValue;
					
				EndIf;
				
			EndDo;
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			FillExchangePlanNodeTable(ExchangePlanNode, Value, Key);
			
		Else // Primitive types
			
			ExchangePlanNode[Key] = Value;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillExchangePlanNodeTable(Node, TabularSectionStructure, TableName)
	
	NodeTable = Node[TableName];
	
	NodeTable.Clear();
	
	For Each Item In TabularSectionStructure Do
		
		SetTableRowCount(NodeTable, Item.Value.Count());
		
		NodeTable.LoadColumn(Item.Value, Item.Key);
		
	EndDo;
	
EndProcedure

Procedure SetTableRowCount(Table, LineCount)
	
	While Table.Count() < LineCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure

Function GetReferenceTypeFromFirstExchangePlanTabularSectionAttribute(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute In TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If CommonUse.IsReference(Type) Then
			
			Return New Structure("Name, Type", Attribute.Name, Attribute.Type);
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
EndFunction

Procedure CheckDocumentIssueSolvedPosting(Source, Cancel, PostingMode) Export
	
	InformationRegisters.DataExchangeResults.RecordIssueSolving(Source, Enums.DataExchangeProblemTypes.UnpostedDocument);
	
EndProcedure

Procedure CheckObjectIssueSolvedOnWrite(Source, Cancel) Export
	
	InformationRegisters.DataExchangeResults.RecordIssueSolving(Source, Enums.DataExchangeProblemTypes.BlankAttributes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for processing data modification conflicts during the data exchange.

// Detects conflicts during the data import and reports the detected conflicts.
Procedure CheckDataModificationConflict(DataItem, ItemReceive, Val Sender, Val IsDataReceiveFromMasterNode)
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		
		Return;
		
	ElsIf DataItem.AdditionalProperties.Property("DataExchange") And DataItem.AdditionalProperties.DataExchange.DataAnalysis Then
		
		Return;
		
	EndIf;
	
	Sender = Sender.Ref;
	ObjectMetadata = DataItem.Metadata();
	IsReferenceType = CommonUse.IsReferenceTypeObject(ObjectMetadata);
	
	HasConflict = ExchangePlans.IsChangeRecorded(Sender, DataItem);
	
	// Performing additional object modification checks.
	// If the object was not modified before and after the conflict, there is no conflict.
	If HasConflict Then
		
		If IsReferenceType And Not DataItem.Ref.IsEmpty() Then
			
			ObjectInInfobase = DataItem.Ref.GetObject();
			RefExists = (ObjectInInfobase <> Undefined);
			
		Else
			RefExists = False;
			ObjectInInfobase = Undefined;
		EndIf;
		
		ObjectRowBeforeChange = GetObjectDataStringBeforeChange(DataItem, ObjectMetadata, IsReferenceType, RefExists, ObjectInInfobase);
		ObjectRowAfterChange  = GetObjectDataStringAfterChanges(DataItem, ObjectMetadata);
		
		// If these values are equal, there is no conflict
		If ObjectRowBeforeChange = ObjectRowAfterChange Then
			
			HasConflict = False;
			
		EndIf;
		
	EndIf;
	
	If HasConflict Then
		
		DataExchangeOverridable.OnDataChangeConflict(DataItem, ItemReceive, Sender, IsDataReceiveFromMasterNode);
		
		If ItemReceive = DataItemReceive.Auto Then
			ItemReceive = ?(IsDataReceiveFromMasterNode, DataItemReceive.Accept, DataItemReceive.Ignore);
		EndIf;
		
		WriteObject = (ItemReceive = DataItemReceive.Accept);
		
		RecordWarningAboutConflictInEventLog(DataItem, ObjectMetadata, WriteObject, IsReferenceType);
		
		If Not IsReferenceType Then
			Return;
		EndIf;
			
		If DataExchangeCached.VersioningUsed(Sender) Then
			
			If RefExists Then
				
				If WriteObject Then
					Comment = NStr("en = 'The previous version (automatic conflict resolving).'");
				Else
					Comment = NStr("en = 'The current version (automatic conflict resolving).'");
				EndIf;
				
				OnCreateObjectVersion(ObjectInInfobase,,, Comment, RefExists);
				
			EndIf;
			
			If WriteObject Then
				
				ObjectVersionDetails = CommonUseClientServer.CopyStructure(
					DataItem.AdditionalProperties.ObjectVersionDetails);
				
				ObjectVersionDetails.ObjectVersionType = "DataAcceptedDuringConflict";
				ObjectVersionDetails.VersionAuthor = Sender;
				ObjectVersionDetails.Comment = NStr("en = 'The accepted version (automatic conflict resolving).'");
				
				DataItem.AdditionalProperties.ObjectVersionDetails = New FixedStructure(ObjectVersionDetails);
				
			Else
				
				Comment = NStr("en = 'The rejected version (automatic conflict resolving).'");
				OnCreateObjectVersion(DataItem, Sender, "DataNotAcceptedDuringConflict", Comment, RefExists);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks whether the import prohibition by date is enabled.
//
// Parameters:
// DataItem    - CatalogObject, DocumentObject, InformationRegisterRecordSet, and other data types.
// 					      Data that is read from the exchange message but is not yet written to the infobase.
// ItemReceive - DataItemReceive.
// Source		   - ExchangePlansRef.
//
Procedure CheckImportProhibitedByDate(DataItem, ItemReceive, Val Sender)
	
	If Sender.Metadata().DistributedInfobase Then
		Return;
	EndIf;
	
	If CommonUse.IsConstant(DataItem.Metadata()) Then
		Return;
	EndIf;
	
	ErrorMessage = "";
	If CommonUse.SubsystemExists("StandardSubsystems.EditProhibitionDates") Then
		EditProhibitionDatesModule = CommonUse.CommonModule("EditProhibitionDates");
		
		If EditProhibitionDatesModule.ImportProhibited(DataItem, Sender, ErrorMessage) = True Then
			
			RegisterDataImportProhibitionByDate(DataItem, Sender, ErrorMessage);
			ItemReceive = DataItemReceive.Ignore;
			
		EndIf;
		
	EndIf;
	
	DataItem.AdditionalProperties.Insert("IgnoreChangeProhibitionCheck");
	
EndProcedure

// Records an event log message about the data import prohibition by date.
// If the passed object has reference type and the ObjectVersioning subsystem is available,
// this object is registered in the same way as in the exchange issue monitor.
// 
// Parameters:
//  DataItem     - reference type object whose registration is prohibited.
//  Source       - ExchangePlanRef - infobase node from which the object is received.
//  ErrorMessage - String - detailed description of the reason for import cancellation.
//
// Note: To check whether the import prohibition by date is enabled,
// call the EditProhibitionDates.ImportProhibited procedure.
//
Procedure RegisterDataImportProhibitionByDate(DataItem, Source, ErrorMessage)
	
	WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
		EventLogLevel.Warning, , DataItem, ErrorMessage);
	
	If DataExchangeCached.VersioningUsed(Source) And CommonUse.IsReferenceTypeObject(DataItem.Metadata()) Then
		
		ObjectRef = DataItem.Ref;
		
		If CommonUse.RefExists(ObjectRef) Then
			
			ObjectInInfobase = ObjectRef.GetObject();
			OnCreateObjectVersion(ObjectInInfobase,,, NStr("en = 'The object version is created during the data synchronization.'"));
			ErrorMessageString = ErrorMessage;
			ObjectVersionType = "DataDeclinedByEditProhibitionDateExistsInInfobase";
			
		Else
			
			ErrorMessageString = NStr("en = 'Importing %1 in the specified period is prohibited.%2%2%3'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString,
				String(DataItem), Chars.LF, ErrorMessage);
			ObjectVersionType = "DataDeclinedByEditProhibitionDateNotExistInInfobase";
			
		EndIf;
		
		OnCreateObjectVersion(DataItem, Source, ObjectVersionType, ErrorMessageString);
		
	EndIf;
	
EndProcedure

// Creates an object version and writes it to the infobase.
//
// Parameters
// Object            - infobase object to write.
// VersionAuthor     - User or Exchange plan node - object version source.
// ObjectVersionType - Enum - type of the object version to be created.
// Comment           - String - comment for the object version that is created.
// UUIDString        - String - it is used to create an empty reference if the passed object has no reference.
//
Procedure OnCreateObjectVersion(Object, VersionAuthor = Undefined, ObjectVersionType = "ChangedByUser",
	Comment = "", RefExists = Undefined)
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		
		ObjectVersionDetails = New Structure;
		
		ObjectVersionDetails.Insert("VersionAuthor", VersionAuthor);
		ObjectVersionDetails.Insert("ObjectVersionType", ObjectVersionType);
		ObjectVersionDetails.Insert("Comment", Comment);
		
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.CreateObjectVersionByDataExchange(Object, ObjectVersionDetails, RefExists);
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure RecordWarningAboutConflictInEventLog(Object, ObjectMetadata, WriteObject, IsReferenceType)
	
	If WriteObject Then
		
		EventLogWarningText = NStr("en = 'Object modification conflict detected.
		|The object from the current infobase is replaced with the object from the second infobase.'");
		
	Else
		
		EventLogWarningText = NStr("en = 'Object modification conflict detected.
		|The object from the second infobase is rejected. The current infobase object is not modified.'");
		
	EndIf;
	
	Data = ?(IsReferenceType, Object.Ref, Undefined);
		
	WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
		EventLogLevel.Warning, ObjectMetadata, Data, EventLogWarningText);
	
EndProcedure

// For internal use only.
//
Function GetObjectDataStringBeforeChange(Object, ObjectMetadata, IsReferenceType, RefExists, ObjectInInfobase)
	
	// Return value
	ObjectString = "";
	
	If IsReferenceType Then
		
		If RefExists Then
			
			// Getting object presentation by the reference from the infobase
			ObjectString = CommonUse.ValueToXMLString(ObjectInInfobase);
			
		Else
			
			ObjectString = "Object is deleted";
			
		EndIf;
		
	ElsIf CommonUse.IsConstant(ObjectMetadata) Then
		
		// Getting constant value from the infobase
		ObjectString = XMLString(Constants[ObjectMetadata.Name].Get());
		
	Else // Record set
		
		OldRecordSet = GetRecordSet(Object);
		ObjectString = CommonUse.ValueToXMLString(OldRecordSet);
		
	EndIf;
	
	Return ObjectString;
	
EndFunction

// For internal use only.
//
Function GetObjectDataStringAfterChanges(Object, ObjectMetadata)
	
	// Return value
	ObjectString = "";
	
	If CommonUse.IsConstant(ObjectMetadata) Then
		
		ObjectString = XMLString(Object.Value);
		
	Else
		
		ObjectString = CommonUse.ValueToXMLString(Object);
		
	EndIf;
	
	Return ObjectString;
	
EndFunction

#EndRegion