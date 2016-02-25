
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
 // Skipping the initialization to guarantee that the form will be 
 // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.SaaSOperations.DataExchangeSaaS\OnCreateStandaloneWorkstation");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnCreateStandaloneWorkstation();
	EndDo;
	
	ExchangePlanName = StandaloneModeInternal.StandaloneModeExchangePlan();
	
	// Getting exchange plan manager by name
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	NodeFilterStructure = DataExchangeServer.NodeFilterStructure(ExchangePlanName, "");
	
	Items.DataTransferRestrictionDetails.Title = DataTransferRestrictionDetails(ExchangePlanName, NodeFilterStructure);
	
	StandaloneWorkstationSetupInstruction = StandaloneModeInternal.InstructionTextFromTemplate("StandaloneWorkstationSetupInstruction");
	
	ItemTitle = NStr("en = 'Running applications in standalone mode requires 1C:Enterprise platform version [PlatformVersion]'");
	ItemTitle = StrReplace(ItemTitle, "[PlatformVersion]", DataExchangeSaaS.RequiredPlatformVersion());
	Items.PlatformVersionInscription.Title = ItemTitle;
	
	Object.StandaloneWorkstationDescription = StandaloneModeInternal.GenerateStandaloneWorkstationDefaultDescription();
	
	// Filling the navigation table
	StandaloneWorkstationGenerationScenario();
	
	ForceCloseForm = False;
	
	StandaloneWorkstationCreationEventLogMessageText = StandaloneModeInternal.StandaloneWorkstationCreationEventLogMessageText();
	
	InstallPackageFileName = StandaloneModeInternal.InstallPackageFileName();
	
	// Setting up user rights for data synchronization
	
	Items.UserRightsSetup.Visible = False;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		SynchronizationUsers.Load(SynchronizationUsers());
		
		Items.UserRightsSetup.Visible = SynchronizationUsers.Count() > 1;
		
	EndIf;
	
	// Thin client setup tooltip
	ThinClientSetupInstructionAddress = DataExchangeSaaS.ThinClientSetupInstructionAddress();
	If IsBlankString(ThinClientSetupInstructionAddress) Then
		Items.UploadInitialImageAtUsersComputer.ToolTipRepresentation = ToolTipRepresentation.None;
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Object.WSURL = ApplicationAddressOnTheInternet();
	
	// Selecting the first wizard step
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Items.MainPanel.CurrentPage = Items.End Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("CancelStandaloneWorkstationGeneration", ThisObject);
	
	WarningText = NStr("en = 'Do you want to cancel the creation of a standalone workstation?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, WarningText, "ForceCloseForm", NotifyDescription);
	
EndProcedure

// Idle handlers

&AtClient
Procedure LongActionIdleHandler()
	
	Try
		
		If JobCompleted(JobID) Then
			
			LongAction = False;
			LongActionFinished = True;
			GoToNext();
			
		Else
			AttachIdleHandler("LongActionIdleHandler", 5, True);
		EndIf;
		
	Except
		LongAction = False;
		GoBack();
		ShowMessageBox(, NStr("en = 'Cannot execute the operation.'"));
		
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), StandaloneWorkstationCreationEventLogMessageText);
	EndTry;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure StandaloneWorkstationSetupInstructionDocumentComplete(Item)
	
	// Print command visibility
	If Not Item.Document.queryCommandSupported("Print") Then
		Items.StandaloneWorkstationSetupInstructionInstructionPrint.Visible = False;
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandHandlers

// Supplied part

&AtClient
Procedure NextCommand(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	ChangeGoToNumber(-1);
	
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

// Overridable part

&AtClient
Procedure SetupDataTransferRestrictions(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.NodeSettingsForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	
	FormParameters = New Structure("NodeFilterStructure, CorrespondentVersion", NodeFilterStructure, "");
	Handler = New NotifyDescription("SetupDataTransferRestrictionsEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure SetupDataTransferRestrictionsEnd(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		For Each FilterSettings In NodeFilterStructure Do
			
			NodeFilterStructure[FilterSettings.Key] = OpeningResult[FilterSettings.Key];
			
		EndDo;
		
		Items.DataTransferRestrictionDetails.Title = DataTransferRestrictionDetails(ExchangePlanName, NodeFilterStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UploadInitialImageAtUsersComputer(Command)
	
	GetFile(InitialImageTempStorageAddress, InstallPackageFileName);
	
EndProcedure

&AtClient
Procedure HowToInstallOrUpdate1CEnterprisePlatfomVersion(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToInstallAndUpdate1CEnterprisePlatfomVersion");
	FormParameters.Insert("Title", NStr("en = 'How to install or update 1C:Enterprise platform'"));
	
	OpenForm("DataProcessor.StandaloneWorkstationGenerationWizard.Form.AdditionalDetails", FormParameters, ThisObject, "HowToInstallAndUpdate1CEnterprisePlatfomVersion");
	
EndProcedure

&AtClient
Procedure InstructionPrint(Command)
	
	Items.StandaloneWorkstationSetupInstruction.Document.execCommand("Print");
	
EndProcedure

&AtClient
Procedure SaveInstructionAs(Command)
	
	AddressInTempStorage = GetTemplate();
	GetFile(AddressInTempStorage, NStr("en = 'Standalone workstation setup instruction.html'"));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersPermitDataSynchronization.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SynchronizationUsers.DataSynchronizationPermitted");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure UploadInitialImageAtUsersComputerExtendedTooltipURLProcessing(Item, URL, StandardProcessing)
	
	If URL = "ThinClientSetupInstructionAddress" Then
		StandardProcessing = False;
		GotoURL(ThinClientSetupInstructionAddress);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Supplied part

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
	
	// Setting page to be displayed
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
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
		
		AttachIdleHandler("ExecuteLongActionHandler", 1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Step change handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// OnGoNext handler
		If Not IsBlankString(GoToRow.GoNextHandlerName)
			And Not GoToRow.LongAction Then
			
			ProcedureName = "Attachable_[HandlerName](Cancel)";
			ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
			
			Cancel = False;
			
			A = Eval(ProcedureName);
			
			If Cancel Then
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// OnGoBack handler
		If Not IsBlankString(GoToRow.GoBackHandlerName)
			And Not GoToRow.LongAction Then
			
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
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction And Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandleName](Cancel, SkipPage, IsGoNext)";
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
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// LongActionProcessing handler
	If Not IsBlankString(GoToRowCurrent.LongActionHandlerName) Then
		
		ProcedureName = "Attachable_[HandleName](Cancel, GoToNext)";
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

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongActionHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
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
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Function GetTemplate()
	
	TempFileName = GetTempFileName();
	TextDocument = New TextDocument;
	TextDocument.SetText(StandaloneWorkstationSetupInstruction);
	TextDocument.Write(TempFileName);
	BinaryData = New BinaryData(TempFileName);
	DeleteFiles(TempFileName);
	
	Return PutToTempStorage(BinaryData, UUID);
	
EndFunction

&AtClient
Procedure CancelStandaloneWorkstationGeneration(Result, AdditionalParameters) Export
	
	If Object.StandaloneWorkstation <> Undefined Then
		DataExchangeServerCall.DeleteSynchronizationSettings(Object.StandaloneWorkstation);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Internal procedures and functions

&AtServer
Procedure CreateStandaloneWorkstationInitialImageAtServer(Cancel)
	
	Try
		
		SelectedSynchronizationUsers = SynchronizationUsers.Unload(
			New Structure("DataSynchronizationPermitted, PermitDataSynchronization", False, True), "User"
				).UnloadColumn("User");
		
		If CommonUse.FileInfobase() Then
			
			InitialImageTempStorageAddress = PutToTempStorage(Undefined, UUID);
			InstallPackageInfoTempStorageAddress = PutToTempStorage(Undefined, UUID);
			
			DataProcessorObject = FormAttributeToValue("Object");
			
			Try
				DataProcessorObject.CreateStandaloneWorkstationInitialImage(
							NodeFilterStructure,
							SelectedSynchronizationUsers,
							InitialImageTempStorageAddress,
							InstallPackageInfoTempStorageAddress);
			Except
				Cancel = True;
				Return;
			EndTry;
			
			SetPrivilegedMode(True);
			
			ValueToFormAttribute(DataProcessorObject, "Object");
			
			InstallPackageInfo = GetFromTempStorage(InstallPackageInfoTempStorageAddress);
			InstallPackageFileSize = InstallPackageInfo.InstallPackageFileSize;
			
		Else
			
			// Getting wizard context as a structure
			WizardContext = New Structure;
			For Each Attribute In Metadata.DataProcessors.StandaloneWorkstationGenerationWizard.Attributes Do
				WizardContext.Insert(Attribute.Name, Object[Attribute.Name]);
			EndDo;
			WizardContext.Insert("NodeFilterStructure", NodeFilterStructure);
			WizardContext.Insert("SelectedSynchronizationUsers", SelectedSynchronizationUsers);
			
			Result = LongActions.ExecuteInBackground(
							UUID,
							"StandaloneModeInternal.CreateStandaloneWorkstationInitialImage",
							WizardContext,
							NStr("en = 'Generation standalone workstation initial image'"),
							True);
			
			InitialImageTempStorageAddress       = Result.StorageAddress;
			InstallPackageInfoTempStorageAddress = Result.StorageAddressAdditional;
			
			If Result.JobCompleted Then
				
				InstallPackageInfo = GetFromTempStorage(InstallPackageInfoTempStorageAddress);
				InstallPackageFileSize = InstallPackageInfo.InstallPackageFileSize;
				
			Else
				
				LongAction = True;
				JobID = Result.JobID;
				
			EndIf;
			
		EndIf;
		
	Except
		Cancel = True;
		WriteErrorToEventLog(
			DetailErrorDescription(ErrorInfo()), StandaloneWorkstationCreationEventLogMessageText);
		Return;
	EndTry;
	
EndProcedure

&AtServerNoContext
Function DataTransferRestrictionDetails(Val ExchangePlanName, NodeFilterStructure)
	
	Return DataExchangeServer.DataTransferRestrictionDetails(ExchangePlanName, NodeFilterStructure, "");
	
EndFunction

&AtClient
Function ApplicationAddressOnTheInternet()
	
	ConnectionParameters = StringFunctionsClientServer.GetParametersFromString(InfobaseConnectionString());
	
	If Not ConnectionParameters.Property("ws") Then
		Raise NStr("en = 'Standalone workstation creation is available in thin client only.'");
	EndIf;
	
	Return ConnectionParameters.ws;
EndFunction

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtServer
Function SynchronizationUsers()
	
	Result = New ValueTable;
	Result.Columns.Add("User"); // Type: CatalogRef.Users
	Result.Columns.Add("DataSynchronizationPermitted", New TypeDescription("Boolean"));
	Result.Columns.Add("PermitDataSynchronization", New TypeDescription("Boolean"));
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.InfobaseUserID AS InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	NOT Users.DeletionMark
	|	AND NOT Users.NotValid
	|	AND NOT Users.Internal
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.InfobaseUserID) Then
			
			IBUser = InfobaseUsers.FindByUUID(Selection.InfobaseUserID);
			
			If IBUser <> Undefined Then
				
				SingleUserSettings = Result.Add();
				SingleUserSettings.User = Selection.User;
				SingleUserSettings.DataSynchronizationPermitted = DataExchangeServer.DataSynchronizationPermitted(IBUser);
				SingleUserSettings.PermitDataSynchronization = SingleUserSettings.DataSynchronizationPermitted;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Step change handlers

&AtClient
Function Attachable_ExportSetup_OnGoNext(Cancel)
	
	If IsBlankString(Object.StandaloneWorkstationDescription) Then
		
		NString = NStr("en = 'Standalone workstation description is not specified.'");
		CommonUseClientServer.MessageToUser(NString,,"Object.StandaloneWorkstationDescription",, Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_InitialImageCreationWaiting_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	JobID = Undefined;
	
	CreateStandaloneWorkstationInitialImageAtServer(Cancel);
	
	If Cancel Then
		
	ElsIf Not LongAction Then
		
		Notify("Create_StandaloneWorkstation");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_InitialImageCreationWaitingLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_InitialImageCreationWaitingLongActionEnd_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		InstallPackageInfo = GetFromTempStorage(InstallPackageInfoTempStorageAddress);
		InstallPackageFileSize = InstallPackageInfo.InstallPackageFileSize;
		
		Notify("Create_StandaloneWorkstation");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_End_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ItemTitle = "[InstallPackageFileName] ([InstallPackageFileSize] [UnitOfMeasurement])";
	ItemTitle = StrReplace(ItemTitle, "[InstallPackageFileName]", InstallPackageFileName);
	ItemTitle = StrReplace(ItemTitle, "[InstallPackageFileSize]", Format(InstallPackageFileSize, "NFD=1; NG=3,0"));
	ItemTitle = StrReplace(ItemTitle, "[UnitOfMeasurement]", NStr("en = 'MB'"));
	
	Items.UploadInitialImageAtUsersComputer.Title = ItemTitle;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Filling wizard navigation table

&AtServer
Procedure StandaloneWorkstationGenerationScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Beginning",                           "NavigationPageStart");
	GoToTableNewRow(2, "ExportSetup",                "NavigationPageContinuation",,, "ExportSetup_OnGoNext");
	GoToTableNewRow(3, "InitialImageCreationWaiting", "NavigationPageWait",,,,, True, "InitialImageCreationWaiting_LongActionProcessing");
	GoToTableNewRow(4, "InitialImageCreationWaiting", "NavigationPageWait",,,,, True, "InitialImageCreationWaitingLongAction_LongActionProcessing");
	GoToTableNewRow(5, "InitialImageCreationWaiting", "NavigationPageWait",,,,, True, "InitialImageCreationWaitingLongActionEnd_LongActionProcessing");
	GoToTableNewRow(6, "End",                        "NavigationPageEnd",, "End_OnOpen");
	
EndProcedure

#EndRegion
