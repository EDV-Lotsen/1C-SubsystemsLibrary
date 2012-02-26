
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	ListOfSelected.LoadValues(Parameters.ArrSelected);
	
	IsAdditionalData = Parameters.IsAdditionalData;
	
	If IsAdditionalData Then
		Title = NStr("en = 'Select Additional Data'");
	Else
		Title = NStr("en = 'Select Additional Attributes'");
	EndIf;
	
	PropertiesTree.Parameters.SetParameterValue("arrSelected", Parameters.ArrSelected);
	
	FilterItem = PropertiesTree.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("IsAdditionalData");
	
	If IsAdditionalData Then
		FilterItem.RightValue = True;
	Else
		FilterItem.RightValue = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	SetComment();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RecordedAdditionalProperty" Then
		
		Items.PropertiesTree.Refresh();
		
		CurrentData = Items.PropertiesTree.CurrentData;
		If CurrentData <> Undefined And CurrentData.Ref = Source Then
			Comment = Parameter.Comment;
		EndIf;
		
	ElsIf EventName = "ChangedSetOfSelected" And Source = ThisForm.FormOwner Then
		For Each Item In Parameter.PropertiesArray Do
			FoundOne = ListOfSelected.FindByValue(Item);
			If Parameter.Operation = "Insert" And FoundOne = Undefined Then
				ListOfSelected.Add(Item);
			ElsIf Parameter.Operation = "Delete" And FoundOne <> Undefined Then
				ListOfSelected.Delete(FoundOne);
			EndIf;
		EndDo;
	EndIf;
	
	PropertiesTree.Parameters.SetParameterValue("arrSelected", ListOfSelected.UnloadValues());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures - handlers of the form tabular section

&AtClient
Procedure PropertiesTreeBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	// Leave standard processing for the groups
	If Folder = True Then
		Return;
	ElsIf Clone And (Items.PropertiesTree.CurrentData.InfoPictureNo % 3 = 0) Then
		Return;
	EndIf;
	
	Cancellation = True;
	OpenParameters = New Structure;
	
	OpenParameters.Insert("OpensFromSetProperties", True);
	
	If Clone Then
		OpenParameters.Insert("Copied", Items.PropertiesTree.CurrentRow);
	Else
		OpenParameters.Insert("Parent", Parent);
		OpenParameters.Insert("IsAdditionalData", IsAdditionalData);
	EndIf;
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.ItemForm", OpenParameters);
	
EndProcedure

&AtClient
Procedure PropertiesTreeBeforeRowChange(Item, Cancellation)
	
	Cancellation = True;
	If Items.PropertiesTree.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If (Items.PropertiesTree.CurrentData.InfoPictureNo % 3 = 0) Then
		FormNameCCT = "GroupForm";
	Else
		FormNameCCT = "ItemForm";
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.PropertiesTree.CurrentRow);
	OpenParameters.Insert("OpensFromSetProperties", True);
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form." + FormNameCCT, OpenParameters);
	
EndProcedure

&AtClient
Procedure PropertiesTreeOnActivateRow(Item)
	
	SetComment();
	
EndProcedure

&AtClient
Procedure PropertiesTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	RunFillOfProperties();
	
EndProcedure

&AtClient
Procedure AddPropertyToSet(Command)
	
	RunFillOfProperties();
	
EndProcedure

&AtClient
Procedure RunFillOfProperties()
	
	If Items.PropertiesTree.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	ArrAddedProperties = New Array;
	
	For Each SelectedRow1 IN Items.PropertiesTree.SelectedRows Do
		Property = Items.PropertiesTree.RowData(SelectedRow1).Ref;
		ArrAddedProperties.Add(Property);
	EndDo;
	
	Result = New Structure("IsAdditionalData, ArrayOfBeingAdded",
								IsAdditionalData,
								ArrAddedProperties);
	
	Notify("FillOfPropertiesToSet", Result);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure SetComment()
	
	If Items.PropertiesTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Comment = Items.PropertiesTree.CurrentData.Comment;
	
EndProcedure
