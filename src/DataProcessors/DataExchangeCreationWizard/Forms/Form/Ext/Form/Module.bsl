&AtClient
Var ForceCloseForm, UserAnsweredYesToQuestionAboutMapping, SkipCurrentPageCancelControl, ExternalResourcesAllowed;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form
	// will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Parameterizing the wizard by exchange plan name (it is mandatory)
	If Not Parameters.Property("ExchangePlanName", Object.ExchangePlanName) And IsBlankString(Object.ExchangePlanName) Then
		
		Raise NStr("en='The data processor cannot be opened manually.'");
		
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
	ExchangeWithServiceSetup = Parameters.Property("ExchangeWithServiceSetup");
	
	If GetFunctionalOption("UseSecurityProfiles") Then
		Object.RefNew = ExchangePlans[Object.ExchangePlanName].GetRef();
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Setting common default values
	InfobasePlacement                 = "ConnectionUnavailable";
	InfobaseType                      = "Server";
	ExecuteDataExchangeNow            = True;
	CreateInitialImageNow             = True;
	ExecuteInteractiveDataExchangeNow = True;
	
	Object.EMAILCompressOutgoingMessageFile = True;
	Object.FTPCompressOutgoingMessageFile   = True;
	Object.FTPConnectionPort = 21;
	
	// The default value for the exchange message transport kind
	Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
	
	// Checking whether an initial image creation form exists for the exchange plan
	InitialImageCreationFormExists = (Metadata.ExchangePlans[Object.ExchangePlanName].Forms.Find("InitialImageCreationForm") <> Undefined);
	
	// Getting exchange plan manager by name
	ExchangePlanManager = ExchangePlans[Object.ExchangePlanName];
	
	BriefDetails  = ExchangePlanManager.ExchangeBriefInfo();
	LinkToDetails = ExchangePlanManager.ExchangeDetailedInformation();
	
	SettingsFileNameForTarget = ExchangePlanManager.SettingsFileNameForTarget() + ".xml";
	
	NodeSettingsForm = "";
	DefaultValueSetupForm = "";
	
	NodeFilterStructure = DataExchangeServer.NodeFilterStructure(Object.ExchangePlanName, CorrespondentConfigurationVersion, NodeSettingsForm);
	NodeDefaultValues   = DataExchangeServer.NodeDefaultValues(Object.ExchangePlanName,   CorrespondentConfigurationVersion, DefaultValueSetupForm);
	
	AccountingSettingsCommentLabel = ExchangePlanManager.AccountingSettingsSetupComment();
	
	NodesSetupFormContext = New Structure;
	
	NodeFilterSettingsAvailable = NodeFilterStructure.Count() > 0;
	NodeDefaultValuesAvailable  = NodeDefaultValues.Count() > 0;
	
	Items.RestrictionsGroupBorder.Visible  = NodeFilterSettingsAvailable;
	Items.RestrictionsGroupBorder1.Visible = NodeFilterSettingsAvailable;
	Items.RestrictionsGroupBorder2.Visible = NodeFilterSettingsAvailable;
	Items.DefaultValueGroupBorder.Visible  = NodeDefaultValuesAvailable;
	Items.DefaultValueGroupBorder1.Visible = NodeDefaultValuesAvailable;
	Items.DefaultValueGroupBorder2.Visible = NodeDefaultValuesAvailable;
	Items.DefaultValueGroupBorder6.Visible = NodeDefaultValuesAvailable;
	
	DataTransferRestrictionDetails = DataExchangeServer.DataTransferRestrictionDetails(Object.ExchangePlanName, NodeFilterStructure, CorrespondentConfigurationVersion);
	DefaultValueDetails            = DataExchangeServer.DefaultValueDetails(Object.ExchangePlanName, NodeDefaultValues, CorrespondentConfigurationVersion);
	
	ThisNode = ExchangePlanManager.ThisNode();
	
	InitialImageCreationFormName = ExchangePlanManager.InitialImageCreationFormName();
	
	UsedExchangeMessageTransports = DataExchangeCached.UsedExchangeMessageTransports(ThisNode);
	
	UseExchangeMessageTransportEMAIL = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.EMAIL) <> Undefined);
	UseExchangeMessageTransportFILE  = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.FILE) <> Undefined);
	UseExchangeMessageTransportFTP   = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.FTP) <> Undefined);
	UseExchangeMessageTransportCOM   = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.COM) <> Undefined);
	UseExchangeMessageTransportWS    = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.WS) <> Undefined);
	
	// Getting other settings
	Object.SourceInfobasePrefix      = GetFunctionalOption("InfobasePrefix");
	Object.SourceInfobasePrefixIsSet = ValueIsFilled(Object.SourceInfobasePrefix);
	
	If Not Object.SourceInfobasePrefixIsSet
		And Not ExchangeWithServiceSetup Then
		
		//Object.SourceInfobasePrefix = DataExchangeOverridable.DefaultInfobasePrefix();
		DataExchangeOverridable.OnDefineDefaultInfobasePrefix(Object.SourceInfobasePrefix);
		
	EndIf;
	
	WizardRunVariant = "SetupNewDataExchange";
	
	If ExchangeWithServiceSetup Then
		
		WizardRunMode = "ExchangeOverWebService";
		
	ElsIf UseExchangeMessageTransportCOM Then
		
		WizardRunMode = "ExchangeOverExternalConnection";
		
	ElsIf UseExchangeMessageTransportWS Then
		
		WizardRunMode = "ExchangeOverWebService";
		
	Else
		
		WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels";
		
	EndIf;
	
	ExchangePlanMetadata = Metadata.ExchangePlans[Object.ExchangePlanName];
	ExchangePlanSynonym  = ExchangePlanMetadata.Synonym;
	
	FormTitle = NStr("en='Data synchronization with %Application% (setup)'");
	FormTitle = StrReplace(FormTitle, "%Application%", ExchangePlanSynonym);
	Title = FormTitle;
	
	Object.IsDistributedInfobaseSetup = DataExchangeCached.IsDistributedInfobaseExchangePlan(Object.ExchangePlanName);
	Object.IsStandardExchangeSetup    = DataExchangeCached.IsStandardDataExchangeNode(ThisNode);
	
	FileInfobase = CommonUse.FileInfobase();
	
	Object.UseTransportParametersFILE  = True;
	Object.UseTransportParametersFTP   = False;
	Object.UseTransportParametersEMAIL = False;
	
	Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
	Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
	Object.ThisInfobaseDescription = DataExchangeServer.PredefinedExchangePlanNodeDescription(Object.ExchangePlanName);
	ThisInfobaseDescriptionSet     = Not IsBlankString(Object.ThisInfobaseDescription);
	
	Items.ThisInfobaseDescription.ReadOnly  = ThisInfobaseDescriptionSet;
	Items.ThisInfobaseDescription1.ReadOnly = ThisInfobaseDescriptionSet;
	
	If Not ThisInfobaseDescriptionSet Then
		
		Object.ThisInfobaseDescription = DataExchangeCached.ThisInfobaseName();
		
	EndIf;
	
	Items.WSConnectionSettingsDecoration.ExtendedTooltip.Title = StrReplace(
		Items.WSConnectionSettingsDecoration.ExtendedTooltip.Title, "[ProhibitedChars]",
		DataExchangeClientServer.ProhibitedCharsInWSProxyUserName());
		
	Items.SaaSConnectionParametersDecoration.ExtendedTooltip.Title = StrReplace(
		Items.SaaSConnectionParametersDecoration.ExtendedTooltip.Title, "[ProhibitedChars]",
		DataExchangeClientServer.ProhibitedCharsInWSProxyUserName());
	
	SetVisibleAtServer();
	
	// Setting values of the Next button comment labels at the bottom of wizard pages
	
	// Comment label on FILE page
	If UseExchangeMessageTransportFILE Then
		
		If UseExchangeMessageTransportFTP Then
			
			Items.LabelNextFILE.Title = NextLabelFTP();
			
		ElsIf UseExchangeMessageTransportEMAIL Then
			
			Items.LabelNextFILE.Title = NextLabelEMAIL();
			
		Else
			
			Items.LabelNextFILE.Title = NextLabelSettings();
			
		EndIf;
		
	EndIf;
	
	// Comment label on FTP page
	If UseExchangeMessageTransportFTP Then
		
		If UseExchangeMessageTransportEMAIL Then
			
			Items.NextLabelFTP.Title = NextLabelEMAIL();
			
		Else
			
			Items.NextLabelFTP.Title = NextLabelSettings();
			
		EndIf;
		
	EndIf;
	
	// Comment label on EMAIL page
	If UseExchangeMessageTransportEMAIL Then
		
		Items.NextLabelEMAIL.Title = NextLabelSettings();
		
	EndIf;
	
	IsContinuedInDIBSubordinateNodeSetup = Parameters.Property("IsContinuedInDIBSubordinateNodeSetup");
	
	If Not IsContinuedInDIBSubordinateNodeSetup Then
		
		If DataExchangeServer.IsSubordinateDIBNode() Then
			
			DIBExchangePlanName = DataExchangeServer.MasterNode().Metadata().Name;
			
			If Object.ExchangePlanName = DIBExchangePlanName
				And Not Constants.SubordinateDIBNodeSetupCompleted.Get() Then
				
				IsContinuedInDIBSubordinateNodeSetup = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		
		DataExchangeServer.OnContinueSubordinateDIBNodeSetup();
		
		WizardRunVariant = "ContinueDataExchangeSetup";
		
		DataProcessorObject = FormAttributeToValue("Object");
		DataProcessorObject.ExecuteWizardParameterImportFromConstant(False);
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
		Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
		Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
		
		Items.WizardRunModeChoiceSwitchGroup.Title = NStr("en = 'Continue setup for synchronization with the master node'");
		
		Items.BackupGroup.Visible = False;
	EndIf;
	
	WizardRunVariantOnChangeAtServer();
	
	WizardRunModeOnChangeAtServer();
	
	EventLogMessageTextEstablishingConnectionToWebService = DataExchangeServer.EventLogMessageTextEstablishingConnectionToWebService();
	DataExchangeCreationEventLogMessageText = DataExchangeServer.DataExchangeCreationEventLogMessageText();
	
	LongAction = False;
	PredefinedDataExchangeSchedule = "EveryHour";
	DataExchangeExecutionSchedule  = PredefinedScheduleEveryHour();
	CustomDescriptionPresentation  = String(DataExchangeExecutionSchedule);
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.InternetAccessParameters.Visible  = True;
		Items.InternetAccessParameters1.Visible = True;
		Items.InternetAccessParameters2.Visible = True;
	Else
		Items.InternetAccessParameters.Visible  = False;
		Items.InternetAccessParameters1.Visible = False;
		Items.InternetAccessParameters2.Visible = False;
	EndIf;
	
	SetBackupDetailsText();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
	EndIf;

	ForceCloseForm = False;
	UserAnsweredYesToQuestionAboutMapping = False;
	
	ExternalResourcesAllowed = New Structure;
	ExternalResourcesAllowed.Insert("COMAllowed",  False);
	ExternalResourcesAllowed.Insert("FILEAllowed", False);
	ExternalResourcesAllowed.Insert("FTPAllowed",  False);
	
	OSAuthenticationOnChange();
	
	InfobaseRunModeOnChange();
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If LongAction Then
		ShowMessageBox(, NStr("en = 'Creating the data synchronization.
		                            |The wizard cannot be terminated at this time.'"));
		Cancel = True;
		Return;
	EndIf;
	
	If ForceCloseForm = True Then
		Return;
	EndIf;
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		WarningText = NStr("en = 'Setting up the subordinate node of the distributed infobase.
		                          |Do you want to cancel the setup and use the default settings?'");
		
		DIBContinuationCancelNotifyDescription = New NotifyDescription("DIBContinuationCancelNotifyDescription", ThisObject);
		CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, WarningText, "CloseFormWithoutWarning", DIBContinuationCancelNotifyDescription);
		
		Return;
	EndIf;
	
	WarningText = NStr("en = 'Do you want to cancel synchronization setup and exit the wizard?'");
	CloseNotifyDescription = New NotifyDescription("DeleteDataExchangeSettings", ThisObject);
	CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, WarningText, "CloseFormWithoutWarning", CloseNotifyDescription);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("DataExchangeCreationWizardFormClosed");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ClosingObjectMappingForm" Then
		
		Cancel = False;
		
		Status(NStr("en = 'Gathering mapping data...'"));
		
		UpdateMappingStatisticsDataAtServer(Cancel, Parameter);
		
		If Cancel Then
			ShowMessageBox(, NStr("en = 'Error gathering statistic data.'"));
		Else
			
			ExpandStatisticsTree(Parameter.UniquenessKey);
			
			Status(NStr("en = 'Data gathering completed.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

////////////////////////////////////////////////////////////////////////////////
// WizardPageStart page.

&AtClient
Procedure DataExchangeSettingsFileNameToImportStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'Data synchronization settings file (*.xml)'") + "|*.xml" );
	
	Notification = New NotifyDescription("ExportDataExchangeFileSelectionCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogSettings, UUID);
EndProcedure

&AtClient
Procedure DataExchangeSettingsFileNameToImportOnChange(Item)
	
	DataExchangeSettingsFileImported = False;
	
EndProcedure

&AtClient
Procedure WizardRunVariantOnChange(Item)
	
	WizardRunVariantOnChangeAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageDataExchangeCreatedSuccessfully page.

&AtClient
Procedure PredefinedDataExchangeScheduleOnChange(Item)
	
	PredefinedDataExchangeScheduleOnValueChange();
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAutomaticallyOnChange(Item)
	
	ExecuteDataExchangeAutomaticallyOnValueChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageWizardRunModeChoice page.

&AtClient
Procedure WizardRunModeOnChange(Item)
	
	WizardRunModeOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Object, "COMInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Object, "COMInfobaseDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfobaseRunModeOnChange(Item)
	
	InfobaseRunModeOnChange();
	
EndProcedure

&AtClient
Procedure AuthenticationTypeOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageSetTransportParametersFILE page.

&AtClient
Procedure FILEDataExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not FileInfobase Then
		Return;
	EndIf;
	
	DataExchangeClient.FileDirectoryChoiceHandler(Object, "FILEDataExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEDataExchangeDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Object, "FILEDataExchangeDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure UseTransportParametersFILEOnChange(Item)
	
	Items.TransportSettingsFILE.Enabled = Object.UseTransportParametersFILE;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageSetTransportParametersFTP page.

&AtClient
Procedure UseTransportParametersFTPOnChange(Item)
	
	Items.TransportSettingsFTP.Enabled = Object.UseTransportParametersFTP;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageSetTransportParametersEMAIL page.

&AtClient
Procedure UseTransportParametersEMAILOnChange(Item)
	
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
EndProcedure

#EndRegion

#Region StatisticsTreeFormTableItemEventHandlers

&AtClient
Procedure StatisticsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

////////////////////////////////////////////////////////////////////////////////
// Supplied part.

&AtClient
Procedure NextCommand(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	UserAnsweredYesToQuestionAboutMapping = False;
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	ExecuteDoneCommand();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure HelpCommand(Command)
	
	OpenFormHelp();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part.

&AtClient
Procedure MapData(Command)
	
	OpenMappingForm();
	
EndProcedure

&AtClient
Procedure SetupDataExport(Command)
	
	JoinType = "WebService";
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[NodeSetupForm]", NodesSetupForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
	FormParameters.Insert("ConnectionParameters", ExternalConnectionParameterStructure(JoinType));
	FormParameters.Insert("Settings",             NodesSetupFormContext);
	
	Handler = New NotifyDescription("DataExportSetupCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure DataExportSetupCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		NodesSetupFormContext = Result;
		
		DataExportSettingsDescription = Result.ContextDetails;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataRegistrationRestrictionSetup(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodeSettingsForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[NodeSettingsForm]", NodeSettingsForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
	FormParameters.Insert("NodeFilterStructure",  NodeFilterStructure);
	
	Handler = New NotifyDescription("DataRegistrationRestrictionSetupCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure DataRegistrationRestrictionSetupCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each FilterSettings In NodeFilterStructure Do
			
			NodeFilterStructure[FilterSettings.Key] = Result[FilterSettings.Key];
			
		EndDo;
		
		// Server call
		GetDataTransferRestrictionDetails(NodeFilterStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseRegistrationRestrictionSetupViaWebService(Command)
	
	CorrespondentInfobaseRegistrationRestrictionSetup("WebService");
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseRegistrationRestrictionSetupThroughExternalConnection(Command)
	
	CorrespondentInfobaseRegistrationRestrictionSetup("ExternalConnection");
	
EndProcedure

&AtClient
Procedure DefaultValueSetup(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[DefaultValueSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[DefaultValueSetupForm]", DefaultValueSetupForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
	FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
	
	Handler = New NotifyDescription("DefaultValueSetupCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure DefaultValueSetupCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each Settings In NodeDefaultValues Do
			
			NodeDefaultValues[Settings.Key] = Result[Settings.Key];
			
		EndDo;
		
		// Server call
		GetDefaultValueDetails(NodeDefaultValues);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetupViaWebService(Command)
	
	CorrespondentInfobaseDefaultValueSetup("WebService");
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetupViaExternalConnection(Command)
	
	CorrespondentInfobaseDefaultValueSetup("ExternalConnection");
	
EndProcedure

&AtClient
Procedure SaveDataExchangeSettingsFile(Command)
	
	Var TempStorageAddress;
	
	Cancel = False;
	
	// Server call
	ExportExchangeSettingsForTarget(Cancel, TempStorageAddress);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Error saving data synchronization settings file.'"));
		
	Else
		
		#If WebClient Then
			
			GetFile(TempStorageAddress, SettingsFileNameForTarget, True);
			
			Object.DataExchangeSettingsFileName = SettingsFileNameForTarget;
			
		#Else
			
			Dialog = New FileDialog(FileDialogMode.Save);
			
			Dialog.Title        = NStr("en = 'Specify data synchronization settings file name.'");
			Dialog.Extension    = "xml";
			Dialog.Filter       = NStr("en = 'Data synchronization settings file(*.xml)|*.xml'");
			Dialog.FullFileName = SettingsFileNameForTarget;
			
			If Dialog.Choose() Then
				
				Object.DataExchangeSettingsFileName = Dialog.FullFileName;
				
				BinaryData = GetFromTempStorage(TempStorageAddress);
				
				DeleteFromTempStorage(TempStorageAddress);
				
				// Getting file
				BinaryData.Write(Object.DataExchangeSettingsFileName);
				
			EndIf;
			
		#EndIf
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFILEConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestFILEConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Object,, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestFTPConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestFTPConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Object,,,, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestEMAILConnection(Command)
	
	TestConnection("EMAIL");
	
EndProcedure

&AtClient
Procedure TestCOMConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestCOMConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Object, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestWSConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestWSConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Object,,, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure ChangeCustomSchedule(Command)
	
	Dialog = New ScheduledJobDialog(DataExchangeExecutionSchedule);
	NotifyDescription = New NotifyDescription("ChangeCustomScheduleCompletion", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure ChangeCustomScheduleCompletion(Schedule) Export
	
	If Schedule <> Undefined Then
		
		DataExchangeExecutionSchedule = Schedule;
		
		CustomDescriptionPresentation = String(DataExchangeExecutionSchedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DetailedDescription(Command)
	
	DataExchangeClient.OpenDetailedSynchronizationDetails(LinkToDetails);
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParameterForm();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure ExecuteDoneCommand(Val CloseForm = True)
	
	Cancel = False;
	If WizardRunMode = "ExchangeOverExternalConnection" Then
		FinishExchangeOverExternalConnectionSetup(CloseForm);
		
	ElsIf WizardRunMode = "ExchangeOverWebService" Then
		FinishExchangeOverWebServiceSetup();
		
	ElsIf WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels" Then
		If WizardRunVariant = "SetupNewDataExchange" Then
			FinishFirstExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel);
			
		ElsIf WizardRunVariant = "ContinueDataExchangeSetup" Then
			FinishSecondExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel, CloseForm);
			
		EndIf;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	RefreshInterface();
	
	If CloseForm Then
		ForceCloseForm = True;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure BackupLabelURLProcessing(Item, URL, StandardProcessing)
	StandardProcessing = False;
	
	If URL = "Backup" Then
		InfobaseBackupClientModule = CommonUseClient.CommonModule("InfobaseBackupClient");
		InfobaseBackupClientModule.OpenBackupForm(ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBackupDetailsText()
	Option = DataExchangeServer.BackupOption();
	
	If IsBlankString(Option) Then
		Return;
	EndIf;
	
	Text = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'It is recommended that you create an <a href=%1>infobase backup</a> before synchronization setup.'"),
		Option);
		
	DocFormat = New FormattedDocument;
	DocFormat.SetHTML(Text, New Structure);
	Text = DocFormat.GetFormattedString();
	
	Items.BackupLabel.Title        = Text;
	Items.BackupServiceLabel.Title = Text;
EndProcedure

&AtClient
Procedure PredefinedDataExchangeScheduleOnValueChange()
	
	UseCustomSchedule = (PredefinedDataExchangeSchedule = "OtherSchedule");
	
	Items.CustomSchedulePages.CurrentPage = ?(UseCustomSchedule,
						Items.CustomSchedulePage,
						Items.EmptyCustomSchedulePage);
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAutomaticallyOnValueChange()
	
	Items.PredefinedSchedulePages.CurrentPage = ?(ExecuteDataExchangeAutomatically,
						Items.PredefinedSchedulePage,
						Items.NotAvailablePredefinedSchedulePage);
	
EndProcedure

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 1 Then
		
		GoToNumber = 1;
		
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
	
	Items.MainPanel.CurrentPage       = Items[GoToRowCurrent.MainPageName];
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
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
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

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									DecorationPageName,
									NavigationPageName,
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									OnOpenHandlerName = "",
									LongAction = False,
									LongActionHandlerName = "")
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
			
			//Return GetFormButtonByCommandName(Item, CommandName);
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
Function TestCOMConnectionAtServer()
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("COMOSAuthentication");
	SettingsStructure.Insert("COMInfobaseOperationMode");
	SettingsStructure.Insert("COMInfobaseNameAtPlatformServer");
	SettingsStructure.Insert("COMUserName");
	SettingsStructure.Insert("COMPlatformServerName");
	SettingsStructure.Insert("COMInfobaseDirectory");
	SettingsStructure.Insert("COMUserPassword");
	FillPropertyValues(SettingsStructure, Object);
	
	Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(SettingsStructure);
	If Result.Connection = Undefined Then
		Return Result.BriefErrorDetails;
	EndIf;
	Return ""; // done
	
EndFunction

&AtClient
Procedure AllowResourceCompletion(Result, PermissionName) Export
	
	If Result = DialogReturnCode.OK Then
		
		ExternalResourcesAllowed[PermissionName] = True;
		ChangeGoToNumber(+1);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestForUseExternalResources(Val Object, RequestCOM = False,
	RequestFILE = False, RequestWS = False, RequestFTP = False)
	
	Write = InformationRegisters.ExchangeTransportSettings.CreateRecordManager();
	FillPropertyValues(Write, Object);
	Write.Node = Object.RefNew;
	
	PermissionRequests = New Array;
	
	InformationRegisters.ExchangeTransportSettings.RequestToUseExternalResources(PermissionRequests,
		Write, RequestCOM, RequestFILE, RequestWS, RequestFTP);
	Return PermissionRequests;
	
EndFunction

&AtClient
Procedure TestCOMConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		ClearMessages();
		
		If StandardSubsystemsClientCached.ClientParameters().FileInfobase Then
			
			CommonUseClient.RegisterCOMConnector(False);
			
		EndIf;
		
		MessageText = TestCOMConnectionAtServer();
		If IsBlankString(MessageText) Then
			MessageText = NStr("en = 'Connection test succeeded.'");
		EndIf;
		ShowMessageBox(,MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFILEConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		TestConnection("FILE");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFTPConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		TestConnection("FTP");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestWSConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Cancel = False;
		
		TestWSConnectionAtClient(Cancel);
		
		If Not Cancel Then
			
			ShowMessageBox(, NStr("en = 'Connection established.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Idle handlers.

&AtClient
Procedure LongActionIdleHandler()
	
	ErrorMessageString = "";
	
	ActionState = DataExchangeServerCall.LongActionState(LongActionID,
																		Object.WSURL,
																		Object.WSUserName,
																		Object.WSPassword,
																		ErrorMessageString);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	ElsIf ActionState = "Completed" Then
		
		LongAction         = False;
		LongActionFinished = True;
		
		NextCommand(Undefined);
		
	Else // Failed, Canceled
		
		WriteErrorToEventLog(ErrorMessageString, DataExchangeCreationEventLogMessageText);
		
		LongAction = False;
		
		BackCommand(Undefined);
		
		QuestionText = NStr("en = 'Error creating data synchronization.
							|Do you want to view the event log?'");
		
		SuggestOpenEventLog(QuestionText, DataExchangeCreationEventLogMessageText);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures and functions.

&AtServer
Procedure SetupNewDataExchangeAtServer(Cancel, NodeFilterStructure, NodeDefaultValues)
	
	Object.WizardRunVariant = WizardRunVariant;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetupNewDataExchangeOverExternalConnectionAtServer(Cancel, CorrespondentInfobaseNodeFilterSetup, CorrespondentInfobaseNodeDefaultValues)
	
	Object.WizardRunVariant = WizardRunVariant;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchangeOverExternalConnection(Cancel, NodeFilterStructure, NodeDefaultValues, CorrespondentInfobaseNodeFilterSetup, CorrespondentInfobaseNodeDefaultValues);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	Items.ExecuteInteractiveDataExchangeNow.Title = StrReplace(Items.ExecuteInteractiveDataExchangeNow.Title, "%Application%", ExchangePlanSynonym);
	
EndProcedure

&AtServer
Procedure SetupNewDataExchangeAtServerOverWebService(Cancel)
	
	Object.WizardRunVariant = WizardRunVariant;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchangeOverWebServiceInTwoBases(Cancel,
																		NodesSetupFormContext,
																		LongAction,
																		LongActionID);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure UpdateDataExchangeSettings(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.UpdateDataExchangeSettings(Cancel,
												NodeDefaultValues,
												CorrespondentInfobaseNodeDefaultValues,
												LongAction,
												LongActionID);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetVisibleAtServer()
	
	Items.ExchangeInformationDirectoryAtServerSelectionComment.Visible = Not FileInfobase;
	Items.FILEDataExchangeDirectory.ChoiceButton = FileInfobase;
	
	Items.SourceInfobasePrefix.Visible  = Not Object.SourceInfobasePrefixIsSet;
	Items.SourceInfobasePrefix1.Visible = Not Object.SourceInfobasePrefixIsSet;
	Items.TargetInfobasePrefix.Visible  = False;
	
	Items.SourceInfobasePrefixExchangeOverWebService.Visible  = Not Object.SourceInfobasePrefixIsSet;
	Items.SourceInfobasePrefixExchangeOverWebService.ReadOnly = Object.SourceInfobasePrefixIsSet;
	
	Items.SourceInfobasePrefixExchangeWithService.ReadOnly = Object.SourceInfobasePrefixIsSet;
	Items.TargetInfobasePrefixExchangeWithService.ReadOnly = True;
	
	Items.FinalActionDisplayPages.CurrentPage = ?(Object.IsDistributedInfobaseSetup,
					Items.ExecuteSubordinateNodeImageInitialCreationPage,
					Items.ExecuteDataExportForMappingPage);
	
	If Object.IsDistributedInfobaseSetup Then
		
		Items.WizardRunVariant.Visible = False;
		
		Items.PrefixStub.Visible = False;
		Items.TargetInfobasePrefix1.ToolTipRepresentation = ToolTipRepresentation.None;
		
		Items.WizardRunModeChoiceSwitchGroup.Title = NStr("en = 'Initial image creation for subordinate DIB node.'");
		
	EndIf;
	
EndProcedure

&AtClient
Function MessageTransportResultPresentation()
	
	If ExchangeWithServiceSetup Then
		
		Result = NStr("en = 'Service application connection parameters:
		|%1'");
		Result = StringFunctionsClientServer.SubstituteParametersInString(Result, GetExchangeTransportSettingsDescription());
		
	Else
		
		Result = String(Object.ExchangeMessageTransportKind)
			+ NStr("en = ', parameters:'") + Chars.LF
			+ GetExchangeTransportSettingsDescription()
		;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function NodeFiltersResultPresentation()
	
	Return ?(IsBlankString(DataTransferRestrictionDetails), "", DataTransferRestrictionDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function CorrespondentInfobaseNodeFilterResultPresentation()
	
	Return ?(IsBlankString(CorrespondentInfobaseDataTransferRestrictionDetails), "", CorrespondentInfobaseDataTransferRestrictionDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function DefaultNodeValueResultPresentation()
	
	Return ?(IsBlankString(DefaultValueDetails), "", DefaultValueDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function CorrespondentInfobaseNodeDefaultValueResultPresentation()
	
	Return ?(IsBlankString(CorrespondentInfobaseDefaultValueDetails), "", CorrespondentInfobaseDefaultValueDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtServer
Procedure ExportExchangeSettingsForTarget(Cancel, TempStorageAddress)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.ExportWizardParametersToTempStorage(Cancel, TempStorageAddress);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure ImportWizardParameters(Cancel, TempStorageAddress)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.ExecuteWizardParameterImportFromTempStorage(Cancel, TempStorageAddress);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
	Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
	If Not Cancel Then
		SettingsRead = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure GetDataTransferRestrictionDetails(NodeFilterStructure)
	
	DataTransferRestrictionDetails = DataExchangeServer.DataTransferRestrictionDetails(Object.ExchangePlanName, NodeFilterStructure, CorrespondentConfigurationVersion);
	
EndProcedure

&AtServer
Procedure GetCorrespondentInfobaseDataTransferRestrictionDetails(CorrespondentInfobaseNodeFilterSetup)
	
	CorrespondentInfobaseDataTransferRestrictionDetails = DataExchangeServer.CorrespondentInfobaseDataTransferRestrictionDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeFilterSetup, CorrespondentConfigurationVersion);
	
EndProcedure

&AtServer
Procedure GetDefaultValueDetails(NodeDefaultValues)
	
	DefaultValueDetails = DataExchangeServer.DefaultValueDetails(Object.ExchangePlanName, NodeDefaultValues, CorrespondentConfigurationVersion);
	
EndProcedure

&AtServer
Procedure GetCorrespondentInfobaseDefaultValueDetails(CorrespondentInfobaseNodeDefaultValues)
	
	CorrespondentInfobaseDefaultValueDetails = DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentConfigurationVersion);
	
EndProcedure

&AtClient
Procedure DataExchangeInitializationAtClient(Cancel)
	
	Status(NStr("en = 'Sending data...'"));
	
	// Exporting data
	DataExchangeServerCall.ExecuteDataExchangeForInfobaseNode(Cancel, Object.InfobaseNode, False, True, Object.ExchangeMessageTransportKind);
	
	Status(NStr("en = 'Sending data completed.'"));
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Error sending data (see the event log for details).'"));
		
	EndIf;
	
EndProcedure

&AtServer
Function GetExchangeTransportSettingsDescription()
	
	COMInfobaseOperationMode = 0;
	COMOSAuthentication = False;
	
	// Return value
	Result = "";
	
	SettingsPresentation = InformationRegisters.ExchangeTransportSettings.TransportSettingsPresentations(Object.ExchangeMessageTransportKind);
	
	For Each Item In SettingsPresentation Do
		
		SettingValue = Object[Item.Key];
		
		If WizardRunMode = "ExchangeOverExternalConnection" Then
			
			If Item.Key = "COMInfobaseOperationMode" Then
				
				SettingValue = ?(Object[Item.Key] = 0, NStr("en = 'File'"), NStr("en = 'Client/server'"));
				
				COMInfobaseOperationMode = Object[Item.Key];
				
			EndIf;
			
			If Item.Key = "COMOSAuthentication" Then
				
				COMOSAuthentication = Object[Item.Key];
				
			EndIf;
			
			If COMInfobaseOperationMode = 0 Then
				
				If    Item.Key = "COMInfobaseNameAtPlatformServer"
					Or Item.Key = "COMPlatformServerName" Then
					Continue;
				EndIf;
				
			Else
				
				If Item.Key = "COMInfobaseDirectory" Then
					Continue;
				EndIf;
				
			EndIf;
			
			If COMOSAuthentication Then
				
				If    Item.Key = "COMUserName"
					Or Item.Key = "COMUserPassword" Then
					Continue;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Find(Upper(Item.Value), "PASSWORD") <> 0 Then
			
			Continue; // Hiding password values
			
		ElsIf  Not ValueType(SettingValue, "Number")
				 And Not ValueType(SettingValue, "Boolean")
				 And Not ValueIsFilled(SettingValue) Then
			
			// Displaying <empty> if the setting value is not specified
			SettingValue = NStr("en = '<empty>'");
			
		EndIf;
		
		SettingRow = "[Presentation]: [Value]";
		SettingRow = StrReplace(SettingRow, "[Presentation]", Item.Value);
		SettingRow = StrReplace(SettingRow, "[Value]", SettingValue);
		
		Result = Result + SettingRow + Chars.LF;
		
	EndDo;
	
	If IsBlankString(Result) Then
		
		Result = NStr("en = 'Connection parameters are not specified.'");
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function ValueType(Value, TypeName)
	
	Return TypeOf(Value) = Type(TypeName);
	
EndFunction

&AtClient
Procedure TestConnection(TransportKind)
	
	Cancel = False;
	
	TestConnectionAtServer(Cancel, TransportKind);
	
	If Not Cancel Then
		
		WarningText = NStr("en = 'Connection established.'");
		ShowMessageBox(, WarningText);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure TestConnectionAtServer(Cancel, TransportKind)
	
	If TypeOf(TransportKind) = Type("String") Then
		
		TransportKind = Enums.ExchangeMessageTransportKinds[TransportKind];
		
	EndIf;
	
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel, Object, TransportKind);
	
EndProcedure

&AtServer
Procedure TestWSConnectionAtServer(Cancel, ExtendedCheck, IsSuggestOpenEventLog)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, Object);
	
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters);
	
	If WSProxy = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CorrespondentVersions = DataExchangeCached.CorrespondentVersions(ConnectionParameters);
	
	Object.CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	Object.CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If Object.CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters);
		
		If WSProxy = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf Object.CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters);
		
		If WSProxy = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
		
	If ExtendedCheck Then
		
		// Getting parameters of the correspondent infobase
		IsSuggestOpenEventLog = False;
		
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(Object.ExchangePlanName, "", ""));
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(Object.ExchangePlanName, "", ""));
			
		Else
			
			TargetParameters = ValueFromStringInternal(WSProxy.GetInfobaseParameters(Object.ExchangePlanName, "", ""));
			
		EndIf;
		
		// {HANDLER: OnConnectToCorrespondent} Start
		CorrespondentConfigurationVersion = Undefined;
		TargetParameters.Property("ConfigurationVersion", CorrespondentConfigurationVersion);
		
		OnConnectToCorrespondent(Cancel, CorrespondentConfigurationVersion);
		
		If Cancel Then
			Return;
		EndIf;
		// {HANDLER: OnConnectToCorrespondent} End
		
		If Not TargetParameters.ExchangePlanExists Then
			
			Message = NStr("en = 'The correspondent infobase does not provide the synchronization with the current infobase.'");
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
			Return;
			
		EndIf;
		
		Object.CorrespondentNodeCode = TargetParameters.ThisNodeCode;
		
		Object.TargetInfobasePrefix = TargetParameters.InfobasePrefix;
		Object.TargetInfobasePrefixIsSet = ValueIsFilled(Object.TargetInfobasePrefix);
		
		If Not Object.TargetInfobasePrefixIsSet Then
			Object.TargetInfobasePrefix = TargetParameters.DefaultInfobasePrefix;
		EndIf;
		
		Items.TargetInfobasePrefixExchangeOverWebService.Visible  = Not Object.TargetInfobasePrefixIsSet;
		Items.TargetInfobasePrefixExchangeOverWebService.ReadOnly = Object.TargetInfobasePrefixIsSet;
		
		// Checking whether an exchange with the correspondent infobase exists
		CheckWhetherDataExchangeWithSecondBaseExists(Cancel);
		If Cancel Then
			Return;
		EndIf;
		
		Object.SecondInfobaseDescription = TargetParameters.InfobaseDescription;
		SecondInfobaseDescriptionSet = Not IsBlankString(Object.SecondInfobaseDescription);
		
		Items.SecondInfobaseDescription1.ReadOnly = SecondInfobaseDescriptionSet;
		
		If Not SecondInfobaseDescriptionSet Then
			
			Object.SecondInfobaseDescription = TargetParameters.DefaultInfobaseDescription;
			
		EndIf;
		
		NodeSettingsForm = "";
		CorrespondentInfobaseNodeSettingsForm = "";
		DefaultValueSetupForm = "";
		CorrespondentInfobaseDefaultValueSetupForm = "";
		NodesSetupForm = "";
		
		NodeFilterStructure = DataExchangeServer.NodeFilterStructure(Object.ExchangePlanName, CorrespondentConfigurationVersion, NodeSettingsForm);
		NodeDefaultValues   = DataExchangeServer.NodeDefaultValues(Object.ExchangePlanName, CorrespondentConfigurationVersion, DefaultValueSetupForm);
		
		DataExchangeServer.CommonNodeData(Object.ExchangePlanName, CorrespondentConfigurationVersion, NodesSetupForm);
		
		CorrespondentInfobaseNodeDefaultValues = DataExchangeServer.CorrespondentInfobaseNodeDefaultValues(Object.ExchangePlanName, CorrespondentConfigurationVersion, CorrespondentInfobaseDefaultValueSetupForm);
		
		CorrespondentInfobaseNodeDefaultValuesAvailable = CorrespondentInfobaseNodeDefaultValues.Count() > 0;
		
		Items.DefaultValueGroupBorder4.Visible                     = CorrespondentInfobaseNodeDefaultValuesAvailable;
		Items.CorrespondentInfobaseDefaultValueGroupBorder.Visible = CorrespondentInfobaseNodeDefaultValuesAvailable;
		
		CorrespondentInfobaseDefaultValueDetails = DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentConfigurationVersion);
		
		CorrespondentAccountingSettingsCommentLabel = DataExchangeServer.CorrespondentInfobaseAccountingSettingsSetupComment(Object.ExchangePlanName, CorrespondentConfigurationVersion);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestWSConnectionAtClient(Cancel, ExtendedCheck = False)
	
	If IsBlankString(Object.WSURL) Then
		
		NString = NStr("en = 'Specify the online application address.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSURL",, Cancel);
		
	ElsIf IsBlankString(Object.WSUserName) Then
		
		NString = NStr("en = 'Specify the user name.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSUserName",, Cancel);
		
	ElsIf IsBlankString(Object.WSPassword) Then
		
		NString = NStr("en = 'Specify the user password.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSPassword",, Cancel);
		
	Else
		
		Try
			DataExchangeClientServer.CheckProhibitedCharsInWSProxyUserName(Object.WSUserName);
		Except
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),, "Object.WSUserName",, Cancel);
			Return;
		EndTry;
		
		IsSuggestOpenEventLog = True;
		
		TestWSConnectionAtServer(Cancel, ExtendedCheck, IsSuggestOpenEventLog);
		
		If Cancel And IsSuggestOpenEventLog Then
			
			QuestionText = NStr("en = 'Error establishing the connection.
				|Do you want to view the event log?'");
			
			SuggestOpenEventLog(QuestionText, EventLogMessageTextEstablishingConnectionToWebService);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SuggestOpenEventLog(QuestionText, Val Event)
	
	NotifyDescription = New NotifyDescription("SuggestOpenEventLogCompletion", ThisObject, Event);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure SuggestOpenEventLogCompletion(Answer, Event) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		Filter = New Structure("EventLogMessageText", Event);
		
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillGoToTable()
	
	If WizardRunVariant = "SetupNewDataExchange" Then
		
		If WizardRunMode = "ExchangeOverExternalConnection" Then
			
			DataExchangeOverExternalConnectionSettingsGoToTable();
			
		ElsIf WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels" Then
			
			FirstExchangeSetupStageGoToTable();
			
		ElsIf WizardRunMode = "ExchangeOverWebService" Then
			
			If ExchangeWithServiceSetup Then
				
				ExtendedExchangeWithServiceSetupGoToTable();
				
			Else
				
				ExchangeOverWebServiceSetupGoToTable();
				
			EndIf;
			
		EndIf;
		
	Else // "ContinueDataExchangeSetup"
		
		SecondExchangeSetupStageGoToTable();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InfobaseRunModeOnChange()
	
	CurrentPage = ?(Object.COMInfobaseOperationMode = 0, Items.FileModePage, Items.ClientServerModePage);
	
	Items.InfobaseRunModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Object.COMOSAuthentication    = (AuthenticationType = 1);
	Items.COMUserName.Enabled     = Not Object.COMOSAuthentication;
	Items.COMUserPassword.Enabled = Not Object.COMOSAuthentication;
	
EndProcedure

&AtServer
Procedure WizardRunVariantOnChangeAtServer()
	
	Items.ExchangeSettingsFileSelectionPages.CurrentPage = ?(WizardRunVariant = "ContinueDataExchangeSetup"
																		And Not Object.IsDistributedInfobaseSetup,
																		Items.ExchangeSettingsFileSelectionPage,
																		Items.EmptyExchangeSettingsFileSelectionPage);
 
	
	If WizardRunVariant = "ContinueDataExchangeSetup" Then
		
		WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels";
		
	Else
		
		If ExchangeWithServiceSetup Then
			
			WizardRunMode = "ExchangeOverWebService";
			
		ElsIf UseExchangeMessageTransportCOM Then
			
			WizardRunMode = "ExchangeOverExternalConnection";
			
		ElsIf UseExchangeMessageTransportWS Then
			
			WizardRunMode = "ExchangeOverWebService";
			
		Else
			
			WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels";
			
		EndIf;
		
	EndIf;
	
	FillGoToTable();
	
EndProcedure

&AtServer
Procedure WizardRunModeOnChangeAtServer()
	
	AllPageSettings = New Structure;
	
	SettingsOption = "ExchangeOverExternalConnection";
	SettingsValues = New Structure;
	
	SettingsValues.Insert("Transport", Items.TransportParameterPageCOM);
	SettingsValues.Insert("Messages",  Enums.ExchangeMessageTransportKinds.COM);
	SettingsValues.Insert("Use",       WizardRunMode = SettingsOption Or UseExchangeMessageTransportCOM);
	AllPageSettings.Insert(SettingsOption, SettingsValues);
	
	SettingsOption  = "ExchangeOverOrdinaryCommunicationChannels";
	SettingsValues = New Structure;
	SettingsValues.Insert("Transport", Items.TransportParameterPage);
	SettingsValues.Insert("Messages",  Enums.ExchangeMessageTransportKinds.FILE);
	SettingsValues.Insert("Use",       WizardRunMode = SettingsOption Or UseExchangeMessageTransportFILE 
		Or UseExchangeMessageTransportFTP Or UseExchangeMessageTransportEMAIL);
	AllPageSettings.Insert(SettingsOption, SettingsValues);
		
	SettingsOption  = "ExchangeOverWebService";
	SettingsValues = New Structure;
	SettingsValues.Insert("Transport", Items.TransportParameterPageWS);
	SettingsValues.Insert("Messages",  Enums.ExchangeMessageTransportKinds.WS);
	SettingsValues.Insert("Use",       WizardRunMode = SettingsOption Or UseExchangeMessageTransportWS);
	AllPageSettings.Insert(SettingsOption, SettingsValues);
	
	// Refining settings, leaving only allowed ones
	OptionSelectionList = Items.WizardRunMode.ChoiceList;
	
	For Each KeyValue In AllPageSettings Do
		SettingsOption  = KeyValue.Key;
		SettingsValues = KeyValue.Value;
		OptionInList   = OptionSelectionList.FindByValue(SettingsOption);
		
		If SettingsValues.Use Then
			If SettingsOption = WizardRunMode Then
				Items.TransportParameterPages.CurrentPage = SettingsValues.Transport;
				Object.ExchangeMessageTransportKind       = SettingsValues.Messages;
			EndIf;
			
		Else
			If OptionInList <> Undefined Then
				OptionSelectionList.Delete( OptionInList );
			EndIf;
			
		EndIf;
		
	EndDo;

	FillGoToTable();
EndProcedure

&AtClient
Function ExternalConnectionParameterStructure(JoinType = "ExternalConnection")
	
	Result = Undefined;
	
	If JoinType = "ExternalConnection" Then
		
		Result = CommonUseClientServer.ExternalConnectionParameterStructure();
		
		Result.InfobaseOperationMode        = Object.COMInfobaseOperationMode;
		Result.InfobaseDirectory            = Object.COMInfobaseDirectory;
		Result.PlatformServerName           = Object.COMPlatformServerName;
		Result.InfobaseNameAtPlatformServer = Object.COMInfobaseNameAtPlatformServer;
		Result.OSAuthentication             = Object.COMOSAuthentication;
		Result.UserName                     = Object.COMUserName;
		Result.UserPassword                 = Object.COMUserPassword;
		
		Result.Insert("JoinType", JoinType);
		Result.Insert("CorrespondentVersion_2_0_1_6", Object.CorrespondentVersion_2_0_1_6);
		Result.Insert("CorrespondentVersion_2_1_1_7", Object.CorrespondentVersion_2_1_1_7);
		
	ElsIf JoinType = "WebService" Then
		
		Result = New Structure;
		Result.Insert("WSURL");
		Result.Insert("WSUserName");
		Result.Insert("WSPassword");
		
		FillPropertyValues(Result, Object);
		
		Result.Insert("JoinType", JoinType);
		Result.Insert("CorrespondentVersion_2_0_1_6", Object.CorrespondentVersion_2_0_1_6);
		Result.Insert("CorrespondentVersion_2_1_1_7", Object.CorrespondentVersion_2_1_1_7);
		
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure CheckAttributeFillingOnForm(Cancel, FormToCheckName, FormParameters, FormAttributeName)
	
	SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[FormName]";
	SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	SettingsFormName = StrReplace(SettingsFormName, "[FormName]", FormToCheckName);
	
	SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
	
	If Not SettingsForm.CheckFilling() Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Specify the mandatory settings.'"),,, FormAttributeName, Cancel);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseRegistrationRestrictionSetup(JoinType)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseNodeSettingsForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[CorrespondentInfobaseNodeSettingsForm]", CorrespondentInfobaseNodeSettingsForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion",         CorrespondentConfigurationVersion);
	FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(JoinType));
	FormParameters.Insert("NodeFilterStructure",          CorrespondentInfobaseNodeFilterSetup);
	
	Handler = New NotifyDescription("CorrespondentInfobaseDataRegistrationRestrictionSetupCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDataRegistrationRestrictionSetupCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each FilterSettings In CorrespondentInfobaseNodeFilterSetup Do
			
			CorrespondentInfobaseNodeFilterSetup[FilterSettings.Key] = Result[FilterSettings.Key];
			
		EndDo;
		
		// Server call
		GetCorrespondentInfobaseDataTransferRestrictionDetails(CorrespondentInfobaseNodeFilterSetup);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetup(JoinType)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseDefaultValueSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[CorrespondentInfobaseDefaultValueSetupForm]", CorrespondentInfobaseDefaultValueSetupForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion",         CorrespondentConfigurationVersion);
	FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(JoinType));
	FormParameters.Insert("NodeDefaultValues",            CorrespondentInfobaseNodeDefaultValues);
	
	Handler = New NotifyDescription("CorrespondentInfobaseDefaultValueSetupCompletion", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetupCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each FilterSettings In CorrespondentInfobaseNodeDefaultValues Do
			
			CorrespondentInfobaseNodeDefaultValues[FilterSettings.Key] = Result[FilterSettings.Key];
			
		EndDo;
		
		// Server call
		GetCorrespondentInfobaseDefaultValueDetails(CorrespondentInfobaseNodeDefaultValues);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExchangeOverExternalConnectionSetup(Val OpenFormAfterCurrentFormClosed)
	
	If ExecuteInteractiveDataExchangeNow Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode",                 Object.InfobaseNode);
		FormParameters.Insert("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
		FormParameters.Insert("ExecuteMappingOnOpen",         False);
		FormParameters.Insert("ExportAdditionExtendedMode",   True);
		
		If OpenFormAfterCurrentFormClosed Then
			OpenParameters = New Structure;
			OpenParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
			DataExchangeClient.OpenFormAfterCurrentFormClosed(ThisObject, "DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, OpenParameters);
			
		Else
			OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, , , WindowOpenVariant.SingleWindow, , ,FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExchangeOverWebServiceSetup()
	
	If ExecuteDataExchangeAutomatically Then
		
		FinishExchangeOverWebServiceSetupAtServer(Object.InfobaseNode, PredefinedDataExchangeSchedule, DataExchangeExecutionSchedule);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure FinishExchangeOverWebServiceSetupAtServer(InfobaseNode, PredefinedSchedule, Schedule)
	
	SetPrivilegedMode(True);
	
	ScenarioSchedule = Undefined;
	
	If PredefinedSchedule = "Every15Minutes" Then
		
		ScenarioSchedule = PredefinedScheduleEvery15Minutes();
		
	ElsIf PredefinedSchedule = "Every30Minutes" Then
		
		ScenarioSchedule = PredefinedScheduleEvery30Minutes();
		
	ElsIf PredefinedSchedule = "EveryHour" Then
		
		ScenarioSchedule = PredefinedScheduleEveryHour();
		
	ElsIf PredefinedSchedule = "EveryDayAt_8_00" Then
		
		ScenarioSchedule = PredefinedScheduleEveryDayAt_8_00();
		
	ElsIf PredefinedSchedule = "OtherSchedule" Then
		
		ScenarioSchedule = Schedule;
		
	EndIf;
	
	If ScenarioSchedule <> Undefined Then
		
		Catalogs.DataExchangeScenarios.CreateScenario(InfobaseNode, ScenarioSchedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishFirstExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel)
	
	ClearMessages();
	
	If Not Object.IsDistributedInfobaseSetup
		And IsBlankString(Object.DataExchangeSettingsFileName) Then
		
		NString = NStr("en = 'Save the settings file for the target infobase.'");
		
		CommonUseClientServer.MessageToUser(NString,,"Object.DataExchangeSettingsFileName",, Cancel);
		Return;
	EndIf;
	
	If Object.IsDistributedInfobaseSetup Then
		
		If CreateInitialImageNow Then
			
			FormParameters = New Structure("Key, Node", Object.InfobaseNode, Object.InfobaseNode);
			
			Mode = FormWindowOpeningMode.LockOwnerWindow;
			Handler = New NotifyDescription("CloseFormAfterInitialImageCreation", ThisObject);
			OpenForm(InitialImageCreationFormName, FormParameters,,,,, Handler, Mode);
			Cancel = True;
			
		EndIf;
		
	Else
		
		If ExecuteDataExchangeNow Then
			
			DataExchangeInitializationAtClient(Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseFormAfterInitialImageCreation(Result, AdditionalParameters) Export
	
	RefreshInterface();
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtClient
Procedure FinishSecondExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel, Val OpenFormAfterCurrentFormClosed)
	
	Status(NStr("en = 'Creating data synchronization settings'"));
	
	SetupNewDataExchangeAtServer(Cancel, NodeFilterStructure, NodeDefaultValues);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Error creating data synchronization settings.'"));
		Return;
	EndIf;
	
	OpenMappingWizard = Not Object.IsDistributedInfobaseSetup And Not Object.IsStandardExchangeSetup;
	
	If OpenMappingWizard Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode",                 Object.InfobaseNode);
		FormParameters.Insert("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
		FormParameters.Insert("ExecuteMappingOnOpen",         False);
		FormParameters.Insert("ExportAdditionExtendedMode",   True);
		
		If OpenFormAfterCurrentFormClosed Then
			OpenParameters = New Structure;
			OpenParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
			DataExchangeClient.OpenFormAfterCurrentFormClosed(ThisObject, "DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, OpenParameters);
			
		Else
			OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, , , WindowOpenVariant.SingleWindow, , ,FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenMappingForm()
	
	CurrentData = Items.StatisticsTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en = 'Cannot create mapping for the selected data.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("TargetTableName",           CurrentData.TargetTableName);
	FormParameters.Insert("SourceTableObjectTypeName", CurrentData.ObjectTypeString);
	FormParameters.Insert("TargetTableFields",         CurrentData.TableFields);
	FormParameters.Insert("TargetTableSearchFields",   CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeString",          CurrentData.SourceTypeString);
	FormParameters.Insert("TargetTypeString",          CurrentData.TargetTypeString);
	FormParameters.Insert("IsObjectDeletion",          CurrentData.IsObjectDeletion);
	FormParameters.Insert("DataImportedSuccessfully",  CurrentData.DataImportedSuccessfully);
	FormParameters.Insert("Key",                       CurrentData.Key);
	
	FormParameters.Insert("InfobaseNode",            Object.InfobaseNode);
	FormParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
	
	FormParameters.Insert("PerformDataImport", False);
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ExpandStatisticsTree(RowKey = "")
	
	ItemCollection = StatisticsTree.GetItems();
	
	For Each TreeRow In ItemCollection Do
		
		Items.StatisticsTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Specifying the value tree cursor position
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsTree.GetItems(), RowKey, False);
		
		Items.StatisticsTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateMappingStatisticsDataAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.Statistics.FindRows(New Structure("Key", NotificationParameters.UniquenessKey));
	
	FillPropertyValues(TableRows[0], NotificationParameters, "DataImportedSuccessfully");
	
	RowKeys = New Array;
	RowKeys.Add(NotificationParameters.UniquenessKey);
	
	UpdateMappingByRowDetailsAtServer(Cancel, RowKeys);
	
EndProcedure

&AtServer
Procedure UpdateMappingByRowDetailsAtServer(Cancel, RowKeys)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowKeys);
	
	InteractiveDataExchangeWizard = DataProcessors.InteractiveDataExchangeWizard.Create();
	
	FillPropertyValues(InteractiveDataExchangeWizard, Object,, "Statistics");
	
	InteractiveDataExchangeWizard.Statistics.Load(Object.Statistics.Unload());
	
	InteractiveDataExchangeWizard.GetObjectMappingByRowStats(Cancel, RowIndexes);
	
	If Not Cancel Then
		
		Object.Statistics.Load(InteractiveDataExchangeWizard.StatisticsTable());
		
		GetStatisticsTree(InteractiveDataExchangeWizard.StatisticsTable());
		
		SetAdditionalInfoGroupVisible();
		
	EndIf;
	
EndProcedure

&AtServer
Function GetStatisticsTableRowIndexes(RowKeys)
	
	RowIndexes = New Array;
	
	For Each Key In RowKeys Do
		
		TableRows = Object.Statistics.FindRows(New Structure("Key", Key));
		
		LineIndex = Object.Statistics.IndexOf(TableRows[0]);
		
		RowIndexes.Add(LineIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServer
Procedure GetStatisticsTree(Statistics)
	
	TreeItemCollection = StatisticsTree.GetItems();
	TreeItemCollection.Clear();
	
	CommonUse.FillFormDataTreeItemCollection(TreeItemCollection,
		DataExchangeServer.GetStatisticsTree(Statistics));
	
EndProcedure

&AtServer
Procedure OnConnectToCorrespondent(Cancel, Val CorrespondentVersion)
	
	If CorrespondentVersion = Undefined
		Or IsBlankString(CorrespondentVersion) Then
		
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Try
		DataExchangeServer.OnConnectToCorrespondent(Object.ExchangePlanName, CorrespondentVersion);
	Except
		CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,,, Cancel);
		WriteErrorToEventLog(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'An error occurred during the OnConnectToCorrespondent handler execution:%1%2'"),
				Chars.LF,
				DetailErrorDescription(ErrorInfo())),
			DataExchangeCreationEventLogMessageText
		);
		Return;
	EndTry;
	
EndProcedure

&AtClient
Procedure DeleteDataExchangeSettings(Result, AdditionalParameters) Export
	
	If Object.InfobaseNode <> Undefined Then
		
		DataExchangeServerCall.DeleteSynchronizationSettings(Object.InfobaseNode);
		
		Notify("Write_ExchangePlanNode");
		
	EndIf;
	
EndProcedure

// Applies the default settings when the DIB setup is canceled.
&AtClient
Procedure DIBContinuationCancelNotifyDescription(Val Result, AdditionalParameters) Export
	
	// Ignoring all steps because the settings must be specified earlier
	ExecuteDoneCommand(False);
	
EndProcedure
	
////////////////////////////////////////////////////////////////////////////////
// Constant values.

&AtClientAtServerNoContext
Function NextLabelFTP()
	
	Return NStr("en = 'Click Next to set up FTP server connection.'");
	
EndFunction

&AtClientAtServerNoContext
Function NextLabelEMAIL()
	
	Return NStr("en = 'Click Next to set up email connection.'");
	
EndFunction

&AtClientAtServerNoContext
Function NextLabelSettings()
	
	Return NStr("en = 'Click Next to set up additional data synchronization parameters.'");
	
EndFunction

&AtServerNoContext
Function PredefinedScheduleEvery15Minutes()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months            = Months;
	Schedule.WeekDays          = WeekDays;
	Schedule.RepeatPeriodInDay = 60*15; // 15 minutes
	Schedule.DaysRepeatPeriod  = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleEvery30Minutes()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months            = Months;
	Schedule.WeekDays          = WeekDays;
	Schedule.RepeatPeriodInDay = 60*30; // 30 minutes
	Schedule.DaysRepeatPeriod  = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleEveryHour()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months            = Months;
	Schedule.WeekDays          = WeekDays;
	Schedule.RepeatPeriodInDay = 60*60; // 60 minutes
	Schedule.DaysRepeatPeriod  = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleEveryDayAt_8_00()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months           = Months;
	Schedule.WeekDays         = WeekDays;
	Schedule.BeginTime        = Date('00010101080000'); // 8:00
	Schedule.DaysRepeatPeriod = 1; // every day
	
	Return Schedule;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part. Step change handlers.

&AtClient
Procedure GoToStepForwardWithDeferredProcessing()
	
	AttachIdleHandler("Attachable_GoToStepForwardWithDeferredProcessing", 0.01, True);
	
EndProcedure

&AtClient
Procedure Attachable_GoToStepForwardWithDeferredProcessing()
	
	// Going a step forward (forced)
	SkipCurrentPageCancelControl = True;
	ChangeGoToNumber( +1 );
	
EndProcedure

&AtClient
Function Attachable_WizardPageSetTransportParametersFILE_OnGoNext(Cancel)
	
	If Object.UseTransportParametersFILE Then
		
		If IsBlankString(Object.FILEDataExchangeDirectory) Or ExternalResourcesAllowed.FileAllowed Then
			WizardPageSetTransportParametersFILE_OnGoNextAtServer(Cancel);
		Else
			ClosingNotification = New NotifyDescription("AllowResourceCompletion", ThisObject, "FileAllowed");
			Queries = CreateRequestForUseExternalResources(Object,, True);
			SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersFTP_OnGoNext(Cancel)
	
	If Object.UseTransportParametersFTP Then
		
		If IsBlankString(Object.FTPConnectionPath) Or ExternalResourcesAllowed.FTPAllowed Then
			WizardPageSetTransportParametersFTP_OnGoNextAtServer(Cancel);
		Else
			ClosingNotification = New NotifyDescription("AllowResourceCompletion", ThisObject, "FTPAllowed");
			Queries = CreateRequestForUseExternalResources(Object,,,, True);
			SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
			Cancel = True;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersEMAIL_OnGoNext(Cancel)
	
	WizardPageSetTransportParametersEMAIL_OnGoNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageWizardRunModeChoice_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportCOM Or Not UseExchangeMessageTransportWS Then
		
		Object.UseTransportParametersCOM = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWizardRunModeChoice_OnGoNext(Cancel)
	
	If ((WizardRunMode = "ExchangeOverExternalConnection" And (Not IsBlankString(Object.COMInfobaseDirectory) Or Not IsBlankString(Object.COMPlatformServerName)))
		Or (WizardRunMode = "ExchangeOverWebService" And Not IsBlankString(Object.WSURL)))
		And Not ExternalResourcesAllowed.COMAllowed Then
		
		ClosingNotification = New NotifyDescription("AllowResourceCompletion", ThisObject, "COMAllowed");
		If WizardRunMode = "ExchangeOverWebService" Then
			Queries = CreateRequestForUseExternalResources(Object,,, True);
		ElsIf WizardRunMode = "ExchangeOverExternalConnection" Then
			Queries = CreateRequestForUseExternalResources(Object, True);
		EndIf;
		SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
		Cancel = True;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersFILE_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ExternalResourcesAllowed.FileAllowed = False;
	
	If Not UseExchangeMessageTransportFILE Then
		
		Object.UseTransportParametersFILE = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersFTP_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ExternalResourcesAllowed.FTPAllowed = False;
	
	If Not UseExchangeMessageTransportFTP Then
		
		Object.UseTransportParametersFTP = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersEMAIL_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportEMAIL Then
		
		Object.UseTransportParametersEMAIL = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageParameterSetup_OnGoNext(Cancel)
	
	If IsBlankString(Object.ThisInfobaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the current infobase.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfobaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.SecondInfobaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the second infobase.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfobaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en = 'Specify the correspondent infobase prefix. You can use the existing prefix or a create a new one.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfobasePrefix) = TrimAll(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en = 'Infobase prefixes must be different.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether the form attributes that describe data migration restriction settings are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeFilterStructure",  NodeFilterStructure);
		
		CheckAttributeFillingOnForm(Cancel, NodeSettingsForm, FormParameters, "DataTransferRestrictionDetails");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether attributes of the additional settings form are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValueSetupForm, FormParameters, "DefaultValueDetails");
		
	EndIf;
	
	WizardPageParameterSetup_OnGoNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageFirstInfobaseExternalConnectionParameterSetup_OnGoNext(Cancel)
	
	If IsBlankString(Object.ThisInfobaseDescription) Then
		
		NString = NStr("en = 'Specify the infobase name.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfobaseDescription",, Cancel);
		Return Undefined;
	EndIf;
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether the form attributes that describe data migration restriction settings are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeFilterStructure",  NodeFilterStructure);
		
		CheckAttributeFillingOnForm(Cancel, NodeSettingsForm, FormParameters, "DataTransferRestrictionDetails");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether attributes of the additional settings form are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeDefaultValues",    NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValueSetupForm, FormParameters, "DefaultValueDetails");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageDataExchangeSetupParameter_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext Then
		
		// Getting context and context description for the node settings form
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("GetDefaultValue");
		FormParameters.Insert("Settings", NodesSetupFormContext);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSetupForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[NodeSetupForm]", NodesSetupForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		NodesSetupFormContext         = SettingsForm.Context;
		DataExportSettingsDescription = SettingsForm.ContextDetails;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageDataExchangeSetupParameter_OnGoNext(Cancel)
	
	CheckJobSettingsForFirstInfobase(Cancel, "WebService");
	
EndFunction

&AtClient
Function Attachable_WizardPageSecondInfobaseExternalConnectionParameterSetup_OnGoNext(Cancel)
	
	CheckJobSettingsForSecondInfobase(Cancel, "ExternalConnection");
	
EndFunction

&AtClient
Function Attachable_WizardPageSecondSetupStageParameterSetup_OnGoNext(Cancel)
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether the form attributes that describe data migration restriction settings are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeFilterStructure", NodeFilterStructure);
		
		CheckAttributeFillingOnForm(Cancel, NodeSettingsForm, FormParameters, "DataTransferRestrictionDetails");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether attributes of the additional settings form are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeDefaultValues",    NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValueSetupForm, FormParameters, "DefaultValueDetails");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageStart_OnGoNext(Cancel)
	
	If True = SkipCurrentPageCancelControl Then
		SkipCurrentPageCancelControl = Undefined;
		Return Undefined;
		
	ElsIf Object.IsDistributedInfobaseSetup Then
		Return Undefined;
		
	ElsIf WizardRunVariant <> "ContinueDataExchangeSetup" Then
		Return Undefined;
		
	ElsIf DataExchangeSettingsFileImported Then
		// No additional checks are required to continue the exchange
		Return Undefined;
		
	EndIf;
	
	// The OnGoNext handler is included in the notifications
	Cancel = True;
	
	// Attempting to upload the file to the server, with an extension installation request. The file selection dialog in not displayed.
	If IsBlankString(Object.DataExchangeSettingsFileNameToImport) Then
		ErrorText = NStr("en = 'Select the data synchronization settings file.'");
		CommonUseClientServer.MessageToUser(ErrorText, , "Object.DataExchangeSettingsFileNameToImport");
		Return Undefined;
	EndIf;
	
	Notification = New NotifyDescription("WizardPageStart_OnGoNext_Completion", ThisObject, New Structure);
	WarningText = NStr("en = 'To upload the synchronization settings file to the server, you have to install the file system extension for 1C:Enterprise web client.'");
	
	FileNames = New Array;
	FileNames.Add(Object.DataExchangeSettingsFileNameToImport);
	
	DataExchangeClient.SendFilesToServer(Notification, FileNames, UUID, WarningText);
EndFunction

// Notification description of the completion of file uploading to the server.
//
&AtClient
Procedure WizardPageStart_OnGoNext_End(Val FileStoringResult, Val AdditionalParameters) Export
	
	ExportDataExchangeFileSelectionCompletion(FileStoringResult[0], Undefined);
	
	If DataExchangeSettingsFileImported Then
		// Going to the next wizard step if the settings file is imported successfully
		GoToStepForwardWithDeferredProcessing();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportDataExchangeFileSelectionCompletion(Val FileStoringResult, Val AdditionalParameters) Export
	
	ClearMessages();
	
	StoredFileAddress = FileStoringResult.Location;
	ErrorText         = FileStoringResult.ErrorDescription;
	
	Object.DataExchangeSettingsFileNameToImport = FileStoringResult.Name;
	
	DataExchangeSettingsFileImported = False;
	
	If IsBlankString(ErrorText) And IsBlankString(StoredFileAddress) Then
		ErrorText = NStr("en = 'An error occurred while sending data synchronization settings to the server.'");
	EndIf;
	
	If IsBlankString(ErrorText) Then
		// Attempting to apply the settings after uploading the settings file to the server
		WizardParameterImportError = False;
		// Server call
		ImportWizardParameters(WizardParameterImportError, StoredFileAddress);
		If WizardParameterImportError Then
			ErrorText = NStr("en = 'The specified data synchronization settings file is invalid. Specify the correct file.'");
		Else
			DataExchangeSettingsFileImported = True;
		EndIf;
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText, , "Object.DataExchangeSettingsFileNameToImport");
	EndIf;
	
	RefreshDataRepresentation();
EndProcedure

&AtClient
Function Attachable_WizardPageParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	// Displaying the error message if the user proceeded to the additional parameter page but no transport kind is set up
	If Not    (Object.UseTransportParametersEMAIL
			Or Object.UseTransportParametersFILE
			Or Object.UseTransportParametersFTP) Then
		
		NString = NStr("en = 'Connection settings for the data synchronization are not specified.
						|You have to set up at least one connection.'");
 
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		
		Return Undefined;
	EndIf;
	
	WizardPageParameterSetup_OnOpenAtServer(Cancel, SkipPage, IsGoNext);
	
EndFunction

&AtClient
Function Attachable_WizardPageFirstInfobaseExternalConnectionParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.DataTransferRestrictionDetails1.Title = StrReplace(Items.DataTransferRestrictionDetails1.Title,
																	   "%Application%", ExchangePlanSynonym);
	
	Items.DefaultValueDetails1.Title = StrReplace(Items.DefaultValueDetails1.Title,
																	   "%Application%", ExchangePlanSynonym);
	
EndFunction

&AtClient
Function Attachable_WizardPageSecondInfobaseExternalConnectionParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.DataTransferRestrictionDetails4.Title = StrReplace(Items.DataTransferRestrictionDetails4.Title,
																	   "%Application%", Object.ThisInfobaseDescription);
	
	Items.DefaultValueDetails4.Title = StrReplace(Items.DefaultValueDetails4.Title,
																	   "%Application%", Object.ThisInfobaseDescription);
	
EndFunction

&AtClient
Function Attachable_WizardPageExchangeSetupResults_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If WizardRunVariant = "SetupNewDataExchange" Then
		
		// Data exchange setup result presentation
		MessageString = NStr("en = '%1%2%3The current infobase prefix is %4
		|The correspondent infobase prefix is %5'");
		
		ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							MessageTransportResultPresentation(),
							NodeFiltersResultPresentation(),
							DefaultNodeValueResultPresentation(),
							Object.SourceInfobasePrefix,
							Object.TargetInfobasePrefix);
		
	Else
		
		// Data exchange setup result presentation
		MessageString = NStr("en = '%1%2%3The current infobase prefix is %4'");
		
		ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							MessageTransportResultPresentation(),
							NodeFiltersResultPresentation(),
							DefaultNodeValueResultPresentation(),
							Object.SourceInfobasePrefix);
		
	EndIf;
	
	// Displaying comment label
	Items.MappingWizardOpenedInfoLabelGroup.Visible =
	(WizardRunVariant = "ContinueDataExchangeSetup" 
	And Not Object.IsDistributedInfobaseSetup
	And Not Object.IsStandardExchangeSetup);
	
EndFunction

&AtClient
Function Attachable_WizardPageExchangeSetupResults_OnOpen_ExternalConnection(Cancel, SkipPage, IsGoNext)
	
	// Data exchange setup result presentation
	If ExchangeWithServiceSetup Then
		
		MessageString = NStr("en = '%1 
   |Settings for the current infobase: 
   |======================================================== 
   |%2%3Infobase prefix: %4 
   |
   |Settings for the service application: 
   |======================================================== 
   |%5%6Application prefix: %7'");
		
	Else
		
		MessageString = NStr("en = '%1 
   |Data synchronization settings for the current infobase: 
   |======================================================== 
   |%2%3Infobase prefix: %4 
   |
   |Data synchronization settings for the second infobase: 
   |======================================================== 
   |%5%6Infobase prefix: %7'");
		
	EndIf;
	
	ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
						MessageTransportResultPresentation(),
						NodeFiltersResultPresentation(),
						DefaultNodeValueResultPresentation(),
						Object.SourceInfobasePrefix,
						CorrespondentInfobaseNodeFilterResultPresentation(),
						CorrespondentInfobaseNodeDefaultValueResultPresentation(),
						Object.TargetInfobasePrefix);
	
	// Displaying comment label
	Items.MappingWizardOpenedInfoLabelGroup.Visible = False;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessing(Cancel, GoToNext)
	
	WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessingAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataExchangeSettingsCreationOverExternalConnection_LongActionProcessing(Cancel, GoToNext)
	
	// Creating data exchange via the external connection
	SetupNewDataExchangeOverExternalConnectionAtServer(Cancel, CorrespondentInfobaseNodeFilterSetup, CorrespondentInfobaseNodeDefaultValues);
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessing(Cancel, GoToNext)
	
	WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessingAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForConnectionCheckOverWebService_LongActionProcessing(Cancel, GoToNext)
	
	TestWSConnectionAtClient(Cancel, True);
	
EndFunction


&AtClient
Function Attachable_WizardPageWaitForExchangeSettingsCreationDataAnalysis_LongActionProcessing(Cancel, GoToNext)
	
	// Creating data exchange settings:
	//  - creating nodes in this infobase and in the correspondent infobase with data export settings,
	//  - registering catalogs to be exported in this infobase and in the correspondent infobase.
	
	LongAction = False;
	LongActionFinished = False;
	LongActionID = "";
	
	SetupNewDataExchangeAtServerOverWebService(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred while creating data synchronization settings.
					|Use the event log to solve the problems.'"));
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForExchangeSettingsCreationDataAnalysisLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction


&AtClient
Function Attachable_WizardPageWaitForDataAnalysisGetMessage_LongActionProcessing(Cancel, GoToNext)
	
	LongAction             = False;
	LongActionFinished     = False;
	MessageFileIDInService = "";
	LongActionID           = "";
	
	DataStructure = DataExchangeServerCall.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
		Cancel,
		Object.InfobaseNode,
		MessageFileIDInService,
		LongAction,
		LongActionID,
		Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred during the data analysis.
					|Use the event log to solve the problems.'"));
		
	ElsIf Not LongAction Then
		
		Object.TempExchangeMessageDirectory = DataStructure.TempExchangeMessageDirectory;
		Object.ExchangeMessageFileName      = DataStructure.ExchangeMessageFileName;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataAnalysisGetMessageLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataAnalysisGetMessageLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataStructure = DataExchangeServerCall.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongAction(
			Cancel,
			Object.InfobaseNode,
			MessageFileIDInService,
			Object.WSPassword);
		
		If Cancel Then
			
			ShowMessageBox(, NStr("en = 'Errors occurred during the data analysis.
						|Use the event log to solve the problems.'"));
			
		Else
			
			Object.TempExchangeMessageDirectory = DataStructure.TempExchangeMessageDirectory;
			Object.ExchangeMessageFileName      = DataStructure.ExchangeMessageFileName;
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataAnalysisAutomaticMapping_LongActionProcessing(Cancel, GoToNext)
	
	WizardPageWaitForDataAnalysisAutomaticMapping_LongActionProcessing(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred during the data analysis.'"));
		
	EndIf;
	
EndFunction

&AtServer
Procedure WizardPageWaitForDataAnalysisAutomaticMapping_LongActionProcessing(Cancel)
	
	InteractiveDataExchangeWizard = DataProcessors.InteractiveDataExchangeWizard.Create();
	
	FillPropertyValues(InteractiveDataExchangeWizard, Object,, "Statistics");
	
	InteractiveDataExchangeWizard.Statistics.Load(Object.Statistics.Unload());
	
	InteractiveDataExchangeWizard.ExecuteExchangeMessagAnalysis(Cancel);
	
	InteractiveDataExchangeWizard.ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Cancel);
	
	If Not Cancel Then
		
		StatisticsTable = InteractiveDataExchangeWizard.StatisticsTable();
		
		// Deleting rows that have 100% mapping
		ReverseIndex = StatisticsTable.Count() - 1;
		
		While ReverseIndex >= 0 Do
			
			TableRow = StatisticsTable[ReverseIndex];
			
			If TableRow.UnmappedObjectCount = 0 Then
				
				StatisticsTable.Delete(TableRow);
				
			EndIf;
			
			ReverseIndex = ReverseIndex - 1;
		EndDo;
		
		Object.Statistics.Load(StatisticsTable);
		
		GetStatisticsTree(StatisticsTable);
		
		SetAdditionalInfoGroupVisible();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAdditionalInfoGroupVisible()
	
	// Making the group with additional information visible if statistic data
	// table contains one or more rows with mapping less than 100%
	RowArray = Object.Statistics.FindRows(New Structure("PictureIndex", 1));
	
	AllDataMapped = (RowArray.Count() = 0);
	
	Items.DataMappingStatusPages.CurrentPage = ?(AllDataMapped,
				Items.MappingStatusAllDataMapped,
				Items.MappingStatusHasUnmappedData);
	
EndProcedure

&AtClient
Function Attachable_WizardPageDataMapping_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext And AllDataMapped Then
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageDataMapping_OnGoNext(Cancel)
	
	If Not AllDataMapped Then
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, "Continue");
		Buttons.Add(DialogReturnCode.No,  "Cancel");
		
		Message = NStr("en = 'Some data is not mapped. Leaving unmapped
							   |data can result in duplicate catalog items.
							   |Do you want to continue?'");
							   
		If Not UserAnsweredYesToQuestionAboutMapping Then
			NotifyDescription = New NotifyDescription("ProcessUserAnswerOnMap", ThisObject);
			ShowQueryBox(NotifyDescription, Message, Buttons,, DialogReturnCode.No);
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Procedure ProcessUserAnswerOnMap(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		UserAnsweredYesToQuestionAboutMapping = True;
		ChangeGoToNumber(+1);
		
	EndIf;
	
EndProcedure
 

&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationImport_LongActionProcessing(Cancel, GoToNext)
	
	DataExchangeServerCall.ImportInfobaseNodeViaFile(Cancel, Object.InfobaseNode, Object.ExchangeMessageFileName);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred during catalog synchronization.
					|Use the event log to solve the problems.'"));
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing(
											Cancel,
											Object.InfobaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate,
											Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred during catalog synchronization.
					|Use the event log to solve the problems.'"));
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing(
											Cancel,
											InfobaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate,
											Password)
	
	ActionStartDate = CurrentSessionDate();
	
	// Starting synchronization
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True,
											Password);
	
EndProcedure

&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationExportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationExportLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataExchangeServerCall.CommitDataExportExecutionInLongActionMode(Object.InfobaseNode, ActionStartDate);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForSaveSettings_LongActionProcessing(Cancel, GoToNext)
	
	// Updating data exchange settings in this infobase and in the correspondent infobase:
	//  - updating default values in the exchange plan nodes,
	//  - registering all data to be exported except catalogs and charts of characteristic types in this infobase and in the correspondent infobase.
	
	LongAction = False;
	LongActionFinished = False;
	LongActionID = "";
	
	UpdateDataExchangeSettings(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred while saving the settings.
					|Use the event log to solve the problems.'"));
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSettingsSavingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction
 

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationImport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	WizardPageWaitForDataSynchronizationImport_LongActionProcessing(
											Cancel,
											Object.InfobaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate,
											Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred during data synchronization.
					|Use the event log to solve the problems.'"));
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure WizardPageWaitForDataSynchronizationImport_LongActionProcessing(
											Cancel,
											InfobaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate,
											Password)
	
	ActionStartDate = CurrentSessionDate();
	
	// Starting synchronization
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											True,
											False,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True,
											Password);
	
EndProcedure

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationImportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationImportLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataExchangeServerCall.ExecuteDataExchangeForInfobaseNodeFinishLongAction(
										Cancel,
										Object.InfobaseNode,
										MessageFileIDInService,
										ActionStartDate,
										Object.WSPassword);
		
		If Cancel Then
			
			ShowMessageBox(, NStr("en = 'Errors occurred during data synchronization.
						|Use the event log to solve the problems.'"));
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationExport_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	WizardPageWaitForDataSynchronizationExport_LongActionProcessing(
											Cancel,
											Object.InfobaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate,
											Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Errors occurred during data synchronization.
					|Use the event log to solve the problems.'"));
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure WizardPageWaitForDataSynchronizationExport_LongActionProcessing(
											Cancel,
											InfobaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate,
											Password)
	
	ActionStartDate = CurrentSessionDate();
	
	// Starting synchronization
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True,
											Password);
	
EndProcedure

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationExportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationExportLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataExchangeServerCall.CommitDataExportExecutionInLongActionMode(Object.InfobaseNode, ActionStartDate);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageAddingDocumentDataToAccountingRecordsSettings_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext Then
		
		JoinType = "WebService";
		
		CheckAccountingSettingsAtServer(
										False,
										JoinType,
										Object.ExchangePlanName,
										ExternalConnectionParameterStructure(JoinType),
										SkipPage);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageAddingDocumentDataToAccountingRecordsSettings_OnGoNext(Cancel)
	
	JoinType = "WebService";
	
	CheckAccountingSettingsAtServer(
									Cancel,
									JoinType,
									Object.ExchangePlanName,
									ExternalConnectionParameterStructure(JoinType),
									False);
	
EndFunction

&AtClient
Function Attachable_WizardPageDataGetParameters_OnGoNext(Cancel)
	
	JoinType = "WebService";
	
	CheckDataGettingRules(Cancel, JoinType);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageDataExchangeCreatedSuccessfully_OnOpen(Cancel, SkipPage, IsGoNext)
	
	PredefinedDataExchangeScheduleOnValueChange();
	
	ExecuteDataExchangeAutomaticallyOnValueChange();
	
EndFunction


&AtClient
Procedure CheckDataGettingRules(Cancel, JoinType)
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether attributes of the additional settings form are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("NodeDefaultValues",    NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValueSetupForm, FormParameters, "DefaultValueDetails");
		
	EndIf;
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		// Checking whether attributes of the additional settings form are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion",         CorrespondentConfigurationVersion);
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(JoinType));
		FormParameters.Insert("NodeDefaultValues",            CorrespondentInfobaseNodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, CorrespondentInfobaseDefaultValueSetupForm, FormParameters, "CorrespondentInfobaseDefaultValueDetails");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckAccountingSettingsAtServer(
									Cancel,
									Val JoinType,
									Val ExchangePlanName,
									ConnectionParameters,
									SkipPage)
	
	ErrorMessage = "";
	CorrespondentErrorMessage = "";
	
	NodeCode = CommonUse.ObjectAttributeValue(Object.InfobaseNode, "Code");
	
	SystemAccountingSettingsAreSet = DataExchangeServer.SystemAccountingSettingsAreSet(ExchangePlanName, NodeCode, ErrorMessage);
	
	If JoinType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters, ErrorMessageString);
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			DataExchangeServer.ReportError(ErrorMessageString, Cancel);
			Return;
		EndIf;
		
		NodeCode = DataExchangeServerCall.GetThisNodeCodeForExchangePlan(Object.ExchangePlanName);
		
		// Getting parameters of the correspondent infobase
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		Else
			
			TargetParameters = ValueFromStringInternal(WSProxy.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		EndIf;
		
		CorrespondentAccountingSettingsAreSet = TargetParameters.SystemAccountingSettingsAreSet;
		
	ElsIf JoinType = "ExternalConnection" Then
		
		TransportParameters = DataExchangeServer.TransportSettingsByExternalConnectionParameters(ConnectionParameters);
		Connection          = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionParameters);
		ErrorMessageString  = Connection.DetailedErrorDetails;
		ExternalConnection  = Connection.Connection;
		
		If ExternalConnection = Undefined Then
			DataExchangeServer.ReportError(ErrorMessageString, Cancel);
			Return;
		EndIf;
		
		NodeCode = DataExchangeServerCall.GetThisNodeCodeForExchangePlan(Object.ExchangePlanName);
		
		// Getting parameters of the correspondent infobase
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			TargetParameters = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			TargetParameters = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		Else
			
			TargetParameters = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		EndIf;
		
		CorrespondentAccountingSettingsAreSet = TargetParameters.SystemAccountingSettingsAreSet;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If SystemAccountingSettingsAreSet And CorrespondentAccountingSettingsAreSet Then
		SkipPage = True;
		Return;
	EndIf;
	
	If Not SystemAccountingSettingsAreSet Then
		
		If IsBlankString(ErrorMessage) Then
			ErrorMessage = NStr("en = 'Accounting parameters of the current application are not set.'");
		EndIf;
		
		AccountingSettingsLabel = ErrorMessage;
		Cancel = True;
		
	EndIf;
	
	If Not CorrespondentAccountingSettingsAreSet Then
		
		If IsBlankString(CorrespondentErrorMessage) Then
			CorrespondentErrorMessage = NStr("en = 'Accounting parameters of the online application are not set.'");
		EndIf;
		
		CorrespondentAccountingSettingsLabel = CorrespondentErrorMessage;
		Cancel = True;
		
	EndIf;
	
	Items.AccountingSettings.Visible = Not SystemAccountingSettingsAreSet;
	Items.CorrespondentAccountingSettings.Visible = Not CorrespondentAccountingSettingsAreSet;
	
EndProcedure

&AtClient
Procedure CheckJobSettingsForFirstInfobase(Cancel, JoinType = "WebService")
	
	If IsBlankString(Object.ThisInfobaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the current infobase.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfobaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.SecondInfobaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the online application.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfobaseDescription",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfobasePrefix) = TrimAll(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en = 'Infobase prefixes must be different.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SourceInfobasePrefix",, Cancel);
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
		Items.SourceInfobasePrefixExchangeWithService.Visible = True;
		Items.SourceInfobasePrefixExchangeWithService.Enabled = True;
		Items.TargetInfobasePrefixExchangeWithService.Visible = True;
		
		Items.SourceInfobasePrefixExchangeOverWebService.Visible = True;
		Items.SourceInfobasePrefixExchangeOverWebService.Enabled = True;
		Items.TargetInfobasePrefixExchangeOverWebService.Visible = True;
		Items.TargetInfobasePrefixExchangeOverWebService.Enabled = True;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("ConnectionParameters", ExternalConnectionParameterStructure(JoinType));
		FormParameters.Insert("Settings",             NodesSetupFormContext);
		FormParameters.Insert("FillChecking");
		
		CheckAttributeFillingOnForm(Cancel, NodesSetupForm, FormParameters, "DataExportSettingsDescription");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckJobSettingsForSecondInfobase(Cancel, JoinType)
	
	If IsBlankString(Object.SecondInfobaseDescription) Then
		
		NString = NStr("en = 'Specify the application name.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfobaseDescription",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfobasePrefix) = TrimAll(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en = 'Infobase prefixes must be different.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If CorrespondentInfobaseNodeFilterSettingsAvailable Then
		
		// Checking whether the form attributes that describe data migration restriction settings are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(JoinType));
		FormParameters.Insert("NodeFilterStructure", CorrespondentInfobaseNodeFilterSetup);
		
		CheckAttributeFillingOnForm(Cancel, CorrespondentInfobaseNodeSettingsForm, FormParameters, "CorrespondentInfobaseDataTransferRestrictionDetails");
		
	EndIf;
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		// Checking whether attributes of the additional settings form are filled
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentConfigurationVersion);
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(JoinType));
		FormParameters.Insert("NodeDefaultValues", CorrespondentInfobaseNodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, CorrespondentInfobaseDefaultValueSetupForm, FormParameters, "CorrespondentInfobaseDefaultValueDetails");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageSetTransportParametersFILE_OnGoNextAtServer(Cancel)
	
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel, Object, Enums.ExchangeMessageTransportKinds.FILE);
	
EndProcedure

&AtServer
Procedure WizardPageSetTransportParametersFTP_OnGoNextAtServer(Cancel)
	
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel, Object, Enums.ExchangeMessageTransportKinds.FTP);
	
EndProcedure

&AtServer
Procedure WizardPageSetTransportParametersEMAIL_OnGoNextAtServer(Cancel)
	
	If Object.UseTransportParametersEMAIL Then
		
		DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel, Object, Enums.ExchangeMessageTransportKinds.EMAIL);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageParameterSetup_OnGoNextAtServer(Cancel)
	
	If Not ExchangePlans[Object.ExchangePlanName].FindByCode(DataExchangeServer.ExchangePlanNodeCodeString(Object.TargetInfobasePrefix)).IsEmpty() Then
		
		NString = NStr("en = 'The prefix of the second infobase is not unique.
			|The system has the data synchronization for the infobase with the specified prefix.
			|Change the prefix value or use the existing synchronization.'");

		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageParameterSetup_OnOpenAtServer(Cancel, SkipPage, IsGoNext)
	
	// Filling data exchange transport choice list with available kinds (selected by user)
	ValueList = New ValueList;
	
	If Object.UseTransportParametersFILE Then
		EnumValue = Enums.ExchangeMessageTransportKinds.FILE;
		ValueList.Add(EnumValue, String(EnumValue));
	EndIf;
	
	If Object.UseTransportParametersFTP Then
		EnumValue = Enums.ExchangeMessageTransportKinds.FTP;
		ValueList.Add(EnumValue, String(EnumValue));
	EndIf;
	
	If Object.UseTransportParametersEMAIL Then
		EnumValue = Enums.ExchangeMessageTransportKinds.EMAIL;
		ValueList.Add(EnumValue, String(EnumValue));
	EndIf;
	
	ChoiceList = Items.ExchangeMessageTransportKind.ChoiceList;
	ChoiceList.Clear();
	
	For Each Item In ValueList Do
		
		FillPropertyValues(ChoiceList.Add(), Item);
		
	EndDo;
	
	// Setting default exchange message
	// transport kind according to transport kinds selected by user.
	If Object.UseTransportParametersFILE Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
		
	ElsIf Object.UseTransportParametersFTP Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP;
		
	ElsIf Object.UseTransportParametersEMAIL Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.EMAIL;
		
	EndIf;
	
	Items.DataTransferRestrictionDetails.Title = StrReplace(Items.DataTransferRestrictionDetails.Title,
																	   "%Application%", ExchangePlanSynonym);
	Items.DataTransferRestrictionDetails2.Title = Items.DataTransferRestrictionDetails.Title;
	
	Items.DefaultValueDetails.Title = StrReplace(Items.DefaultValueDetails.Title,
																 "%Application%", ExchangePlanSynonym);
	Items.DefaultValueDetails2.Title = Items.DefaultValueDetails.Title;
	
EndProcedure

&AtServer
Procedure WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessingAtServer(Cancel)
	
	// Creating data exchange setup
	SetupNewDataExchangeAtServer(Cancel, NodeFilterStructure, NodeDefaultValues);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Creating a settings file for the correspondent infobase
	If Object.IsDistributedInfobaseSetup Then
		
		DataProcessorObject = FormAttributeToValue("Object");
		
		DataProcessorObject.ExecuteWizardParameterExportToConstant(Cancel);
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
	ElsIf Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
		
		TempStorageAddress = "";
		
		ExportExchangeSettingsForTarget(Cancel, TempStorageAddress);
		
		If Not Cancel Then
			
			Object.DataExchangeSettingsFileName = CommonUseClientServer.GetFullFileName(Object.FILEDataExchangeDirectory, SettingsFileNameForTarget);
			
			BinaryData = GetFromTempStorage(TempStorageAddress);
			
			DeleteFromTempStorage(TempStorageAddress);
			
			// Getting file
			BinaryData.Write(Object.DataExchangeSettingsFileName);
			
		EndIf;
		
	EndIf;
	
	Items.ExecuteDataExchangeNow21.Title = StrReplace(Items.ExecuteDataExchangeNow21.Title, "%Application%", ExchangePlanSynonym);
	
EndProcedure

&AtServer
Procedure WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessingAtServer(Cancel)
	
	If Object.COMInfobaseOperationMode = 0 Then
		
		If IsBlankString(Object.COMInfobaseDirectory) Then
			
			NString = NStr("en = 'Specify the infobase directory.'");
			CommonUseClientServer.MessageToUser(NString,, "Object.COMInfobaseDirectory",, Cancel);
			Cancel = True;
			Return;
			
		EndIf;
		
	Else
		
		If IsBlankString(Object.COMPlatformServerName) Then
			
			NString = NStr("en = 'Specify the server cluster name.'");
			CommonUseClientServer.MessageToUser(NString,, "Object.COMPlatformServerName",, Cancel);
			Cancel = True;
			Return;
			
		ElsIf IsBlankString(Object.COMInfobaseNameAtPlatformServer) Then
			
			NString = NStr("en = 'Specify the infobase name.'");
			CommonUseClientServer.MessageToUser(NString,, "Object.COMInfobaseNameAtPlatformServer",, Cancel);
			Cancel = True;
			Return;
			
		EndIf;
		
	EndIf;
	
	Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(Object);
	ExternalConnection = Result.Connection;
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	If ExternalConnection = Undefined Then
		CommonUseClientServer.MessageToUser(Result.BriefErrorDetails,,,, Cancel);
		Return;
	EndIf;
	
	// {HANDLER: OnConnectToCorrespondent} Start
	CorrespondentConfigurationVersion = ExternalConnection.Metadata.Version;
	
	OnConnectToCorrespondent(Cancel, CorrespondentConfigurationVersion);
	
	If Cancel Then
		Return;
	EndIf;
	// {HANDLER: OnConnectToCorrespondent} End
	
	CorrespondentVersions = DataExchangeServer.CorrespondentVersionsViaExternalConnection(ExternalConnection);
	
	Object.CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	Object.CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	Try
		ExchangePlanExists = ExternalConnection.DataExchangeExternalConnection.ExchangePlanExists(Object.ExchangePlanName);
	Except
		ExchangePlanExists = False;
	EndTry;
	
	If Not ExchangePlanExists Then
		
		Message = NStr("en = 'Data synchronization with the specified application is not available.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return;
		
	EndIf;
	
	If Lower(InfobaseConnectionString()) = Lower(ExternalConnection.InfobaseConnectionString()) Then
		
		Message = NStr("en = 'The specified settings are the connection settings of the current infobase.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return;
		
	EndIf;
	
	Object.TargetInfobasePrefix      = ExternalConnection.GetFunctionalOption("InfobasePrefix");
	Object.TargetInfobasePrefixIsSet = ValueIsFilled(Object.TargetInfobasePrefix);
	
	// Checking whether an exchange with the correspondent infobase exists
	CheckWhetherDataExchangeWithSecondBaseExists(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If Not Object.TargetInfobasePrefixIsSet Then
		Object.TargetInfobasePrefix = ExternalConnection.DataExchangeExternalConnection.DefaultInfobasePrefix();
	EndIf;
	
	Items.TargetInfobasePrefix.Visible = Not Object.TargetInfobasePrefixIsSet;
	
	Object.SecondInfobaseDescription = ExternalConnection.DataExchangeExternalConnection.PredefinedExchangePlanNodeDescription(Object.ExchangePlanName);
	SecondInfobaseDescriptionSet = Not IsBlankString(Object.SecondInfobaseDescription);
	
	Items.SecondInfobaseDescription2.ReadOnly = SecondInfobaseDescriptionSet;
	
	If Not SecondInfobaseDescriptionSet Then
		
		Object.SecondInfobaseDescription = ExternalConnection.DataExchangeCached.ThisInfobaseName();
		
	EndIf;
	
	NodeSettingsForm = "";
	CorrespondentInfobaseNodeSettingsForm = "";
	DefaultValueSetupForm = "";
	CorrespondentInfobaseDefaultValueSetupForm = "";
	NodesSetupForm = "";
	
	NodeFilterStructure = DataExchangeServer.NodeFilterStructure(Object.ExchangePlanName, CorrespondentConfigurationVersion, NodeSettingsForm);
	NodeDefaultValues   = DataExchangeServer.NodeDefaultValues(Object.ExchangePlanName, CorrespondentConfigurationVersion, DefaultValueSetupForm);
	
	CorrespondentInfobaseNodeFilterSetup   = DataExchangeServer.CorrespondentInfobaseNodeFilterSetup(Object.ExchangePlanName, CorrespondentConfigurationVersion, CorrespondentInfobaseNodeSettingsForm);
	CorrespondentInfobaseNodeDefaultValues = DataExchangeServer.CorrespondentInfobaseNodeDefaultValues(Object.ExchangePlanName, CorrespondentConfigurationVersion, CorrespondentInfobaseDefaultValueSetupForm);
	
	CorrespondentInfobaseNodeFilterSettingsAvailable = CorrespondentInfobaseNodeFilterSetup.Count() > 0;
	CorrespondentInfobaseNodeDefaultValuesAvailable  = CorrespondentInfobaseNodeDefaultValues.Count() > 0;
	
	Items.RestrictionsGroupBorder4.Visible                     = CorrespondentInfobaseNodeFilterSettingsAvailable;
	Items.DefaultValueGroupBorder4.Visible                     = CorrespondentInfobaseNodeDefaultValuesAvailable;
	Items.CorrespondentInfobaseDefaultValueGroupBorder.Visible = CorrespondentInfobaseNodeDefaultValuesAvailable;
	
	CorrespondentInfobaseDataTransferRestrictionDetails = DataExchangeServer.CorrespondentInfobaseDataTransferRestrictionDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeFilterSetup, CorrespondentConfigurationVersion);
	CorrespondentInfobaseDefaultValueDetails            = DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentConfigurationVersion);
	
	CorrespondentAccountingSettingsCommentLabel = DataExchangeServer.CorrespondentInfobaseAccountingSettingsSetupComment(Object.ExchangePlanName, CorrespondentConfigurationVersion);
	
EndProcedure

&AtServer
Procedure CheckWhetherDataExchangeWithSecondBaseExists(Cancel)
	
	NodeCode = ?(IsBlankString(Object.CorrespondentNodeCode),
					DataExchangeServer.ExchangePlanNodeCodeString(Object.TargetInfobasePrefix),
					Object.CorrespondentNodeCode);
	
	If Not IsBlankString(NodeCode)
		And Not ExchangePlans[Object.ExchangePlanName].FindByCode(NodeCode).IsEmpty() Then
		
		Message = NStr("en = 'Data synchronization between the applications is already set up.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part. Filling wizard navigation table.

&AtServer
Procedure FirstExchangeSetupStageGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WizardPageStart",                            "", "NavigationPageStart");
	GoToTableNewRow(2, "WizardPageWizardRunModeChoice",              "", "NavigationPageContinuation", "",,"WizardPageWizardRunModeChoice_OnOpen");
	GoToTableNewRow(3, "WizardPageSetTransportParametersFILE",       "", "NavigationPageContinuation", "WizardPageSetTransportParametersFILE_OnGoNext",,"WizardPageSetTransportParametersFILE_OnOpen");
	GoToTableNewRow(4, "WizardPageSetTransportParametersFTP",        "", "NavigationPageContinuation", "WizardPageSetTransportParametersFTP_OnGoNext",,"WizardPageSetTransportParametersFTP_OnOpen");
	GoToTableNewRow(5, "WizardPageSetTransportParametersEMAIL",      "", "NavigationPageContinuation", "WizardPageSetTransportParametersEMAIL_OnGoNext",,"WizardPageSetTransportParametersEMAIL_OnOpen");
	GoToTableNewRow(6, "WizardPageParameterSetup",                   "", "NavigationPageContinuation", "WizardPageParameterSetup_OnGoNext",, "WizardPageParameterSetup_OnOpen");
	GoToTableNewRow(7, "WizardPageExchangeSetupResults",             "", "NavigationPageContinuation",,,"WizardPageExchangeSetupResults_OnOpen");
	GoToTableNewRow(8, "WizardPageWaitForDataExchangeSettingsCreation", "", "NavigationPageWait",,,, True, "WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessing");
	GoToTableNewRow(9, "WizardPageEndWithSettingsExport",            "", "NavigationPageEnd");

	
EndProcedure

&AtServer
Procedure SecondExchangeSetupStageGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WizardPageStart",                          "", "NavigationPageStart", "WizardPageStart_OnGoNext");
	GoToTableNewRow(2, "WizardPageSetTransportParametersFILE",     "", "NavigationPageContinuation", "WizardPageSetTransportParametersFILE_OnGoNext",,"WizardPageSetTransportParametersFILE_OnOpen");
	GoToTableNewRow(3, "WizardPageSetTransportParametersFTP",      "", "NavigationPageContinuation", "WizardPageSetTransportParametersFTP_OnGoNext",,"WizardPageSetTransportParametersFTP_OnOpen");
	GoToTableNewRow(4, "WizardPageSetTransportParametersEMAIL",    "", "NavigationPageContinuation", "WizardPageSetTransportParametersEMAIL_OnGoNext",,"WizardPageSetTransportParametersEMAIL_OnOpen");
 GoToTableNewRow(5, "WizardPageSecondSetupStageParameterSetup", "", "NavigationPageContinuation", "WizardPageSecondSetupStageParameterSetup_OnGoNext",, "WizardPageParameterSetup_OnOpen");
	GoToTableNewRow(6, "WizardPageExchangeSetupResults",           "", "NavigationPageEndAndBack",,,"WizardPageExchangeSetupResults_OnOpen");

	
EndProcedure

&AtServer
Procedure DataExchangeOverExternalConnectionSettingsGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WizardPageStart",                                          "", "NavigationPageStart");
	GoToTableNewRow(2, "WizardPageWizardRunModeChoice",                            "", "NavigationPageContinuation", "WizardPageWizardRunModeChoice_OnGoNext");
	GoToTableNewRow(3, "WizardPageWaitForCheckExternalConnectionConnected",        "", "NavigationPageWait",,,, True, "WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessing");
	GoToTableNewRow(4, "WizardPageFirstInfobaseExternalConnectionParameterSetup",  "", "NavigationPageContinuation", "WizardPageFirstInfobaseExternalConnectionParameterSetup_OnGoNext",,"WizardPageFirstInfobaseExternalConnectionParameterSetup_OnOpen");
	GoToTableNewRow(5, "WizardPageSecondInfobaseExternalConnectionParameterSetup", "", "NavigationPageContinuation", "WizardPageSecondInfobaseExternalConnectionParameterSetup_OnGoNext",,"WizardPageSecondInfobaseExternalConnectionParameterSetup_OnOpen");
	GoToTableNewRow(6, "WizardPageExchangeSetupResults",                           "", "NavigationPageContinuation",,,"WizardPageExchangeSetupResults_OnOpen_ExternalConnection");
	GoToTableNewRow(7, "WizardPageWaitForDataExchangeSettingsCreation",            "", "NavigationPageWait",,,, True, "WizardPageWaitForDataExchangeSettingsCreationOverExternalConnection_LongActionProcessing");
	GoToTableNewRow(8, "WizardPageEndWithExchangeOverExternalConnection",          "", "NavigationPageEnd");
	
EndProcedure

&AtServer
Procedure ExchangeOverWebServiceSetupGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1,  "WizardPageStart",, "NavigationPageStart");
	GoToTableNewRow(2,  "WizardPageWizardRunModeChoice", , "NavigationPageContinuation");
	
	// Setting connection parameters. Verifying connection
	GoToTableNewRow(3,  "WizardPageWaitForConnectionToServiceCheck", "", "NavigationPageWait",,,, True, "WizardPageWaitForTestConnectionViaWebService_LongActionProcessing");
	
	// Setting data export parameters (node filters)
	GoToTableNewRow(4,  "WizardPageDataExchangeOverWebServiceParameterSetup", "", "NavigationPageContinuation", "WizardPageDataExchangeParameterSetup_OnGoNext",, "WizardPageDataExchangeParameterSetup_OnOpen");
	
	// Applying default values for data import
	GoToTableNewRow(5, "WizardPageDataGetParameters",, "NavigationPageContinuation", "WizardPageDataGetParameters_OnGoNext");
	
	// Creating data exchange settings. Registering catalogs to be exported.
	GoToTableNewRow(6,  "WizardPageWaitForExchangeSettingsCreationDataAnalysis",  "", "NavigationPageWait",,,, True, "WizardPageWaitForExchangeSettingsCreationDataAnalysis_LongActionProcessing");
	GoToTableNewRow(7,  "WizardPageWaitForExchangeSettingsCreationDataAnalysis",, "NavigationPageWait",,,, True, "WizardPageWaitForExchangeSettingsCreationDataAnalysisLongAction_LongActionProcessing");
	
	// Getting catalogs from the correspondent infobase
	GoToTableNewRow(8,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessage_LongActionProcessing");
	GoToTableNewRow(9,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongAction_LongActionProcessing");
	GoToTableNewRow(10,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongActionEnd_LongActionProcessing");
	
	// Mapping data automatically. Getting mapping statistics.
	GoToTableNewRow(11, "WizardPageWaitForDataAnalysisAutomaticMapping",, "NavigationPageWait",,,, True, "WizardPageWaitForAutomaticMappingDataAnalysis_LongActionProcessing");
	
	// Mapping data manually
	GoToTableNewRow(12, "WizardPageDataMapping",, "NavigationPageContinuationOnlyNext", "WizardPageDataMapping_OnGoNext",, "WizardPageDataMapping_OnOpen");
	
	// Catalog synchronization
	GoToTableNewRow(13, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(14, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(15, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(16, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongActionEnd_LongActionProcessing");
	
	// Accounting parameter settings
	GoToTableNewRow(17, "WizardPageAddingDocumentDataToAccountingRecordsSettings",, "NavigationPageContinuationOnlyNext", "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnGoNext",, "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnOpen");
	
	// Saving settings. Registering all data to be exported except catalogs.
	GoToTableNewRow(18, "WizardPageWaitForSaveSettings",, "NavigationPageWait",,,, True, "WizardPageWaitForSaveSettings_LongActionProcessing");
	GoToTableNewRow(19, "WizardPageWaitForSaveSettings",, "NavigationPageWait",,,, True, "WizardPageWaitForSaveSettingsLongAction_LongActionProcessing");
	
	// Synchronizing all data except catalogs
	GoToTableNewRow(20, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(21, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongAction_LongActionProcessing");
	GoToTableNewRow(22, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongActionEnd_LongActionProcessing");
	GoToTableNewRow(23, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(24, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(25, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongActionEnd_LongActionProcessing");
	
	GoToTableNewRow(26, "WizardPageDataExchangeCreatedSuccessfully",, "NavigationPageEnd",,, "WizardPageDataExchangeSuccessfullyCreated_OnOpen");
	
EndProcedure

&AtServer
Procedure ExtendedExchangeWithServiceSetupGoToTable()
	
	GoToTable.Clear();
	
	// Setting connection parameters. Verifying connection
	GoToTableNewRow(1,  "WizardPageStartExchangeWithServiceSetup",   "", "NavigationPageStart");
	GoToTableNewRow(2,  "WizardPageWaitForConnectionToServiceCheck", "", "NavigationPageWait",,,, True, "WizardPageWaitForTestConnectionViaWebService_LongActionProcessing");
	
	// Setting data export parameters (node filters)
	GoToTableNewRow(3,  "WizardPageDataExchangeSetupParameter", "", "NavigationPageContinuation", "WizardPageDataExchangeParameterSetup_OnGoNext",, "WizardPageDataExchangeParameterSetup_OnOpen");
	
	// Applying default values for data import
	GoToTableNewRow(4, "WizardPageDataGetParameters",, "NavigationPageContinuation", "WizardPageDataGetParameters_OnGoNext");
	
	// Creating data exchange settings. Registering catalogs to be exported.
	GoToTableNewRow(5,  "WizardPageWaitForExchangeSettingsCreationDataAnalysis",  "", "NavigationPageWait",,,, True, "WizardPageWaitForExchangeSettingsCreationDataAnalysis_LongActionProcessing");
	GoToTableNewRow(6,  "WizardPageWaitForExchangeSettingsCreationDataAnalysis",, "NavigationPageWait",,,, True, "WizardPageWaitForExchangeSettingsCreationDataAnalysisLongAction_LongActionProcessing");
	
	// Getting catalogs from the correspondent infobase
	GoToTableNewRow(7,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessage_LongActionProcessing");
	GoToTableNewRow(8,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongAction_LongActionProcessing");
	GoToTableNewRow(9,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongActionEnd_LongActionProcessing");
	
	// Mapping data automatically. Getting mapping statistics.
	GoToTableNewRow(10,  "WizardPageWaitForDataAnalysisAutomaticMapping",, "NavigationPageWait",,,, True, "WizardPageWaitForAutomaticMappingDataAnalysis_LongActionProcessing");
	
	// Mapping data manually
	GoToTableNewRow(11, "WizardPageDataMapping",, "NavigationPageContinuationOnlyNext", "WizardPageDataMapping_OnGoNext",, "WizardPageDataMapping_OnOpen");
	
	// Catalog synchronization
	GoToTableNewRow(12, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(13, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(14, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(15, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongActionEnd_LongActionProcessing");
	
	// Accounting parameter settings
	GoToTableNewRow(16, "WizardPageAddingDocumentDataToAccountingRecordsSettings",, "NavigationPageContinuationOnlyNext", "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnGoNext",, "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnOpen");
	
	// Saving settings; Registering all data to be exported except catalogs.
	GoToTableNewRow(17, "WizardPageWaitForSaveSettings",, "NavigationPageWait",,,, True, "WizardPageWaitForSaveSettings_LongActionProcessing");
	GoToTableNewRow(18, "WizardPageWaitForSaveSettings",, "NavigationPageWait",,,, True, "WizardPageWaitForSaveSettingsLongAction_LongActionProcessing");
	
	// Synchronizing all data except catalogs
	GoToTableNewRow(19, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(20, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongAction_LongActionProcessing");
	GoToTableNewRow(21, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongActionEnd_LongActionProcessing");
	GoToTableNewRow(22, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(23, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(24, "DataSynchronizationWait",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongActionEnd_LongActionProcessing");
	
	GoToTableNewRow(25, "WizardPageDataExchangeCreatedSuccessfully",, "NavigationPageEnd",,, "WizardPageDataExchangeSuccessfullyCreated_OnOpen");
	
EndProcedure

#EndRegion
