
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	//Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	   EndIf;
	
	Role = Parameters.Role;
	MainAddressingObject = Parameters.MainAddressingObject;
	If MainAddressingObject = Undefined Or MainAddressingObject = "" Then
		Items.AdditionalAddressingObject.Visible = False;
		Items.List.Header = False;
		Items.MainAddressingObject.Visible = False;
	Else	                                
		Items.MainAddressingObject.Title = MainAddressingObject.Metadata().ObjectPresentation;
		AdditionalAddressingObject = Parameters.Role.AdditionalAddressingObjectTypes;
		Items.AdditionalAddressingObject.Visible = Not AdditionalAddressingObject.IsEmpty();
		Items.AdditionalAddressingObject.Title = AdditionalAddressingObject.Description;
		AdditionalAddressingObjectTypes = AdditionalAddressingObject.ValueType;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Performers for role: %1'"), Role);
	
	RecordSetObject = FormAttributeToValue("RecordSet");
	RecordSetObject.Filter.MainAddressingObject.Connect(MainAddressingObject);
	RecordSetObject.Filter.PerformerRole.Connect(Role);
	RecordSetObject.Read();
	ValueToFormAttribute(RecordSetObject, "RecordSet");
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_RoleAddressing", WriteParameters, RecordSet);
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	If Role <> Undefined Then
		Item.CurrentData.PerformerRole = Role;
	EndIf;
	If MainAddressingObject <> Undefined 
Then
		Item.CurrentData.MainAddressingObject = MainAddressingObject;
	EndIf;
EndProcedure
                               
&AtClient
Procedure ListOnStartEdit(Item, NewRow, Copying)
	
	If Items.AdditionalAddressingObject.Visible Then
 		Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessingList(Item, 
SelectedValue, StandardProcessing)
	
	For Each Value In SelectedValue Do
		
		If RecordSet.FindRows(New Structure("Performer", Value)).Count() > 0 Then
			Continue;
		EndIf;
			
		Performer = RecordSet.Add();
		Performer.Performer = Value;
		If Role <> Undefined Then
			Performer.PerformerRole = Role;
		EndIf;
		If MainAddressingObject <> Undefined 
Then
			Performer.MainAddressingObject = MainAddressingObject;
		EndIf;
		Modified = True;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Pick(Command)
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", False);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("Multiselect", True);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	ChoiceFormParameters.Insert("GroupsChoice", False);
	ChoiceFormParameters.Insert("UserGroupsSelection", False);
	
	OpenForm("Catalog.Users.ChoiceForm", ChoiceFormParameters, Items.List);
	
EndProcedure

#EndRegion
