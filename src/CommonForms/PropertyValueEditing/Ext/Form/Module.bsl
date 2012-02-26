

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	WasPressedClosingButton = False;
	ObjectReference = Parameters.Ref;
	
	// Get list of available property sets
	AvailableSets = AdditionalDataAndAttributesManagement.GetAvailablePropertiesSets(Parameters.Ref);
	If TypeOf(AvailableSets) = Type("ValueList") Then
		AvailablePropertiesSets = AvailableSets;
	ElsIf AvailableSets <> Catalogs.AdditionalDataAndAttributesSettings.EmptyRef() Then
		AvailablePropertiesSets.Add(AvailableSets);
	EndIf;
	
	// Assign title
	Title = StringFunctionsClientServer.SubstitureParametersInString(
	              NStr("en = 'Additional info: %1'"), String(Parameters.Ref) );
	
	// Fill value table of properties
	FillValuesPropertiesTable(True);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancellation, StandardProcessing)
	
	If Modified And Not WasPressedClosingButton Then
		Result = DoQueryBox(NStr("en = 'Values have been changed. Do you want to save?'"), QuestionDialogMode.YesNoCancel);
		If Result = DialogReturnCode.Yes Then
			WritePropertiesValues();
		ElsIf Result = DialogReturnCode.Cancel Then
			Cancellation = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PropertiesSetChanged" Then
		If AvailablePropertiesSets.FindByValue(Parameter) <> Undefined Then
			FillValuesPropertiesTable(False);
		EndIf;
	EndIf;
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF TABLE BOX PropertyValueTree AND OF COMMAND EditContentOfProperties

&AtClient
Procedure PropertyValuesTableOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValuesTableBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	Cancellation = True;
	
EndProcedure

&AtClient
Procedure PropertyValuesTableBeforeDelete(Item, Cancellation)
	
	If Item.CurrentData.PictureNo = -1 Then
		Cancellation 			= True;
		Item.CurrentData.Value 	= Item.CurrentData.ValueType.AdjustValue(Undefined);
		Modified 				= True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertyValuesTableOnStartEdit(Item, NewRow, Clone)
	
	Item.ChildItems.PropertyValuesTableValue.TypeRestriction = Item.CurrentData.ValueType;
	
EndProcedure

&AtClient
Procedure EditContentOfProperties()
	
	If AvailablePropertiesSets.Count() = 0 Then
		DoMessageBox(NStr("en = 'This object does not have available property sets!'"));
		Return;
	ElsIf AvailablePropertiesSets.Count() = 1 Then
		Item = AvailablePropertiesSets.Get(0);
	Else
		Item = AvailablePropertiesSets.ChooseItem();
		If Item = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	SetPropertiesFormParameters = New Structure("Key", Item.Value);
	OpenFormModal("Catalog.AdditionalDataAndAttributesSettings.Form.ItemForm", SetPropertiesFormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF CLICK ON BUTTONS OK AND CANCEL

&AtClient
Procedure CommandOKExecute()
	
	WritePropertiesValues();
	WasPressedClosingButton = True;
	Close();
	
EndProcedure

&AtClient
Procedure CommandCancelExecute()
	
	WasPressedClosingButton = True;
	Close();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

// Fill tree of properties with values
&AtServer
Procedure FillValuesPropertiesTable(ChangeHandlerOnCreate)
	
	If ChangeHandlerOnCreate Then
		PropertiesValues = ReadPropertiesValuesFromInformationRegister();
	Else
		PropertiesValues = GetCurrentValuesOfProperties();
		PropertyValuesTable.Clear();
	EndIf;
	
	Table = AdditionalDataAndAttributesManagement.GetPropertyValuesTable(PropertiesValues, AvailablePropertiesSets, True);
	For Each Row In Table Do
		newRow = PropertyValuesTable.Add();
		FillPropertyValues(newRow, Row);
		newRow.PictureNo = ?(Row.Filled, 0, -1);
		
		If Row.Value = Undefined And 
			CommonUse.TypeDetailsConsistsOfType(Row.ValueType, Type("Boolean")) Then
			newRow.Value = False;
		EndIf;
	EndDo;
	
EndProcedure

// Write values of properties into information register
&AtClient
Procedure WritePropertiesValues()
	
	PropertiesValues = New Array;
	
	For Each Str In PropertyValuesTable Do
		If ValueIsFilled(Str.Value) And (Str.Value <> False) Then
			Value = New Structure("Property, Value", Str.Property, Str.Value);
			PropertiesValues.Add(Value);
		EndIf;
	EndDo;
	
	WriteSetPropertiesToRegister(ObjectReference, PropertiesValues);
	
EndProcedure

&AtServerNoContext
Procedure WriteSetPropertiesToRegister(Ref, PropertiesValues)
	
	Set = InformationRegisters.AdditionalData.CreateRecordSet();
	Set.Filter.Object.Set(Ref);
	
	For Each Str In PropertiesValues Do
		Record	 		= Set.Add();
		Record.Property = Str.Property;
		Record.Value 	= Str.Value;
		Record.Object   = Ref;
	EndDo;
	
	SetPrivilegedMode(True);
	
	Set.Write();
	
EndProcedure

&AtServer
Function ReadPropertiesValuesFromInformationRegister()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalData.Property,
	|	AdditionalData.Value
	|FROM
	|	InformationRegister.AdditionalData AS AdditionalData
	|WHERE
	|	AdditionalData.Object = &Object";
	Query.SetParameter("Object", Parameters.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function GetCurrentValuesOfProperties()
	
	PropertiesValues = New ValueTable;
	PropertiesValues.Columns.Add("Property");
	PropertiesValues.Columns.Add("Value");
	
	For Each Str In PropertyValuesTable Do
		If ValueIsFilled(Str.Value) And (Str.Value <> False) Then
			newStr = PropertiesValues.Add();
			newStr.Property = Str.Property;
			newStr.Value = Str.Value;
		EndIf;
	EndDo;
	
	Return PropertiesValues;
	
EndFunction
