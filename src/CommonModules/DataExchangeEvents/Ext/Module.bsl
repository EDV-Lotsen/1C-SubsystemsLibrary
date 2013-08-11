////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Determines the sending kind of the data item to be exported.
// Is called from the following exchange plan handlers: 
//  - OnSendDataToMaster();
//  - OnSendDataToSubordinate().
//
// Parameters:
//  DataItem, ItemSending - for details, see the OnSendDataToMaster() and
//                          OnSendDataToSubordinate() parameter descriptions in the
//                          syntax assistant.
//  InfoBaseNode          - ExchangePlanRef - current exchange plan node for which data
//                          will be exported.
//  ExchangePlanName      - String - exchange plan name as it is set in the designer.
//
// Note:
//  It is desirable to update the object registration mechanism cache before the
//  procedure execution. Call DataExchangeServer.RefreshORMCachedValuesIfNecessary() to do it.
//
Procedure OnSendData(DataItem, ItemSending, InfoBaseNode, Val ExchangePlanName, Val CreatingInitialImage) Export
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return; // Sending the object deletion as it is
	EndIf;
	
	MetadataObject = DataItem.Metadata();
	
	If Not DataExchangeCached.RecordChangesAccordingToObjectChangeRecordRules(ExchangePlanName, MetadataObject.FullName()) Then
		Return; // No filter required
	EndIf;
	
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
	
	If BaseTypeName = CommonUse.TypeNameCatalogs()
		Or BaseTypeName = CommonUse.TypeNameDocuments()
		Or BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes()
		Or BaseTypeName = CommonUse.TypeNameChartsOfAccounts()
		Or BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes()
		Or BaseTypeName = CommonUse.TypeNameBusinessProcesses()
		Or BaseTypeName = CommonUse.TypeNameTasks() Then
		
		// Defining an array of nodes for the the object registration.
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
		
		
		NumberInArray = NodeArrayForObjectChangeRecord.Find(InfoBaseNode);
		
		// Sending the object deletion if the current node is not found in the array 
		If NumberInArray = Undefined Then
			
			ItemSending = ?(CreatingInitialImage, DataItemSend.Ignore, DataItemSend.Delete);
			
		EndIf;
		
	ElsIf BaseTypeName = CommonUse.TypeNameInformationRegisters()
			Or BaseTypeName = CommonUse.TypeNameAccumulationRegisters()
			Or BaseTypeName = CommonUse.TypeNameAccountingRegisters()
			Or BaseTypeName = CommonUse.TypeNameCalculationRegisters() Then
		
			DataItem.AdditionalProperties.Insert("InfoBaseNode", InfoBaseNode);
			
			ExecuteObjectChangeRecordRulesForExchangePlan(New Array,
															DataItem,
															ExchangePlanName,
															MetadataObject,
															,
															True,
															,
															,
															,
															True);
			
			
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedure and function to be used in the registration rule event handlers.

// Supplements the object recipient node list with the passed values.
//
// Parameters:
//  Object – object for which the registration rule must be executed.
//  Nodes  – Array – exchange plan nodes to be added to the object recipient node list. 
//
Procedure SupplementRecipients(Object, Nodes) Export
	
	For Each Item In Nodes Do
		
		Try
			
			Object.DataExchange.Recipients.Add(Item);
			
		Except
			
			// Writing the error to the event log
			ExchangePlanName = Item.Metadata().Name;
			
			MetadataObject = Object.Metadata();
			
			MessageString = NStr("en = 'The [FullName] object registration is not specified for the [ExchangePlanName] exchange plan content.'");
			MessageString = StrReplace(MessageString, "[ExchangePlanName]", ExchangePlanName);
			MessageString = StrReplace(MessageString, "[FullName]",      	MetadataObject.FullName());
			
			WriteEventLogORR(MessageString, MetadataObject);
			
		EndTry;
		
	EndDo;
	
EndProcedure

// Deletes the passed values from the object recipient node list.
//
// Parameters:
//  Object – object for which the registration rule must be executed.
//  Nodes  – Array – exchange plan nodes to be deleted from the object recipient node list.
// 
Procedure ReduceRecipients(Object, Nodes) Export
	
	Recipients = ReduceArray(Object.DataExchange.Recipients, Nodes);
	
	// Clearing the recipient list and filling it over again.
	Object.DataExchange.Recipients.Clear();
	
	// Adding nodes for the object registration.
	SupplementRecipients(Object, Recipients);
	
EndProcedure

// Generates an array of recipient nodes for the object of the specified exchange plan and registers object in this nodes.

// Parameters:
//  Object            - object to be registered in nodes.
//  ExchangePlanName  - String - exchange plan name as it is set in the designer.
//  Sender (Optional) – ExchangePlanRef – exchange plan node that sends the exchange
//                      message. Objects are not registered in this node if it is set.
// 
Procedure ExecuteObjectChangeRecordRulesForObject(Object, ExchangePlanName, Sender = Undefined) Export
	
	Recipients = GetRecipients(Object, ExchangePlanName);
	
	CommonUseClientServer.DeleteValueFromArray(Recipients, Sender);
	
	If Recipients.Count() > 0 Then
		
		ExchangePlans.RecordChanges(Recipients, Object);
		
	EndIf;
	
EndProcedure

// Subtracts one array of elements from another. Returns the result of subtraction.
//
Function ReduceArray(Array, SubstractionArray) Export
	
	Return CommonUseClientServer.ReduceArray(Array, SubstractionArray);
	
EndFunction

// Retrieves an array of all nodes except the predefined one for the specified exchange plan.
// 
// Parameters:
// ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
// NodeArray - Array - array of all nodes except the predefined one for the specified
// exchange plan.
//
Function AllExchangePlanNodes(ExchangePlanName) Export
	
	Return DataExchangeServer.AllExchangePlanNodes(ExchangePlanName);
	
EndFunction

// Retrieves an array of recipient nodes for the object from the specified exchange plan.
// 
// Parameters:
//  Object           - object whose recipient node list will be returned.
//  ExchangePlanName - String - exchange plan name as it is set in the designer.
// 
// Returns:
//  NodeArrayResult  - Array - array of target nodes for the object.
//
Function GetRecipients(Object, ExchangePlanName) Export
	
	NodeArrayResult = New Array;
	
	MetadataObject = Object.Metadata();
	
	IsRegister = CommonUse.IsRegister(MetadataObject);
	
	ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName, MetadataObject, False, IsRegister);
	
	Return NodeArrayResult;
	
EndFunction

// Checking whether AutoChangeRecord for the metadata object from the exchange plan
// is allowed.
//
// Parameters:
// MetadataObject (Mandatory)   – metadata object whose AutoChangeRecord flag will be checked.
// ExchangePlanName (mandatory) – String – exchange plan name as it is set in the 
//                                designer. The name of the plan that contains the 
//                                metadata object.
//
// Returns:
//  Boolean. True if AutoChangeRecord of the metadata object is allowed, False if 
//  AutoChangeRecord of the metadata object is denied or the exchange plan does not
//  contain the metadata object.
//
Function AutoChangeRecordAllowed(MetadataObject, ExchangePlanName) Export
	
	Return DataExchangeCached.AutoChangeRecordAllowed(ExchangePlanName, MetadataObject.FullName());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism (ORM).

// BeforeWrite event handler of documents for the object registration mechanism. 
//
// Parameters:
//  ExchangePlanName – String – name of the exchange plan for which the object 
//                     registration mechanism is executed.
//  Source           - DocumentObject - event source.
//  Cancel           - Boolean - cancel flag.
// 
Procedure ObjectChangeRecordMechanismBeforeWriteDocument(ExchangePlanName, Source, Cancel, WriteMode, PostingMode) Export
	
	ObjectChangeRecordMechanism(ExchangePlanName, Source, Cancel, WriteMode);
	
EndProcedure

// BeforeWrite event handler of all reference types (except documents) for the object 
// registration mechanism.
//
// Parameters:
//  ExchangePlanName – String – name of the exchange plan for which the object
//                     registration mechanism is executed.
//  Source           - DocumentObject - event source.
//  Cancel           - Boolean - cancel flag.
// 
Procedure ObjectChangeRecordMechanismBeforeWrite(ExchangePlanName, Source, Cancel) Export
	
	ObjectChangeRecordMechanism(ExchangePlanName, Source, Cancel);
	
EndProcedure

// BeforeWrite event handler of registers for the object registration mechanism.
//
// Parameters: 
//  ExchangePlanName – String – name of the exchange plan for which the object
//                     registration mechanism is executed.
//  Source           - DocumentObject - event source.
//  Cancel           - Boolean - cancel flag.
//  Replacing        - Boolean - flag that shows whether the record set will be replaced 
//                     if it exists.
// 
Procedure ObjectChangeRecordMechanismBeforeWriteRegister(ExchangePlanName, Source, Cancel, Replacing) Export
	
	ObjectChangeRecordMechanism(ExchangePlanName, Source, Cancel,, Replacing, True);
	
EndProcedure

// BeforeWrite event handler of constants for the object registration mechanism. 
//
// Parameters:
//  ExchangePlanName – String – name of the exchange plan for which the object 
//                     registration mechanism is executed.
//  Source           - DocumentObject - event source.
//  Cancel           - Boolean - cancel flag.
// 
Procedure ObjectChangeRecordMechanismBeforeWriteConstant(ExchangePlanName, Source, Cancel) Export
	
	ObjectChangeRecordMechanism(ExchangePlanName, Source, Cancel,,,,, True);
	
EndProcedure

// BeforeDelete event handler of reference types for the object registration mechanism.
//
// Parameters:
//  ExchangePlanName – String – name of the exchange plan for which the object
//                     registration mechanism is executed.
//  Source           - DocumentObject - event source.
//  Cancel           - Boolean - cancel flag.
// 
Procedure ObjectChangeRecordMechanismBeforeDelete(ExchangePlanName, Source, Cancel) Export
	
	ObjectChangeRecordMechanism(ExchangePlanName, Source, Cancel,,,, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

Procedure BeforeCheckEditProhibition(Object, StandardProcessing, ExchangePlanNode, InformAboutProhibition) Export
	
	If Object.AdditionalProperties.Property("DontCheckEditProhibitionDates") Then
		
		StandardProcessing = False;
		
	ElsIf Object.DataExchange.Load Then
		
		Sender = Object.DataExchange.Sender;
		
		If Sender = Undefined Then
			
			Object.AdditionalProperties.Property("DataExchange_Sender", Sender);
			
		EndIf;
		
		If Sender <> Undefined Then
			
			If DataExchangeCached.IsDistributedInfoBaseNode(Sender) Then
				
				// Skipping the check of the edit prohibition date when exchanging in the DIB
				StandardProcessing = False;
				
			Else
				
				StandardProcessing = False;
				
				ExchangePlanNode = Sender;
				
				InformAboutProhibition = False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// For internal use only.
//
Procedure RecordDataMigrationRestrictionFilterChanges(Source, Cancel) Export
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // writing the node when receiving the exchange message (universal data exchange)
	ElsIf Not DataExchangeCached.IsSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf DataExchangeCached.IsPredefinedExchangePlanNode(Source.Ref) Then
		Return;
	EndIf;
	
	SourceRef = CommonUse.GetAttributeValues(Source.Ref, "SentNo, ReceivedNo");
	
	If SourceRef.SentNo <> Source.SentNo Then
		Return; // writing the node when sending the exchange message
	ElsIf SourceRef.ReceivedNo <> Source.ReceivedNo Then
		Return; // writing the node when receiving the exchange message
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Source.Ref);
	
	// Getting reference type attributes that are presumably used as registration rule
	// filter filters.
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
	
	ReferenceTypeAttributeTable = Undefined;
	
	If Source.AdditionalProperties.Property("NodeAttributeTable", ReferenceTypeAttributeTable) Then
		
		// Registering selected objects of reference types on the current node using no
		// object registration rules.
		RecordReferenceTypeObjectChangesByNodeProperties(Source, ReferenceTypeAttributeTable);
		
		// Updating cached values of the mechanism
		DataExchangeServer.SetORMCachedValueRefreshDate();
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure EnableUseExchangePlan(Source, Cancel) Export
	
	If Source.IsNew() And DataExchangeCached.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		
		// The open session cache became obsolete for the object registration mechanism
		DataExchangeServer.SetORMCachedValueRefreshDate();
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure DisableUseExchangePlan(Source, Cancel) Export
	
	If DataExchangeCached.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		
		// The open session cache became obsolete for the object registration mechanism
		DataExchangeServer.SetORMCachedValueRefreshDate();
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure CanChangeDataExchangeSettings(Source, Cancel) Export
	
	If Not Source.AdditionalProperties.Property("GettingExchangeMessage")
		And Not Source.IsNew()
		And Not DataExchangeCached.IsPredefinedExchangePlanNode(Source.Ref)
		And DataExchangeCached.IsSLDataExchangeNode(Source.Ref)
		And DataDifferent(Source, Source.Ref.GetObject(),, "SentNo, ReceivedNo, DeletionMark, Code, Description")
		And DataExchangeServer.ChangesRegistered(Source.Ref)
		Then
		
		DetailErrorDescription = NStr("en = 'Data exchange settings cannot be changed
												|because of registered exchange data changes.
												|Execute data exchange twice and try to change settings again.'"
		);
		
		CommonUseClientServer.MessageToUser(DetailErrorDescription,,,, Cancel);
		
		WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,, Source.Ref, DetailErrorDescription);
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure CancelSendNodeDataInDistributedInfoBase(Source, DataItem, Ignore) Export
	
	Ignore = True;
	
EndProcedure

// For internal use only.
//
Procedure RegisterCommonNodeDataChanges(Source, Cancel) Export
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // writing the node when receiving the exchange message (universal data exchange)
	ElsIf Not DataExchangeCached.IsSLDataExchangeNode(Source.Ref) Then
		Return;
	EndIf;
	
	CommonNodeData = DataExchangeCached.CommonNodeData(Source.Ref);
	
	If IsBlankString(CommonNodeData) Then
		Return;
	EndIf;
	
	If DataExchangeCached.IsDistributedInfoBaseNode(Source.Ref) Then
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
Procedure OnSendDataToSubordinate(Source, DataItem, ItemSending, CreatingInitialImage) Export
	
	If DataExchangeCached.IsSLDataExchangeNode(Source.Ref) Then
		
		If TypeOf(DataItem) = Type("ConstantValueManager.UseDataExchangeLocalMode") Then
			
			DataItem.Value = True;
			
		ElsIf TypeOf(DataItem) = Type("ConstantValueManager.UseDataExchangeServiceMode") Then
			
			DataItem.Value = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure OnReceiveDataFromSubordinate(Source, DataItem, ItemReceive, SendBack) Export
	
	If DataExchangeCached.IsSLDataExchangeNode(Source.Ref) Then
		
		If CommonUseCached.DataSeparationEnabled() Then
			
			If TypeOf(DataItem) = Type("ConstantValueManager.UseDataExchangeLocalMode") Then
				
				DataItem.Value = False;
				
			ElsIf TypeOf(DataItem) = Type("ConstantValueManager.UseDataExchangeServiceMode") Then
				
				DataItem.Value = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object registration mechanism (ORM).

// The object registration mechanism procedure. Determines the list of exchange plan 
// target nodes where the object must be registered to be exported.
// Consists of the SOR and ORR mechanisms.
// SOR - mechanism of selective object registration;
// ORR - mechanism of object registration with registration rules;
// The SOR mechanism is executed first, then the PRO mechanism is executed.
// The SOR mechanism determines in which exchange plans the object must be registered;
// The ORR mechanism determines in which nodes of each exchange plan the object must be
// registered.
//
// Parameters:
//  Object - CatalogObject or DocumentObject - object whose attribute values and other 
//           properties will be retrieved.
//  Cancel - Boolean - cancel flag. It is set to True if errors occur during the
//           procedure execution.
// 
Procedure ObjectChangeRecordMechanism(ExchangePlanName,
										Object,
										Cancel,
										WriteMode = Undefined,
										Replacing = False,
										IsRegister = False,
										IsObjectDeletion = False,
										IsConstant = False
	)
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	DisableObjectChangeRecordMechanism = False;
	If  Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism", DisableObjectChangeRecordMechanism)
		And DisableObjectChangeRecordMechanism = True Then
		
		Return; // The object registration mechanism execution has been canceled
	EndIf;
	
	// Checking whether the cache is relevant for the object registration mechanism
	DataExchangeServer.RefreshORMCachedValuesIfNecessary();
	
	If Not DataExchangeServer.DataExchangeEnabled() Then
		Return;
	EndIf;
	
	// Checking whether the object must be registered in the sender node
	RegisterObjectInSenderNode = False;
	If  Object.AdditionalProperties.Property("RegisterObjectInSenderNode", RegisterObjectInSenderNode)
		And RegisterObjectInSenderNode = True Then
		
		// Clearing the reference to the sender node
		Object.DataExchange.Sender = Undefined;
		
	EndIf;
	
	MetadataObject = Object.Metadata();
	
	// Skipping SOR if the object has been deleted physically
	RecordObjectChangeToExport = IsRegister Or IsObjectDeletion Or IsConstant;
	
	ObjectModified = ObjectModifiedForExchangePlan(Object, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport);
	
	If Not ObjectModified Then
		
		If DataExchangeCached.AutoChangeRecordAllowed(ExchangePlanName, MetadataObject.FullName()) Then
			
			// Deleting all nodes where the object was registered automatically from the
			// recipient list if object was not modified and it is registered automatically.
			ReduceRecipients(Object, AllExchangePlanNodes(ExchangePlanName));
			
		EndIf;
		
		// Skipping the registration in the node if the object has not been modified
		// relative to the current exchange plan.
		Return;
		
	EndIf;
	
	If Not DataExchangeCached.AutoChangeRecordAllowed(ExchangePlanName, MetadataObject.FullName()) Then
		
		CheckRef = ?(IsRegister Or IsConstant, False, Not Object.IsNew() And Not IsObjectDeletion);
		
		NodeArrayResult = New Array;
		
		ExecuteObjectChangeRecordRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName, MetadataObject, CheckRef, IsRegister, IsObjectDeletion, Replacing, WriteMode);
		
		// After define recipients event handler
		DataExchangeOverridable.AfterGetRecipients(Object, NodeArrayResult, ExchangePlanName);
		
		SupplementRecipients(Object, NodeArrayResult);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Selective object registration (SOR).

Function ObjectModifiedForExchangePlan(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	Try
		ObjectModified = ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport);
	Except
		ObjectModified = True;
		ErrorMessage = NStr("en = 'Error determining whether the object has been modified: %1'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, DetailErrorDescription(ErrorInfo()));
		WriteEventLogORR(ErrorMessage, MetadataObject);
	EndTry;
	
	Return ObjectModified;
EndFunction

Function ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	If    RecordObjectChangeToExport
		Or Source.IsNew()
		Or Source.DataExchange.Load Then
		
		// Changes of the following object are registered always:
		//  - register record sets;
		//  - objects that were physically deleted;
		//  - new objects;
		//  - objects written with the data exchange.
		Return True;
		
	ElsIf  WriteMode <> Undefined
		And DocumentPostingChanged(Source, WriteMode) Then
		
		// If the Posted flag has been changed, the document is considered as modified
		Return True;
	EndIf;
	
	ObjectName = MetadataObject.FullName();
	
	ChangeRecordAttributeTable = DataExchangeCached.GetChangeRecordAttributeTable(ObjectName, ExchangePlanName);
	
	If ChangeRecordAttributeTable.Count() = 0 Then
		
		// If no SOR rules are set, considering that there is no SOR filter and the object
		// is always modified.
		Return True;
		
	EndIf;
	
	For Each ChangeRecordAttributeTableRow In ChangeRecordAttributeTable Do
		
		HasObjectVersionChanges = GetObjectVersionChanges(Source, ChangeRecordAttributeTableRow);
		
		If HasObjectVersionChanges Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	// The object has not been changed relative to registration details, the registration
	// is not required.
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
	  + " FROM " + ChangeRecordAttributeTableRow.ObjectName + " AS CurrentObject
	|WHERE
	|   CurrentObject.Ref = &Ref
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
	+ "." + ChangeRecordAttributeTableRow.TabularSectionName + " AS CurrentObjectTabularSectionName
	|WHERE
	|   CurrentObjectTabularSectionName.Ref = &Ref
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
	
	ResultTable.GroupBy(ChangeRecordAttributeTableRow.ChangeRecordAttributes, "ChangeRecordAttributeTableIterator");
	
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
		
		ErrorMessage = NStr("en = 'Error executing object registration rules for the %1 exchange plan.
								|Error details: %2'");
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, ExchangePlanName, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
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
															Data
	)
	
	ObjectChangeRecordRules = New Array;
	
	Rules = ObjectChangeRecordRules(ExchangePlanName, MetadataObject.FullName());
	
	For Each Rule In Rules Do
		
		ObjectChangeRecordRules.Add(ChangeRecordRuleStructure(Rule, Rules.Columns));
		
	EndDo;
	
	If ObjectChangeRecordRules.Count() = 0 Then // registration rules are not set
		
		// Registering the object in all exchange plan nodes except the predefined one if 
		// the ORR for the object are not specified and the automatic registration is 
		// disable.
		Recipients = AllExchangePlanNodes(ExchangePlanName);
		
		CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
		
	Else // Executing registration rules sequentially
		
		If IsRegister Then // for the register
			
			For Each ORR In ObjectChangeRecordRules Do
				
				// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "BY CONDITION"
				
				GetRecipientsByConditionForRecordSet(NodeArrayResult, ORR, Object, MetadataObject, ExchangePlanName, Replacing, Data);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "ALWAYS"
					
					Recipients = DataExchangeServer.GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, ORR.FlagAttributeName);
					
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
					
					Recipients = DataExchangeServer.GetNodeArrayForChangeRecordExportAlways(ExchangePlanName, ORR.FlagAttributeName);
					
					CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "IF NECESSARY"
					
					If Not Object.IsNew() Then
						
						Recipients = DataExchangeServer.GetNodeArrayForChangeRecordExportIfNecessary(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
						
						CommonUse.FillArrayWithUniqueValues(NodeArrayResult, Recipients);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ExecuteObjectChangeRecordRuleForRecordSet(NodeArrayResult,
															ORR,
															Object,
															MetadataObject,
															ExchangePlanName,
															Replacing,
															Data
	)
	
	// Getting the array of recipient nodes by the current record set
	GetRecipientArrayByRecordSet(NodeArrayResult, Object, ORR, MetadataObject, ExchangePlanName, False, Data);
	
	If Replacing Then
		
		// Getting the old record set from the global context
		BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
		
		If BaseTypeName = CommonUse.TypeNameInformationRegisters() Then
			
			OldRecordSet = InformationRegisters[MetadataObject.Name].CreateRecordSet();
			
		ElsIf BaseTypeName = CommonUse.TypeNameAccumulationRegisters() Then
			
			OldRecordSet = AccumulationRegisters[MetadataObject.Name].CreateRecordSet();
			
		ElsIf BaseTypeName = CommonUse.TypeNameAccountingRegisters() Then
			
			OldRecordSet = AccountingRegisters[MetadataObject.Name].CreateRecordSet();
			
		ElsIf BaseTypeName = CommonUse.TypeNameCalculationRegisters() Then
			
			OldRecordSet = CalculationRegisters[MetadataObject.Name].CreateRecordSet();
			
		Else
			
			Return; // Internal error (error embedding the library)
			
		EndIf;
		
		For Each SelectValue In Object.Filter Do
			
			If SelectValue.Use = False Then
				Continue;
			EndIf;
			
			FilterRow = OldRecordSet.Filter.Find(SelectValue.Name);
			FilterRow.Value = SelectValue.Value;
			FilterRow.Use = True;
			
		EndDo;
		
		OldRecordSet.Read();
		
		// Defining an array of components-recipients to old set records
		GetRecipientArrayByRecordSet(NodeArrayResult, OldRecordSet, ORR, MetadataObject, ExchangePlanName, True, Data);
		
	EndIf;
	
EndProcedure

Procedure ExecuteObjectChangeRecordRuleForReferenceType(NodeArrayResult,
															ORR,
															Object,
															ExchangePlanName,
															CheckRef,
															IsObjectDeletion,
															WriteMode,
															Data
	)
	
	// ORROP  - registration rules by object properties
	// ORREPP -  registration rules by exchange plan properties
	// PRO = ORROP <And> ORREPP
	
	// ORROP
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
										Data
	)
	
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
														Data
	)
	
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
										Data
	)
	
	// Getting property value structure for the object
	ObjectPropertyValues = GetPropertyValuesForObject(Source, ORR);
	
	// Defining an array of nodes for the object registration
	NodeArray = GetNodeArrayByPropertyValues(ObjectPropertyValues, ORR, ExchangePlanName, Source, Data);
	
	// Adding nodes for the registration
	CommonUse.FillArrayWithUniqueValues(NodeArrayResult, NodeArray);
	
	If CheckRef Then
		
		// Getting the property value structure for the reference
		RefPropertyValues = DataExchangeServer.GetPropertyValuesForRef(Source.Ref, ORR.ObjectProperties, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
		
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
													Data
	)
	
	// Getting the value of the recorder from the filter for the record set
	Recorder = Undefined;
	
	FilterItem = RecordSet.Filter.Find("Recorder");
	
	HasRecorder = FilterItem <> Undefined;
	
	If HasRecorder Then
		
		Recorder = FilterItem.Value;
		
	EndIf;
	
	If Data Then
		
		InfoBaseNode = RecordSet.AdditionalProperties.InfoBaseNode;
		
		ReverseIndex = RecordSet.Count() - 1;
		
		While ReverseIndex >= 0 Do
			
			ORR_SetRows = CopyStructure(ORR);
			
			SetRow = RecordSet[ReverseIndex];
			
			If HasRecorder And SetRow["Recorder"] = Undefined Then
				
				If Recorder <> Undefined Then
					
					SetRow["Recorder"] = Recorder;
					
				EndIf;
				
			EndIf;
			
			// ORROP
			If Not ObjectPassedChangeRecordRuleFilterByProperties(ORR_SetRows, SetRow, False) Then
				
				RecordSet.Delete(ReverseIndex);
				
			Else // ORREPP
				
				ObjectPropertyValues = GetPropertyValuesForObject(SetRow, ORR_SetRows);
				
				// Defining an array of nodes for the object registration
				NodeArray = GetNodeArrayByPropertyValues(ObjectPropertyValues, ORR_SetRows, ExchangePlanName, SetRow, Data);
				
				NumberInArray = NodeArray.Find(InfoBaseNode);
				
				// Deleting the row from the set if the array does not contain the current node
				If NumberInArray = Undefined Then
					
					RecordSet.Delete(ReverseIndex);
					
				EndIf;
				
			EndIf;
			
			ReverseIndex = ReverseIndex - 1;
			
		EndDo;
		
	Else
		
		For Each SetRow In RecordSet Do
			
			ORR_SetRows = CopyStructure(ORR);
			
			If HasRecorder And SetRow["Recorder"] = Undefined Then
				
				If Recorder <> Undefined Then
					
					SetRow["Recorder"] = Recorder;
					
				EndIf;
				
			EndIf;
			
			// ORROP
			If Not ObjectPassedChangeRecordRuleFilterByProperties(ORR_SetRows, SetRow, False) Then
				
				Continue;
				
			EndIf;
			
			// ORREPP
			
			// Getting the property value structure for the object
			ObjectPropertyValues = GetPropertyValuesForObject(SetRow, ORR_SetRows);
			
			If IsObjectVersionBeforeChanges Then
				
				// Defining an array of nodes for the object registration
				NodeArray = GetNodeArrayByPropertyValuesAdditional(ObjectPropertyValues, ORR_SetRows, ExchangePlanName, SetRow);
				
			Else
				
				// Defining an array of nodes for the object registration
				NodeArray = GetNodeArrayByPropertyValues(ObjectPropertyValues, ORR_SetRows, ExchangePlanName, SetRow, Data);
				
			EndIf;
			
			// Adding nodes for the registration
			CommonUse.FillArrayWithUniqueValues(NodeArrayResult, NodeArray);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function GetNodeArrayByPropertyValues(PropertyValues, ORR, Val ExchangePlanName, Object, Data)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {HANDLER: On processing} Start
	Cancel = False;
	
	ExecuteORRHandlerOnProcess(Cancel, ORR, Object, QueryText, PropertyValues, UseCache, Data);
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {HANDLER: On processing} End
	
	If UseCache Then
		
		Return DataExchangeCached.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	Else
		
		Return DataExchangeServer.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	EndIf;
	
EndFunction

Function GetNodeArrayByPropertyValuesAdditional(PropertyValues, ORR, Val ExchangePlanName, Object)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {HANDLER: On processing (additional)} Start
	Cancel = False;
	
	ExecuteORRHandlerOnProcessAdditional(Cancel, ORR, Object, QueryText, PropertyValues, UseCache);
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {HANDLER: On processing (additional)} End
	
	If UseCache Then
		
		Return DataExchangeCached.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	Else
		
		Return DataExchangeServer.NodeArrayByPropertyValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	EndIf;
	
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
	
	// Getting the value considering the property indirection possibility
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
		
		CulKey = Column.Name;
		Value = Rule[CulKey];
		
		If TypeOf(Value) = Type("ValueTable") Then
			
			Result.Insert(CulKey, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("ValueTree") Then
			
			Result.Insert(CulKey, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			Result.Insert(CulKey, CopyStructure(Value));
			
		Else
			
			Result.Insert(CulKey, Value);
			
		EndIf;
		
	EndDo;
	
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

// Retrieving constant values that are calculated by the arbitrary expressions.
// Values are calculated in privileged mode.
//
Procedure GetConstantAlgorithmValues(ORR, ValueTree)
	
	For Each TreeRow In ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			GetConstantAlgorithmValues(ORR, TreeRow);
			
		Else
			
			If TreeRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				Value = Undefined;
				
				Try
					
					DataExchangeServer.ExecuteHandlerInPrivilegedMode(Value, TreeRow.ConstantValue);
					
				Except
					
					// Writing error message to the event log
					MessageString = NStr("en = 'Error determining the constant value:
												|Exchange plan: [ExchangePlanName]
												|Metadata object: [MetadataObjectName]
												|Error details: [Details]
												|Algorithm:
												|// {Algorithm start}
												|[ConstantValue]
												|// {Algorithm end}
												|'");
					
					MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
					MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
					MessageString = StrReplace(MessageString, "[Details]",            ErrorInfo().Details);
					MessageString = StrReplace(MessageString, "[ConstantValue]",   String(TreeRow.ConstantValue));
					
					WriteEventLogORR(MessageString);
					
				EndTry;
				
				TreeRow.ConstantValue = Value;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ObjectHasProperties(Object, Val ObjectPropertyRow)
	
	Value = Object;
	
	SubstringArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(ObjectPropertyRow, ".");
	
	// Getting the value considering the property indirection possibility
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
// If the object passed the ORROP filter by the reference value,
// skipping ORROP for object values.
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
	If ObjectPassesORROPFilter(ORR, Object) Then
		
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
		If ObjectPassesORROPFilter(ORR, Object.Ref) Then
			
			Return True;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function ObjectPassesORROPFilter(ORR, Object)
	
	ORR.FilterByProperties = DataProcessors.ObjectChangeRecordRuleImport.FilterByObjectPropertiesTableInitialization();
	
	CreateValidFilterByProperties(Object, ORR.FilterByProperties, ORR.FilterByObjectProperties);
	
	FillPropertyValuesFromObject(ORR.FilterByProperties, Object);
	
	Return ConditionIsTrueForValueTreeBranch(ORR.FilterByProperties);
	
EndFunction

// By default, filter items of the root group are compared by the AND condition
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
// Procedures for working with the event log.

// Adds one record to the event log for the object registration rules subsystem.
//
Procedure WriteEventLogORR(Comment, MetadataObject = Undefined) Export
	
	WriteLogEvent(NStr("en = 'Data exchange. Object registration rules.'"), EventLogLevel.Error, MetadataObject, , Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object registration rule events (ORR events).

Procedure ExecuteORRBeforeProcessHandler(ORR, Cancel, Object, MetadataObject, Val Data)
	
	If ORR.HasBeforeProcessHandler Then
		
		Try
			
			Execute(ORR.BeforeProcess);
			
		Except
			
			// Writing the error message to the event log
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'Before processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			WriteEventLogORR(MessageString, MetadataObject);
			
			// Error flag
			Cancel = True;
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcess(Cancel, ORR, Object, QueryText, QueryParameters, UseCache, Val Data)
	
	If ORR.HasOnProcessHandler Then
		
		Try
			
			Execute(ORR.OnProcess);
			
		Except
			
			// Writing the error message to the event log
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'On processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			WriteEventLogORR(MessageString);
			
			// Error flag
			Cancel = True;
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcessAdditional(Cancel, ORR, Object, QueryText, QueryParameters, UseCache)
	
	If ORR.HasOnProcessHandlerAdditional Then
		
		Try
			
			Execute(ORR.OnProcessAdditional);
			
		Except
			
			// Writing the error message to the event log
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'On processing (additional)'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			WriteEventLogORR(MessageString);
			
			// Error flag
			Cancel = True;
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRAfterProcessHandler(ORR, Cancel, Object, MetadataObject, Recipients, Val Data)
	
	If ORR.HasAfterProcessHandler Then
		
		Try
			
			Execute(ORR.AfterProcess);
			
		Except
			
			// Writing the error message to the event log
			MessageString = NStr("en = 'Error executing the [HandlerName] handler; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]; Error details: [Details].'");
			
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'After processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			WriteEventLogORR(MessageString, MetadataObject);
			
			// Error flag
			Cancel = True;
			
		EndTry;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// Fills values of attributes and tabular parts of infobase objects of the same type.
//
// Parameters:
//  Source (mandatory)            – infobase object (CatalogObject, DocumentObject,
//                                  ChartOfCharacteristicTypesObject, and so on) 
//                                  that is the data source.
//
// Target (mandatory)             – infobase object (CatalogObject, DocumentObject,
//                                  ChartOfCharacteristicTypesObject and so on) that  
//                                  will be filled with source data.
//
// PropertyList (optional)        - String - comma-separated properties of object and
//                                  table parts. If this parameter is passed, object
//                                  properties will be filled according to the specified
//                                  properties and the ExcludingProperties parameter 
//                                  will be ignored.
//
// ExcludingProperties (optional) - String - comma-separated properties of object and
//                                  table parts. If this parameter is passed, all
//                                  properties and table parts will be filled, except
//                                  the specified properties.
//
Procedure FillObjectPropertyValues(Target, Source, Val PropertyList = Undefined, Val ExcludingProperties = Undefined) Export
	
	If PropertyList <> Undefined Then
		
		PropertyList = StrReplace(PropertyList, " ", "");
		
		PropertyList = StringFunctionsClientServer.SplitStringIntoSubstringArray(PropertyList);
		
		MetadataObject = Target.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		HeaderPropertyList = New Array;
		UsedTabularSections = New Array;
		
		For Each Property In PropertyList Do
			
			If TabularSections.Find(Property) <> Undefined Then
				
				UsedTabularSections.Add(Property);
				
			Else
				
				HeaderPropertyList.Add(Property);
				
			EndIf;
			
		EndDo;
		
		HeaderPropertyList = StringFunctionsClientServer.GetStringFromSubstringArray(HeaderPropertyList);
		
		FillPropertyValues(Target, Source, HeaderPropertyList);
		
		For Each TabularSection In UsedTabularSections Do
			
			Target[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	ElsIf ExcludingProperties <> Undefined Then
		
		FillPropertyValues(Target, Source,, ExcludingProperties);
		
		MetadataObject = Target.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection In TabularSections Do
			
			If Find(ExcludingProperties, TabularSection) <> 0 Then
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
	
	InfoBaseNode = Object.Ref;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
	
	For Each TableRow In ReferenceTypeAttributeTable Do
		
		If IsBlankString(TableRow.TabularSectionName) Then // header attributes
			
			For Each Item In TableRow.ChangeRecordAttributeStructure Do
				
				Ref = Object[Item.Key];
				
				If Not Ref.IsEmpty()
					And ExchangePlanContentContainsType(ExchangePlanName, TypeOf(Ref)) Then
					
					ExchangePlans.RecordChanges(InfoBaseNode, Ref);
					
				EndIf;
				
			EndDo;
			
		Else // Tabular section attributes
			
			TabularSection = Object[TableRow.TabularSectionName];
			
			For Each TabularSectionRow In TabularSection Do
				
				For Each Item In TableRow.ChangeRecordAttributeStructure Do
					
					Ref = TabularSectionRow[Item.Key];
					
					If Not Ref.IsEmpty()
						And ExchangePlanContentContainsType(ExchangePlanName, TypeOf(Ref)) Then
						
						ExchangePlans.RecordChanges(InfoBaseNode, Ref);
						
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

// Creates a new instance of the Structure object. Fills the object with data of the 
// specified structure.
// 
// Parameters:
//  SourceStructure – Structure – structure whose copy will be retrieved.
// 
//  Returns:
//   Structure.
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
//  Structure - Structure - structure whose keys will be converted into the string;
//  Separator - String - separator to be included into string.
//
// Returns:
//  String - String that contains structure keys.
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
//  Data1 (mandatory)              - CatalogObject,
//                                 - DocumentObject,
//                                 - ChartOfCharacteristicTypesObject,
//                                 - ChartOfCalculationTypesObject,
//                                 - ChartOfAccountsObject,
//                                 - ExchangePlanObject,
//                                 - BusinessProcessObject,
//                                 - TaskObject - first version of data to be compared.
//
//  Data2 (mandatory)              - CatalogObject,
//                                 - DocumentObject,
//                                 - ChartOfCharacteristicTypesObject,
//                                 - ChartOfCalculationTypesObject,
//                                 - ChartOfAccountsObject,
//                                 - ExchangePlanObject,
//                                 - BusinessProcessObject,
//                                 - TaskObject - second version of data to be compared.
//
//  PropertyList (optional)        - String - comma-separated properties of object and
//                                   table parts. If this parameter is passed, only 
//                                   specified object properties will be used during   
//                                   the comparison and the ExcludingProperties 
//                                   parameter will be ignored.
//
//  ExcludingProperties (optional) - String - comma-separated properties of object and
//                                   table parts. If this parameter is passed, all
//                                   properties and table parts will be used during the 
//                                   comparison, except the specified properties.
//
// Returns:
//  Boolean - True if data versions has differences, otherwise is False.
//
Function DataDifferent(Data1, Data2, PropertyList = Undefined, ExcludingProperties = Undefined) Export
	
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
		
		Raise NStr("en = 'The value of the [1] parameter for the CommonUse.PropertyValuesChanged method is not valid .'");
		
	EndIf;
	
	FillObjectPropertyValues(Object1, Data1, PropertyList, ExcludingProperties);
	FillObjectPropertyValues(Object2, Data2, PropertyList, ExcludingProperties);
	
	Return InfoBaseDataString(Object1) <> InfoBaseDataString(Object2);
	
EndFunction

Function InfoBaseDataString(Data)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	WriteXML(XMLWriter, Data, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
	
EndFunction

Function ObjectTabularSections(MetadataObject)
	
	Result = New Array;
	
	For Each TabularSection In MetadataObject.TabularSections Do
		
		Result.Add(TabularSection.Name);
		
	EndDo;
	
	Return Result;
EndFunction

Procedure _DemoDataExchangeRecordChangesBeforeWrite(Source, Cancel) Export
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWrite("_DemoExchangeWithSubsystemsLibrary", Source, Cancel);
EndProcedure
