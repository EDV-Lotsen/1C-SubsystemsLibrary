
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 		
  Return;
	EndIf;
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", ValueIsFilled(Object.Ref));
	
	// Preparing auxiliary data
	AccessManagementInternal.OnCreateAtServerAllowedValueEditingForm(ThisObject, True);
	
	// Setting the availability of properties
	
	// Determining if the access restrictions must be set up
	If Not AccessManagement.UseRecordLevelSecurity() Then
		Items.AccessKindsAndValues.Visible = False;
	EndIf;
	
	// Determining if the form item editing (writing the form) is possible
	WithoutEditingSuppliedValues = ReadOnly
		Or Not Object.Ref.IsEmpty() And Catalogs.AccessGroupProfiles.ProfileChangeProhibition(Object);
		
	If Object.Ref = Catalogs.AccessGroupProfiles.Administrator
	   And Not Users.InfobaseUserWithFullAccess(,CommonUseCached.ApplicationRunMode().Local) Then
		ReadOnly = True;
	EndIf;
	
	Items.Description.ReadOnly = WithoutEditingSuppliedValues;
	
	// Specifying access kind editing settings
	Items.AccessKinds.ReadOnly     = WithoutEditingSuppliedValues;
	Items.AccessValues.ReadOnly = WithoutEditingSuppliedValues;
	
	ProcessRolesInterface("SetRolesReadOnly", WithoutEditingSuppliedValues);
	
	SetAvailabilityToDescribeAndRestoreSuppliedProfile();
	
	ProcedureExecutedOnCreateAtServer = True;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 	
  Return;
	EndIf;
	
	If Not ProcedureExecutedOnCreateAtServer Then
		Return;
	EndIf;
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", True);
	
	AccessManagementInternal.OnRereadAtServerAllowedValueEditingForm(
		ThisObject, CurrentObject);
	
	UpdateProfileAccessGroups = False;
	
	SetAvailabilityToDescribeAndRestoreSuppliedProfile(CurrentObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	NeedToCheckProfileFilling = Not WriteParameters.Property(
		"AnswerToUpdateProfileAccessGroupsReceived");
	
	If ValueIsFilled(Object.Ref)
	   And NeedToUpdateProfileAccessGroups
	   And Not WriteParameters.Property("AnswerToUpdateProfileAccessGroupsReceived") Then
		
		Cancel = True;
		If CheckFilling() Then
			ShowQueryBox(
				New NotifyDescription("BeforeWriteContinued", ThisObject, WriteParameters),
				QuestionTextUpdateProfileAccessGroups(),
				QuestionDialogMode.YesNoCancel,
				,
				DialogReturnCode.No);
		EndIf;
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Filling object roles from the collection
	CurrentObject.Roles.Clear();
	For Each Row In RoleCollection Do
		CurrentObject.Roles.Add().Role = CommonUse.MetadataObjectID(
			"Role." + Row.Role);
	EndDo;
	
	If WriteParameters.Property("UpdateProfileAccessGroups") Then
		CurrentObject.AdditionalProperties.Insert("UpdateProfileAccessGroups");
	EndIf;
	
	AccessManagementInternal.BeforeWriteAtServerAllowedValueEditingForm(
		ThisObject, CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.AdditionalProperties.Property(
	         "PersonalAccessGroupsWithUpdatedDescription") Then
		
		WriteParameters.Insert(
			"PersonalAccessGroupsWithUpdatedDescription",
			CurrentObject.AdditionalProperties.PersonalAccessGroupsWithUpdatedDescription);
	EndIf;
	
	AccessManagementInternal.AfterWriteAtServerAllowedValueEditingForm(
		ThisObject, CurrentObject, WriteParameters);
	
	SetAvailabilityToDescribeAndRestoreSuppliedProfile(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	ObjectWasWritten = True;
	NeedToUpdateProfileAccessGroups = False;
	
	Notify("Write_AccessGroupProfiles", New Structure, Object.Ref);
	
	If WriteParameters.Property("PersonalAccessGroupsWithUpdatedDescription") Then
		NotifyChanged(Type("CatalogRef.AccessGroups"));
		
		For Each PersonalAccessGroup In WriteParameters.PersonalAccessGroupsWithUpdatedDescription Do
			Notify("Write_AccessGroups", New Structure, PersonalAccessGroup);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If Not NeedToCheckProfileFilling Then
		AttributesToCheck.Clear();
		Return;
	EndIf;
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether roles are present in the metadata
	CheckedObjectAttributes.Add("Roles.Role");
	
	TreeItems = Roles.GetItems();
	For Each Row In TreeItems Do
		If Row.Check And Left(Row.Synonym, 1) = "?" Then
			CommonUseClientServer.AddUserError(Errors,
				"Roles[%1].RolesSynonym",
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The %1 role is not found in the metadata.'"),
					Row.Synonym),
				"Roles",
				TreeItems.IndexOf(Row),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The %2 role in the row %1 is not found in the metadata.'"),
					"%1", Row.Synonym));
		EndIf;
	EndDo;
	
	// Checking for blank and duplicate access kinds and values
	AccessManagementInternalClientServer.ProcessingCheckOfFillingEditingFormsOfAllowedValuesAtServer(
		ThisObject, Cancel, CheckedObjectAttributes, Errors);
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	AttributesToCheck.Delete(AttributesToCheck.Find("Object"));
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert("CheckedObjectAttributes",
		CheckedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region AccessKindFormTableItemEventHandlers

&AtClient
Procedure AccessKindsOnChange(Item)
	
	NeedToUpdateProfileAccessGroups = True;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	
	AccessManagementInternalClient.AccessKindsBeforeAddRow(
		ThisObject, Item, Cancel, Clone, Parent, Group);
	
EndProcedure

&AtClient
Procedure AccessKindsBeforeDelete(Item, Cancel)
	
	AccessManagementInternalClient.AccessKindsBeforeDelete(
		ThisObject, Item, Cancel);
	
EndProcedure

&AtClient
Procedure AccessKindsOnStartEdit(Item, NewRow, Clone)
	
	AccessManagementInternalClient.AccessKindsOnStartEdit(
		ThisObject, Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure AccessKindsOnEndEdit(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessKindsOnEndEdit(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the AccessKindPresentation item of the AccessKinds form table

&AtClient
Procedure AccessKindsAccessKindPresentationOnChange(Item)
	
	AccessManagementInternalClient.AccessKindsAccessKindPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAccessKindPresentationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	AccessManagementInternalClient.AccessKindsAccessKindPresentationChoiceProcessing(
		ThisObject, Item, SelectedValue, StandardProcessing);
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the AllAllowedPresentation item of the AccessKinds form table

&AtClient
Procedure AccessKindsAllAllowedPresentationOnChange(Item)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationChoiceProcessing(
		ThisObject, Item, SelectedValue, StandardProcessing);
	
EndProcedure

#EndRegion

#Region AccessValueFormTableItemEventHandlers

&AtClient
Procedure AccessValuesOnChange(Item)
	
	AccessManagementInternalClient.AccessValuesOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessValuesOnStartEdit(Item, NewRow, Clone)
	
	AccessManagementInternalClient.AccessValuesOnStartEdit(
		ThisObject, Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure AccessValuesOnEndEdit(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessValuesOnEndEdit(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

&AtClient
Procedure AccessValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueStartChoice(
		ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueChoiceProcessing(
		ThisObject, Item, SelectedValue, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueClearing(Item, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueClearing(
		ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueAutoComplete(
		ThisObject, Item, Text, ChoiceData, Waiting, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueTextEditCompletion(Item, Text, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueTextEditCompletion(
		ThisObject, Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region RolesFormTableItemEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Role interface procedures and functions

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("UpdateRoleContent");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RestoreByInitialFilling(Command)
	
	If Modified Or ObjectWasWritten Then
		UnlockFormDataForEdit();
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("RestoreByInitialFillingContinued", ThisObject),
		NStr("en = 'Do you want to restore the profile based on the initial filling values?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure SuppliedProfileDescription(Command)
	
	TextDocument = New TextDocument;
	TextDocument.SetText(SuppliedProfileDescriptionAtServer(Object.Ref));
	TextDocument.ReadOnly = True;
	
	TextDocument.Show(StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Description of ""%1"" supplied profile'"),
		Object.Description));
	
EndProcedure

&AtClient
Procedure ShowNotUsedAccessKinds(Command)
	
	ShowNotUsedAccessKindsAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Role interface procedures and functions

&AtClient
Procedure ShowSelectedRolesOnly(Command)
	
	ProcessRolesInterface("SelectedRolesOnly");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure RoleGroupingBySubsystems(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure EnableRoles(Command)
	
	ProcessRolesInterface("UpdateRoleContent", "EnableAll");
	
	UsersInternalClient.ExpandRoleSubsystems(ThisObject, False);
	
EndProcedure

&AtClient
Procedure DisableRoles(Command)
	
	ProcessRolesInterface("UpdateRoleContent", "DisableAll");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// BeforeWrite event handler continuation
&AtClient
Procedure BeforeWriteContinued(Answer, WriteParameters) Export
	
	If Answer = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Answer = DialogReturnCode.Yes Then
		WriteParameters.Insert("UpdateProfileAccessGroups");
	EndIf;
	
	WriteParameters.Insert("AnswerToUpdateProfileAccessGroupsReceived");
	
	Write(WriteParameters);
	
EndProcedure

// The RestoreByInitialFilling command handler continued
&AtClient
Procedure RestoreByInitialFillingContinued(Answer, NotDefined) Export
	
	If Answer <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("RestoreByInitialFillingCompletion", ThisObject),
		QuestionTextUpdateProfileAccessGroups(),
		QuestionDialogMode.YesNoCancel,
		,
		DialogReturnCode.No);
	
EndProcedure

// The RestoreByInitialFilling command handler continued
&AtClient
Procedure RestoreByInitialFillingCompletion(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	UpdateAccessGroups = (Answer = DialogReturnCode.Yes);
	
	InitialAccessGroupProfileFilling(UpdateAccessGroups);
	
	Read();
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
	If UpdateAccessGroups Then
		Text = NStr("en = 'Profile ""%1"" is restored based on initial filling values, the profile access groups are updated.'");
	Else
		Text = NStr("en = 'Profile ""%1"" is restored based on initial filling values, the profile access groups are not updated.'");
	EndIf;
	
	ShowUserNotification(StringFunctionsClientServer.SubstituteParametersInString(
		Text, Object.Description));
	
EndProcedure

&AtServer
Procedure ShowNotUsedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshNotUsedAccessKindRepresentation(ThisObject);
	
EndProcedure

&AtServer
Procedure SetAvailabilityToDescribeAndRestoreSuppliedProfile(CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = Object;
	EndIf;
	
	If Catalogs.AccessGroupProfiles.HasInitialProfileFilling(CurrentObject.Ref) Then
		
		If Catalogs.AccessGroupProfiles.SuppliedProfileChanged(CurrentObject) Then
			// Defining the rights to restore based on the initial filling values
			Items.RestoreByInitialFilling.Visible =
				Users.InfobaseUserWithFullAccess(,, False);
			
			Items.SuppliedProfileDescription.Enabled = False;
		Else
			Items.RestoreByInitialFilling.Visible = False;
			Items.SuppliedProfileDescription.Enabled = True;
		EndIf;
	Else
		Items.RestoreByInitialFilling.Visible = False;
		Items.SuppliedProfileDescription.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Function QuestionTextUpdateProfileAccessGroups()
	
	Return
		NStr("en = 'Refresh access groups that use this profile?
             
             |This will delete the extra access kinds with
             |the access values for these access kinds, and
             |will add the missing access kinds.'");
		
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Role interface procedures and functions

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form", ThisObject);
	ActionParameters.Insert("RoleCollection", RoleCollection);
	
	ActionParameters.Insert("HideFullAccessRole",
		Object.Ref <> Catalogs.AccessGroupProfiles.Administrator);
	
	UserType = ?(CommonUseCached.DataSeparationEnabled(), 
		Enums.UserTypes.DataAreaUser, 
		Enums.UserTypes.LocalApplicationUser);
	ActionParameters.Insert("UserType", UserType);
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

&AtServer
Procedure InitialAccessGroupProfileFilling(Val UpdateAccessGroups)
	
	Catalogs.AccessGroupProfiles.FillSuppliedProfile(
		Object.Ref, UpdateAccessGroups);
	
EndProcedure

&AtServerNoContext
Function SuppliedProfileDescriptionAtServer(Val Profile)
	
	Return Catalogs.AccessGroupProfiles.SuppliedProfileDescription(Profile);
	
EndFunction

#EndRegion
