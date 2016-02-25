&AtClient
Var ContinuationHandlerOnWriteError;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	// Object attribute editing prohibition subsystem handler.
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	
	CurrentPropertySet = Parameters.CurrentPropertySet;
	
	If ValueIsFilled(Object.Ref) Then
		Items.IsAdditionalData.Enabled = False;
		ShowSetAdjustment = Parameters.ShowSetAdjustment;
	Else
		If ValueIsFilled(CurrentPropertySet) Then
			Object.PropertySet = CurrentPropertySet;
		EndIf;
		
		If ValueIsFilled(Parameters.AdditionalValueOwner) Then
			Object.AdditionalValueOwner = Parameters.AdditionalValueOwner;
		EndIf;
		
		If Parameters.IsAdditionalData <> Undefined Then
			Object.IsAdditionalData = Parameters.IsAdditionalData;
			
		ElsIf Not ValueIsFilled(Parameters.CopyingValue) Then
			Items.IsAdditionalData.Visible = True;
		EndIf;
	EndIf;
	
	IsAdditionalData = ?(Object.IsAdditionalData, 1, 0);
	
	RefreshFormItemtContent();
	
	If Object.MultilineInputField > 0 Then
		MultilineInputField = True;
		MultilineInputFieldNumber = Object.MultilineInputField;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If TypeOf(SelectedValue) = Type("ChartOfCharacteristicTypesRef.AdditionalDataAndAttributes") Then
		Close();
		
		// Open the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", SelectedValue);
		FormParameters.Insert("CurrentPropertySet", CurrentPropertySet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm",
			FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not WriteParameters.Property("WhenDescriptionAlreadyUsed") Then
	
		// Fill description by property set and check if there is a property with the same description.
		QuestionText = DescriptionAlreadyUsed(
			Object.Title, Object.Ref, Object.PropertySet, Object.Description);
		
		If ValueIsFilled(QuestionText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("en = 'Continue writing'"));
			Buttons.Add("BackToDescriptionInput", NStr("en = 'Back to the description input'"));
			
			ShowQueryBox(
				New NotifyDescription("AfterQueryBoxResponseWhenDescriptionAlreadyUsed", ThisObject, WriteParameters),
				QuestionText, Buttons, , "BackToDescriptionInput");
			
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	If WriteParameters.Property("ContinuationHandler") Then
		ContinuationHandlerOnWriteError = WriteParameters.ContinuationHandler;
		AttachIdleHandler("AfterWriteError", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If PropertyManagementInternal.ValueTypeContainsPropertyValues(Object.ValueType) 
Then
		CurrentObject.AdditionalValuesUsed = True;
	Else
		CurrentObject.AdditionalValuesUsed = False;
		CurrentObject.ValueFormTitle = "";
		CurrentObject.ValueChoiceFormTitle = "";
	EndIf;
	
	If Object.IsAdditionalData
	 Or Not (   Object.ValueType.ContainsType(Type("Number"))
	         Or Object.ValueType.ContainsType(Type("Date"))
	         Or Object.ValueType.ContainsType(Type("Boolean")) )Then
		
		CurrentObject.FormatProperties = "";
	EndIf;
	
	CurrentObject.MultilineInputField = 0;
	
	If Not Object.IsAdditionalData
	   And Object.ValueType.Types().Count() = 1
	   And Object.ValueType.ContainsType(Type("String")) Then
		
		If MultilineInputField Then
			CurrentObject.MultilineInputField = MultilineInputFieldNumber;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(CurrentObject.PropertySet) Then
		AddIntoSet = CurrentObject.PropertySet;
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("Catalog.AdditionalDataAndAttributeSets");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Ref", AddIntoSet);
		DataLock.Lock();
		LockDataForEdit(AddIntoSet);
		
		ObjectPropertySet = AddIntoSet.GetObject();
		If CurrentObject.IsAdditionalData Then
			TabularSection = ObjectPropertySet.AdditionalData;
		Else
			TabularSection = ObjectPropertySet.AdditionalAttributes;
		EndIf;
		FoundRow = TabularSection.Find(CurrentObject.Ref, "Property");
		If FoundRow = Undefined Then
			NewRow = TabularSection.Add();
			NewRow.Property = CurrentObject.Ref;
			ObjectPropertySet.Write();
			CurrentObject.AdditionalProperties.Insert("ModifiedSet", AddIntoSet);
		EndIf;
	EndIf;
	
	If WriteParameters.Property("ClearInputWeightFigures") Then
		ClearInputWeightFigures();
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Object attribute editing prohibition subsystem handler.
	ObjectAttributeEditProhibition.LockAttributes(ThisObject);
	
	RefreshFormItemtContent();
	
	If CurrentObject.AdditionalProperties.Property("ModifiedSet") Then
		WriteParameters.Insert("ModifiedSet", CurrentObject.AdditionalProperties.ModifiedSet);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_AdditionalDataAndAttributes",
		New Structure("Ref", Object.Ref), Object.Ref);
	
	If WriteParameters.Property("ModifiedSet") Then
		
		Notify("Write_AdditionalDataAndAttributeSets",
			New Structure("Ref", WriteParameters.ModifiedSet), WriteParameters.ModifiedSet);
	EndIf;
	
	If WriteParameters.Property("ContinuationHandler") Then
		ContinuationHandlerOnWriteError = Undefined;
		DetachIdleHandler("AfterWriteError");
		ExecuteNotifyProcessing(
			New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
				ThisObject, WriteParameters.ContinuationHandler.Parameters),
			False);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure IsAdditionalDataOnChange(Item)
	
	Object.IsAdditionalData = IsAdditionalData;
	
	RefreshFormItemtContent();
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentCommentClick(Item)
	
	WriteObject("GoToValueList",
		"ValueListAdjustmentCommentClickEnd");
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClick(Item)
	
	WriteObject("GoToValueList",
		"SetAdjustmentCommentClickContinuation");
	
EndProcedure

&AtClient
Procedure ValueTypeOnChange(Item)
	
	WarningText = "";
	RefreshFormItemtContent(WarningText);
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
	   And Not Object.AdditionalValuesWithWeight Then
		
		QuestionText =
			NStr("en = 'Clear the entered weight coefficients? 
                |
                |Data will be recorded.'");
		
		Buttons = New ValueList;
		Buttons.Add("ClearAndWrite", NStr("en = 'Clear and write'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel'"));
		
		ShowQueryBox(
			New NotifyDescription("AfterWeightCoefficientClearingConfirmation", ThisObject),
			QuestionText, Buttons, , "ClearAndWrite");
	Else
		WriteObject("UseWeightUpdate",
			"AdditionalValuesWithWeightOnChangeEnd");
	EndIf;
	
EndProcedure

&AtClient
Procedure MultilineInputFieldNumberOnChange(Item)
	
	MultilineInputField = True;
	
EndProcedure

&AtClient
Procedure CommentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CommonUseClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region TableValueFormItemEventHandlers

&AtClient
Procedure ValuesOnChange(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) 
Then
		EventName = "Write_ObjectPropertyValues";
	Else
		EventName = "Write_ObjectPropertyValueHierarchy";
	EndIf;
	
	Notify(EventName,
		New Structure("Ref", Item.CurrentData.Ref),
		Item.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ValuesBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	Cancel = True;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Clone", Clone);
	AdditionalParameters.Insert("Parent", Parent);
	AdditionalParameters.Insert("Group", Group);
	
	WriteObject("GoToValueList",
		"BeforeAddEndRowValues", AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ValuesBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Items.AdditionalValues.ReadOnly Then
		Return;
	EndIf;
	
	WriteObject("GoToValueList",
		"ValuesBeforeChangeEndRow");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EditValueFormat(Command)
	
	Constructor = New FormatStringWizard(Object.FormatProperties);
	
	Constructor.AvailableTypes = Object.ValueType;
	
	Constructor.Show(
		New NotifyDescription("EditValueFormatEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentChange(Command)
	
	WriteObject("AttributeKindUpdate",
		"ValueListAdjustmentChangeEnd");
	
EndProcedure

&AtClient
Procedure SetAdjustmentChange(Command)
	
	WriteObject("AttributeKindUpdate",
		"ChangeSetAdjustmentEnd");
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributeEdit(Command)
	
	LockedAttributes = ObjectAttributeEditProhibitionClient.Attributes(ThisObject);
	
	If LockedAttributes.Count() > 0 Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Ref", Object.Ref);
		FormParameters.Insert("IsAdditionalAttribute", Object.IsAdditionalData);
		
		OpenForm(
			"ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.AttributeUnlocking",
			FormParameters,
			ThisObject);
	Else
 
		ObjectAttributeEditProhibitionClient.ShowAllVisibleAttributesAreUnlockedMessageBox();
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure AfterQueryBoxResponseWhenDescriptionAlreadyUsed(Answer, WriteParameters) Export
	
	If Answer <> "ContinueWrite" Then
		CurrentItem = Items.Title;
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenDescriptionAlreadyUsed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWeightCoefficientClearingConfirmation(Answer, NotDefined) Export
	
	If Answer <> "ClearAndWrite" Then
		Object.AdditionalValuesWithWeight = NOT Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("ClearInputWeightFigures");
	
	WriteObject("UseWeightUpdate",
		"AdditionalValuesWithWeightOnChangeEnd",
		,
		WriteParameters);
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChangeEnd(Cancel, NotDefined) Export
	
	If Cancel Then
		Object.AdditionalValuesWithWeight = NOT Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		Notify(
			"Change_ValueIsCharacterizedByWeightCoefficient",
			Object.AdditionalValuesWithWeight,
			Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentCommentClickEnd(Cancel, NotDefined) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowSetAdjustment", True);
	FormParameters.Insert("Key", Object.AdditionalValueOwner);
	FormParameters.Insert("CurrentPropertySet", CurrentPropertySet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.ObjectForm",
		FormParameters, FormOwner);
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClickContinuation(Cancel, NotDefined) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	SelectedSet = Undefined;
	
	If SetList.Count() > 1 Then
		ShowChooseFromList(
			New NotifyDescription("SetAdjustmentCommentClickEnd", ThisObject),
			SetList, Items.SetAdjustmentComment);
	Else
		SetAdjustmentCommentClickEnd(, SetList[0].Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClickEnd(SelectedItem, SelectedSet) 
Export
	
	If SelectedItem <> Undefined Then
		SelectedSet = SelectedItem.Value;
	EndIf;
	
	If SelectedSet <> Undefined Then
		Close();
		
		SelectionValue = New Structure;
		SelectionValue.Insert("Set", SelectedSet);
		SelectionValue.Insert("Property", Object.Ref);
		SelectionValue.Insert("IsAdditionalData", Object.IsAdditionalData);
		NotifyChoice(SelectionValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeAddEndRowValues(Cancel, ProcessingParameters) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) 
Then
		ValueTableName = "Catalog.ObjectPropertyValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	FillingValues = New Structure;
	FillingValues.Insert("Parent", ProcessingParameters.Parent);
	FillingValues.Insert("Owner", Object.Ref);
	
	FormParameters = New Structure;
	FormParameters.Insert("HideOwner", True);
	FormParameters.Insert("FillingValues", FillingValues);
	
	If ProcessingParameters.Group Then
		FormParameters.Insert("IsFolder", True);
		
		OpenForm(ValueTableName + ".FolderForm", FormParameters, Items.Values);
	Else
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		
		If ProcessingParameters.Clone Then
			FormParameters.Insert("CopyingValue", Items.Values.CurrentRow);
		EndIf;
		
		OpenForm(ValueTableName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesBeforeChangeEndRow(Cancel, NotDefined) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) 
Then
		ValueTableName = "Catalog.ObjectPropertyValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	If Items.Values.CurrentRow <> Undefined Then
		// Opening  value form or value set.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.Values.CurrentRow);
		
		OpenForm(ValueTableName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentChangeEnd(Cancel, NotDefined) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertySet", CurrentPropertySet);
	FormParameters.Insert("PropertySet", Object.PropertySet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("AdditionalValueOwner", Object.AdditionalValueOwner);
	FormParameters.Insert("IsAdditionalData", Object.IsAdditionalData);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.PropertySettingChange",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeSetAdjustmentEnd(Cancel, NotDefined) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertySet", CurrentPropertySet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("PropertySet", Object.PropertySet);
	FormParameters.Insert("AdditionalValueOwner", Object.AdditionalValueOwner);
	FormParameters.Insert("IsAdditionalData", Object.IsAdditionalData);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.PropertySettingChange",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure WriteObject(QuestionTextVarian, ContinuationProcedureName, AdditionalParameters = Undefined, WriteParameters = Undefined)
	
	If ValueIsFilled(Object.Ref) And Not Modified Then
		
		ExecuteNotifyProcessing(New NotifyDescription(
			ContinuationProcedureName, ThisObject, AdditionalParameters), False);
		Return;
	EndIf;
	
	If WriteParameters = Undefined Then
		WriteParameters = New Structure;
	EndIf;
	
	ContinuationHandler = New Structure;
	ContinuationHandler.Insert("ProcedureName", ContinuationProcedureName);
	ContinuationHandler.Insert("Parameters", AdditionalParameters);
	
	WriteParameters.Insert("ContinuationHandler", ContinuationHandler);
	
	If ValueIsFilled(Object.Ref) Then
		WriteObjectContinuation("Write", WriteParameters);
		Return;
	EndIf;
	
	If QuestionTextVarian = "GoToValueList" Then
		QuestionText =
			NStr("en = 'Transition to the work with value list 
                |is possible only after writing data
			           |
			           |Data will be written.'");
	Else
		QuestionText =
			NStr("en = 'Data will be recorded.'")
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Write", NStr("en = 'Write'"));
	Buttons.Add("Cancel", NStr("en = 'Cancel'"));
	
	ShowQueryBox(
		New NotifyDescription(
			"WriteObjectContinuation", ThisObject, WriteParameters),
		QuestionText, Buttons, , "Write");
	
EndProcedure

&AtClient
Procedure WriteObjectContinuation(Answer, WriteParameters) Export
	
	If Answer <> "Write" Then
		Return;
	EndIf;
	
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWriteError()
	
	If ContinuationHandlerOnWriteError <> Undefined Then
		ExecuteNotifyProcessing(
			New NotifyDescription(ContinuationHandlerOnWriteError.ProcedureName,
				ThisObject, ContinuationHandlerOnWriteError.Parameters),
			True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditValueFormatEnd(Text, NotDefined) Export
	
	If Text <> Undefined Then
		Object.FormatProperties = Text;
		SetFormatButtonTitle(ThisObject);
		
		WarningText = "";
		Array = StringFunctionsClientServer.SplitStringIntoSubstringArray(Text, ";");
		
		For Each Substring In Array Do
			If Find(Substring, "DE=") > 0 Then
				WarningText = WarningText + Chars.LF +
					NStr("en = 'Presentation of blank data is not supported in input fields.'");
				Continue;
			EndIf;
			If Find(Substring, "NZ=") > 0 Then
				WarningText = WarningText + Chars.LF +
					NStr("en = 'Presentation of blank number is not supported in input fields.'");
				Continue;
			EndIf;
			If Find(Substring, "DF=") > 0 Then
				If Find(Substring, "ddd") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en = 'Short name of a weekday is not supported in input fields.'");
				EndIf;
				If Find(Substring, "dddd") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en = 'Full name of a week day is not supported in input fields.'");
				EndIf;
				If Find(Substring, "MMM") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en = 'Month short name is not supported in input fields.'");
				EndIf;
				If Find(Substring, "MMMM") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en = 'Full name of a month is not supported in input fields.'");
				EndIf;
			EndIf;
			If Find(Substring, "DLF=") > 0 Then
				If Find(Substring, "DD") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en = 'Long date (month in words) is not supported in input fields.'");
				EndIf;
			EndIf;
		EndDo;
		
		If ValueIsFilled(WarningText) Then
			WarningText = WarningText + Chars.LF +
				NStr("en = 'There are no usage restrictions where label fields are used.'");
			ShowMessageBox(, WarningText);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshFormItemtContent(WarningText = "")
	
	Title = GetTitle(Object);
	
	If Not Object.ValueType.ContainsType(Type("Number"))
	   And Not Object.ValueType.ContainsType(Type("Date"))
	   And Not Object.ValueType.ContainsType(Type("Boolean")) Then
		
		Object.FormatProperties = "";
	EndIf;
	
	SetFormatButtonTitle(ThisObject);
	
	If Object.IsAdditionalData
	 Or Not (   Object.ValueType.ContainsType(Type("Number"))
	         Or Object.ValueType.ContainsType(Type("Date"))
	         Or Object.ValueType.ContainsType(Type("Boolean")) ) Then
		
		Items.EditValueFormat.Visible = False;
	Else
		Items.EditValueFormat.Visible = True;
	EndIf;
	
	If Not Object.IsAdditionalData
	   And Object.ValueType.Types().Count() = 1
	   And Object.ValueType.ContainsType(Type("String")) Then
		
		Items.MultilineGroup.Visible = True;
	Else
		Items.MultilineGroup.Visible = False;
	EndIf;
	
	If Object.IsAdditionalData Then
		Object.RequiredToFill = False;
		Items.RequiredToFill.Visible = False;
	Else
		Items.RequiredToFill.Visible = True;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		OldValueType = CommonUse.ObjectAttributeValue(Object.Ref, "ValueType");
	Else
		OldValueType = New TypeDescription;
	EndIf;
	
	If ValueIsFilled(Object.AdditionalValueOwner) Then
		
		OwnerProperties = CommonUse.ObjectAttributeValues(
			Object.AdditionalValueOwner, "ValueType, AdditionalValuesWithWeight");
		
		If OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectPropertyValueHierarchy",
				"CatalogRef.ObjectPropertyValues");
		Else
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectPropertyValues",
				"CatalogRef.ObjectPropertyValueHierarchy");
		EndIf;
		
		OwnerValues = Object.AdditionalValueOwner;
		ValuesWithWeight   = OwnerProperties.AdditionalValuesWithWeight;
	Else
		// Checking possibility to delete additional value type.
		If PropertyManagementInternal.ValueTypeContainsPropertyValues(OldValueType) Then
			Query = New Query;
			Query.SetParameter("Owner", Object.Ref);
			
			If OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
				|WHERE
				|	ObjectPropertyValueHierarchy.Owner = &Owner";
			Else
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectPropertyValues AS ObjectPropertyValues
				|WHERE
				|	ObjectPropertyValues.Owner = &Owner";
			EndIf;
			
			If Not Query.Execute().IsEmpty() Then
				
				If OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
				   And Not Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = It is impossible to delete the %1 type, 
                     |as additional values are already input.
						           |First you need to delete entered additional values.
						           |
						           |Deleted type is restored.'"),
						String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectPropertyValueHierarchy",
						"CatalogRef.ObjectPropertyValues");
				
				ElsIf OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues"))
				    And Not Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = It is impossible to delete the %1 type,  
                     |as additional values are already input.
						           |First you need to delete entered additional values.
						           |
						           |Deleted type is restored.'"),
						String(Type("CatalogRef.ObjectPropertyValues")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectPropertyValues",
						"CatalogRef.ObjectPropertyValueHierarchy");
				EndIf;
			EndIf;
		EndIf;
		
		// Checking, that not more than one additional value type is set.
		If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
		   And Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) 
Then
			
			If Not OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))Then
				
				WarningText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = It is impossible to use 
                   |%1 and 
                   |%2 value types at the same time.
					           |
					           |The Second type deleted.'"),
					String(Type("CatalogRef.ObjectPropertyValues")),
					String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
				
				// Deletion of the second type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectPropertyValueHierarchy");
			Else
				WarningText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = It is impossible to use
                   |%1 and 
                   |%2 value types at the same time.
					           |
					           |First type deleted.'"),
					String(Type("CatalogRef.ObjectPropertyValues")),
					String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
				
				// Deletion of the first type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectPropertyValues");
			EndIf;
		EndIf;
		
		OwnerValues = Object.Ref;
		ValuesWithWeight = Object.AdditionalValuesWithWeight;
	EndIf;
	
	If PropertyManagementInternal.ValueTypeContainsPropertyValues(Object.ValueType) Then
		Items.ValueFormTitlesGroup.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
		Items.AdditionalValues.Visible = True;
	Else
		Items.ValueFormTitlesGroup.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		Items.AdditionalValues.Visible = False;
	EndIf;
	
	Items.Values.Header = ValuesWithWeight;
	Items.ValuesWeight.Visible = ValuesWithWeight;
	
	CommonUseClientServer.SetDynamicListFilterItem(
		Values, "Owner", OwnerValues, , , True);
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) Then
		Values.MainTable = "Catalog.ObjectPropertyValues";
	Else
		Values.MainTable = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	// Displaying elaboration.
	
	If Not ValueIsFilled(Object.AdditionalValueOwner) Then
		Items.ValueListAdjustment.Visible = False;
		Items.AdditionalValues.ReadOnly = False;
		Items.ValuesEditingCommandBar.Visible = True;
		Items.ValuesEditingContextMenu.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
		Items.ValueFormTitlesGroup.Visible = True;
	Else
		Items.ValueListAdjustment.Visible = True;
		Items.AdditionalValues.ReadOnly = True;
		Items.ValuesEditingCommandBar.Visible = False;
		Items.ValuesEditingContextMenu.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		Items.ValueFormTitlesGroup.Visible = False;
		
		Items.ValueListAdjustmentComment.Hyperlink = ValueIsFilled(Object.Ref);
		Items.ValueListAdjustmentChange.Enabled = ValueIsFilled(Object.Ref);
		
		OwnerProperties = CommonUse.ObjectAttributeValues(
			Object.AdditionalValueOwner, "PropertySet, Title, IsAdditionalData");
		
		If OwnerProperties.IsAdditionalData <> True Then
			DetailsTemplate = NStr("en = 'The value list is common with the value list of the %1 attribute of the %2 set.'");
		Else
			DetailsTemplate = NStr("en = 'The value list is common with the value list of the %1 data of the %2 set.'");
		EndIf;
		
		Items.ValueListAdjustmentComment.Title =
			StringFunctionsClientServer.SubstituteParametersInString(
				DetailsTemplate, OwnerProperties.Title, String(OwnerProperties.PropertySet)) + "  ";
	EndIf;
	
	RefreshSetList();
	
	If Not ShowSetAdjustment
	   And ValueIsFilled(Object.PropertySet)
	   And SetList.Count() < 2 Then
		
		Items.SetAdjustment.Visible = False;
	Else
		Items.SetAdjustment.Visible = True;
		Items.SetAdjustmentComment.Hyperlink =
			ValueIsFilled(Object.Ref) And ValueIsFilled(CurrentPropertySet);
		
		Items.SetAdjustmentChange.Enabled = ValueIsFilled(Object.Ref);
		
		If ValueIsFilled(Object.PropertySet)
		   And SetList.Count() < 2 Then
			
			Items.SetAdjustmentChange.Visible = False;
		
		ElsIf ValueIsFilled(CurrentPropertySet) Then
			Items.SetAdjustmentChange.Visible = True;
		Else
			Items.SetAdjustmentChange.Visible = False;
		EndIf;
		
		If SetList.Count() > 0 Then
		
			If ValueIsFilled(Object.PropertySet)
			   And SetList.Count() < 2 Then
				
				If Object.IsAdditionalData Then
					DetailsTemplate = NStr("en = 'The data is used in the %1 set.'");
				Else
					DetailsTemplate = NStr("en = 'The attribute is used in the %1 set.'");
				EndIf;
				CommentText = StringFunctionsClientServer.SubstituteParametersInString(
					DetailsTemplate, TrimAll(SetList[0].Presentation));
			Else
				If SetList.Count() > 1 Then
					If Object.IsAdditionalData Then
						DetailsTemplate = NStr("en = 'The common data is used in %1 %2'");
					Else
						DetailsTemplate = NStr("en = 'The common attribute is used in %1 %2'");
					EndIf;
					
					StringSets = TrimAll(NumberInWords(
						SetList.Count(), "FS=False", "set,sets,,,0"));
					
					While True Do
						Position = Find(StringSets, " ");
						If Position = 0 Then
							Break;
						EndIf;
						StringSets = TrimAll(Mid(StringSets, Position + 1));
					EndDo;
					
					CommentText = StringFunctionsClientServer.SubstituteParametersInString(
						DetailsTemplate, Format(SetList.Count(), "NG="), StringSets);
				Else
					If Object.IsAdditionalData Then
						DetailsTemplate = NStr("en = 'The common data is used in the %1 set.'");
					Else
						DetailsTemplate = NStr("en = 'The common attribute is used in the %1 set'");
					EndIf;
					
					CommentText = StringFunctionsClientServer.SubstituteParametersInString(
						DetailsTemplate, TrimAll(SetList[0].Presentation));
				EndIf;
			EndIf;
		Else
			Items.SetAdjustmentComment.Hyperlink = False;
			Items.SetAdjustmentChange.Visible = False;
			
			If ValueIsFilled(Object.PropertySet) Then
				If Object.IsAdditionalData Then
					CommentText = NStr("en = 'The data is not used in the set'");
				Else
					CommentText = NStr("en = 'The attribute is not used in the set'");
				EndIf;
			Else
				If Object.IsAdditionalData Then
					CommentText = NStr("en = 'The common data is not used in the sets'");
				Else
					CommentText = NStr("en = 'The common attribute is not used in the sets'");
				EndIf;
			EndIf;
		EndIf;
		
		Items.SetAdjustmentComment.Title = CommentText + " ";
		
		If Items.SetAdjustmentComment.Hyperlink Then
			Items.SetAdjustmentComment.ToolTip = NStr("en = 'Go to the set'");
		Else
			Items.SetAdjustmentComment.ToolTip = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearInputWeightFigures()
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues")) 
Then
		ValueTableName = "Catalog.ObjectPropertyValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	DataLock = New DataLock;
	LockItem = DataLock.Add(ValueTableName);
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Query = New Query;
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref
		|FROM
		|	Catalog.ObjectPropertyValues AS CurrentTable
		|WHERE
		|	CurrentTable.Weight <> 0";
		Query.Text = StrReplace(Query.Text, "Catalog.ObjectPropertyValues", ValueTableName);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ValueObject = Selection.Ref.GetObject();
			ValueObject.Weight = 0;
			ValueObject.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure RefreshSetList()
	
	SetList.Clear();
	
	If ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT
		|	AdditionalAttributes.Ref AS Set,
		|	AdditionalAttributes.Ref.Description
		|FROM
		|	Catalog.AdditionalDataAndAttributeSets.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Property = &Property
		|	AND NOT AdditionalAttributes.Ref.IsFolder
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalData.Ref,
		|	AdditionalData.Ref.Description
		|FROM
		|	Catalog.AdditionalDataAndAttributeSets.AdditionalData AS AdditionalData
		|WHERE
		|	AdditionalData.Property = &Property
		|	AND NOT AdditionalData.Ref.IsFolder");
		
		Query.SetParameter("Property", Object.Ref);
		
		BeginTransaction();
		Try
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				SetList.Add(Selection.Set, Selection.Description + "         ");
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DescriptionAlreadyUsed(Val Title, Val CurrentPropery, Val PropertySet, NewDescription)
	
	If ValueIsFilled(PropertySet) Then
		PropertySetDescription = CommonUse.ObjectAttributeValue(PropertySet, "Description");
		NewDescription = Title + " (" + PropertySetDescription + ")";
	Else
		NewDescription = Title;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Properties.IsAdditionalData,
	|	Properties.PropertySet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Properties
	|WHERE
	|	Properties.Description = &Description
	|	AND Properties.Ref <> &Ref";
	
	Query.SetParameter("Ref", CurrentPropery);
	Query.SetParameter("Description", NewDescription);
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Not Selection.Next() Then
		Return "";
	EndIf;
	
	If ValueIsFilled(Selection.PropertySet) Then
		If Selection.IsAdditionalData Then
			QuestionText = NStr("en = 'There is an additional data with %1 description.'");
		Else
			QuestionText = NStr("en = 'There is an additional attribute with %1 description.'");
		EndIf;
	Else
		If Selection.IsAdditionalData Then
			QuestionText = NStr("en = 'There is a common additional data with %1 description.'");
		Else
			QuestionText = NStr("en = 'There is a common additional attribute with %1 description.'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText + NStr("en ='
		                         |
		                         |It is recommended to use another description,
                            |otherwise program can work incorrectly.'"),
		NewDescription);
	
	Return QuestionText;
	
EndFunction

&AtClientAtServerNoContext
Function GetTitle(Object)
	
	If ValueIsFilled(Object.Ref) Then
		
		If ValueIsFilled(Object.PropertySet) Then
			If Object.IsAdditionalData Then
				Title = String(Object.Title) + " " + NStr("en = '(Additional data)'");
			Else
				Title = String(Object.Title) + " " + NStr("en = '(Additional attribute)'");
			EndIf;
		Else
			If Object.IsAdditionalData Then
				Title = String(Object.Title) + " " + NStr("en = '(Common additional data)'");
			Else
				Title = String(Object.Title) + " " + NStr("en = '(Common additional attribute)'");
			EndIf;
		EndIf;
	Else
		If ValueIsFilled(Object.PropertySet) Then
			If Object.IsAdditionalData Then
				Title = NStr("en = 'Additional data (creating)'");
			Else
				Title = NStr("en = 'additional attribute (creating)'");
			EndIf;
		Else
			If Object.IsAdditionalData Then
				Title = NStr("en = 'Common additional data (creating)'");
			Else
				Title = NStr("en = 'Common additional attribute (creating)'");
			EndIf;
		EndIf;
	EndIf;
	
	Return Title;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetFormatButtonTitle(Form)
	
	If IsBlankString(Form.Object.FormatProperties) Then
		TitleText = NStr("en = 'Default format'");
	Else
		TitleText = NStr("en = 'Format is set'");
	EndIf;
	
	Form.Items.EditValueFormat.Title = TitleText;
	
EndProcedure

#EndRegion