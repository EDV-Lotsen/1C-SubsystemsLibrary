// Confirmation flag, used when closing form
&AtClient
Var FormClosingConfirmation;

// Storage for transmitted files
&AtClient
Var PlacedFiles;

// Import parameters to be sent between client calls
&AtClient
Var BackgroundClassifierClearingParameters;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	LongActionParameters = New Structure("IdleInterval, Completed, ResultAddress, ID, Error", 5);
	
	// Getting the previously imported states
	StateTable = InformationRegisters.AddressClassifier.RegionImportInformation();
	StateTable .Columns.Add("Clear", New TypeDescription("Boolean"));
	
	For Each State In StateTable Do
		State.Presentation = Format(State.RegionCode, "ND=2; NZ=; NLZ=; NG=") + ", " + State.Presentation;
	EndDo;
	
	ValueToFormAttribute(StateTable, "Regions");
	
	// Autosaving settings
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshInterfaceByClearedCount();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	// Checking the client variable
	If FormClosingConfirmation<>True Then
		Notification = New NotifyDescription("FormClosingCompletion", ThisObject);
		Cancel = True;
		
		Text = NStr("en = 'Cancel clearing the address classifier?'");
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If LongActionParameters.ID = Undefined Then
		CancelBackgroundJob(LongActionParameters.ID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormsItemEventHandlers

&AtClient
Procedure RegionsSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Field = Items.RegionsPresentation Then
		CurrentData = Regions.FindByID(SelectedRow);
		If CurrentData <> Undefined Then
			CurrentData.Clear = Not CurrentData.Clear;
			RefreshInterfaceByClearedCount();
		EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure RegionsClearOnChange(Item)
	
	RefreshInterfaceByClearedCount();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CheckAll(Command)
	
	SetCheckboxesForStateList(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	SetCheckboxesForStateList(False);
	
EndProcedure

&AtClient
Procedure Clear(Command)
	
	ClearClassifier();
	
EndProcedure

&AtClient
Procedure CancelClearing(Command)
	
	FormClosingConfirmation = Undefined;
	Close();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Exiting the form closing dialog
&AtClient
Procedure FormClosingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		FormClosingConfirmation = True;
		Close();
	Else 
		FormClosingConfirmation = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure SetClearingPermission(Val ClearedCount = Undefined)
	
	If ClearedCount = Undefined Then
		ClearedCount = Regions.FindRows( New Structure("Clear", True) ).Count();
	EndIf;
	
	Items.Clear.Enabled = ClearedCount > 0
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	Fields = Item.Fields.Items;
	Fields.Add().Field = New DataCompositionField("RegionsRegionCode");
	Fields.Add().Field = New DataCompositionField("RegionsPresentation");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Regions.Downloaded");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
EndProcedure

&AtClient
Procedure SetCheckboxesForStateList(Val Check)
	
	// Set check boxes for visible rows only
	TableItem = Items.Regions;
	For Each StateString In Regions Do
		If TableItem.RowData(StateString.GetID() ) <> Undefined Then
			StateString.Clear = Check;
		EndIf;
	EndDo;
	
	RefreshInterfaceByClearedCount();
EndProcedure

&AtClient
Procedure RefreshInterfaceByClearedCount()
	
	// Selection page
	StatesSelectedForClearing = Regions.FindRows( New Structure("Clear", True) ).Count();
	
	// Import page
	ClearingDescriptionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Clearing data for selected states (%1)'"), StatesSelectedForClearing
	);
	
	SetClearingPermission(StatesSelectedForClearing);
EndProcedure

&AtClient
Procedure ClearClassifier()
	
	ClearMessages();
	
	// Switching modes - page
	Items.ClearingSteps.CurrentPage = Items.ClearingWait;
	ClearingStatusText = NStr("en = 'Clearing the address classifier ...'");
	
	Items.CancelClearing.Enabled = False;
	
	BackgroundClassifierClearingParameters = New Structure;
	BackgroundClassifierClearingParameters.Insert("StateCodes", StateCodesForClearing() );
	
	UsedClassifier = AddressClassifierClientServer.UsedAddressClassifier();
	If UsedClassifier <> "AC" Then
		Items.ClearingSteps.CurrentPage = Items.SelectStatesForImport;
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot process address classifier type ""%1""'"), UsedClassifier);
	EndIf;
	
	AttachIdleHandler("ClearAddressClassifier", 0.1, True);
EndProcedure

&AtClient
Procedure ClearAddressClassifier()
	
	StateCodes = BackgroundClassifierClearingParameters.StateCodes;
	BackgroundClassifierClearingParameters= Undefined;
	
	StartBackgroundClearingOnServer(StateCodes);
	AttachIdleHandler("Attachable_LongActionWait", 0.1, True);
	
EndProcedure

&AtServer
Procedure StartBackgroundClearingOnServer(Val StateCodes)
	MethodParameters = New Array;
	MethodParameters.Add(StateCodes);
	
	LongActionParameters.ID   = Undefined;
	LongActionParameters.Completed       = True;
	LongActionParameters.ResultAddress = Undefined;
	LongActionParameters.Error          = Undefined;
	
	Try
		StartResult = LongActions.ExecuteInBackground(
			UUID,
			"AddressClassifier.AddressClassifierClearingBackgroundJob",
			MethodParameters,
			NStr("en = 'Address classifier clearing'")
		);
	Except
		LongActionParameters.Error = DetailErrorDescription( ErrorInfo() );
		Return;
		
	EndTry;
	
	LongActionParameters.ID   = StartResult.JobID;
	LongActionParameters.Completed       = StartResult.JobCompleted;
	LongActionParameters.ResultAddress = StartResult.StorageAddress;
	
	// Executing 
	Items.CancelClearing.Enabled = True;
EndProcedure

&AtServer
Function BackgroundJobState()
	Result = New Structure("Progress, Completed, Error");
	
	Result.Error = "";
	If LongActionParameters.ID = Undefined Then
		Result.Completed = True;
		Result.Progress  = Undefined;
		Result.Error    = LongActionParameters.Error;
	Else
		Try
			Result.Completed = LongActions.JobCompleted(LongActionParameters.ID);
			Result.Progress  = LongActions.ReadProgress(LongActionParameters.ID);
		Except
			Result.Error = DetailErrorDescription( ErrorInfo() );
		EndTry
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure CancelBackgroundJob(Val ID)
	
	If ID <> Undefined Then
		Try
			LongActions.CancelJobExecution(ID);
		Except
			// No action required, event log record already created
		EndTry
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_LongActionWait()
	
	// Updating status
	State = BackgroundJobState();
	If Not IsBlankString(State.Error) Then
		// Job failed; generating message and going back to the initial page
		Items.ClearingSteps.CurrentPage = Items.SelectStatesForImport;
		Message(State.Error);
		Return;
		
	ElsIf State.Completed Then
		Items.ClearingSteps.CurrentPage = Items.NoErrors;
		ClearingDescriptionText = NStr("en = 'Address classifier cleared succeffully.'");
		
		Notify("AddressClassifierCleared", , ThisObject);
		
		Items.Close.DefaultButton = True;
		CurrentItem = Items.Close;
		FormClosingConfirmation = True;
		Return;
		
	EndIf;
	
	// Process continues running
	If TypeOf(State.Progress) = Type("Structure") Then
		ClearingStatusText = State.Progress.Text;
	EndIf;
	AttachIdleHandler("Attachable_LongActionWait", LongActionParameters.IdleInterval, True);
	
EndProcedure

&AtClient
Function StateCodesForClearing()
	Result = New Array;
	
	For Each State In Regions.FindRows( New Structure("Clear", True) ) Do
		Result.Add(State.RegionCode);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
