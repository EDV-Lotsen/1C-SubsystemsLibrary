

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If TypeOf(Parameters.CurrentRow) = Type("CatalogRef.ExternalUserGroups") Then
		Items.ExternalUserGroups.CurrentRow = Parameters.CurrentRow;
	Else
		CurrentItem = Items.ExternalUsersList;
		Items.ExternalUserGroups.CurrentRow = Catalogs.ExternalUserGroups.AllExternalUsers;
		RefreshDataCompositionParameterValue(ExternalUsersList, "GroupExternalUsers", Catalogs.ExternalUserGroups.AllExternalUsers);
		RefreshDataCompositionParameterValue(ExternalUsersList, "SelectHierarchically", True);
	EndIf;
	
	If Parameters.Property("Filter") And Parameters.Filter.Property("AuthorizationObject") Then
		FilterAuthorizationObject = Parameters.Filter.AuthorizationObject;
	EndIf;
	
	// Configure constant data for user list
	RefreshDataCompositionParameterValue(ExternalUsersList, "EmptyUUID", New Uuid("00000000-0000-0000-0000-000000000000"));
	GroupExternalUsersAllUsers = Catalogs.ExternalUserGroups.AllExternalUsers;
	
	// Prepare presentations of the authorization object types.
	For each CurrentAuthorizationObjectType In Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types() Do
		ArrayOfTypes = New Array;
		ArrayOfTypes.Add(CurrentAuthorizationObjectType);
		TypeDetails = New TypeDescription(ArrayOfTypes);
		PresentationOfTypesOfAuthorizationObjects.Add(TypeDetails.AdjustValue(Undefined), Metadata.FindByType(CurrentAuthorizationObjectType).Synonym);
	EndDo;
	
	If NOT AccessRight("Insert", Metadata.Catalogs.ExternalUserGroups) Then
		Items.CreateGroupOfExternalUsers.Visible = False;
	EndIf;
	If NOT AccessRight("Insert", Metadata.Catalogs.ExternalUsers) Then
		Items.CreateExternalUser.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
		
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		
		Parameters.Property("AuthorizationObjectType", AuthorizationObjectType);
		
		// Filter of items not marked for deletion
		ExternalUsersList.Filter.Items[0].Use = True;
		
		Items.ExternalUsersList.ChoiceMode     = True;
		Items.SelectExternalUsersGroup.Visible = Parameters.ChoiceOfExternalUserGroups;
		Items.ExternalUserGroups.ChoiceMode    = Parameters.ChoiceOfExternalUserGroups;
		Items.SelectExternalUser.DefaultButton = NOT Parameters.ChoiceOfExternalUserGroups;
		
		If Parameters.CloseOnChoice = False Then
			// Selection mode
			Items.ExternalUsersList.MultipleChoice = True;
			Items.ExternalUsersList.SelectionMode = TableSelectionMode.MultiRow;
			
			If Parameters.ChoiceOfExternalUserGroups Then
				Title                                  	= NStr("en = 'Fill up of the external users and groups'");
				Items.SelectExternalUser.Title         	= NStr("en = 'Select external users'");
				Items.SelectExternalUsersGroup.Title   	= NStr("en = 'Select groups'");
				
				Items.ExternalUserGroups.Multiselect 	= True;
				Items.ExternalUserGroups.SelectionMode  = TableSelectionMode.MultiRow;
			Else
				Title                                   = NStr("en = 'Selection of external users'");
			EndIf;
		Else
			If Parameters.ChoiceOfExternalUserGroups Then
				Title                                  = NStr("en = 'Select external user or group'");
				Items.SelectExternalUser.Title         = NStr("en = 'Select the external user'");
			Else
				Title                                  = NStr("en = 'Select external user'");
			EndIf;
		EndIf;
	Else
		Items.SelectExternalUser.Visible       = False;
		Items.SelectExternalUsersGroup.Visible = False;
	EndIf;
	
	RefreshDataCompositionParameterValue(ExternalUserGroups, "AnyAuthorizationObjectType", AuthorizationObjectType = Undefined);
	RefreshDataCompositionParameterValue(ExternalUserGroups, "AuthorizationObjectType",    TypeOf(AuthorizationObjectType));
	
	RefreshDataCompositionParameterValue(ExternalUsersList, "AnyAuthorizationObjectType", AuthorizationObjectType = Undefined);
	RefreshDataCompositionParameterValue(ExternalUsersList, "AuthorizationObjectType",    TypeOf(AuthorizationObjectType));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	RefreshFormContentOnGroupChange(Items.ExternalUserGroups.CurrentData);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ChangedGroupOfExternalUsers" Then
		
		If Parameter = Items.ExternalUserGroups.CurrentRow Then
			Items.ExternalUserGroups.Refresh();
			Items.ExternalUsersList.Refresh();
			RefreshFormContentOnGroupChange(Items.ExternalUserGroups.CurrentData);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Settings[SelectHierarchically] = Undefined Then
		SelectHierarchically = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of commands and form items
//

&AtClient
Procedure CreateGroupOfExternalUsers(Command)
	
	Items.ExternalUserGroups.AddRow();
	
EndProcedure


&AtClient
Procedure ExternalUserGroupsOnActivateRow(Item)
	
	RefreshFormContentOnGroupChange(Items.ExternalUserGroups.CurrentData);
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	If NOT Clone Then
		Cancellation = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.ExternalUserGroups.CurrentRow) Then
			
			FormParameters.Insert("FillingValues", New Structure("Parent", Items.ExternalUserGroups.CurrentRow));
		EndIf;
		
		OpenForm("Catalog.ExternalUserGroups.ObjectForm", FormParameters, Items.ExternalUserGroups);
	EndIf;
	
EndProcedure


&AtClient
Procedure ExternalUsersListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure ExternalUsersListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	Cancellation = True;
	
	FormParameters = New Structure("GroupNewExternalUser", Items.ExternalUserGroups.CurrentRow);
	
	If FilterAuthorizationObject <> Undefined Then
		FormParameters.Insert("AuthorizationObjectOfNewExternalUser", FilterAuthorizationObject);
	EndIf;
	
	If Clone And Item.CurrentData <> Undefined Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm("Catalog.ExternalUsers.ObjectForm", FormParameters, Items.ExternalUsersList);
	
EndProcedure


&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary form procedures and functions
//

&AtClient
Procedure RefreshFormContentOnGroupChange(Val CurrentData = Undefined)
	
	If Items.ExternalUserGroups.CurrentRow = GroupExternalUsersAllUsers Then
		
		DescriptionOfDisplayedExternalUsers = NStr("en = 'All external users'");
		
		Items.GroupShowExternalUsersOfChildGroups.CurrentPage = Items.GroupUnableToSetProperty;
		RefreshDataCompositionParameterValue(ExternalUsersList, "SelectHierarchically", True);
		
	ElsIf Items.ExternalUserGroups.CurrentRow <> Undefined And
	          CurrentData <> Undefined And
	          CurrentData.AllAuthorizationObjects Then
		
		ItemPresentationOfTypeOfAuthorizationObject = PresentationOfTypesOfAuthorizationObjects.FindByValue(CurrentData.AuthorizationObjectType);
		DescriptionOfDisplayedExternalUsers = StringFunctionsClientServer.SubstitureParametersInString(
						NStr("en = 'All %1'"),
						Lower(?(ItemPresentationOfTypeOfAuthorizationObject = Undefined, NStr("en = '<Invalid type>'"), ItemPresentationOfTypeOfAuthorizationObject.Presentation)) );
		
		Items.GroupShowExternalUsersOfChildGroups.CurrentPage = Items.GroupUnableToSetProperty;
		RefreshDataCompositionParameterValue(ExternalUsersList, "SelectHierarchically", True);
	Else
		Items.GroupShowExternalUsersOfChildGroups.CurrentPage = Items.GroupSetProperty;
		RefreshDataCompositionParameterValue(ExternalUsersList, "SelectHierarchically", SelectHierarchically);
	EndIf;
	
	RefreshDataCompositionParameterValue(ExternalUsersList, "GroupExternalUsers", Items.ExternalUserGroups.CurrentRow);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshDataCompositionParameterValue(Val OwnerOfParameters, Val ParameterName, Val ValueOfParameter)
	
	For each Parameter In OwnerOfParameters.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			If Parameter.Use And Parameter.Value = ValueOfParameter Then
				Return;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	OwnerOfParameters.Parameters.SetParameterValue(ParameterName, ValueOfParameter);
	
EndProcedure

