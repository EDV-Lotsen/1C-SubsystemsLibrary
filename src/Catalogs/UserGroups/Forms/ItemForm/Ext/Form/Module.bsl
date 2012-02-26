

//////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Object.Ref = Catalogs.UserGroups.EmptyRef() And
		Object.Parent.Ref = Catalogs.UserGroups.AllUsers Then
		
		Object.Parent = Catalogs.UserGroups.EmptyRef();
		
	EndIf;
	
	If Object.Ref = Catalogs.UserGroups.AllUsers Then
		Items.Description.Enabled 	= False;
		Items.Parent.Enabled 		= False;
		Items.ContentFill.Enabled 	= False;
		Items.Content.Enabled 		= False;
		Items.Comment.Enabled 		= False;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancellation, WriteParameters)
	
	FillCheckProcessing(Cancellation);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.AdditionalProperties.Property("AreErrors") Then
		WriteParameters.Insert("AreErrors");
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("UserGroupContentChanged", Object.Ref, ThisForm);
	
	If WriteParameters.Property("AreErrors") Then
		DoMessageBox(NStr("en = 'Some errors occurred while writing (see event log)'"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of commands and form items
//

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ParentChoice");
	
	OpenForm("Catalog.UserGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

&AtClient
Procedure FillUsers(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", False);
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Content);

EndProcedure

&AtClient
Procedure ContentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		For each Value In ValueSelected Do
			UserChoiceProcessing(Value);
		EndDo;
	Else
		UserChoiceProcessing(ValueSelected);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary form procedures and functions
//

&AtClient
Procedure UserChoiceProcessing(ValueSelected)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Users") Then
		If Object.Content.FindRows(New Structure("User", ValueSelected)).Count() = 0 Then
			Object.Content.Add().User = ValueSelected;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillCheckProcessing(Cancellation)
	
	// Check not filled and duplicated users.
	LineNumber = Object.Content.Count()-1;
	
	While NOT Cancellation And LineNumber >= 0 Do
		CurrentRow = Object.Content.Get(LineNumber);
		
		// Check that value is filled.
		If NOT ValueIsFilled(CurrentRow.User) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'User is not selected!'"),
			                                                  ,
			                                                  "Object.Content[" + Format(LineNumber, "NG=0") + "].User",
			                                                  ,
			                                                  Cancellation);
			Return;
		EndIf;
		
		// Check duplicated values.
		ValuesFound = Object.Content.FindRows(New Structure("User", CurrentRow.User));
		If ValuesFound.Count() > 1 Then
			CommonUseClientServer.MessageToUser(NStr("en = 'User is not unique!'"),
			                                                  ,
			                                                  "Object.Content[" + Format(LineNumber, "NG=0") + "].User",
			                                                  ,
			                                                  Cancellation);
			Return;
		EndIf;
			
		LineNumber = LineNumber - 1;
	EndDo;
	
EndProcedure
