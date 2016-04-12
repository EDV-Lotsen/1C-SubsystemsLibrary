////////////////////////////////////////////////////////////////////////////////////////////////////
// Form parameters:
//
//     InfobaseNode  - ExchangePlanRef - Correspondent exchange plan node reference.
//
//     DenyExportOnlyChanged - Boolean - if True, the option to send changed items only is not available.
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ErrorText = Undefined;
	
	If Not DataExchangeSaaSCached.DataSynchronizationSupported() Then
		ErrorText = NStr("en='The configuration does not support data synchronization.'");
		
	ElsIf Not Parameters.Property("InfobaseNode", Object.InfobaseNode) Then
		ErrorText = NStr("en='The data processor cannot be opened manually'");
		
	ElsIf Object.InfobaseNode.IsEmpty() Then
		ErrorText = NStr("en='Data exchange settings item not found.'");
		
	EndIf;
	
	If ErrorText <> Undefined Then
		Raise ErrorText;
	EndIf;
	
	// Setting the title to infobase node presentation
	SetCorrespondentInTitle(ThisObject);
	
	// Initializing additional export items
	InitializeExportAdditionAttributes();
	
	// Filling wizard navigation table according to the options
	GoToNumber = 0;
	
	If ExportAddition.ExportVariant = -1 Then
		ScenarioWithoutAddition();
	Else
		FullScenarioManually();
	EndIf;
	
	// If the current interface version is 8.2
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		SetGroupTitleFont(Items.ExportWaitingTitle);
		SetGroupTitleFont(Items.TitleEnding);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ForceCloseForm = False;
	
	// Setting the first wizard step
	SetGoToNumber(1);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	ConfirmationText = NStr("en='Do you want to abort data synchronization?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, ConfirmationText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If LongActionState <> Undefined Then
		CompleteBackgroundJob(LongActionState.ID);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	// Checking whether the additional export item initialization event occurred 
	If DataExchangeClient.ExportAdditionChoiceProcessing(SelectedValue, ChoiceSource, ExportAddition) Then
		// Event is handled, updating filter details
		SetExportAdditionFilterDescription();
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	GoBack();
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ExportAdditionExportContent(Command)
	
	DataExchangeClient.OpenExportAdditionFormDataContent(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearing(Command)
	
	TitleText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Clear general filter?'");
	
	Notification = New NotifyDescription("ExportAdditionGeneralFilterClearingCompletion", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,TitleText);
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearing(Command)
	
	TitleText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Clear detailed filter?'");
	
	Notification = New NotifyDescription("ExportAdditionDetailedFilterClearingCompletion", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,TitleText);
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistory(Command)
	
	// Filling a menu list with all saved settings options
	VariantList = ExportAdditionSettingsHistoryServer();
	
	// Adding the option for saving the current settings
	Text = NStr("en='Save current settings...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryMenuSelection", ThisObject);
	ShowChooseFromMenu(NotifyDescription, VariantList, Items.ExportAdditionFilterHistory);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

// Page ModifyExportContent
 
&AtClient
Procedure ExportAdditionExportVariantOnChange(Item)
	
	ExportAdditionExportVariantSetVisibility();
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralDocumentFilterClick(Item)
	
	DataExchangeClient.OpenExportAdditionFormAllDocuments(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClick(Item)
	
	DataExchangeClient.OpenExportAdditionFormDetailedFilter(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionFilterByNodeScenarioClick(Item)
	
	DataExchangeClient.OpenExportAdditionFormNodeScenario(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodOnChange(Item)
	
	ExportAdditionNodeScenarioPeriodChanging();
	
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodClearing(Item, StandardProcessing)
	
	// Prohibiting period clearing
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetGroupTitleFont(Val GroupItem)
	
	GroupItem.TitleFont = New Font(StyleFonts.LargeTextFont, , , True);
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	ExportAdditionGeneralFilterClearingServer();
EndProcedure

&AtServer
Procedure ExportAdditionGeneralFilterClearingServer()
	
	DataExchangeServer.InteractiveExportModificationGeneralFilterClearing(ExportAddition);
	SetGeneralFilterAdditionDescription();
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	ExportAdditionDetailedFilterClearingServer();
EndProcedure

&AtServer
Procedure ExportAdditionDetailedFilterClearingServer()
	DataExchangeServer.InteractiveExportModificationDetailsClearing(ExportAddition);
	SetAdditionDetailDescription();
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistoryMenuSelection(Val SelectedItem, Val AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingsItemPresentation = SelectedItem.Value;
	If TypeOf(SettingsItemPresentation)=Type("String") Then
	
   // If the selected settings item is a previously saved one
		TitleText = NStr("en='Confirmation'");
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Restore ""%1"" settings?'"), SettingsItemPresentation
		);
		
		NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryCompletion", ThisObject, SettingsItemPresentation);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
		
	ElsIf SettingsItemPresentation = 1 Then
		// The option to save the settings is selected. Opening the settings form.
		DataExchangeClient.OpenExportAdditionFormSettingsSaving(ExportAddition, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistoryCompletion(Answer, SettingsItemPresentation) Export
	
	If Answer = DialogReturnCode.Yes Then
		ExportAdditionSetSettingsServer(SettingsItemPresentation);
		ExportAdditionExportVariantSetVisibility();
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportAdditionNodeScenarioPeriodChanging()
	
	DataExchangeServer.InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServer
Procedure SetCorrespondentInTitle(TitleOwner)
	
	TitleOwner.Title = StringFunctionsClientServer.SubstituteParametersInString(TitleOwner.Title, String(Object.InfobaseNode));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtClient
Procedure ChangeGoToNumber(Iterator)
	ClearMessages();
	SetGoToNumber(GoToNumber + Iterator);
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	IsGoNext = (Value > GoToNumber);
	GoToNumber = Value;
	If GoToNumber < 0 Then
		GoToNumber = 0;
	EndIf;
	GoToNumberOnChange(IsGoNext);
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing wizard step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting wizard page to be displayed
	GoToRowsCurrent = GoToTable.FindRows(New Structure(
        "GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Wizard page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Setting the default button
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		NextButton.DefaultButton = True;
	Else
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		If DoneButton <> Undefined Then
			DoneButton.DefaultButton = True;
		EndIf;
	EndIf;
	
	If IsGoNext And GoToRowCurrent.LongAction Then
		AttachIdleHandler("ExecuteLongActionHandler", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Step change handlers
	If IsGoNext Then
		GoToRows = GoToTable.FindRows( New Structure(
            "GoToNumber", GoToNumber - 1));
		If GoToRows.Count() > 0 Then
			GoToRow = GoToRows[0];
			// OnGoNext handler
			If Not IsBlankString(GoToRow.GoNextHandlerName) And Not GoToRow.LongAction Then
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					SetGoToNumber(GoToNumber - 1);
					Return;
				EndIf;
			EndIf;
		EndIf;
	
	Else
		GoToRows = GoToTable.FindRows(New Structure(
			"GoToNumber", GoToNumber + 1));
		If GoToRows.Count() > 0 Then
			GoToRow = GoToRows[0];
			// OnGoBack handler
			If Not IsBlankString(GoToRow.GoBackHandlerName) And Not GoToRow.LongAction Then
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					SetGoToNumber(GoToNumber + 1);
					Return;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure(
        "GoToNumber", GoToNumber));
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Wizard page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	If GoToRowCurrent.LongAction And Not IsGoNext Then
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			SetGoToNumber(GoToNumber - 1);
			Return;
		ElsIf SkipPage Then
			If IsGoNext Then
				SetGoToNumber(GoToNumber + 1);
				Return;
			Else
				SetGoToNumber(GoToNumber - 1);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongActionHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure(
        "GoToNumber", GoToNumber));
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Wizard page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// LongActionProcessing handler
	If Not IsBlankString(GoToRowCurrent.LongActionHandlerName) Then
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongActionHandlerName);
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			SetGoToNumber(GoToNumber - 1);
			Return;
		ElsIf GoToNext Then
			SetGoToNumber(GoToNumber + 1);
			Return;
		EndIf;
		
	Else
		SetGoToNumber(GoToNumber + 1);
		Return;
	EndIf;
	
EndProcedure

//
//  The procedure adds a row to the end of the navigation table.
//
//  Parameters:
//      GoToNumber             - Number - current step number.
//      MainPageName           - String - name of the "MainPanel" panel page that matches the current step number. 
//      NavigationPageName     - String - name of the "NavigationPanel" panel page that matches the current step number. 
//      DecorationPageName     - String - name of the "DecorationPanel" panel page that matches the current step number. 
//      OnOpenHandlerName      - String - name of the "open current wizard page" event handler. 
//      GoNextHandlerName      - String - name of the "go to next wizard page" event handler. 
//      GoBackHandlerName      - String - name of the "go to previous wizard page" event handler. 
//      LongAction             - Boolean - flag that shows whether a long action execution page is displayed. 
//                               If False, a standard page is displayed.
//      LongActionHandlerName  - String - name of the long action handler.
//
&AtServer
Procedure GoToTableNewRow(GoToNumber, MainPageName, NavigationPageName, 
    DecorationPageName = "",
    OnOpenHandlerName = "", GoNextHandlerName = "", GoBackHandlerName = "",
	LongAction = False, LongActionHandlerName = "")

	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber         = GoToNumber;
	NewRow.MainPageName       = MainPageName;
	NewRow.DecorationPageName = DecorationPageName;
	NewRow.NavigationPageName = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongAction            = LongAction;
	NewRow.LongActionHandlerName = LongActionHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			If FormItemByCommandName <> Undefined Then
				Return FormItemByCommandName;
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton") And Find(Item.CommandName, CommandName)> 0 Then
			Return Item;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
EndFunction

&AtClient
Procedure GoToNext()
	ChangeGoToNumber(+1);
EndProcedure

&AtClient
Procedure GoBack()
	ChangeGoToNumber(-1);
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
//  Initialization of additional export items.
//

&AtServer
Procedure InitializeExportAdditionAttributes()
	
	// Getting settings structure. The settings are implicitly saved to a temporary form storage.
	ExportAdditionSettings = DataExchangeServer.InteractiveExportModification(
		Object.InfobaseNode, ThisObject.UUID, True
	);
		
	// Setting up the form.
	// Converting ThisObject form attribute to a value of DataProcessor type. This simplifies access to form data.
	DataExchangeServer.InteractiveExportModificationAttributeBySettings(ThisObject, ExportAdditionSettings, "ExportAddition");
	
	AdditionScenarioParameters = ExportAddition.AdditionScenarioParameters;
	
	// Configuring interface according to the specified scenario
	
	// Special cases
	StandardVariantsProhibited = Not AdditionScenarioParameters.VariantWithoutAddition.Use
		And Not AdditionScenarioParameters.AllDocumentVariant.Use
		And Not AdditionScenarioParameters.ArbitraryFilterVariant.Use;
		
	If StandardVariantsProhibited Then
		If AdditionScenarioParameters.AdditionalVariant.Use Then
			// A single node scenario option is available
			Items.ExportAdditionExportVariantNodeString.Visible = True;
			Items.ExportAdditionNodeExportVariant.Visible       = False;
			Items.DecorationCustomGroupIndent.Visible           = False;
			ExportAddition.ExportVariant = 3;
		Else
			// No options are available. Setting the skip page flag value to True and exiting the procedure.
			ExportAddition.ExportVariant = -1;
			Items.ExportAdditionVariants.Visible = False;
			Return;
		EndIf;
	EndIf;
	
	// Setting input field properties
	Items.StandardAdditionVariantNo.Visible = AdditionScenarioParameters.VariantWithoutAddition.Use;
	If Not IsBlankString(AdditionScenarioParameters.VariantWithoutAddition.Title) Then
		Items.ExportAdditionExportVariant0.ChoiceList[0].Presentation = AdditionScenarioParameters.VariantWithoutAddition.Title;
	EndIf;
	Items.StandardAdditionVariantNoExplanation.Title = AdditionScenarioParameters.VariantWithoutAddition.Explanation;
	If IsBlankString(Items.StandardAdditionVariantNoExplanation.Title) Then
		Items.StandardAdditionVariantNoExplanation.Visible = False;
	EndIf;
	
	Items.StandardAdditionVariantDocuments.Visible = AdditionScenarioParameters.AllDocumentVariant.Use;
	If Not IsBlankString(AdditionScenarioParameters.AllDocumentVariant.Title) Then
		Items.ExportAdditionExportVariant1.ChoiceList[0].Presentation = AdditionScenarioParameters.AllDocumentVariant.Title;
	EndIf;
	Items.StandardAdditionVariantDocumentsExplanation.Title = AdditionScenarioParameters.AllDocumentVariant.Explanation;
	If IsBlankString(Items.StandardAdditionVariantDocumentsExplanation.Title) Then
		Items.StandardAdditionVariantDocumentsExplanation.Visible = False;
	EndIf;
	
	Items.StandardAdditionVariantArbitrary.Visible = AdditionScenarioParameters.ArbitraryFilterVariant.Use;
	If Not IsBlankString(AdditionScenarioParameters.ArbitraryFilterVariant.Title) Then
		Items.ExportAdditionExportVariant2.ChoiceList[0].Presentation = AdditionScenarioParameters.ArbitraryFilterVariant.Title;
	EndIf;
	Items.StandardAdditionVariantArbitraryExplanation.Title = AdditionScenarioParameters.ArbitraryFilterVariant.Explanation;
	If IsBlankString(Items.StandardAdditionVariantArbitraryExplanation.Title) Then
		Items.StandardAdditionVariantArbitraryExplanation.Visible = False;
	EndIf;
	
	Items.CustomAdditionVariant.Visible              = AdditionScenarioParameters.AdditionalVariant.Use;
	Items.ExportPeriodNodeScenarioGroup.Visible      = AdditionScenarioParameters.AdditionalVariant.UseFilterPeriod;
	Items.ExportAdditionFilterByNodeScenario.Visible = Not IsBlankString(AdditionScenarioParameters.AdditionalVariant.FilterFormName);
	
	Items.ExportAdditionNodeExportVariant.ChoiceList[0].Presentation = AdditionScenarioParameters.AdditionalVariant.Title;
	Items.ExportAdditionExportVariantNodeString.Title                = AdditionScenarioParameters.AdditionalVariant.Title;
	
	Items.CustomAdditionVariantExplanation.Title = AdditionScenarioParameters.AdditionalVariant.Explanation;
	If IsBlankString(Items.CustomAdditionVariantExplanation.Title) Then
		Items.CustomAdditionVariantExplanation.Visible = False;
	EndIf;
	
	// Command titles
	If Not IsBlankString(AdditionScenarioParameters.AdditionalVariant.FormCommandTitle) Then
		Items.ExportAdditionFilterByNodeScenario.Title = AdditionScenarioParameters.AdditionalVariant.FormCommandTitle;
	EndIf;
	
	// Sorting visible items
	AdditionGroupOrder = New ValueList;
	If Items.StandardAdditionVariantNo.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionVariantNo, 
			Format(AdditionScenarioParameters.VariantWithoutAddition.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionVariantDocuments.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionVariantDocuments, 
			Format(AdditionScenarioParameters.AllDocumentVariant.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionVariantArbitrary.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionVariantArbitrary, 
			Format(AdditionScenarioParameters.ArbitraryFilterVariant.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.CustomAdditionVariant.Visible Then
		AdditionGroupOrder.Add(Items.CustomAdditionVariant, 
			Format(AdditionScenarioParameters.AdditionalVariant.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	AdditionGroupOrder.SortByPresentation();
	For Each AdditionGroupItem In AdditionGroupOrder Do
		Items.Move(AdditionGroupItem.Value, Items.ExportAdditionVariants);
	EndDo;
	
	// Editing settings is only allowed if the appropriate rights are granted
	HasRightsToSetup = AccessRight("SaveUserData", Metadata);
	Items.StandardSettingsVariantImportGroup.Visible = HasRightsToSetup;
	If HasRightsToSetup Then
		// Restoring predefined settings
		SetFirstItem = Not ExportAdditionSetSettingsServer(DataExchangeServer.ExportAdditionSettingsAutoSavingName());
		ExportAddition.CurrentSettingsItemPresentation = "";
	Else
		SetFirstItem = True;
	EndIf;
		
	SetFirstItem = SetFirstItem
		Or
		ExportAddition.ExportVariant < 0 
		Or
		( (ExportAddition.ExportVariant = 0) And (Not AdditionScenarioParameters.VariantWithoutAddition.Use) )
		Or
		( (ExportAddition.ExportVariant = 1) And (Not AdditionScenarioParameters.AllDocumentVariant.Use) )
		Or
		( (ExportAddition.ExportVariant = 2) And (Not AdditionScenarioParameters.ArbitraryFilterVariant.Use) )
		Or
		( (ExportAddition.ExportVariant = 3) And (Not AdditionScenarioParameters.AdditionalVariant.Use) );
	
	If SetFirstItem Then
		For Each AdditionGroupItem In AdditionGroupOrder[0].Value.ChildItems Do
			If TypeOf(AdditionGroupItem)=Type("FormField") And AdditionGroupItem.Type = FormFieldType.RadioButtonField Then
				ExportAddition.ExportVariant = AdditionGroupItem.ChoiceList[0].Value;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	// Initial view, same as ExportAdditionExportVariantSetVisibility client procedure
	Items.AllDocumentsFilterGroup.Enabled = ExportAddition.ExportVariant = 1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportVariant = 2;
	Items.CustomFilterGroup.Enabled      = ExportAddition.ExportVariant = 3;
	
	// Description of standard initial filters
	SetExportAdditionFilterDescription();
EndProcedure

&AtServer
Procedure SetExportAdditionFilterDescription()
	
	SetGeneralFilterAdditionDescription();
	SetAdditionDetailDescription();
	
EndProcedure

&AtServer
Procedure SetGeneralFilterAdditionDescription()
	
	Text = DataExchangeServer.InteractiveExportModificationGeneralFilterAdditionDescription(ExportAddition);
	NoFilter = IsBlankString(Text);
	If NoFilter Then
		Text = NStr("en='All documents'");
	EndIf;
	
	Items.ExportAdditionGeneralDocumentFilter.Title   = Text;
	Items.ExportAdditionGeneralFilterClearing.Visible = Not NoFilter;
EndProcedure

&AtServer
Procedure SetAdditionDetailDescription()
	
	Text = DataExchangeServer.InteractiveExportModificationDetailedFilterDetails(ExportAddition);
	NoFilter = IsBlankString(Text);
	If NoFilter Then
		Text = NStr("en='Additional data is not selected'");
	EndIf;
	
	Items.ExportAdditionDetailedFilter.Title           = Text;
	Items.ExportAdditionDetailedFilterClearing.Visible = Not NoFilter;
EndProcedure

// Returns a Boolean value - True if settings are restored, False if settings are not found.
&AtServer 
Function ExportAdditionSetSettingsServer(SettingsItemPresentation)
	
	Result = DataExchangeServer.InteractiveExportModificationRestoreSettings(ExportAddition, SettingsItemPresentation);
	SetExportAdditionFilterDescription();
	
	Return Result;
EndFunction

&AtServer 
Function ExportAdditionSettingsHistoryServer()
	
	Return DataExchangeServer.InteractiveExportModificationSettingsHistory(ExportAddition);
	
EndFunction

&AtServer
Procedure ExportAdditionExportVariantSetVisibility()
	
	Items.AllDocumentsFilterGroup.Enabled = ExportAddition.ExportVariant = 1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportVariant = 2;
	Items.CustomFilterGroup.Enabled       = ExportAddition.ExportVariant = 3;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// Step change event handlers and auxiliary procedures and functions.
//

&AtClient
Function Attachable_WaitingForExport_OnOpen(Cancel, SkipPage, IsGoNext)
	
	// Starting a long action
	BackgroundJob = ExportBackgroundJobAtServer();
	
	LongActionState               = NewLongActionState();
	LongActionState.ID            = BackgroundJob.ID;
	LongActionState.ResultAddress = BackgroundJob.ResultAddress;
	
	AttachIdleHandler("RegistrationAndExportIdleHandler", 0.1, True);
EndFunction

&AtClient
Function Attachable_End_OnOpen(Cancel, SkipPage, IsGoNext)
	
	NoErrors = LongActionState.ErrorInfo = Undefined;
	
	Items.SuccessfullyCompletedGroup.Visible = NoErrors;
	Items.CompletedWithErrorsGroup.Visible   = Not NoErrors;
EndFunction

// Periodical idle handler of the first stage (background registration)
&AtClient
Procedure RegistrationAndExportIdleHandler()
	
	ExchangeState = BackgroundJobStateAtServer(LongActionState.ID);
	
	If Not ExchangeState.Completed Then
		AttachIdleHandler("RegistrationAndExportIdleHandler", LongActionState.IdleInterval, True);
		Return;
	EndIf;
	
	LongActionState.ErrorInfo = ExchangeState.ErrorInfo;
	If LongActionState.ErrorInfo <> Undefined Then
		// Switching to the completion page due to a long action error
		GoToNext();
		Return;
	EndIf;
	
	// Exporting is completed. Waiting for session completion.
	Session = GetFromTempStorage(LongActionState.ResultAddress);
	
	LongActionState = NewLongActionState();
	LongActionState.ID  = Session.Session;
	
	AttachIdleHandler("CorrespondentWaitingHandler", LongActionState.IdleInterval, True);
EndProcedure

// Periodical idle handler of the second stage (background export)
&AtClient
Procedure CorrespondentWaitingHandler()
	
	Status = MessageSessionStatus(LongActionState.ID);
	
	If Status = "Executing" Then
		AttachIdleHandler("CorrespondentWaitingHandler", LongActionState.IdleInterval, True);
		
	ElsIf Status = "Done" Then
		GoToNext();
		
	Else
		LongActionState.ErrorInfo = NStr("en = 'Correspondent message delivery error'");
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.
// 

&AtClientAtServerNoContext
Function NewLongActionState()
	
	LongActionState = New Structure("ErrorInfo, ID, ResultAddress");
	LongActionState.Insert("IdleInterval", ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 5, 3) );
	
	Return LongActionState;
EndFunction

&AtServerNoContext
Function BackgroundJobStateAtServer(Val BackgroundJobID)
	
	Result = New Structure("Completed, ErrorInfo", True);
	
	Job = BackgroundJobs.FindByUUID(BackgroundJobID);
	If Job <> Undefined Then
		Result.Completed = Job.State <> BackgroundJobState.Active;
		If Result.Completed And Job.ErrorInfo <> Undefined Then
			Result.ErrorInfo = DetailErrorDescription(Job.ErrorInfo);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Function MessageSessionStatus(Val ID)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessageExchangeSessions.SessionStatus(ID);
	
EndFunction

&AtServerNoContext
Procedure CompleteBackgroundJob(Val ID)
	
	Job = BackgroundJobs.FindByUUID(ID);
	If Job <> Undefined Then
		Job.Cancel();
	EndIf;
	
EndProcedure

&AtServer
Function ExportBackgroundJobAtServer()
	
	Result = New Structure("ResultAddress", PutToTempStorage(Undefined, UUID) );
	
	BackgroundExecutionParameters = New Array;
	
	ExportParameters = New Structure;
	MetaDataProcessor = Metadata.DataProcessors.InteractiveExportModification;
	For Each MetaAttribute In MetaDataProcessor.Attributes Do
		AttributeName = MetaAttribute.Name;
		ExportParameters.Insert(AttributeName, ExportAddition[AttributeName]);
	EndDo;
	ExportParameters.Insert("AdditionalNodeScenarioRegistration", ExportAddition.AdditionalNodeScenarioRegistration.Unload() );
	ExportParameters.Insert("AdditionalRegistration",             ExportAddition.AdditionalRegistration.Unload() );
	
	BackgroundExecutionParameters.Add( ExportParameters );
	BackgroundExecutionParameters.Add( Result.ResultAddress );
	
	Job = BackgroundJobs.Execute("DataExchangeSaaS.ExchangeOnDemand", 
		BackgroundExecutionParameters, , NStr("en = 'Interactive exchange on demand.'"));
		
	Result.Insert("ID", Job.UUID);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////
// OVERRIDABLE PART: Filling wizard navigation table.
//

&AtServer
Procedure FullScenarioManually()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ModifyExportContent", "NavigationPageStart");
	GoToTableNewRow(2, "WaitingForExport",      "NavigationPageWait" , , "WaitingForExport_OnOpen");
	GoToTableNewRow(3, "End",                   "NavigationPageEnd", , "End_OnOpen");
	
EndProcedure

&AtServer
Procedure ScenarioWithoutAddition()
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WaitingForExport", "NavigationPageWait" , , "WaitingForExport_OnOpen");
	GoToTableNewRow(2, "End",              "NavigationPageEnd", , "End_OnOpen");
EndProcedure

#EndRegion