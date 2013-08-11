////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ShowNotValidUsers = False;
	
	If Not Parameters.ChoiceMode Then
		
		// Filtering only if ChoiceMode is False
		If ShowNotValidUsers Then
			CommonUseClientServer.DeleteFilterItems(ExternalUserList.Filter, "NotValid");
		Else	
			CommonUseClientServer.SetFilterItem(
				ExternalUserList.Filter,
				"NotValid",
				False);
		EndIf;
			
	EndIf;
	
	UseGroups = GetFunctionalOption("UseUserGroups");
	
	If TypeOf(Parameters.CurrentRow) = Type("CatalogRef.ExternalUserGroups") Then
		If UseGroups Then
			Items.ExternalUserGroups.CurrentRow = Parameters.CurrentRow;
		Else
			Parameters.CurrentRow = Undefined;
		EndIf;
	Else
		CurrentItem = Items.ExternalUserList;
		Items.ExternalUserGroups.CurrentRow = Catalogs.ExternalUserGroups.AllExternalUsers;
		UpdateDataCompositionParameterValue(ExternalUserList, "ExternalUserGroup", Catalogs.ExternalUserGroups.AllExternalUsers);
		UpdateDataCompositionParameterValue(ExternalUserList, "SelectHierarchy", True);
	EndIf;
	
	If Not UseGroups Then
		Parameters.ExternalUserGroupChoice = False;
		Items.ShowChildGroupExternalUsersGroup.Visible = False;
		Items.CreateExternalUserGroup.Visible = False;
	EndIf;
	
	If Parameters.Property("Filter") And Parameters.Filter.Property("AuthorizationObject") Then
		AuthorizationObjectFilter = Parameters.Filter.AuthorizationObject;
	EndIf;
	
	// Setting up permanent data of the user list
	UpdateDataCompositionParameterValue(ExternalUserList, "EmptyUUID", New UUID("00000000-0000-0000-0000-000000000000"));
	ExternalUserGroupAllUsers = Catalogs.ExternalUserGroups.AllExternalUsers;
	
	// Preparing presentations of authorization object types
	For Each CurrentAuthorizationObjectType In Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types() Do
		TypeArray = New Array;
		TypeArray.Add(CurrentAuthorizationObjectType);
		TypeDescription = New TypeDescription(TypeArray);
		AuthorizationObjectTypePresentation.Add(TypeDescription.AdjustValue(Undefined), Metadata.FindByType(CurrentAuthorizationObjectType).Synonym);
	EndDo;
	
	If Not AccessRight("Insert", Metadata.Catalogs.ExternalUserGroups) Then
		Items.CreateExternalUserGroup.Visible = False;
	EndIf;
	If Not AccessRight("Insert", Metadata.Catalogs.ExternalUsers) Then
		Items.CreateExternalUser.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
		
		If Items.Find("InfoBaseUsers") <> Undefined Then
			Items.InfoBaseUsers.Visible = False;
		EndIf;
		
		Parameters.Property("AuthorizationObjectType", AuthorizationObjectType);
		
		// Selecting items that are not marked for deletion
		ExternalUserList.Filter.Items[0].Use = True;
		
		Items.ExternalUserList.ChoiceMode = True;
		Items.ChooseExternalUserGroup.Visible = Parameters.ExternalUserGroupChoice;
		Items.ExternalUserGroups.ChoiceMode = Parameters.ExternalUserGroupChoice;
		Items.ChooseExternalUser.DefaultButton = Not Parameters.ExternalUserGroupChoice;
		
		If Parameters.CloseOnChoice = False Then
			// Multiple choice mode
			Items.ExternalUserList.MultipleChoice = True;
			
			If Parameters.ExternalUserGroupChoice Then
				Title = NStr("en = 'Choose external users and groups'");
				Items.ChooseExternalUser.Title = NStr("en = 'Choose external users'");
				Items.ChooseExternalUserGroup.Title = NStr("en = 'Choose external groups'");
				
				Items.ExternalUserGroups.MultipleChoice = True;
				Items.ExternalUserGroups.SelectionMode = TableSelectionMode.MultiRow;
			Else
				Title = NStr("en = 'Choose external users'");
			EndIf;
		Else
			// Single choice mode
			If Parameters.ExternalUserGroupChoice Then
				Title = NStr("en = 'Choose external users and groups'");
				Items.ChooseExternalUser.Title = NStr("en = 'Choose external users'");
			Else
				Title = NStr("en = 'Choose external users'");
			EndIf;
		EndIf;
	Else
		Items.ChooseExternalUser.Visible = False;
		Items.ChooseExternalUserGroup.Visible = False;
	EndIf;
	
	UpdateDataCompositionParameterValue(ExternalUserGroups, "AnyAuthorizationObjectType", AuthorizationObjectType = Undefined);
	UpdateDataCompositionParameterValue(ExternalUserGroups, "AuthorizationObjectType", TypeOf(AuthorizationObjectType));
	
	UpdateDataCompositionParameterValue(ExternalUserList, "AnyAuthorizationObjectType", AuthorizationObjectType = Undefined);
	UpdateDataCompositionParameterValue(ExternalUserList, "AuthorizationObjectType", TypeOf(AuthorizationObjectType));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshFormContentOnGroupChange(Items.ExternalUserGroups.CurrentData);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ExternalUserGroups")
	 And Source = Items.ExternalUserGroups.CurrentRow Then
		
		Items.ExternalUserGroups.Refresh();
		Items.ExternalUserList.Refresh();
		RefreshFormContentOnGroupChange(Items.ExternalUserGroups.CurrentData);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Settings[SelectHierarchy] = Undefined Then
		SelectHierarchy = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF ExternalUserGroups TABLE

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
Procedure ExternalUserGroupsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Copy Then
		Cancel = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.ExternalUserGroups.CurrentRow) Then
			
			FormParameters.Insert("FillingValues", New Structure("Parent", Items.ExternalUserGroups.CurrentRow));
		EndIf;
		
		OpenForm("Catalog.ExternalUserGroups.ObjectForm", FormParameters, Items.ExternalUserGroups);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF ExternalUsers TABLE 

&AtClient
Procedure ExternalUserListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure ExternalUserListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	FormParameters = New Structure("NewExternalUserGroup", Items.ExternalUserGroups.CurrentRow);
	
	If AuthorizationObjectFilter <> Undefined Then
		FormParameters.Insert("NewExternalUserAuthorizationObject", AuthorizationObjectFilter);
	EndIf;
	
	If Copy And Item.CurrentData <> Undefined Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm("Catalog.ExternalUsers.ObjectForm", FormParameters, Items.ExternalUserList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure CreateExternalUserGroup(Command)
	
	Items.ExternalUserGroups.AddRow();
	
EndProcedure

&AtClient
Procedure ShowNotValidUsers(Command)
	
	ShowNotValidUsers = Not ShowNotValidUsers;
	
	Items.ShowNotValidUsers.Check = ShowNotValidUsers;
	
	If ShowNotValidUsers Then
		CommonUseClientServer.DeleteFilterItems(ExternalUserList.Filter, "NotValid");
	Else	
		CommonUseClientServer.SetFilterItem(
			ExternalUserList.Filter,
			"NotValid",
			False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure RefreshFormContentOnGroupChange(Val CurrentData = Undefined)
	
	If Not UseGroups
	 Or Items.ExternalUserGroups.CurrentRow = ExternalUserGroupAllUsers Then
		
		ExternalUserSummary = NStr("en = 'All external users'");
		
		Items.ShowChildGroupExternalUsersGroup.CurrentPage = Items.CannotSetPropertyGroup;
		UpdateDataCompositionParameterValue(ExternalUserList, "SelectHierarchy", True);
		
		UpdateDataCompositionParameterValue(ExternalUserList, "ExternalUserGroup", ExternalUserGroupAllUsers);
	Else
		If Items.ExternalUserGroups.CurrentRow <> Undefined And
		 CurrentData <> Undefined And
		 CurrentData.AllAuthorizationObjects Then
			//
			AuthorizationObjectTypePresentationItem = AuthorizationObjectTypePresentation.FindByValue(CurrentData.AuthorizationObjectType);
			ExternalUserSummary = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'All %1'"),
							Lower(?(AuthorizationObjectTypePresentationItem = Undefined, NStr("en = '<Invalid type>'"), AuthorizationObjectTypePresentationItem.Presentation)) );
			//
			Items.ShowChildGroupExternalUsersGroup.CurrentPage = Items.CannotSetPropertyGroup;
			UpdateDataCompositionParameterValue(ExternalUserList, "SelectHierarchy", True);
		Else
			Items.ShowChildGroupExternalUsersGroup.CurrentPage = Items.SetPropertyGroup;
			UpdateDataCompositionParameterValue(ExternalUserList, "SelectHierarchy", SelectHierarchy);
		EndIf;
		UpdateDataCompositionParameterValue(ExternalUserList, "ExternalUserGroup", Items.ExternalUserGroups.CurrentRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateDataCompositionParameterValue(Val ParameterOwner, Val ParameterName, Val ParameterValue)
	
	For Each Parameter In ParameterOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			If Parameter.Use And Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	ParameterOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure
