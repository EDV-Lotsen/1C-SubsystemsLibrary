
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	ObjectRef = Parameters.ObjectRef;
	AvailableRights = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings;
	
	If AvailableRights.ByRefTypes[TypeOf(ObjectRef)] = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Access rights cannot be set up
			           |for objects of type ""%1"".'"),
			String(TypeOf(ObjectRef)));
	EndIf;
	
	// Checking the permissions to open a form
	ValidatePermissionToManageRights();
	
	UseExternalUsers =
		ExternalUsers.UseExternalUsers()
		And AccessRight("View", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	UserTypeList.Add(Type("CatalogRef.Users"),
		Metadata.Catalogs.Users.Synonym);
	
	UserTypeList.Add(Type("CatalogRef.ExternalUsers"),
		Metadata.Catalogs.ExternalUsers.Synonym);
	
	ParentFilled =
		Parameters.ObjectRef.Metadata().Hierarchical
		And ValueIsFilled(CommonUse.ObjectAttributeValue(Parameters.ObjectRef, "Parent"));
	
	Items.InheritParentRights.Visible = ParentFilled;
	
	RightsSettings = InformationRegisters.ObjectRightsSettings.Read(Parameters.ObjectRef);
	
	FillRights();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure InheritParentRightsOnChange(Item)
	
	InheritParentRightsOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure InheritParentRightsOnChangeAtServer()
	
	If InheritParentRights Then
		AddInheritedRights();
		FillUserPictureNumbers();
	Else
		// Clearing settings inherited from the hierarchical parents
		Index = RightsGroups.Count()-1;
		While Index >= 0 Do
			If RightsGroups.Get(Index).ParentSettings Then
				RightsGroups.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersRightsGroupFormTableElements

&AtClient
Procedure RightsGroupsOnChange(Item)
	
	RightsGroups.Sort("ParentSettings Desc");
	
EndProcedure

&AtClient
Procedure RightsGroupsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "RightsGroupsUser" Then
		Return;
	EndIf;
	
	Cancel = False;
	CheckingOpportunityToChangeRights(Cancel);
	
	If Not Cancel Then
		CurrentRight  = Mid(Field.Name, StrLen("RightsGroups") + 1);
		CurrentData = Items.RightsGroups.CurrentData;
		
		If CurrentRight = "InheritanceIsAllowed" Then
			CurrentData[CurrentRight] = Not CurrentData[CurrentRight];
			Modified = True;
			
		ElsIf AvailableRights.Property(CurrentRight) Then
			OldValue = CurrentData[CurrentRight];
			
			If CurrentData[CurrentRight] = True Then
				CurrentData[CurrentRight] = False;
				
			ElsIf CurrentData[CurrentRight] = False Then
				CurrentData[CurrentRight] = Undefined;
			Else
				CurrentData[CurrentRight] = True;
			EndIf;
			Modified = True;
			
			RefreshDependentRights(CurrentData, CurrentRight, OldValue);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsOnActivateRow(Item)
	
	CurrentData = Items.RightsGroups.CurrentData;
	
	CommandAvailability = ?(CurrentData = Undefined, False, Not CurrentData.ParentSettings);
	Items.RightsGroupsContextMenuDelete.Enabled = CommandAvailability;
	Items.FormDelete.Enabled                    = CommandAvailability;
	Items.FormMoveUp.Enabled                    = CommandAvailability;
	Items.FormMoveDown.Enabled                  = CommandAvailability; 
	
EndProcedure

&AtClient
Procedure RightsGroupsOnActivateField(Item)
	
	CommandAvailability = AvailableRights.Property(Mid(Item.CurrentItem.Name, StrLen("RightsGroups") + 1));
	Items.RightsGroupsContextMenuClearRight.Enabled = CommandAvailability;
	Items.RightsGroupsContextMenuGrantRight.Enabled = CommandAvailability;
	Items.RightsGroupsContextMenuDenyRight.Enabled  = CommandAvailability;
	
EndProcedure

&AtClient
Procedure RightsGroupsBeforeChange(Item, Cancel)
	
	CheckingOpportunityToChangeRights(Cancel);
	
EndProcedure

&AtClient
Procedure RightsGroupsBeforeDelete(Item, Cancel)
	
	CheckingOpportunityToChangeRights(Cancel, True);
	
EndProcedure

&AtClient
Procedure RightsGroupsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		// Setting initial values
		Items.RightsGroups.CurrentData.SettingsOwner  = Parameters.ObjectRef;
		Items.RightsGroups.CurrentData.InheritanceIsAllowed = True;
		Items.RightsGroups.CurrentData.ParentSettings  = False;
		
		For Each AddedAttribute In AddedAttributes Do
			Items.RightsGroups.CurrentData[AddedAttribute.Key] = AddedAttribute.Value;
		EndDo;
	EndIf;
	
	If Items.RightsGroups.CurrentData.User = Undefined Then
		Items.RightsGroups.CurrentData.User  = PredefinedValue("Catalog.Users.EmptyRef");
		Items.RightsGroups.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserOnChange(Item)
	
	If ValueIsFilled(Items.RightsGroups.CurrentData.User) Then
		FillUserPictureNumbers(Items.RightsGroups.CurrentRow);
	Else
		Items.RightsGroups.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChooseUsers();
	
EndProcedure

&AtClient
Procedure RightsGroupsUserClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.RightsGroups.CurrentData.User  = PredefinedValue("Catalog.Users.EmptyRef");
	Items.RightsGroups.CurrentData.PictureNumber = -1;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteBeginning(True);
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteBeginning();
	
EndProcedure

&AtClient
Procedure Reread(Command)
	
	If Not Modified Then
		ReadRights();
	Else
		ShowQueryBox(
			New NotifyDescription("RereadEnd", ThisObject),
			NStr("en = 'The data is changed. Read again without changes?'"),
			QuestionDialogMode.YesNo,
			5,
			DialogReturnCode.No);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearRight(Command)
	
	SetCurrentRightValue(Undefined);
	
EndProcedure

&AtClient
Procedure DenyRight(Command)
	
	SetCurrentRightValue(False);
	
EndProcedure

&AtClient
Procedure GrantRight(Command)
	
	SetCurrentRightValue(True);
	
EndProcedure

&AtClient
Procedure SetCurrentRightValue(NewValue)
	
	Cancel = False;
	CheckingOpportunityToChangeRights(Cancel);
	
	If Not Cancel Then
		CurrentRight  = Mid(Items.RightsGroups.CurrentItem.Name, StrLen("RightsGroups") + 1);
		CurrentData = Items.RightsGroups.CurrentData;
		
		If AvailableRights.Property(CurrentRight)
		   And CurrentData <> Undefined Then
			
			OldValue = CurrentData[CurrentRight];
			CurrentData[CurrentRight] = NewValue;
			
			Modified = True;
			
			RefreshDependentRights(CurrentData, CurrentRight, OldValue);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RightsGroups.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RightsGroups.ParentSettings");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure WriteAndCloseNotification(Result = Undefined, NotDefined = Undefined) Export
	
	WriteBeginning(True);
	
EndProcedure

&AtClient
Procedure WriteBeginning(Close = False)
	
	Cancel = False;
	FillCheckProcessing(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	SubmitCancelRightsManagement = Undefined;
	WriteRights(SubmitCancelRightsManagement);
	
	If SubmitCancelRightsManagement = True Then
		Buttons = New ValueList;
		Buttons.Add("WriteAndClose", NStr("en = 'Save and close'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel'"));
		ShowQueryBox(
			New NotifyDescription("SaveAfterConfirmation", ThisObject),
			NStr("en = 'Rights setting will be disabled after saving.'"),
			Buttons,, "Cancel");
	Else
		If Close Then
			Close();
		Else
			ClearMessages();
		EndIf;
		WriteEnd();
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveAfterConfirmation(Answer, NotDefined) Export
	
	If Answer = "WriteAndClose" Then
		SubmitCancelRightsManagement = False;
		WriteRights(SubmitCancelRightsManagement);
		Close();
	EndIf;
	
	WriteEnd();
	
EndProcedure

&AtClient
Procedure WriteEnd()
	
	Notify("Write_ObjectRightsSettings", , Parameters.ObjectRef);
	
EndProcedure

&AtClient
Procedure RereadEnd(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.Yes Then
		ReadRights();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

&AtClient
Procedure RefreshDependentRights(Val Data, Val Right, Val OldValue, Val RecursionDepth = 0)
	
	If Data[Right] = OldValue Then
		Return;
	EndIf;
	
	If RecursionDepth > 100 Then
		Return;
	Else
		RecursionDepth = RecursionDepth + 1;
	EndIf;
	
	DependentRights = Undefined;
	
	If Data[Right] = True Then
		
		// Permissions increased (from Undefined or False to True). 
		// The permissions for leading rights must be increased as well.
		DirectRightDependencies.Property(Right, DependentRights);
		DependentRightValue = True;
		
	ElsIf Data[Right] = False Then
		
		// Prohibitions increased (from True or Undefined to False).
		// The prohibitions for dependent rights must be increased as well.
		ReverseRightDependencies.Property(Right, DependentRights);
		DependentRightValue = False;
	Else
		If OldValue = False Then
			// Prohibition decreased (from False to Undefined).
			// The prohibitions for leading rights must be decreased as well.
			DirectRightDependencies.Property(Right, DependentRights);
			DependentRightValue = Undefined;
		Else
			// Permissions decreased (from True to Undefined).
			// The permissions for dependent rights must be decreased as well.
			ReverseRightDependencies.Property(Right, DependentRights);
			DependentRightValue = Undefined;
		EndIf;
	EndIf;
	
	If DependentRights <> Undefined Then
		For Each DependentRight In DependentRights Do
			If TypeOf(DependentRight) = Type("Array") Then
				SetDependentRight = True;
				For Each OneOfDependentRight In DependentRight Do
					If Data[OneOfDependentRight] = DependentRightValue Then
						SetDependentRight = False;
						Break;
					EndIf;
				EndDo;
				If SetDependentRight Then
					If Not (DependentRightValue = Undefined And Data[DependentRight[0]] <> OldValue) Then
						CurrentOldValue = Data[DependentRight[0]];
						Data[DependentRight[0]] = DependentRightValue;
						RefreshDependentRights(Data, DependentRight[0], CurrentOldValue);
					EndIf;
				EndIf;
			Else
				If Not (DependentRightValue = Undefined And Data[DependentRight] <> OldValue) Then
					CurrentOldValue = Data[DependentRight];
					Data[DependentRight] = DependentRightValue;
					RefreshDependentRights(Data, DependentRight, CurrentOldValue);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAttribute(NewAttributes, Attribute, InitialValue)
	
	NewAttributes.Add(Attribute);
	AddedAttributes.Insert(Attribute.Name, InitialValue);
	
EndProcedure

&AtServer
Function AddItem(Name, Type, Parent)
	
	Item = Items.Add(Name, Type, Parent);
	Item.FixingInTable = FixingInTable.None;
	
	Return Item;
	
EndFunction

&AtServer
Procedure AddAttributesOrFormItems(NewAttributes = Undefined)
	
	PossibleRightsDescription = AccessManagementInternalCached.Parameters(
		).AvailableRightsForObjectRightsSettings.ByRefTypes.Get(
			TypeOf(Parameters.ObjectRef));
	
	DescriptionOfPseudoFlagTypes = New TypeDescription("Boolean, Number",
		New NumberQualifiers(1, 0, AllowedSign.Nonnegative));
	
	// Adding available rights restricted by owner (by access value table)
	For Each RightDetails In PossibleRightsDescription Do
		
		If NewAttributes <> Undefined Then
			
			AddAttribute(NewAttributes, New FormAttribute(RightDetails.Name, DescriptionOfPseudoFlagTypes,
				"RightsGroups", RightDetails.Title), RightDetails.InitialValue);
			
			AvailableRights.Insert(RightDetails.Name);
			
			// Adding direct and reverse rights dependencies
			DirectRightDependencies.Insert(RightDetails.Name, RightDetails.RequiredRights);
			For Each DependentRight In RightDetails.RequiredRights Do
				If TypeOf(DependentRight) = Type("Array") Then
					DependentRights = DependentRight;
				Else
					DependentRights = New Array;
					DependentRights.Add(DependentRight);
				EndIf;
				For Each DependentRight In DependentRights Do
					If ReverseRightDependencies.Property(DependentRight) Then
						DependentRights = ReverseRightDependencies[DependentRight];
					Else
						DependentRights = New Array;
						ReverseRightDependencies.Insert(DependentRight, DependentRights);
					EndIf;
					If DependentRights.Find(RightDetails.Name) = Undefined Then
						DependentRights.Add(RightDetails.Name);
					EndIf;
				EndDo;
			EndDo;
		Else
			Item = AddItem("RightsGroups" + RightDetails.Name, Type("FormField"), Items.RightsGroups);
			Item.ReadOnly              = True;
			Item.Format                = "ND=1; NZ=; BF=None; BT=Yes";
			Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
			Item.HorizontalLocation    = ItemHorizontalLocation.Center;
			Item.DataPath              = "RightsGroups." + RightDetails.Name;
			
			Item.Tooltip = RightDetails.Tooltip;
			// Calculating the optimal item width
			ItemWidth = 0;
			For LineNumber = 1 To StrLineCount(RightDetails.Title) Do
				ItemWidth = Max(ItemWidth, StrLen(StrGetLine(RightDetails.Title, LineNumber)));
			EndDo;
			If StrLineCount(RightDetails.Title) = 1 Then
				ItemWidth = ItemWidth + 1;
			EndIf;
			Item.Width = ItemWidth;
		EndIf;
		
		If Items.RightsGroups.HeaderHeight < StrLineCount(RightDetails.Title) Then
			Items.RightsGroups.HeaderHeight = StrLineCount(RightDetails.Title);
		EndIf;
	EndDo;
	
	If NewAttributes = Undefined And Parameters.ObjectRef.Metadata().Hierarchical Then
		Item = AddItem("RightsGroupsInheritanceAllowed", Type("FormField"), Items.RightsGroups);
		Item.ReadOnly                = True;
		Item.Format                  = "ND=1; NZ=; BF=None; BT=Yes";
		Item.HeaderHorizontalAlign   = ItemHorizontalLocation.Center;
		Item.HorizontalLocation      = ItemHorizontalLocation.Center;
		Item.DataPath                = "RightsGroups.InheritanceAllowed";
		
		Item.Title   = NStr("en = 'For subfolders'");
		Item.Tooltip = NStr("en = 'Rights not only for
		                               |a current folder but also for its subfolders'");
		
		Item = AddItem("RightsGroupsOwnerSettings", Type("FormField"), Items.RightsGroups);
		Item.ReadOnly   = True;
		Item.DataPath   = "RightsGroups.OwnerSettings";
		Item.Title   = NStr("en = 'Is inherited from'");
		Item.Tooltip = NStr("en = 'Folder from which the rights setting are inherited'");
		Item.Visible = ParentFilled;
		
		ConditionalAppearanceItem     = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.Use = True;
		ConditionalAppearanceItem.Appearance.SetParameterValue("Text", "");
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(
			Type("DataCompositionFilterItem"));
		FilterItem.Use            = True;
		FilterItem.LeftValue      = New DataCompositionField("RightsGroups.ParentSettings");
		FilterItem.ComparisonTyp  = DataCompositionComparisonType.Equal;
		FilterItem.RightValue     = False;
		
		AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
		AppearanceField.Use = True;
		AppearanceField.Field = New DataCompositionField("RightsGroupsOwnerSettings");
		
		If Items.RightsGroups.HeaderHeight = 1 Then
			Items.RightsGroups.HeaderHeight = 2;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillRights()
	
	DirectRightDependencies  = New Structure;
	ReverseRightDependencies = New Structure;
	AvailableRights          = New Structure;
	
	AddedAttributes = New Structure;
	NewAttributes = New Array;
	AddAttributesOrFormItems(NewAttributes);
	
	// Adding form attributes
	ChangeAttributes(NewAttributes);
	
	// Adding form items
	AddAttributesOrFormItems();
	
	ReadRights();
	
EndProcedure

&AtServer
Procedure ReadRights()
	
	RightsGroups.Clear();
	
	SetPrivilegedMode(True);
	RightsSettings = InformationRegisters.ObjectRightsSettings.Read(Parameters.ObjectRef);
	
	InheritParentRights = RightsSettings.Inherit;
	
	For Each Settings In RightsSettings.Settings Do
		If InheritParentRights Or Not Settings.ParentSettings Then
			FillPropertyValues(RightsGroups.Add(), Settings);
		EndIf;
	EndDo;
	FillUserPictureNumbers();
	
	Modified = False;
	
EndProcedure

&AtServer
Procedure AddInheritedRights()
	
	SetPrivilegedMode(True);
	RightsSettings = InformationRegisters.ObjectRightsSettings.Read(Parameters.ObjectRef);
	
	Index = 0;
	For Each Settings In RightsSettings.Settings Do
		If Settings.ParentSettings Then
			FillPropertyValues(RightsGroups.Insert(Index), Settings);
			Index = Index + 1;
		EndIf;
	EndDo;
	
	FillUserPictureNumbers();
	
EndProcedure

&AtClient
Procedure FillCheckProcessing(Cancel)
	
	ClearMessages();
	
	LineNumber = RightsGroups.Count()-1;
	
	While Not Cancel And LineNumber >= 0 Do
		CurrentRow = RightsGroups.Get(LineNumber);
		
		// Checking whether the rights flags are set up
		NoFilledRight = True;
		FirstRightName = "";
		For Each PossibleRight In AvailableRights Do
			If Not ValueIsFilled(FirstRightName) Then
				FirstRightName = PossibleRight.Key;
			EndIf;
			If TypeOf(CurrentRow[PossibleRight.Key]) = Type("Boolean") Then
				NoFilledRight = False;
				Break;
			EndIf;
		EndDo;
		If NoFilledRight Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No access rights are set up.'"),
				,
				"RightsGroups[" + Format(LineNumber, "NG=0") + "]." + FirstRightName,
				,
				Cancel);
			Return;
		EndIf;
		
		// Checking whether the users, user groups,
		// access values and their duplicates are filled.
		
		// Checking whether the values are filled
		If Not ValueIsFilled(CurrentRow["User"]) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'User or group is not filled.'"),
				,
				"RightsGroups[" + Format(LineNumber, "NG=0") + "].User",
				,
				Cancel);
			Return;
		EndIf;
		
		// Checking duplicates
		Filter = New Structure("SettingsOwner, User",
		                        CurrentRow["SettingsOwner"],
		                        CurrentRow["User"]);
		If RightsGroups.FindRows(Filter).Count() > 1 Then
			If TypeOf(Filter.User) = Type("CatalogRef.Users") Then
				MessageText = NStr("en = 'Settings for ""%1"" user already exist.'");
			Else
				MessageText = NStr("en = 'Settings for ""%1"" user group already exist.'");
			EndIf;
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(MessageText, Filter.User),
				,
				"RightsGroups[" + Format(LineNumber, "NG=0") + "].User",
				,
				Cancel);
			Return;
		EndIf;
			
		LineNumber = LineNumber - 1;
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteRights(SubmitCancelRightsManagement)
	
	ValidatePermissionToManageRights();
	
	BeginTransaction();
	Try
		SetPrivilegedMode(True);
		InformationRegisters.ObjectRightsSettings.Write(Parameters.ObjectRef, RightsGroups, InheritParentRights);
		SetPrivilegedMode(False);
		
		If SubmitCancelRightsManagement = False
		 Or AccessManagement.HasRight("RightsManagement", Parameters.ObjectRef) Then
			
			CommitTransaction();
			Modified = False;
		Else
			RollbackTransaction();
			SubmitCancelRightsManagement = True;
		EndIf;
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure CheckingOpportunityToChangeRights(Cancel, DeletionChecking = False)
	
	CurrentOwnerSettings = Items.RightsGroups.CurrentData["SettingsOwner"];
	
	If ValueIsFilled(CurrentOwnerSettings)
	   And CurrentOwnerSettings <> Parameters.ObjectRef Then
		
		Cancel = True;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'These rights are inherited. They can be changed in
			           |the rights settings form of parent folder ""%1"".'"),
			CurrentOwnerSettings);
		
		If DeletionChecking Then
			MessageText = MessageText + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'To delete all inherited rights,
					           |clear the %1 check box.'"),
					Items.InheritParentRights.Title);
		EndIf;
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, MessageText);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GenerateUserSelectionData(Text)
	
	Return Users.GenerateUserSelectionData(Text);
	
EndFunction

&AtClient
Procedure ShowSelectionTypeUsersOrExternalUsers(ContinuationHandler)
	
	ExternalUsersSelectionAndPickup = False;
	
	If UseExternalUsers Then
		
		UserTypeList.ShowChooseItem(
			New NotifyDescription(
				"ShowSelectionTypeUsersOrExternalUsersEnd",
				ThisObject,
				ContinuationHandler),
			NStr("en = 'Select data type'"),
			UserTypeList[0]);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSelectionTypeUsersOrExternalUsersEnd(SelectedItem, ContinuationHandler) Export
	
	If SelectedItem <> Undefined Then
		ExternalUsersSelectionAndPickup =
			SelectedItem.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseUsers()
	
	CurrentUser = ?(Items.RightsGroups.CurrentData = Undefined,
		Undefined, Items.RightsGroups.CurrentData.User);
	
	If ValueIsFilled(CurrentUser)
	   And (    TypeOf(CurrentUser) = Type("CatalogRef.Users")
	      Or TypeOf(CurrentUser) = Type("CatalogRef.UserGroups") ) Then
		
		ExternalUsersSelectionAndPickup = False;
		
	ElsIf UseExternalUsers
	        And ValueIsFilled(CurrentUser)
	        And (    TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers")
	           Or TypeOf(CurrentUser) = Type("CatalogRef.ExternalUserGroups") ) Then
	
		ExternalUsersSelectionAndPickup = True;
	Else
		ShowSelectionTypeUsersOrExternalUsers(
			New NotifyDescription("SelectUsersEnd", ThisObject));
		Return;
	EndIf;
	
	SelectUsersEnd(ExternalUsersSelectionAndPickup);
	
EndProcedure

&AtClient
Procedure SelectUsersEnd(ExternalUsersSelectionAndPickup, NotDefined = Undefined) Export
	
	If ExternalUsersSelectionAndPickup = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.RightsGroups.CurrentData = Undefined,
		Undefined,
		Items.RightsGroups.CurrentData.User));
	
	If ExternalUsersSelectionAndPickup Then
		FormParameters.Insert("ExternalUserGroupSelection", True);
	Else
		FormParameters.Insert("UserGroupSelection", True);
	EndIf;
	
	If ExternalUsersSelectionAndPickup Then
		
		OpenForm(
			"Catalog.ExternalUsers.ChoiceForm",
			FormParameters,
			Items.RightsGroupsUser);
	Else
		OpenForm(
			"Catalog.Users.ChoiceForm",
			FormParameters,
			Items.RightsGroupsUser);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillUserPictureNumbers(RowID = Undefined)
	
	Users.FillUserPictureNumbers(RightsGroups, "User", "PictureNumber", RowID);
	
EndProcedure

&AtServer
Procedure ValidatePermissionToManageRights()
	
	If AccessManagement.HasRight("RightsManagement", Parameters.ObjectRef) Then
		Return;
	EndIf;
	
	Raise NStr("en = 'Rights settings are navailable.'");
	
EndProcedure

#EndRegion
