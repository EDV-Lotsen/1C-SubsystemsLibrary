
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.FormNavigationPanel
	   And AccessRight("Edit", Metadata.InformationRegisters.AdditionalData) Then
		
		Items.FormWriteAndClose.Visible = False;
		Items.FormWrite.DefaultButton = True;
		Items.FormWrite.Representation = ButtonRepresentation.PictureAndText;
	EndIf;
	
	ObjectRef = Parameters.Ref;
	
	// Getting the list of available property sets.
	PropertySets = PropertyManagementInternal.GetObjectPropertySets(Parameters.Ref);
	For Each Row In PropertySets Do
		AvailablePropertySets.Add(Row.Set);
	EndDo;
	
	// Filling the property value table.
	FillPropertyValueTable(True);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalDataAndAttributeSets" Then
		
		If AvailablePropertySets.FindByValue(Source) <> Undefined Then
			FillPropertyValueTable(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region PropertyValueTableFormTableItemEventHandlers

&AtClient
Procedure PropertyValueTableOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeDelete(Item, Cancel)
	
	If Item.CurrentData.PictureNumber = -1 Then
		Cancel = True;
		Item.CurrentData.Value = Item.CurrentData.ValueType.AdjustValue(Undefined);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertyValueTableOnStartEdit(Item, NewRow, Clone)
	
	Item.ChildItems.PropertyValueTableValue.TypeRestriction
		= Item.CurrentData.ValueType;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	WritePropertyValues();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure ChangeAdditionalDataContent(Command)
	
	If AvailablePropertySets.Count() = 0
	 Or Not ValueIsFilled(AvailablePropertySets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Failed to get object additional data sets.
			           |
			           |Perhaps the necessary object attributes are not filled.'"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("PurposeUseKey", "AdditionalDataSets");
		
		OpenForm("Catalog.AdditionalDataAndAttributeSets.ListForm", FormParameters);
		
		GoParameters = New Structure;
		GoParameters.Insert("Set", AvailablePropertySets[0].Value);
		GoParameters.Insert("Property", Undefined);
		GoParameters.Insert("IsAdditionalData", True);
		
		If Items.PropertyValueTable.CurrentData <> Undefined Then
			GoParameters.Insert("Set", Items.PropertyValueTable.CurrentData.Set);
			GoParameters.Insert("Property", Items.PropertyValueTable.CurrentData.Property);
		EndIf;
		
		Notify("Go_AdditionalDataAndAttributeSets", GoParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WritePropertyValues();
	Modified = False;
	Close();
	
EndProcedure

&AtServer
Procedure FillPropertyValueTable(FromOnCreateHandler)
	
	// Filling the tree with property values.
	If FromOnCreateHandler Then
		PropertyValues = ReadPropertyValuesInInformationRegister();
	Else
		PropertyValues = GetCurrentPropertyValues();
		PropertyValueTable.Clear();
	EndIf;
	
	Table = PropertyManagementInternal.GetPropertyValueTable(
		PropertyValues, AvailablePropertySets, True);
	
	For Each Row In Table Do
		NewRow = PropertyValueTable.Add();
		FillPropertyValues(NewRow, Row);
		NewRow.PictureNumber = ?(Row.Deleted, 0, -1);
		
		If Row.Value = Undefined And 
			CommonUse.TypeDescriptionContainsType(Row.ValueType, Type("Boolean")) Then
			NewRow.Value = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure WritePropertyValues()
	
	// Writing property values in the information register.
	PropertyValues = New Array;
	
	For Each Row In PropertyValueTable Do
		
		If ValueIsFilled(Row.Value)
		  And (Row.Value <> False) Then
			
			Value = New Structure("Property, Value", Row.Property, Row.Value);
			PropertyValues.Add(Value);
		EndIf;
	EndDo;
	
	WritePropertySetInRegister(ObjectRef, PropertyValues);
	
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure WritePropertySetInRegister(Val Ref, Val PropertyValues)
	
	Set = InformationRegisters.AdditionalData.CreateRecordSet();
	Set.Filter.Object.Set(Ref);
	
	For Each Row In PropertyValues Do
		Write = Set.Add();
		Write.Property = Row.Property;
		Write.Value = Row.Value;
		Write.Object = Ref;
	EndDo;
	
	Set.Write();
	
EndProcedure

&AtServer
Function ReadPropertyValuesInInformationRegister()
	
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
Function GetCurrentPropertyValues()
	
	PropertyValues = New ValueTable;
	PropertyValues.Columns.Add("Property");
	PropertyValues.Columns.Add("Value");
	
	For Each Row In PropertyValueTable Do
		
		If ValueIsFilled(Row.Value) And (Row.Value <> False) Then
			NewRow = PropertyValues.Add();
			NewRow.Property = Row.Property;
			NewRow.Value = Row.Value;
		EndIf;
	EndDo;
	
	Return PropertyValues;
	
EndFunction

#EndRegion
