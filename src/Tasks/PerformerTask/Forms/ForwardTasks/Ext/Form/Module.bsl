
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	FormTitleText = Parameters.FormTitle;
	DefaultTitle = IsBlankString(FormTitleText);
	If Not DefaultTitle Then
		Title = FormTitleText;
	EndIf;
	
	TitleText = "";
	
	If Parameters.TaskQuantity > 1 Then
		TitleText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 (%2)'"),
			?(DefaultTitle, NStr("en = 'Selected tasks'"), FormTitleText),
			String(Parameters.TaskQuantity));
	ElsIf Parameters.TaskQuantity = 1 Then
		TitleText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1: %2'"),
			?(DefaultTitle, NStr("en = 'Selected task'"), FormTitleText),
			String(Parameters.Task));
	Else
		Items.DecorationTitle.Visible = False;
	EndIf;
	Items.DecorationTitle.Title = TitleText;
	
	SetAddressingObjectTypes();
	SetItemStates();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If AddressingType = 0 Then
		If Performer.IsEmpty() Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Task performer is not specified.'"),,,
				"Performer",
				Cancel);
		EndIf;
		Return;
	EndIf;
	
	If Role.IsEmpty() Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Task performer role is not specified.'"),,,
			"Role",
			Cancel);
		Return;
	EndIf;
	
	MainAddressingObjectTypesSet = UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	AditionalAddressingObjectTypesSet = UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesSet And MainAddressingObject = Undefined Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %1 field is required.'"),
				Role.MainAddressingObjectTypes.Description),,,
			"MainAddressingObject",
			Cancel);
		Return;
	ElsIf AditionalAddressingObjectTypesSet And AdditionalAddressingObject = Undefined Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %1 field is required.'"),
				Role.AdditionalAddressingObjectTypes.Description),,,
			"AdditionalAddressingObject",
			Cancel);
		Return;
	EndIf;
	
	If Not IgnoreWarnings And 
		Not BusinessProcessesAndTasksServer.HasRolePerformers(Role, MainAddressingObject, AdditionalAddressingObject) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'No performer is appointed for the specified role. (To ignore this warning, select the check box.)'"),,,
			"Role",
			Cancel);
		Items.IgnoreWarnings.Visible = True;
	EndIf;	
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PerformerOnChange(Item)
	
	AddressingType = 0;
	PerformerRole = Undefined;
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemStates();
	
EndProcedure

&AtClient
Procedure RoleOnChange(Item)
	
	AddressingType = 1;
	Performer = Undefined;
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemStates();
	
EndProcedure

&AtClient
Procedure AddressingTypeOnChange(Item)
	SetItemStates();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	Close(CloseParameters());
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetAddressingObjectTypes()
	
	MainAddressingObjectTypes = Role.MainAddressingObjectTypes.ValueType;
	AdditionalAddressingObjectTypes = Role.AdditionalAddressingObjectTypes.ValueType;
	UsedByAddressingObjects = Role.UsedByAddressingObjects;
	UsedWithoutAddressingObjects = Role.UsedWithoutAddressingObjects;
	
EndProcedure

&AtServer
Procedure SetItemStates()
	
	Items.Performer.MarkIncomplete = False;
	Items.Performer.AutoMarkIncomplete = AddressingType = 0;
	Items.Performer.Enabled = AddressingType = 0;
	Items.Role.MarkIncomplete = False;
	Items.Role.AutoMarkIncomplete = AddressingType <> 0;
	Items.Role.Enabled = AddressingType <> 0;
	
	MainAddressingObjectTypesSet = UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	AditionalAddressingObjectTypesSet = UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
		
	Items.MainAddressingObject.Title = Role.MainAddressingObjectTypes.Description;
	Items.OneMainAddressingObject.Title = Role.MainAddressingObjectTypes.Description;
	
	If MainAddressingObjectTypesSet And AditionalAddressingObjectTypesSet Then
		Items.OneAddressingObjectGroup.Visible = False;
		Items.TwoAddressingObjectsGroup.Visible = True;
	ElsIf MainAddressingObjectTypesSet Then
		Items.OneAddressingObjectGroup.Visible = True;
		Items.TwoAddressingObjectsGroup.Visible = False;
	Else	
		Items.OneAddressingObjectGroup.Visible = False;
		Items.TwoAddressingObjectsGroup.Visible = False;
	EndIf;
		
	Items.AdditionalAddressingObject.Title = Role.AdditionalAddressingObjectTypes.Description;
	
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
 
	Items.OneMainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
 
	Items.AdditionalAddressingObject.AutoMarkIncomplete = AditionalAddressingObjectTypesSet
		And Not UsedWithoutAddressingObjects;
	Items.OneMainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
 
	Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	
EndProcedure

&AtClient
Function CloseParameters()
	
	Return New Structure("Performer,PerformerRole,MainAddressingObject,AdditionalAddressingObject,Comment",
		Performer,
		Role,
		?(MainAddressingObject <> Undefined And Not MainAddressingObject.IsEmpty(), MainAddressingObject, Undefined),
		?(AdditionalAddressingObject <> Undefined And Not AdditionalAddressingObject.IsEmpty(), AdditionalAddressingObject, Undefined),
		Comment);
	
EndFunction

#EndRegion
