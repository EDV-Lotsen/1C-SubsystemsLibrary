////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref = Catalogs.UserGroups.EmptyRef() And
		Object.Parent.Ref = Catalogs.UserGroups.AllUsers Then
		
		Object.Parent = Catalogs.UserGroups.EmptyRef();
		
	EndIf;
	
	If Object.Ref = Catalogs.UserGroups.AllUsers Then
		Items.Description.Enabled = False;
		Items.Parent.Enabled = False;
		Items.ContentFill.Enabled = False;
		Items.Content.Enabled = False;
		Items.Comment.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_UserGroups", New Structure, Object.Ref);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ChooseParent");
	
	OpenForm("Catalog.UserGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Content TABLE

&AtClient
Procedure ContentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array") Then
		For Each Value In SelectedValue Do
			UserChoiceProcessing(Value);
		EndDo;
	Else
		UserChoiceProcessing(SelectedValue);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FillUsers(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", False);
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Content);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure UserChoiceProcessing(SelectedValue)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Users") Then
		If Object.Content.FindRows(New Structure("User", SelectedValue)).Count() = 0 Then
			Object.Content.Add().User = SelectedValue;
		EndIf;
	EndIf;
	
EndProcedure
