&AtClient
Var mWarnOnFormClose;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	mWarnOnFormClose = True;
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	// Checking whether the form has been opened programmatically
	If Not Parameters.Property("ExchangeMessageFileName") Then
		
		NString = NStr("en = 'The form cannot be opened interactively.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
		
	EndIf;
	
	// Initializing the data processor with the passed parameters
	FillPropertyValues(Object, Parameters,, "UsedFieldList, TableFieldList");
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Defining the UsedFieldList property
	DataProcessorObject.UsedFieldList.Clear();
	CommonUseClientServer.FillPropertyCollection(Parameters.UsedFieldList, DataProcessorObject.UsedFieldList);
	
	// Defining the TableFieldList property
	DataProcessorObject.TableFieldList.Clear();
	CommonUseClientServer.FillPropertyCollection(Parameters.TableFieldList, DataProcessorObject.TableFieldList);
	
	// Loading the unapproved relation table
	UnapprovedRelationTable = GetFromTempStorage(Parameters.UnapprovedRelationTableTempStorageAddress);
	DeleteFromTempStorage(Parameters.UnapprovedRelationTableTempStorageAddress);
	DataProcessorObject.UnapprovedRelationTable.Load(UnapprovedRelationTable);
	
	// Getting the automatic object mapping table
	DataProcessorObject.ExecuteAutomaticObjectMapping(Cancel, Parameters.MappingFieldList);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	// Setting table field titles and visibility on form
	SetTableFieldVisible("AutomaticallyMappedObjectTable", Parameters.MaxCustomFieldCount);
	
	// Setting the form title
	Title = Parameters.Title;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If  Object.AutomaticallyMappedObjectTable.Count() > 0
		And mWarnOnFormClose = True Then
			
		DoMessageBox(NStr("en = 'The form contains data of automatic mapping. The action has been canceled.'"));
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Apply(Command)
	
	mWarnOnFormClose = False;
	
	// Context server call
	Close(PutAutomaticallyMappedObjectTableIntoTempStorage());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	mWarnOnFormClose = False;
	
	Close(Undefined);
	
EndProcedure

&AtClient
Procedure ClearAllMarks(Command)
	
	SetAllMarksAtServer(False);
	
EndProcedure

&AtClient
Procedure SetAllMarks(Command)
	
	SetAllMarksAtServer(True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Function PutAutomaticallyMappedObjectTableIntoTempStorage()
	
	Return PutToTempStorage(Object.AutomaticallyMappedObjectTable.Unload(New Structure("Check", True), "TargetUUID, SourceUUID, SourceType, TargetType"));
	
EndFunction

&AtServer
Procedure SetTableFieldVisible(Val FormTableName, Val MaxCustomFieldCount)
	
	SourceFieldName = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#TargetFieldNN","#FormTableName#", FormTableName);
	
	// Making all mapping table fields invisible
	For FieldNumber = 1 to MaxCustomFieldCount Do
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		ThisForm.Items[SourceField].Visible = False;
		ThisForm.Items[TargetField].Visible = False;
		
	EndDo;
	
	// Making visible all mapping table fields that are selected by user 
	For Each Item In Object.UsedFieldList Do
		
		FieldNumber = Object.UsedFieldList.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		// Setting field visibility
		ThisForm.Items[SourceField].Visible = Item.Check;
		ThisForm.Items[TargetField].Visible = Item.Check;
		
		// Setting field titles
		ThisForm.Items[SourceField].Title = Item.Value;
		ThisForm.Items[TargetField].Title = Item.Value;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetAllMarksAtServer(Check)
	
	ValueTable = Object.AutomaticallyMappedObjectTable.Unload();
	
	ValueTable.FillValues(Check, "Check");
	
	Object.AutomaticallyMappedObjectTable.Load(ValueTable);
	
EndProcedure
