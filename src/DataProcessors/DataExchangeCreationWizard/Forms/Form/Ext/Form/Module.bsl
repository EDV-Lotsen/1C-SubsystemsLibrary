&AtClient
Var ForceCloseForm;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If Not Users.RolesAvailable("AddEditDataExchanges") Then
		DataExchangeServer.ReportError(NStr("en = 'Insufficient rights to add/edit data exchanges.'"), Cancel);
		Return;
	EndIf;
	
	// Parametrizing the wizard by the exchange plan name (it is mandatory)
	If Not Parameters.Property("ExchangePlanName", Object.ExchangePlanName) Then
		
		DataExchangeServer.ReportError(
		NStr("en = 'The wizard can be called from the command interface only. The wizard has been terminated.'"), Cancel);
		
	ElsIf IsBlankString(Object.ExchangePlanName) Then
		
		DataExchangeServer.ReportError(NStr("en = 'The exchange plan name is not specified. The wizard has been terminated.'"), Cancel);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	ExchangeWithServiceSetup = Parameters.Property("ExchangeWithServiceSetup");
	
	SetPrivilegedMode(True);
	
	// Setting common default values 
	InfoBasePlacement                 = "ConnectionUnavailable";
	InfoBaseType                      = "Server";
	ExecuteDataExchangeNow            = True;
	CreateInitialImageNow             = True;
	ExecuteInteractiveDataExchangeNow = True;
	
	Object.EMAILCompressOutgoingMessageFile = True;
	Object.FTPCompressOutgoingMessageFile   = True;
	Object.FTPConnectionPort                = 21;
	
	// The default value for the exchange message transport kind
	Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
	
	// Checking whether an initial image creation form exists for the exchange plan.
	InitialImageCreationFormExists = (Metadata.ExchangePlans[Object.ExchangePlanName].Forms.Find("InitialImageCreationForm") <> Undefined);
	
	// Getting default exchange plan values
	ExchangePlanManager = ExchangePlans[Object.ExchangePlanName];
	
	Title = Metadata.ExchangePlans[Object.ExchangePlanName].Synonym + "" + NStr("en='(creating)'");
	
	SettingsFileNameForTarget = ExchangePlanManager.SettingsFileNameForTarget() + ".xml";
	
	NodeFilterStructure    = DataExchangeServer.ValueByType(ExchangePlanManager.NodeFilterStructure(), "Structure");
	NodeDefaultValues = DataExchangeServer.ValueByType(ExchangePlanManager.NodeDefaultValues(), "Structure");
	
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
	Items.FixExternalConnectionErrors.Visible = False;
	
	DataTransferRestrictionDetails = ExchangePlanManager.DataTransferRestrictionDetails(NodeFilterStructure);
	DefaultValueDetails            = ExchangePlanManager.DefaultValueDetails(NodeDefaultValues);
	
	ThisNode = ExchangePlanManager.ThisNode();
	
	InitialImageCreationFormName = ExchangePlanManager.InitialImageCreationFormName();
	
	UsedExchangeMessageTransports = DataExchangeCached.UsedExchangeMessageTransports(ThisNode);
	
	UseExchangeMessageTransportEMAIL = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.EMAIL) <> Undefined);
	UseExchangeMessageTransportFILE  = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.FILE) <> Undefined);
	UseExchangeMessageTransportFTP   = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.FTP) <> Undefined);
	UseExchangeMessageTransportCOM   = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.COM) <> Undefined);
	UseExchangeMessageTransportWS    = (UsedExchangeMessageTransports.Find(Enums.ExchangeMessageTransportKinds.WS) <> Undefined);
	
	If UseExchangeMessageTransportCOM
		Or UseExchangeMessageTransportWS Then
		
		CorrespondentInfoBaseNodeFilterSetup    = DataExchangeServer.ValueByType(ExchangePlanManager.CorrespondentInfoBaseNodeFilterSetup(), "Structure");
		CorrespondentInfoBaseNodeDefaultValues = DataExchangeServer.ValueByType(ExchangePlanManager.CorrespondentInfoBaseNodeDefaultValues(), "Structure");
		
		CorrespondentInfoBaseNodeFilterSettingsAvailable    = CorrespondentInfoBaseNodeFilterSetup.Count() > 0;
		CorrespondentInfoBaseNodeDefaultValuesAvailable = CorrespondentInfoBaseNodeDefaultValues.Count() > 0;
		
		Items.RestrictionsGroupBorder4.Visible = CorrespondentInfoBaseNodeFilterSettingsAvailable;
		Items.DefaultValueGroupBorder4.Visible = CorrespondentInfoBaseNodeDefaultValuesAvailable;
		
		Items.CorrespondentInfoBaseDefaultValueGroupBorder.Visible = CorrespondentInfoBaseNodeDefaultValuesAvailable;
		
		CorrespondentInfoBaseDataTransferRestrictionDetails = ExchangePlanManager.CorrespondentInfoBaseDataTransferRestrictionDetails(CorrespondentInfoBaseNodeFilterSetup);
		CorrespondentInfoBaseDefaultValueDetails       = ExchangePlanManager.CorrespondentInfoBaseDefaultValueDetails(CorrespondentInfoBaseNodeDefaultValues);
		
		CorrespondentAccountingSettingsCommentLabel = ExchangePlanManager.CorrespondentInfoBaseAccountingSettingsSetupComment();
		
	EndIf;
	
	// Getting other settings
	Object.SourceInfoBasePrefix      = GetFunctionalOption("InfoBasePrefix");
	Object.SourceInfoBasePrefixIsSet = ValueIsFilled(Object.SourceInfoBasePrefix);
	
	If Not Object.SourceInfoBasePrefixIsSet
		And Not ExchangeWithServiceSetup Then
		
		Object.SourceInfoBasePrefix = DataExchangeOverridable.DefaultInfoBasePrefix();
	EndIf;
	
	WizardRunVariant = "SetupNewDataExchange";
	
	If ExchangeWithServiceSetup Then
		
		WizardRunMode = "ExchangeOverWebService";
		
	ElsIf UseExchangeMessageTransportCOM Then
		
		WizardRunMode = "ExchangeOverExternalConnection";
		
	Else
		
		WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels";
		
	EndIf;
	
	ExchangePlanMetadata = Metadata.ExchangePlans[Object.ExchangePlanName];
	
	Object.IsDistributedInfoBaseSetup = DataExchangeCached.IsDistributedInfoBaseExchangePlan(Object.ExchangePlanName);
	Object.IsStandardExchangeSetup    = DataExchangeCached.IsStandardDataExchangeNode(ThisNode);
	
	FileInfoBase = CommonUse.FileInfoBase();
	
	SetVisibleAtServer();
	
	
	Object.UseTransportParametersFILE  = True;
	Object.UseTransportParametersFTP   = False;
	Object.UseTransportParametersEMAIL = False;
	
	Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
	Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
	Object.ThisInfoBaseDescription = DataExchangeServer.PredefinedExchangePlanNodeDescription(Object.ExchangePlanName);
	ThisInfoBaseDescriptionSet     = Not IsBlankString(Object.ThisInfoBaseDescription);
	
	Items.ThisInfoBaseDescription.ReadOnly  = ThisInfoBaseDescriptionSet;
	Items.ThisInfoBaseDescription1.ReadOnly = ThisInfoBaseDescriptionSet;
	
	If Not ThisInfoBaseDescriptionSet Then
		
		Object.ThisInfoBaseDescription = DataExchangeCached.ThisInfoBaseName();
		
	EndIf;
	
	// Setting values of the Next button comment labels on the bottom of wizard pages
	
	// Comment label on first page
	If UseExchangeMessageTransportFILE Then
		
		Items.NextLabelWizardRunVariant.Title = LabelNextFILE();
		
	ElsIf UseExchangeMessageTransportFTP Then
		
		Items.NextLabelWizardRunVariant.Title = NextLabelFTP();
		
	ElsIf UseExchangeMessageTransportEMAIL Then
		
		Items.NextLabelWizardRunVariant.Title = NextLabelEMAIL();
		
	Else
		
		Items.NextLabelWizardRunVariant.Title = NextLabelSettings();
		
	EndIf;
	
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
			
			DIBExchangePlanName = ExchangePlans.MasterNode().Metadata().Name;
			
			If Object.ExchangePlanName = DIBExchangePlanName
				And Not Constants.SubordinateDIBNodeSetupCompleted.Get() Then
				
				IsContinuedInDIBSubordinateNodeSetup = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		
		WizardRunVariant = "ContinueDataExchangeSetup";
		
		DataProcessorObject = FormAttributeToValue("Object");
		
		DataProcessorObject.ExecuteWizardParameterImportFromConstant(False);
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
		Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP ;
		Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
		
	EndIf;
	
	WizardRunVariantOnChangeAtServer();
	
	WizardRunModeOnChangeAtServer();
	
	EventLogMessageTextEstablishingConnectionToWebService = DataExchangeServer.EventLogMessageTextEstablishingConnectionToWebService();
	DataExchangeCreationEventLogMessageText = DataExchangeServer.DataExchangeCreationEventLogMessageText();
	
	LongAction = False;
	PredefinedDataExchangeSchedule = "EveryHour";
	DataExchangeExecutionSchedule = PredefinedScheduleEveryHour();
	CustomDescriptionPresentation = String(DataExchangeExecutionSchedule);
	
	EnableAllEventWritingToEventLog = Not CommonUse.EventLogEnabled("Error");
	Items.EnableAllEventWritingToEventLogGroup.Visible  = EnableAllEventWritingToEventLog;
	Items.EnableAllEventWritingToEventLogGroup1.Visible = EnableAllEventWritingToEventLog;
	Items.EnableAllEventWritingToEventLogGroup2.Visible = EnableAllEventWritingToEventLog;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ForceCloseForm = False;
	
	OSAuthenticationOnChange();
	
	InfoBaseRunModeOnChange();
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If LongAction Then
		DoMessageBox(NStr("en = 'Creating the data exchange.
							|The wizard cannot be terminated.'")
		);
		Cancel = True;
		Return;
	EndIf;
	
	If ForceCloseForm = True Then
		Return;
	EndIf;
	
	NString = NStr("en = 'Do you want to cancel exchange setup and exit the wizard?'");
	
	Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	
	If Response = DialogReturnCode.No Then
		
		Cancel = True;
		
	EndIf;
	
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
			DoMessageBox(NStr("en = 'Error gathering statistic data.'"));
		Else
			
			ExpandStatisticsTree(Parameter.UniqueKey);
			
			Status(NStr("en = 'Data gathering completed."));
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

////////////////////////////////////////////////////////////////////////////////
// WizardPageStart page

&AtClient
Procedure DataExchangeSettingsFileNameToImportStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectExchangeSettingsFile(True);
	
EndProcedure

&AtClient
Procedure DataExchangeSettingsFileNameToImportOnChange(Item)
	
	File = New File(Object.DataExchangeSettingsFileNameToImport);
	
	If    Not File.Exist()
		Or Not File.IsFile() Then
		
		DoMessageBox(NStr("en = 'Specify the correct settings file name.'"));
		Object.DataExchangeSettingsFileNameToImport = "";
		Return;
	EndIf;
	
	SelectExchangeSettingsFile(False);
	
EndProcedure

&AtClient
Procedure FirstInfoBasePicture1Click(Item)
	
	WizardRunVariant = "SetupNewDataExchange";
	
	WizardRunVariantOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure SecondInfoBasePicture1Click(Item)
	
	WizardRunVariant = "ContinueDataExchangeSetup";
	
	WizardRunVariantOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure WizardRunVariantOnChange(Item)
	
	WizardRunVariantOnChangeAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageDataExchangeCreatedSuccessfully page

&AtClient
Procedure PredefinedDataExchangeScheduleOnChange(Item)
	
	PredefinedDataExchangeScheduleOnValueChange();
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAutomaticallyOnChange(Item)
	
	ExecuteDataExchangeAutomaticallyOnValueChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageWizardRunModeChoice page

&AtClient
Procedure WizardRunModeOnChange(Item)
	
	WizardRunModeOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure COMInfoBaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Object, "COMInfoBaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfoBaseDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Object, "COMInfoBaseDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMOSAuthenticationOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure COMInfoBaseRunModeOnChange(Item)
	
	InfoBaseRunModeOnChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageSetTransportParametersFILE page

&AtClient
Procedure FILEDataExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
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
// WizardPageSetTransportParametersFTP page

&AtClient
Procedure UseTransportParametersFTPOnChange(Item)
	
	Items.TransportSettingsFTP.Enabled = Object.UseTransportParametersFTP;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// WizardPageSetTransportParametersEMAIL page

&AtClient
Procedure UseTransportParametersEMAILOnChange(Item)
	
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF StatisticsTree TABLE

&AtClient
Procedure StatisticsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

////////////////////////////////////////////////////////////////////////////////
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
	
	// Enabling event log, if necessary
	If EnableAllEventWritingToEventLog Then
		
		DoMessageBox = "";
		
		EnableUseEventLog(DataExchangeCreationEventLogMessageText, DoMessageBox);
		
		If Not IsBlankString(DoMessageBox) Then
			
			DoMessageBox(DoMessageBox);
			
		EndIf;
		
	EndIf;
	
	Cancel = False;
	
	If WizardRunMode = "ExchangeOverExternalConnection" Then
		
		FinishExchangeOverExternalConnectionSetup();
		
	ElsIf WizardRunMode = "ExchangeOverWebService" Then
		
		FinishExchangeOverWebServiceSetup();
		
	ElsIf WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels" Then
		
		If WizardRunVariant = "SetupNewDataExchange" Then
			
			FinishFirstExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel);
			
		ElsIf WizardRunVariant = "ContinueDataExchangeSetup" Then
			
			FinishSecondExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel);
			
		EndIf;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	DataExchangeClientOverridable.OnExchangeCreationWizardExit(ThisForm, StartJobManager());
	
	ForceCloseForm = True;
	Close();
	
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
// Overridable part 

&AtClient
Procedure MapData(Command)
	
	OpenMappingForm();
	
EndProcedure

&AtClient
Procedure SetupDataExport(Command)
	
	ConnectionType = "WebService";
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.NodesSetupForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
	FormParameters.Insert("Settings", NodesSetupFormContext);
	
	OpeningResult = OpenFormModal(NodeSettingsFormName, FormParameters, ThisForm);
	
	If OpeningResult <> Undefined Then
		
		NodesSetupFormContext = OpeningResult;
		
		DataExportSettingsDescription = OpeningResult.ContextDetails;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataRegistrationRestrictionSetup(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.NodeSettingsForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	
	OpeningResult = OpenFormModal(NodeSettingsFormName, New Structure("NodeFilterStructure", NodeFilterStructure), ThisForm);
	
	If OpeningResult <> Undefined Then
		
		For Each FilterSettings In NodeFilterStructure Do
			
			NodeFilterStructure[FilterSettings.Key] = OpeningResult[FilterSettings.Key];
			
		EndDo;
		
		// Calling server
		GetDataTransferRestrictionDetails(NodeFilterStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfoBaseRegistrationRestrictionSetupViaWebService(Command)
	
	CorrespondentInfoBaseRegistrationRestrictionSetup("WebService");
	
EndProcedure

&AtClient
Procedure CorrespondentInfoBaseRegistrationRestrictionSetupThroughExternalConnection(Command)
	
	CorrespondentInfoBaseRegistrationRestrictionSetup("ExternalConnection");
	
EndProcedure

&AtClient
Procedure DefaultValueSetup(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.DefaultValueSetupForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	
	FormParameters = New Structure;
	FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
	
	OpeningResult = OpenFormModal(NodeSettingsFormName, FormParameters, ThisForm);
	
	If OpeningResult <> Undefined Then
		
		For Each Setting In NodeDefaultValues Do
			
			NodeDefaultValues[Setting.Key] = OpeningResult[Setting.Key];
			
		EndDo;
		
		// Calling server
		GetDefaultValueDetails(NodeDefaultValues);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfoBaseDefaultValueSetupViaWebService(Command)
	
	CorrespondentInfoBaseDefaultValueSetup("WebService");
	
EndProcedure

&AtClient
Procedure CorrespondentInfoBaseDefaultValueSetupViaExternalConnection(Command)
	
	CorrespondentInfoBaseDefaultValueSetup("ExternalConnection");
	
EndProcedure

&AtClient
Procedure SaveDataExchangeSettingsFile(Command)
	
	Var TempStorageAddress;
	
	Cancel = False;
	
	// Calling server
	ExportExchangeSettingsForTarget(Cancel, TempStorageAddress);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error saving data exchange settings file.'"));
		
	Else
		
		#If WebClient Then
			
			GetFile(TempStorageAddress, SettingsFileNameForTarget, True);
			
			Object.DataExchangeSettingsFileName = SettingsFileNameForTarget;
			
		#Else
			
			Dialog = New FileDialog(FileDialogMode.Save);
			
			Dialog.Title        = NStr("en = 'Specify the data exchange settings file name.'");
			Dialog.Extension    = "xml";
			Dialog.Filter       = "Data exchange settings file(*.xml)|*.xml";
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
Procedure CheckFILEConnection(Command)
	
	CheckConnection("FILE");
	
EndProcedure

&AtClient
Procedure CheckFTPConnection(Command)
	
	CheckConnection("FTP");
	
EndProcedure

&AtClient
Procedure CheckEMAILConnection(Command)
	
	CheckConnection("EMAIL");
	
EndProcedure

&AtClient
Procedure CheckCOMConnection(Command)
	
	ClearMessages();
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("COMOSAuthentication");
	SettingsStructure.Insert("COMInfoBaseOperationMode");
	SettingsStructure.Insert("COMInfoBaseNameAtPlatformServer");
	SettingsStructure.Insert("COMUserName");
	SettingsStructure.Insert("COMPlatformServerName");
	SettingsStructure.Insert("COMInfoBaseDirectory");
	SettingsStructure.Insert("COMUserPassword");
	
	FillPropertyValues(SettingsStructure, Object);
	
	Cancel = False;
	ErrorAttachingAddIn = False;
	
	DataExchangeServer.CheckExternalConnection(Cancel, SettingsStructure, ErrorAttachingAddIn);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error establishing connection (see the event log for details).'"));
		
		If ErrorAttachingAddIn And FileInfoBase Then
			
			Items.FixExternalConnectionErrors.Visible = True;
			
		EndIf;
		
	Else
		DoMessageBox(NStr("en = 'Connection established successfully.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckWSConnection(Command)
	
	Cancel = False;
	
	CheckWSConnectionAtClient(Cancel);
	
	If Not Cancel Then
		
		DoMessageBox(NStr("en = 'Connection established successfully.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FixExternalConnectionErrors(Command)
	
	ForceCloseForm = True;
	CommonUseClient.RegisterCOMConnector();
	
EndProcedure

&AtClient
Procedure HowToGetWebServiceConnectionParameters(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToGetWebServiceConnectionParameters");
	FormParameters.Insert("Title", NStr("en = 'How to determine parameters for connecting the second infobase'"));
	
	OpenFormModal("DataProcessor.DataExchangeCreationWizard.Form.AdditionalDetails", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure HowToGetServiceConnectionParameters(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToGetServiceConnectionParameters");
	FormParameters.Insert("Title", NStr("en = 'How to determine parameters for connecting the application located in the service'"));
	
	OpenFormModal("DataProcessor.DataExchangeCreationWizard.Form.AdditionalDetails", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure HowToGetConnectionParameters(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToGetConnectionParameters");
	FormParameters.Insert("Title", NStr("en = 'How to determine parameters for connecting the second infobase'"));
	
	OpenFormModal("DataProcessor.DataExchangeCreationWizard.Form.AdditionalDetails", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure HowToGetSecondInfoBasePrefix(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToGetSecondInfoBasePrefix");
	FormParameters.Insert("Title", NStr("en = 'How to determine the prefix of the correspondent infobase'"));
	
	OpenFormModal("DataProcessor.DataExchangeCreationWizard.Form.AdditionalDetails", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure HowToGenerateExchangeSettingsFile(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToGenerateExchangeSettingsFile");
	FormParameters.Insert("Title", NStr("en = 'How to generate the data exchange settings file'"));
	
	OpenFormModal("DataProcessor.DataExchangeCreationWizard.Form.AdditionalDetails", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure GetThisInfoBasePrefix(Command)
	
	OpenFormModal("DataProcessor.DataExchangeCreationWizard.Form.GetThisInfoBasePrefix", , ThisForm);
	
EndProcedure

&AtClient
Procedure ExecuteDataImportInSecondInfoBase(Command)
	
	DataExchangeClient.RunPlatformAppAndExecuteInteractiveDataImport(ExternalConnectionParameterStructure(), Object.ExchangePlanName);
	
EndProcedure

&AtClient
Procedure ChangeCustomSchedule(Command)
	
	Dialog = New ScheduledJobDialog(DataExchangeExecutionSchedule);
	
	If Dialog.DoModal() Then
		
		DataExchangeExecutionSchedule = Dialog.Schedule;
		
		CustomDescriptionPresentation = String(DataExchangeExecutionSchedule);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure PredefinedDataExchangeScheduleOnValueChange()
	
	UseCustomSchedule = (PredefinedDataExchangeSchedule = "OtherSchedule");
	
	Items.CustomSchedulePages.CurrentPage = ?(UseCustomSchedule,
						Items.CustomSchedulePage,
						Items.EmptyCustomSchedulePage
	);
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAutomaticallyOnValueChange()
	
	Items.PredefinedSchedulePages.CurrentPage = ?(ExecuteDataExchangeAutomatically,
						Items.PredefinedSchedulePage,
						Items.NotAvailablePredefinedSchedulePage
	);
	
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
	
	// Executing step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visibility
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Setting current default button
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
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
	
	// Step change event handlers
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
		Raise NStr("en = 'The page to be displayed is not specified.'");
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
		Raise NStr("en = 'The page to be displayed is not specified.'");
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
									LongActionHandlerName = ""
	)
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
			
		ElsIf TypeOf(Item) = Type("FormButton")
				And Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Idle handlers

&AtClient
Procedure LongActionIdleHandler()
	
	ErrorMessageString = "";
	
	ActionState = DataExchangeServer.LongActionState(LongActionID,
																		Object.WSURL,
																		Object.WSUserName,
																		Object.WSPassword,
																		ErrorMessageString
	);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	ElsIf ActionState = "Completed" Then
		
		LongAction = False;
		LongActionFinished = True;
		
		NextCommand(Undefined);
		
	Else // Failed, Canceled
		
		WriteErrorToEventLog(ErrorMessageString, DataExchangeCreationEventLogMessageText);
		
		LongAction = False;
		
		BackCommand(Undefined);
		
		QuestionText = NStr("en = 'Error creating the data exchange.
							|Do you want to open the event log?'"
		);
		
		SuggestOpenEventLog(QuestionText, DataExchangeCreationEventLogMessageText);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures and functions

&AtServer
Procedure SetupNewDataExchangeAtServer(Cancel, NodeFilterStructure, NodeDefaultValues)
	
	Object.WizardRunVariant = WizardRunVariant;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetupNewDataExchangeOverExternalConnectionAtServer(Cancel, CorrespondentInfoBaseNodeFilterSetup, CorrespondentInfoBaseNodeDefaultValues)
	
	Object.WizardRunVariant = WizardRunVariant;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchangeOverExternalConnection(Cancel, NodeFilterStructure, NodeDefaultValues, CorrespondentInfoBaseNodeFilterSetup, CorrespondentInfoBaseNodeDefaultValues);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetupNewDataExchangeAtServerOverWebService(Cancel)
	
	Object.WizardRunVariant = WizardRunVariant;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchangeOverWebServiceInTwoBases(Cancel,
																		NodesSetupFormContext,
																		LongAction,
																		LongActionID
	);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure UpdateDataExchangeSettings(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.UpdateDataExchangeSettings(Cancel,
												NodeDefaultValues,
												CorrespondentInfoBaseNodeDefaultValues,
												LongAction,
												LongActionID
	);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetVisibleAtServer()
	
	Items.ExchangeInformationDirectoryAtServerSelectionComment.Visible = Not FileInfoBase;
	
	Items.SourceInfoBasePrefix.Visible  = Not Object.SourceInfoBasePrefixIsSet;
	Items.SourceInfoBasePrefix1.Visible = Not Object.SourceInfoBasePrefixIsSet;
	Items.TargetInfoBasePrefix.Visible  = False;
	
	Items.SourceInfoBasePrefixExchangeOverWebService.Visible  = Not Object.SourceInfoBasePrefixIsSet;
	Items.SourceInfoBasePrefixExchangeOverWebService.ReadOnly = Object.SourceInfoBasePrefixIsSet;
	
	Items.SourceInfoBasePrefixExchangeWithService.ReadOnly = Object.SourceInfoBasePrefixIsSet;
	Items.TargetInfoBasePrefixExchangeWithService.ReadOnly = True;
	
	Items.FinalActionDisplayPages.CurrentPage = ?(Object.IsDistributedInfoBaseSetup,
					Items.ExecuteSubordinateNodeImageInitialCreationPage,
					Items.ExecuteDataExportForMappingPage);
	
	If Object.IsDistributedInfoBaseSetup Then
		
		Items.WizardRunVariant.Enabled = False;
		Items.FirstInfoBasePicture.Href = False;
		Items.FirstInfoBasePicture1.Href = False;
		Items.SecondInfoBasePicture.Href = False;
		Items.SecondInfoBasePicture1.Href = False;
		
		// The settings file does not created for a DIB node. Settings for the
		// correspondent infobase are passed via constant.
		Items.ExchangeSettingsFileGroup1.Visible = False;
		Items.ExchangeSettingsFileSelectionPages.Visible = False;
		
		Items.HowToGetSecondInfoBasePrefix.Visible = False;
		Items.GetThisInfoBasePrefix.Visible = False;
		
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
Function CorrespondentInfoBaseNodeFilterResultPresentation()
	
	Return ?(IsBlankString(CorrespondentInfoBaseDataTransferRestrictionDetails), "", CorrespondentInfoBaseDataTransferRestrictionDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function DefaultNodeValueResultPresentation()
	
	Return ?(IsBlankString(DefaultValueDetails), "", DefaultValueDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function CorrespondentInfoBaseNodeDefaultValueResultPresentation()
	
	Return ?(IsBlankString(CorrespondentInfoBaseDefaultValueDetails), "", CorrespondentInfoBaseDefaultValueDetails + Chars.LF + Chars.LF);
	
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
	
EndProcedure

&AtServer
Procedure GetDataTransferRestrictionDetails(NodeFilterStructure)
	
	DataTransferRestrictionDetails = ExchangePlans[Object.ExchangePlanName].DataTransferRestrictionDetails(NodeFilterStructure);
	
EndProcedure

&AtServer
Procedure GetCorrespondentInfoBaseDataTransferRestrictionDetails(CorrespondentInfoBaseNodeFilterSetup)
	
	CorrespondentInfoBaseDataTransferRestrictionDetails = ExchangePlans[Object.ExchangePlanName].CorrespondentInfoBaseDataTransferRestrictionDetails(CorrespondentInfoBaseNodeFilterSetup);
	
EndProcedure

&AtServer
Procedure GetDefaultValueDetails(NodeDefaultValues)
	
	DefaultValueDetails = ExchangePlans[Object.ExchangePlanName].DefaultValueDetails(NodeDefaultValues);
	
EndProcedure

&AtServer
Procedure GetCorrespondentInfoBaseDefaultValueDetails(CorrespondentInfoBaseNodeDefaultValues)
	
	CorrespondentInfoBaseDefaultValueDetails = ExchangePlans[Object.ExchangePlanName].CorrespondentInfoBaseDefaultValueDetails(CorrespondentInfoBaseNodeDefaultValues);
	
EndProcedure

&AtClient
Procedure DataExchangeInitializationAtClient(Cancel)
	
	Status(NStr("en = 'Exporting data...'"));
	
	// Exporting data
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(Cancel, Object.InfoBaseNode, False, True, Object.ExchangeMessageTransportKind);
	
	Status(NStr("en = 'Data export completed.'"));
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error exporting data (see the event log for details).'"));
		
	EndIf;
	
EndProcedure

&AtServer
Function GetExchangeTransportSettingsDescription()
	
	COMInfoBaseOperationMode = 0;
	COMOSAuthentication = False;
	
	// Return value
	Result = "";
	
	SettingsPresentation = InformationRegisters.ExchangeTransportSettings.TransportSettingsPresentations(Object.ExchangeMessageTransportKind);
	
	For Each Item In SettingsPresentation Do
		
		SettingValue = Object[Item.Key];
		
		If WizardRunMode = "ExchangeOverExternalConnection" Then
			
			If Item.Key = "COMInfoBaseOperationMode" Then
				
				SettingValue = ?(Object[Item.Key] = 0, NStr("en = 'File'"), NStr("en = 'Client/server'"));
				
				COMInfoBaseOperationMode = Object[Item.Key];
				
			EndIf;
			
			If Item.Key = "COMOSAuthentication" Then
				
				COMOSAuthentication = Object[Item.Key];
				
			EndIf;
			
			If COMInfoBaseOperationMode = 0 Then
				
				If    Item.Key = "COMInfoBaseNameAtPlatformServer"
					Or Item.Key = "COMPlatformServerName" Then
					Continue;
				EndIf;
				
			Else
				
				If Item.Key = "COMInfoBaseDirectory" Then
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
			
			Continue; // hiding password values
			
		ElsIf  Not ValueType(SettingValue, "Number")
				 And Not ValueType(SettingValue, "Boolean")
				 And Not ValueIsFilled(SettingValue) Then
			
			// Displaying <Empty> if the setting value is not specified
			SettingValue = NStr("en = '<Empty>'");
			
		EndIf;
		
		SettingRow = "[Presentation]: [Value]";
		SettingRow = StrReplace(SettingRow, "[Presentation]", Item.Value);
		SettingRow = StrReplace(SettingRow, "[Value]", SettingValue);
		
		Result = Result + SettingRow + Chars.LF;
		
	EndDo;
	
	If IsBlankString(Result) Then
		
		Result = NStr("en = 'Transport parameters are not specified.'");
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function ValueType(Value, TypeName)
	
	Return TypeOf(Value) = Type(TypeName);
	
EndFunction

&AtClient
Procedure CheckConnection(TransportKind)
	
	Cancel = False;
	
	CheckConnectionAtServer(Cancel, TransportKind);
	
	MessageString = ?(Cancel,  NStr("en = 'Error establishing the connection (see the event log for details).'"),
								NStr("en = 'The connection has been successfully established.'"));
	
	DoMessageBox(MessageString);
	
EndProcedure

&AtServer
Procedure CheckConnectionAtServer(Cancel, TransportKind)
	
	If TypeOf(TransportKind) = Type("String") Then
		
		TransportKind = Enums.ExchangeMessageTransportKinds[TransportKind];
		
	EndIf;
	
	DataExchangeServer.CheckExchangeMessageTransportDataProcessorConnection(Cancel, Object, TransportKind);
	
EndProcedure

&AtServer
Procedure CheckWSConnectionAtServer(Cancel, ExtendedCheck, IsSuggestOpenEventLog)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, Object);
	
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters);
	
	If WSProxy = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CorrespondentVersions = DataExchangeCached.CorrespondentVersions(ConnectionParameters);
	
	Object.CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If Object.CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters);
		
		If WSProxy = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
		
	If ExtendedCheck Then
		
		// Getting parameters of the correspondent information base
		IsSuggestOpenEventLog = False;
		
		If Object.CorrespondentVersion_2_0_1_6 Then
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetIBParameters(Object.ExchangePlanName, "", ""));
		Else
			TargetParameters = ValueFromStringInternal(WSProxy.GetIBParameters(Object.ExchangePlanName, "", ""));
		EndIf;
		
		If Not TargetParameters.ExchangePlanExists Then
			
			Message = NStr("en = 'The correspondent infobase does not provide the exchange with the current infobase.'");
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
			Return;
			
		EndIf;
		
		Object.CorrespondentNodeCode = TargetParameters.ThisNodeCode;
		
		Object.TargetInfoBasePrefix = TargetParameters.InfoBasePrefix;
		Object.TargetInfoBasePrefixIsSet = ValueIsFilled(Object.TargetInfoBasePrefix);
		
		If Not Object.TargetInfoBasePrefixIsSet Then
			Object.TargetInfoBasePrefix = TargetParameters.DefaultInfoBasePrefix;
		EndIf;
		
		Items.TargetInfoBasePrefixExchangeOverWebService.Visible = Not Object.TargetInfoBasePrefixIsSet;
		Items.TargetInfoBasePrefixExchangeOverWebService.ReadOnly = Object.TargetInfoBasePrefixIsSet;
		
		// Checking whether an exchange with the correspondent infobase exists
		CheckWhetherDataExchangeWithSecondBaseExists(Cancel);
		If Cancel Then
			Return;
		EndIf;
		
		Object.SecondInfoBaseDescription = TargetParameters.InfoBaseDescription;
		SecondInfoBaseDescriptionSet = Not IsBlankString(Object.SecondInfoBaseDescription);
		
		Items.SecondInfoBaseDescription1.ReadOnly = SecondInfoBaseDescriptionSet;
		
		If Not SecondInfoBaseDescriptionSet Then
			
			Object.SecondInfoBaseDescription = TargetParameters.DefaultInfoBaseDescription;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckWSConnectionAtClient(Cancel, ExtendedCheck = False)
	
	If IsBlankString(Object.WSURL) Then
		
		NString = NStr("en = 'Specify the Internet application address.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSURL",, Cancel);
		
	ElsIf IsBlankString(Object.WSUserName) Then
		
		NString = NStr("en = 'Specify the user name.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSUserName",, Cancel);
		
	ElsIf IsBlankString(Object.WSPassword) Then
		
		NString = NStr("en = 'Specify the user password.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSPassword",, Cancel);
		
	Else
		
		IsSuggestOpenEventLog = True;
		
		CheckWSConnectionAtServer(Cancel, ExtendedCheck, IsSuggestOpenEventLog);
		
		If Cancel And IsSuggestOpenEventLog Then
			
			QuestionText = NStr("en = 'Error establishing the connection.
								|Do you want to open the event log?'"
			);
			
			SuggestOpenEventLog(QuestionText, EventLogMessageTextEstablishingConnectionToWebService);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SuggestOpenEventLog(QuestionText, Val Event)
	
	Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure("EventLogMessageText", Event);
		
		OpenFormModal("DataProcessor.EventLogMonitor.Form", Filter, ThisForm);
		
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

&AtServer
Procedure FirstWizardPagePictureCompositionItemRepresentation()
	
	IsFirstInfoBase = (WizardRunVariant = "SetupNewDataExchange");
	
	Postfix1 = ?(IsFirstInfoBase, "Active", "Inactive");
	Postfix2 = ?(IsFirstInfoBase, "Inactive", "Active");
	
	FirstInfoBasePageName = "FirstInfoBasePage[Postfix]";
	FirstInfoBasePageName = StrReplace(FirstInfoBasePageName, "[Postfix]", Postfix1);
	
	SecondInfoBasePageName = "SecondInfoBasePage[Postfix]";
	SecondInfoBasePageName = StrReplace(SecondInfoBasePageName, "[Postfix]", Postfix2);
	
	Items.FirstInfoBasePages.CurrentPage = Items[FirstInfoBasePageName];
	Items.SecondInfoBasePages.CurrentPage = Items[SecondInfoBasePageName];
	
EndProcedure

&AtClient
Procedure InfoBaseRunModeOnChange()
	
	CurrentPage = ?(Object.COMInfoBaseOperationMode = 0, Items.FileModePage, Items.ClientServerModePage);
	
	Items.InfobaseRunModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Items.COMUserName.Enabled     = Not Object.COMOSAuthentication;
	Items.COMUserPassword.Enabled = Not Object.COMOSAuthentication;
	
EndProcedure

&AtServer
Procedure WizardRunVariantOnChangeAtServer()
	
	FirstWizardPagePictureCompositionItemRepresentation();
	
	Items.ExchangeSettingsFileSelectionPages.CurrentPage = ?(WizardRunVariant = "ContinueDataExchangeSetup",
																		Items.ExchangeSettingsFileSelectionPage,
																		Items.EmptyExchangeSettingsFileSelectionPage);
	
	
	If WizardRunVariant = "ContinueDataExchangeSetup" Then
		
		WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels";
		
	Else
		
		If ExchangeWithServiceSetup Then
			
			WizardRunMode = "ExchangeOverWebService";
			
		ElsIf UseExchangeMessageTransportCOM Then
			
			WizardRunMode = "ExchangeOverExternalConnection";
			
		Else
			
			WizardRunMode = "ExchangeOverOrdinaryCommunicationChannels";
			
		EndIf;
		
	EndIf;
	
	FillGoToTable();
	
EndProcedure

&AtServer
Procedure WizardRunModeOnChangeAtServer()
	
	PicturePages = New Structure;
	PicturePages.Insert("ExchangeOverExternalConnection",  Items.PictureForExchangeOverExternalConnection);
	PicturePages.Insert("ExchangeOverWebService",          Items.PictureForExchangeOverWebService);
	PicturePages.Insert("ExchangeOverOrdinaryCommunicationChannels", Items.PictureForExchangeOverOrdinaryCommunicationChannels);
	
	Items.WizardRunModeChoicePictures.CurrentPage = PicturePages[WizardRunMode];
	
	TransportParameterPages = New Structure;
	TransportParameterPages.Insert("ExchangeOverExternalConnection",  Items.TransportParameterPageCOM);
	TransportParameterPages.Insert("ExchangeOverOrdinaryCommunicationChannels", Items.TransportParameterPage);
	TransportParameterPages.Insert("ExchangeOverWebService",          Items.TransportParameterPageWS);
	
	ExchangeMessageTransportKinds = New Structure;
	ExchangeMessageTransportKinds.Insert("ExchangeOverExternalConnection",  Enums.ExchangeMessageTransportKinds.COM);
	ExchangeMessageTransportKinds.Insert("ExchangeOverOrdinaryCommunicationChannels", Enums.ExchangeMessageTransportKinds.FILE);
	ExchangeMessageTransportKinds.Insert("ExchangeOverWebService",          Enums.ExchangeMessageTransportKinds.WS);
	
	Items.TransportParameterPages.CurrentPage = TransportParameterPages[WizardRunMode];
	
	Object.ExchangeMessageTransportKind = ExchangeMessageTransportKinds[WizardRunMode];
	
	FillGoToTable();
	
EndProcedure

&AtClient
Procedure SelectExchangeSettingsFile(Interactively)
	
	Var SelectedFileName;
	Var TempStorageAddress;
	
	DefaultFileName = ?(IsBlankString(Object.DataExchangeSettingsFileNameToImport), SettingsFileNameForTarget, Object.DataExchangeSettingsFileNameToImport);
	
	If PutFile(TempStorageAddress, DefaultFileName, SelectedFileName, Interactively, UUID) Then
		
		Cancel = False;
		
		// Calling server
		ImportWizardParameters(Cancel, TempStorageAddress);
		
		If Cancel Then
			DoMessageBox(NStr("en = 'Invalid data exchange settings file is specified. Specify the correct file.'"));
			Return;
		EndIf;
			
		If Interactively Then
			
			Object.DataExchangeSettingsFileNameToImport = SelectedFileName;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function ExternalConnectionParameterStructure(ConnectionType = "ExternalConnection")
	
	Result = Undefined;
	
	If ConnectionType = "ExternalConnection" Then
		
		Result = CommonUseClientServer.ExternalConnectionParameterStructure();
		
		Result.InfoBaseOperationMode        = Object.COMInfoBaseOperationMode;
		Result.InfoBaseDirectory            = Object.COMInfoBaseDirectory;
		Result.PlatformServerName           = Object.COMPlatformServerName;
		Result.InfoBaseNameAtPlatformServer = Object.COMInfoBaseNameAtPlatformServer;
		Result.OSAuthentication             = Object.COMOSAuthentication;
		Result.UserName                     = Object.COMUserName;
		Result.UserPassword                 = Object.COMUserPassword;
		
		Result.Insert("ConnectionType", ConnectionType);
		Result.Insert("CorrespondentVersion_2_0_1_6", Object.CorrespondentVersion_2_0_1_6);
		
	ElsIf ConnectionType = "WebService" Then
		
		Result = New Structure;
		Result.Insert("WSURL");
		Result.Insert("WSUserName");
		Result.Insert("WSPassword");
		
		FillPropertyValues(Result, Object);
		
		Result.Insert("ConnectionType", ConnectionType);
		Result.Insert("CorrespondentVersion_2_0_1_6", Object.CorrespondentVersion_2_0_1_6);
		
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure CheckAttributeFillingOnForm(Cancel, FormToCheckName, FormParameters, FormAttributeName)
	
	SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[FormName]";
	SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	SettingsFormName = StrReplace(SettingsFormName, "[FormName]", FormToCheckName);
	
	SettingsForm = GetForm(SettingsFormName, FormParameters, ThisForm);
	
	If Not SettingsForm.CheckFilling() Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Specify mandatory settings.'"),,, FormAttributeName, Cancel);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorToEventLog(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtClient
Procedure CorrespondentInfoBaseRegistrationRestrictionSetup(ConnectionType)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.CorrespondentInfoBaseNodeSettingsForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
	FormParameters.Insert("NodeFilterStructure",      CorrespondentInfoBaseNodeFilterSetup);
	
	OpeningResult = OpenFormModal(NodeSettingsFormName, FormParameters, ThisForm);
	
	If OpeningResult <> Undefined Then
		
		For Each FilterSettings In CorrespondentInfoBaseNodeFilterSetup Do
			
			CorrespondentInfoBaseNodeFilterSetup[FilterSettings.Key] = OpeningResult[FilterSettings.Key];
			
		EndDo;
		
		// Calling server
		GetCorrespondentInfoBaseDataTransferRestrictionDetails(CorrespondentInfoBaseNodeFilterSetup);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfoBaseDefaultValueSetup(ConnectionType)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.CorrespondentInfoBaseDefaultValueSetupForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
	FormParameters.Insert("NodeDefaultValues",   CorrespondentInfoBaseNodeDefaultValues);
	
	OpeningResult = OpenFormModal(NodeSettingsFormName, FormParameters, ThisForm);
	
	If OpeningResult <> Undefined Then
		
		For Each FilterSettings In CorrespondentInfoBaseNodeDefaultValues Do
			
			CorrespondentInfoBaseNodeDefaultValues[FilterSettings.Key] = OpeningResult[FilterSettings.Key];
			
		EndDo;
		
		// Calling server
		GetCorrespondentInfoBaseDefaultValueDetails(CorrespondentInfoBaseNodeDefaultValues);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExchangeOverExternalConnectionSetup()
	
	If ExecuteInteractiveDataExchangeNow Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfoBaseNode",                 Object.InfoBaseNode);
		FormParameters.Insert("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
		FormParameters.Insert("ExecuteMappingOnOpen",         False);
		
		OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExchangeOverWebServiceSetup()
	
	If ExecuteDataExchangeAutomatically Then
		
		FinishExchangeOverWebServiceSetupAtServer(Object.InfoBaseNode, PredefinedDataExchangeSchedule, DataExchangeExecutionSchedule);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure FinishExchangeOverWebServiceSetupAtServer(InfoBaseNode, PredefinedSchedule, Schedule)
	
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
		
		Catalogs.DataExchangeScenarios.CreateScenario(InfoBaseNode, ScenarioSchedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishFirstExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel)
	
	ClearMessages();
	
	If Not Object.IsDistributedInfoBaseSetup
		And IsBlankString(Object.DataExchangeSettingsFileName) Then
		
		NString = NStr("en = 'Save the settings file for the target infobase.'");
		
		CommonUseClientServer.MessageToUser(NString,,"Object.DataExchangeSettingsFileName",, Cancel);
		Return;
	EndIf;
	
	If Object.IsDistributedInfoBaseSetup Then
		
		If CreateInitialImageNow Then
			
			FormParameters = New Structure("Key, Node", Object.InfoBaseNode, Object.InfoBaseNode);
			
			OpenFormModal(InitialImageCreationFormName, FormParameters);
			
		EndIf;
		
	Else
		
		If ExecuteDataExchangeNow Then
			
			DataExchangeInitializationAtClient(Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishSecondExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel)
	
	Status(NStr("en = 'Creating data exchange settings.'"));
	
	SetupNewDataExchangeAtServer(Cancel, NodeFilterStructure, NodeDefaultValues);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error creating data exchange settings.'"));
		Return;
	EndIf;
	
	OpenMappingWizard = Not Object.IsDistributedInfoBaseSetup And Not Object.IsStandardExchangeSetup;
	
	If OpenMappingWizard Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfoBaseNode",                 Object.InfoBaseNode);
		FormParameters.Insert("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
		FormParameters.Insert("ExecuteMappingOnOpen",         False);
		
		OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Function StartJobManager()
	
	Return (	WizardRunMode = "ExchangeOverExternalConnection"
			Or WizardRunMode = "ExchangeOverWebService")
		And FileInfoBase
		And ExecuteDataExchangeAutomatically
	;
EndFunction

&AtServerNoContext
Procedure EnableUseEventLog(Val EventLogMessageText, DoMessageBox)
	
	Try
		CommonUse.EnableUseEventLog();
	Except
		DoMessageBox = NStr("en = 'Failed to enable the event log: %1'");
		DoMessageBox = StringFunctionsClientServer.SubstituteParametersInString(DoMessageBox, BriefErrorDescription(ErrorInfo()));
		WriteLogEvent(EventLogMessageText, EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
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
		DoMessageBox(NStr("en = 'This data cannot be mapped.'"));
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
	
	FormParameters.Insert("InfoBaseNode",              Object.InfoBaseNode);
	FormParameters.Insert("ExchangeMessageFileName",   Object.ExchangeMessageFileName);
	
	FormParameters.Insert("PerformDataImport",         False);
	
	OpenForm("DataProcessor.InfoBaseObjectMapping.Form", FormParameters, ThisForm, CurrentData.Key);
	
EndProcedure

&AtClient
Procedure ExpandStatisticsTree(RowKey = "")
	
	ItemCollection = StatisticsTree.GetItems();
	
	For Each TreeRow In ItemCollection Do
		
		Items.StatisticsTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Determining value tree cursor position
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsTree.GetItems(), RowKey, False);
		
		Items.StatisticsTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateMappingStatisticsDataAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.Statistics.FindRows(New Structure("Key", NotificationParameters.UniqueKey));
	
	FillPropertyValues(TableRows[0], NotificationParameters, "DataImportedSuccessfully");
	
	RowKeys = New Array;
	RowKeys.Add(NotificationParameters.UniqueKey);
	
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
		
		FillPropertyValues(Object, InteractiveDataExchangeWizard, "IncomingMessageNumber");
		
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
		
		RowIndex = Object.Statistics.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServer
Procedure GetStatisticsTree(Statistics)
	
	TreeItemCollection = StatisticsTree.GetItems();
	TreeItemCollection.Clear();
	
	CommonUse.FillFormDataTreeItemCollection(TreeItemCollection,
		DataExchangeServer.GetStatisticsTree(Statistics)
	);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Constant values

&AtClientAtServerNoContext
Function LabelNextFILE()
	
	Return NStr("en = 'Click Next to set up the exchange via local or network directory.'");
	
EndFunction

&AtClientAtServerNoContext
Function NextLabelFTP()
	
	Return NStr("en = 'Click Next to set up the exchange via FTP site.'");
	
EndFunction

&AtClientAtServerNoContext
Function NextLabelEMAIL()
	
	Return NStr("en = 'Click Next to set up the exchange via Email.'");
	
EndFunction

&AtClientAtServerNoContext
Function NextLabelSettings()
	
	Return NStr("en = 'Click Next to set up additional data exchange parameters.'");
	
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
	Schedule.DaysRepeatPeriod  = 1;     // Every day
	
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
	Schedule.DaysRepeatPeriod  = 1;     // Every day
	
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
	Schedule.DaysRepeatPeriod  = 1;     // Every Day
	
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
	Schedule.DaysRepeatPeriod = 1;                      // Every day
	
	Return Schedule;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - step change event handlers

&AtClient
Function Attachable_WizardPageSetTransportParametersFILE_OnGoNext(Cancel)
	
	WizardPageSetTransportParametersFILE_OnGoNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersFTP_OnGoNext(Cancel)
	
	WizardPageSetTransportParametersFTP_OnGoNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersEMAIL_OnGoNext(Cancel)
	
	WizardPageSetTransportParametersEMAIL_OnGoNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageWizardRunModeChoice_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportCOM Then
		
		Object.UseTransportParametersCOM = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersFILE_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportFILE Then
		
		Object.UseTransportParametersFILE = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageSetTransportParametersFTP_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportFTP Then
		
		Object.UseTransportParametersFTP  = False;
		
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
	
	If IsBlankString(Object.ThisInfoBaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the current infobase.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfoBaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.SecondInfoBaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the second infobase.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfoBaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.TargetInfoBasePrefix) Then
		
		NString = NStr("en = 'Specify the correspondent infobase prefix. You can use the existing prefix or a create a new one.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfoBasePrefix",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfoBasePrefix) = TrimAll(Object.TargetInfoBasePrefix) Then
		
		NString = NStr("en = 'Infobase prefixes must be different.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfoBasePrefix",, Cancel);
		
	EndIf;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether data migration restriction settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeFilterStructure", NodeFilterStructure);
		
		CheckAttributeFillingOnForm(Cancel, "NodeSettingsForm", FormParameters, "DataTransferRestrictionDetails");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether additional settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, "DefaultValueSetupForm", FormParameters, "DefaultValueDetails");
		
	EndIf;
	
	WizardPageParameterSetup_OnGoNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageFirstInfoBaseExternalConnectionParameterSetup_OnGoNext(Cancel)
	
	If IsBlankString(Object.ThisInfoBaseDescription) Then
		
		NString = NStr("en = 'Specify the infobase name.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfoBaseDescription",, Cancel);
		Return Undefined;
	EndIf;
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether data migration restriction settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeFilterStructure", NodeFilterStructure);
		
		CheckAttributeFillingOnForm(Cancel, "NodeSettingsForm", FormParameters, "DataTransferRestrictionDetails");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether additional settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, "DefaultValueSetupForm", FormParameters, "DefaultValueDetails");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageDataExchangeParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext Then
		
		// Getting node settings form context description
		
		FormParameters = New Structure;
		FormParameters.Insert("GetContextDescription");
		FormParameters.Insert("Settings", NodesSetupFormContext);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.NodesSetupForm";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisForm);
		
		DataExportSettingsDescription = SettingsForm.ContextDetails;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageDataExchangeParameterSetup_OnGoNext(Cancel)
	
	CheckJobSettingsForFirstInfoBase(Cancel, "WebService");
	
EndFunction

&AtClient
Function Attachable_WizardPageSecondInfoBaseExternalConnectionParameterSetup_OnGoNext(Cancel)
	
	CheckJobSettingsForSecondInfoBase(Cancel, "ExternalConnection");
	
EndFunction

&AtClient
Function Attachable_WizardPageSecondSetupStageParameterSetup_OnGoNext(Cancel)
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether data migration restriction settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeFilterStructure", NodeFilterStructure);
		
		CheckAttributeFillingOnForm(Cancel, "NodeSettingsForm", FormParameters, "DataTransferRestrictionDetails");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether additional settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, "DefaultValueSetupForm", FormParameters, "DefaultValueDetails");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageStart_OnGoNext(Cancel)
	
	If Not Object.IsDistributedInfoBaseSetup Then
		
		If IsBlankString(Object.DataExchangeSettingsFileNameToImport) Then
			
			NString = NStr("en = 'Select the data exchange settings file.'");
			CommonUseClientServer.MessageToUser(NString,,"Object.DataExchangeSettingsFileNameToImport",, Cancel);
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	// Displaying the error message if the user proceed to the additional parameter page
	// but no transport kind is set up.
	If Not (Object.UseTransportParametersEMAIL
			Or Object.UseTransportParametersFILE
			Or Object.UseTransportParametersFTP ) Then
		
		NString = NStr("en = 'No data exchange kind is set up.
						|Set up at least one exchange data kind.'");
		
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		
		Return Undefined;
	EndIf;
	
	WizardPageParameterSetup_OnOpenAtServer(Cancel, SkipPage, IsGoNext);
	
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
							Object.SourceInfoBasePrefix,
							Object.TargetInfoBasePrefix
		);
		
	Else
		
		// Data exchange setup result presentation
		MessageString = NStr("en = '%1%2%3The current infobase prefix is %4'");
		
		ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							MessageTransportResultPresentation(),
							NodeFiltersResultPresentation(),
							DefaultNodeValueResultPresentation(),
							Object.SourceInfoBasePrefix
		);
		
	EndIf;
	
	// Displaying comment label
	Items.MappingWizardOpenedInfoLabelGroup.Visible =
	(WizardRunVariant = "ContinueDataExchangeSetup" 
	And Not Object.IsDistributedInfoBaseSetup
	And Not Object.IsStandardExchangeSetup
	);
	
EndFunction

&AtClient
Function Attachable_WizardPageExchangeSetupResults_OnOpen_ExternalConnection(Cancel, SkipPage, IsGoNext)
	
	// Data exchange setup result presentation
	If ExchangeWithServiceSetup Then
		
		MessageString = NStr("en = '%1
		|Settings for the current information base:
		|========================================================
		|%2%3Infobase prefix: %4
		|
		|Settings for the service application:
		|========================================================
		|%5%6Application prefix: %7'");
		
	Else
		
		MessageString = NStr("en = '%1
		|Data exchange settings for the current information base:
		|========================================================
		|%2%3Infobase prefix: %4
		|
		|Data exchange settings for the second infobase:
		|========================================================
		|%5%6Infobase prefix: %7'");
		
	EndIf;
	
	ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
						MessageTransportResultPresentation(),
						NodeFiltersResultPresentation(),
						DefaultNodeValueResultPresentation(),
						Object.SourceInfoBasePrefix,
						CorrespondentInfoBaseNodeFilterResultPresentation(),
						CorrespondentInfoBaseNodeDefaultValueResultPresentation(),
						Object.TargetInfoBasePrefix
	);
	
	// Displaying comment label
	Items.MappingWizardOpenedInfoLabelGroup.Visible = False;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessing(Cancel, GoToNext)
	
	WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessingAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataExchangeSettingsCreationOverExternalConnection_LongActionProcessing(Cancel, GoToNext)
	
	// Creating data exchange via the external connection setup 
	SetupNewDataExchangeOverExternalConnectionAtServer(Cancel, CorrespondentInfoBaseNodeFilterSetup, CorrespondentInfoBaseNodeDefaultValues);
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessing(Cancel, GoToNext)
	
	WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessingAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForConnectionViaWebServiceCheck_LongActionProcessing(Cancel, GoToNext)
	
	CheckWSConnectionAtClient(Cancel, True);
	
EndFunction



&AtClient
Function Attachable_WizardPageWaitForDataAnalysisExchangeSettingsCreation_LongActionProcessing(Cancel, GoToNext)
	
	// Creating data exchange settings:
	//  - creating nodes in this infobase and in the correspondent infobase with data
	//    export settings.
	//  - registering catalogs to be exported in this infobase and in the correspondent
	//    infobase.
	
	LongAction = False;
	LongActionFinished = False;
	LongActionID = "";
	
	SetupNewDataExchangeAtServerOverWebService(Cancel);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during creating data exchange settings.
					|Use the event log to solve the problems.'")
		);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataAnalysisExchangeSettingsCreationLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction



&AtClient
Function Attachable_WizardPageWaitForDataAnalysisGetMessage_LongActionProcessing(Cancel, GoToNext)
	
	LongAction = False;
	LongActionFinished = False;
	MessageFileIDInService = "";
	LongActionID = "";
	
	DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfoBaseOverWebService(
		Cancel,
		Object.InfoBaseNode,
		MessageFileIDInService,
		LongAction,
		LongActionID
	);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during the data analysis.
					|Use the event log to solve the problems.'")
		);
		
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
Function Attachable_WizardPageWaitForDataAnalysisGetMessageLongActionEnd_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfoBaseOverWebServiceFinishLongAction(
			Cancel,
			Object.InfoBaseNode,
			MessageFileIDInService
		);
		
		If Cancel Then
			
			DoMessageBox(NStr("en = 'Errors occurred during the data analysis.
						|Use the event log to solve the problems.'")
			);
			
		Else
			
			Object.TempExchangeMessageDirectory = DataStructure.TempExchangeMessageDirectory;
			Object.ExchangeMessageFileName      = DataStructure.ExchangeMessageFileName;
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataAnalysisAutomaticMapping_LongActionProcessing(Cancel, GoToNext)
	
	WizardPageWaitForAutomaticMappingDataAnalysis_LongActionProcessing(Cancel);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during the data analysis.'"));
		
	EndIf;
	
EndFunction

&AtServer
Procedure WizardPageWaitForAutomaticMappingDataAnalysis_LongActionProcessing(Cancel)
	
	InteractiveDataExchangeWizard = DataProcessors.InteractiveDataExchangeWizard.Create();
	
	FillPropertyValues(InteractiveDataExchangeWizard, Object,, "Statistics");
	
	InteractiveDataExchangeWizard.Statistics.Load(Object.Statistics.Unload());
	
	InteractiveDataExchangeWizard.ExecuteExchangeMessagAnalysis(Cancel, False);
	
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
		
		FillPropertyValues(Object, InteractiveDataExchangeWizard, "IncomingMessageNumber");
		
		Object.Statistics.Load(StatisticsTable);
		
		GetStatisticsTree(StatisticsTable);
		
		SetAdditionalInfoGroupVisible();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAdditionalInfoGroupVisible()
	
	// Making the group with additional information visible if statistic data table
	// contains one or more rows with mapping less than 100%.
	RowArray = Object.Statistics.FindRows(New Structure("PictureIndex", 1));
	
	AllDataMapped = (RowArray.Count() = 0);
	
	Items.DataMappingStatePages.CurrentPage = ?(AllDataMapped,
				Items.MappingStateAllDataMapped,
				Items.MappingStateHasUnmappedData
	);
	
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
		Buttons.Add(DialogReturnCode.No, "Cancel");
		
		Message = NStr("en = 'Unmapped data has been found. This can lead to
							 |duplication of catalog items.
							 |Do you want to continue?'"
		);
		
		Response = DoQueryBox(Message, Buttons,, DialogReturnCode.No);
		
		If Response = DialogReturnCode.No Then
			
			Cancel = True;
			
		EndIf;
		
	EndIf;
	
EndFunction



&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationImport_LongActionProcessing(Cancel, GoToNext)
	
	DataExchangeServer.ImportInfoBaseNodeViaFile(Cancel, Object.InfoBaseNode, Object.ExchangeMessageFileName);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during catalog synchronization.
					|Use the event log to solve problems.'")
		);
		
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
											Object.InfoBaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate
	);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during catalog synchronization.
					|Use the event log to solve problems.'")
		);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate
	)
	
	ActionStartDate = CurrentSessionDate();
	
	// Executing exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											False,
											True,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True
	);
	
EndProcedure

&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationExportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForCatalogSynchronizationExportLongActionEnd_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataExchangeServer.CommitDataExportExecutionInLongActionMode(Object.InfoBaseNode, ActionStartDate);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForSaveSettings_LongActionProcessing(Cancel, GoToNext)
	
	// Updating data exchange settings in this infobase and in the correspondent infobase:
	//  - updating default values on the exchange plan nodes.
	//  - registering all data to be exported except catalogs and CCT in this infobase and
	//    in the correspondent infobase.
	
	LongAction = False;
	LongActionFinished = False;
	LongActionID = "";
	
	UpdateDataExchangeSettings(Cancel);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during settings saving.
					|Use the event log to solve the problems.'")
		);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForSaveSettingsLongAction_LongActionProcessing(Cancel, GoToNext)
	
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
											Object.InfoBaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate
	);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during data synchronization.
					|Use the event log to solve the problems.'")
		);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure WizardPageWaitForDataSynchronizationImport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate
	)
	
	ActionStartDate = CurrentSessionDate();
	
	// Executing exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											True,
											False,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True
	);
	
EndProcedure

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationImportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationImportLongActionEnd_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataExchangeServer.ExecuteDataExchangeForInfoBaseNodeFinishLongAction(
										Cancel,
										Object.InfoBaseNode,
										MessageFileIDInService,
										ActionStartDate
		);
		
		If Cancel Then
			
			DoMessageBox(NStr("en = 'Errors occurred during data synchronization.
						|Use the event log to solve the problems.'")
			);
			
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
											Object.InfoBaseNode,
											LongAction,
											LongActionID,
											MessageFileIDInService,
											ActionStartDate
	);
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Errors occurred during data synchronization.
					|Use the event log to solve the problems.'")
		);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure WizardPageWaitForDataSynchronizationExport_LongActionProcessing(
											Cancel,
											InfoBaseNode,
											LongAction,
											ActionID,
											FileID,
											ActionStartDate
	)
	
	ActionStartDate = CurrentSessionDate();
	
	// run execution exchange
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(
											Cancel,
											InfoBaseNode,
											False,
											True,
											Enums.ExchangeMessageTransportKinds.WS,
											LongAction,
											ActionID,
											FileID,
											True
	);
	
EndProcedure

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationExportLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongActionIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageWaitForDataSynchronizationExportLongActionEnd_LongActionProcessing(Cancel, GoToNext)
	
	If LongActionFinished Then
		
		DataExchangeServer.CommitDataExportExecutionInLongActionMode(Object.InfoBaseNode, ActionStartDate);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageAddingDocumentDataToAccountingRecordsSettings_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext Then
		
		ConnectionType = "WebService";
		
		CheckAccountingSettingsAtServer(
										False,
										ConnectionType,
										Object.ExchangePlanName,
										ExternalConnectionParameterStructure(ConnectionType)
		);
		
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WizardPageAddingDocumentDataToAccountingRecordsSettings_OnGoNext(Cancel)
	
	ConnectionType = "WebService";
	
	CheckAddingDocumentDataToAccountingRecordsForAccountingSettings(Cancel, ConnectionType);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	CheckAccountingSettingsAtServer(
									Cancel,
									ConnectionType,
									Object.ExchangePlanName,
									ExternalConnectionParameterStructure(ConnectionType)
	);
	
EndFunction

&AtClient
Function Attachable_WizardPageDataExchangeCreatedSuccessfully_OnOpen(Cancel, SkipPage, IsGoNext)
	
	PredefinedDataExchangeScheduleOnValueChange();
	
	ExecuteDataExchangeAutomaticallyOnValueChange();
	
EndFunction



&AtClient
Procedure CheckAddingDocumentDataToAccountingRecordsForAccountingSettings(Cancel, ConnectionType)
	
	If NodeDefaultValuesAvailable Then
		
		// Checking whether additional settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("NodeDefaultValues", NodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, "DefaultValueSetupForm", FormParameters, "DefaultValueDetails");
		
	EndIf;
	
	If CorrespondentInfoBaseNodeDefaultValuesAvailable Then
		
		// Checking whether additional settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("NodeDefaultValues", CorrespondentInfoBaseNodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, "CorrespondentInfoBaseDefaultValueSetupForm", FormParameters, "CorrespondentInfoBaseDefaultValueDetails");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckAccountingSettingsAtServer(
									Cancel,
									Val ConnectionType,
									Val ExchangePlanName,
									ConnectionParameters
	)
	
	ErrorMessage = "";
	CorrespondentErrorMessage = "";
	
	NodeCode = CommonUse.GetAttributeValue(Object.InfoBaseNode, "Code");
	
	AccountingSettingsAreSet = DataExchangeServer.SystemAccountingSettingsAreSet(ExchangePlanName, NodeCode, ErrorMessage);
	
	If ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Object.CorrespondentVersion_2_0_1_6 Then
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
		Else
			WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
		EndIf;
		
		If WSProxy = Undefined Then
			DataExchangeServer.ReportError(ErrorMessageString, Cancel);
			Return;
		EndIf;
		
		NodeCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(Object.ExchangePlanName);
		
		// Getting correspondent infobase parameters
		If Object.CorrespondentVersion_2_0_1_6 Then
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetIBParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
		Else
			TargetParameters = ValueFromStringInternal(WSProxy.GetIBParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
		EndIf;
		
		CorrespondentAccountingSettingsAreSet = TargetParameters.AccountingSettingsAreSet;
		
	ElsIf ConnectionType = "ExternalConnection" Then
		
		ErrorMessageString = "";
		
		ExternalConnection = DataExchangeServer.EstablishExternalConnection(ConnectionParameters, ErrorMessageString);
		
		If ExternalConnection = Undefined Then
			DataExchangeServer.ReportError(ErrorMessageString, Cancel);
			Return;
		EndIf;
		
		NodeCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(Object.ExchangePlanName);
		
		// Getting correspondent infobase parameters
		If Object.CorrespondentVersion_2_0_1_6 Then
			TargetParameters = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetInfoBaseParameters_2_0_1_6(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
		Else
			TargetParameters = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetInfoBaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
		EndIf;
		
		CorrespondentAccountingSettingsAreSet = TargetParameters.AccountingSettingsAreSet;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If Not AccountingSettingsAreSet Then
		
		If IsBlankString(ErrorMessage) Then
			ErrorMessage = NStr("en = 'Accounting parameters for the current application are not set.'");
		EndIf;
		
		CommonUseClientServer.MessageToUser(ErrorMessage,, "AccountingSettingsCommentLabel",, Cancel);
		
	EndIf;
	
	If Not CorrespondentAccountingSettingsAreSet Then
		
		If IsBlankString(CorrespondentErrorMessage) Then
			CorrespondentErrorMessage = NStr("en = 'Accounting parameters for the cloud application are not set.'");
		EndIf;
		
		CommonUseClientServer.MessageToUser(CorrespondentErrorMessage,, "CorrespondentAccountingSettingsCommentLabel",, Cancel);
		
	EndIf;
	
	Items.AccountingSettings.Visible = Not AccountingSettingsAreSet;
	Items.CorrespondentAccountingSettings.Visible = Not CorrespondentAccountingSettingsAreSet;
	
EndProcedure

&AtClient
Procedure CheckJobSettingsForFirstInfoBase(Cancel, ConnectionType = "WebService")
	
	If IsBlankString(Object.ThisInfoBaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the current application.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfoBaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.SecondInfoBaseDescription) Then
		
		NString = NStr("en = 'Specify the name of the cloud application.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfoBaseDescription",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfoBasePrefix) = TrimAll(Object.TargetInfoBasePrefix) Then
		
		NString = NStr("en = 'The infobase prefixes must be different.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SourceInfoBasePrefix",, Cancel);
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfoBasePrefix",, Cancel);
		
		Items.SourceInfoBasePrefixExchangeWithService.Visible = True;
		Items.SourceInfoBasePrefixExchangeWithService.Enabled = True;
		Items.TargetInfoBasePrefixExchangeWithService.Visible = True;
		
		Items.SourceInfoBasePrefixExchangeOverWebService.Visible = True;
		Items.SourceInfoBasePrefixExchangeOverWebService.Enabled = True;
		Items.TargetInfoBasePrefixExchangeOverWebService.Visible = True;
		Items.TargetInfoBasePrefixExchangeOverWebService.Enabled = True;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If NodeFilterSettingsAvailable Then
		
		// Checking whether form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("ConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("Settings", NodesSetupFormContext);
		FormParameters.Insert("CheckFillinging");
		
		CheckAttributeFillingOnForm(Cancel, "NodesSetupForm", FormParameters, "DataExportSettingsDescription");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckJobSettingsForSecondInfoBase(Cancel, ConnectionType)
	
	If IsBlankString(Object.SecondInfoBaseDescription) Then
		
		NString = NStr("en = 'Specify the infobase name.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfoBaseDescription",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfoBasePrefix) = TrimAll(Object.TargetInfoBasePrefix) Then
		
		NString = NStr("en = 'The infobase prefixes must be different.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfoBasePrefix",, Cancel);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If CorrespondentInfoBaseNodeFilterSettingsAvailable Then
		
		// Checking whether data migration restriction settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("NodeFilterStructure", CorrespondentInfoBaseNodeFilterSetup);
		
		CheckAttributeFillingOnForm(Cancel, "CorrespondentInfoBaseNodeSettingsForm", FormParameters, "CorrespondentInfoBaseDataTransferRestrictionDetails");
		
	EndIf;
	
	If CorrespondentInfoBaseNodeDefaultValuesAvailable Then
		
		// Checking whether additional settings form attributes are filled
		FormParameters = New Structure;
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("NodeDefaultValues", CorrespondentInfoBaseNodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, "CorrespondentInfoBaseDefaultValueSetupForm", FormParameters, "CorrespondentInfoBaseDefaultValueDetails");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageSetTransportParametersFILE_OnGoNextAtServer(Cancel)
	
	If Object.UseTransportParametersFILE Then
		
		DataExchangeServer.CheckExchangeMessageTransportDataProcessorConnection(Cancel, Object, Enums.ExchangeMessageTransportKinds.FILE);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageSetTransportParametersFTP_OnGoNextAtServer(Cancel)
	
	If Object.UseTransportParametersFTP  Then
		
		DataExchangeServer.CheckExchangeMessageTransportDataProcessorConnection(Cancel, Object, Enums.ExchangeMessageTransportKinds.FTP);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageSetTransportParametersEMAIL_OnGoNextAtServer(Cancel)
	
	If Object.UseTransportParametersEMAIL Then
		
		DataExchangeServer.CheckExchangeMessageTransportDataProcessorConnection(Cancel, Object, Enums.ExchangeMessageTransportKinds.EMAIL);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageParameterSetup_OnGoNextAtServer(Cancel)
	
	If Not ExchangePlans[Object.ExchangePlanName].FindByCode(DataExchangeServer.ExchangePlanNodeCodeString(Object.TargetInfoBasePrefix)).IsEmpty() Then
		
		NString = NStr("en = 'The prefix of the second infobase is not unique.
			|The system has the data exchange for the infobase with the specified prefix.
			|Change the prefix value or use the existing exchange.'");
		
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfoBasePrefix",, Cancel);
		
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
	
	If Object.UseTransportParametersFTP  Then
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
	
	// Setting default exchange message transport kind according to transport kinds
	// selected by user.
	If Object.UseTransportParametersFILE Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
		
	ElsIf Object.UseTransportParametersFTP  Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP;
		
	ElsIf Object.UseTransportParametersEMAIL Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.EMAIL;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessingAtServer(Cancel)
	
	// Creating data exchange setup
	SetupNewDataExchangeAtServer(Cancel, NodeFilterStructure, NodeDefaultValues);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Creating a settings file for the correspondent infobase
	If Object.IsDistributedInfoBaseSetup Then
		
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
	
EndProcedure

&AtServer
Procedure WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessingAtServer(Cancel)
	
	ErrorAttachingAddIn = False;
	ErrorMessageString = "";
	
	ExternalConnection = DataExchangeServer.EstablishExternalConnection(Object, ErrorMessageString, ErrorAttachingAddIn);
	
	If ExternalConnection = Undefined Then
		CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
		
		If ErrorAttachingAddIn And FileInfoBase Then
			Items.FixExternalConnectionErrors.Visible = True;
		EndIf;
		Return;
	EndIf;
	
	CorrespondentVersions = DataExchangeServer.CorrespondentVersionsViaExternalConnection(ExternalConnection);
	
	Object.CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	Try
		ExchangePlanExists = ExternalConnection.DataExchangeExternalConnection.ExchangePlanExists(Object.ExchangePlanName);
	Except
		ExchangePlanExists = False;
	EndTry;
	
	If Not ExchangePlanExists Then
		
		Message = NStr("en = 'The second infobase does not provide the exchange with the current infobase.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return;
		
	EndIf;
	
	If Lower(InfoBaseConnectionString()) = Lower(ExternalConnection.InfoBaseConnectionString()) Then
		
		Message = NStr("en = 'Connection settings point to the current infobase.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return;
		
	EndIf;
	
	Object.TargetInfoBasePrefix      = ExternalConnection.GetFunctionalOption("InfoBasePrefix");
	Object.TargetInfoBasePrefixIsSet = ValueIsFilled(Object.TargetInfoBasePrefix);
	
	If Not Object.TargetInfoBasePrefixIsSet Then
		Object.TargetInfoBasePrefix = ExternalConnection.DataExchangeExternalConnection.DefaultInfoBasePrefix();
	EndIf;
	
	Items.TargetInfoBasePrefix.Visible = Not Object.TargetInfoBasePrefixIsSet;
	
	// Checking whether exchange with the correspondent infobase exists
	CheckWhetherDataExchangeWithSecondBaseExists(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	Object.SecondInfoBaseDescription = ExternalConnection.DataExchangeExternalConnection.PredefinedExchangePlanNodeDescription(Object.ExchangePlanName);
	SecondInfoBaseDescriptionSet = Not IsBlankString(Object.SecondInfoBaseDescription);
	
	Items.SecondInfoBaseDescription2.ReadOnly = SecondInfoBaseDescriptionSet;
	
	If Not SecondInfoBaseDescriptionSet Then
		
		Object.SecondInfoBaseDescription = ExternalConnection.DataExchangeCached.ThisInfoBaseName();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckWhetherDataExchangeWithSecondBaseExists(Cancel)
	NodeCode = ?(IsBlankString(Object.CorrespondentNodeCode),
					DataExchangeServer.ExchangePlanNodeCodeString(Object.TargetInfoBasePrefix),
					Object.CorrespondentNodeCode
	);
	
	If Not IsBlankString(NodeCode)
		And Not ExchangePlans[Object.ExchangePlanName].FindByCode(NodeCode).IsEmpty() Then
		
		Message = NStr("en = 'The data exchange is already configured in the system. Use the existing exchange.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Wizard step change initialization

&AtServer
Procedure FirstExchangeSetupStageGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WizardPageStart",                            "", "NavigationPageStart");
	GoToTableNewRow(2, "WizardPageWizardRunModeChoice",              "", "NavigationPageContinuation", "",,"WizardPageWizardRunModeChoice_OnOpen");
	GoToTableNewRow(3, "WizardPageSetTransportParametersFILE",       "", "NavigationPageContinuation", "WizardPageSetTransportParametersFILE_OnGoNext",,"WizardPageSetTransportParametersFILE_OnOpen");
	GoToTableNewRow(4, "WizardPageSetTransportParametersFTP",        "", "NavigationPageContinuation", "WizardPageSetTransportParametersFTP_OnGoNext",,"WizardPageSetParametersFTP_OnOpenTransport");
	GoToTableNewRow(5, "WizardPageSetTransportParametersEMAIL",      "", "NavigationPageContinuation", "WizardPageSetTransportParametersEMAIL_OnGoNext",,"WizardPageSetParametersEMAIL_OnOpenTransport");
	GoToTableNewRow(6, "WizardPageParameterSetup",                   "", "NavigationPageContinuation", "WizardPageParameterSetup_OnGoNext",, "WizardPageParameterSetup_OnOpen");
	GoToTableNewRow(7, "WizardPageExchangeSetupResults",             "", "NavigationPageContinuation",,,"WizardPageExchangeSetupResults_OnOpen");
	GoToTableNewRow(8, "WizardPageWaitForDataExchangeSettingsCreation", "", "NavigationPageWait",,,, True, "WizardPageWaitForDataExchangeSettingsCreation_LongActionProcessing");
	GoToTableNewRow(9, "WizardPageEndWithSettingsExport",            "", "NavigationPageEnd");
	
EndProcedure

&AtServer
Procedure SecondExchangeSetupStageGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WizardPageStart",                        "", "NavigationPageStart", "WizardPageStart_OnGoNext");
	GoToTableNewRow(2, "WizardPageSetTransportParametersFILE",   "", "NavigationPageContinuation", "WizardPageSetTransportParametersFILE_OnGoNext",,"WizardPageSetTransportParametersFILE_OnOpen");
	GoToTableNewRow(3, "WizardPageSetTransportParametersFTP",    "", "NavigationPageContinuation", "WizardPageSetTransportParametersFTP_OnGoNext",,"WizardPageSetTransportParametersFTP_OnOpen");
	GoToTableNewRow(4, "WizardPageSetTransportParametersEMAIL",  "", "NavigationPageContinuation", "WizardPageSetTransportParametersEMAIL_OnGoNext",,"WizardPageSetTransportParametersEMAIL_OnOpen");
	GoToTableNewRow(5, "WizardPageSecondSetupStageParameterSetup", "", "NavigationPageContinuation", "Attachable_WizardPageSecondSetupStageParameterSetup_OnGoNext",, "WizardPageParameterSetup_OnOpen");
	GoToTableNewRow(6, "WizardPageExchangeSetupResults",          "", "NavigationPageEnd",,,"WizardPageExchangeSetupResults_OnOpen");
	
EndProcedure

&AtServer
Procedure DataExchangeOverExternalConnectionSettingsGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WizardPageStart",                                             "", "NavigationPageStart");
	GoToTableNewRow(2, "WizardPageWizardRunModeChoice",                               "", "NavigationPageContinuation");
	GoToTableNewRow(3, "WizardPageWaitForCheckExternalConnectionConnected",                    "", "NavigationPageWait",,,, True, "WizardPageWaitForCheckExternalConnectionConnected_LongActionProcessing");
	GoToTableNewRow(4, "WizardPageFirstInfoBaseExternalConnectionParameterSetup",  "", "NavigationPageContinuation", "WizardPageFirstInfoBaseExternalConnectionParameterSetup_OnGoNext");
	GoToTableNewRow(5, "WizardPageSecondInfoBaseExternalConnectionParameterSetup", "", "NavigationPageContinuation", "WizardPageSecondInfoBaseExternalConnectionParameterSetup_OnGoNext");
	GoToTableNewRow(6, "WizardPageExchangeSetupResults",                                "", "NavigationPageContinuation",,,"WizardPageExchangeSetupResults_OnOpen_ExternalConnection");
	GoToTableNewRow(7, "WizardPageWaitForDataExchangeSettingsCreation",                  "", "NavigationPageWait",,,, True, "WizardPageWaitForDataExchangeSettingsCreationOverExternalConnection_LongActionProcessing");
	GoToTableNewRow(8, "WizardPageEndWithExchangeOverExternalConnection",              "", "NavigationPageEnd");
	
EndProcedure

&AtServer
Procedure ExchangeOverWebServiceSetupGoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1,  "WizardPageStart",, "NavigationPageStart");
	GoToTableNewRow(2,  "WizardPageWizardRunModeChoice", , "NavigationPageContinuation");
	
	// Setting connection parameters; Verifying connection.
	GoToTableNewRow(3,  "WizardPageWaitForConnectionToServiceCheck", "", "NavigationPageWait",,,, True, "WizardPageWaitForConnectionViaWebServiceCheck_LongActionProcessing");
	
	// Setting data export parameters (node filters)
	GoToTableNewRow(4,  "WizardPageDataExchangeOverWebServiceParameterSetup", "", "NavigationPageContinuation", "WizardPageDataExchangeParameterSetup_OnGoNext",, "WizardPageDataExchangeParameterSetup_OnOpen");
	
	// Creating data exchange settings; Registering catalogs to be exported.
	GoToTableNewRow(5,  "WizardPageWaitForDataAnalysisExchangeSettingsCreation",  "", "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisExchangeSettingsCreation_LongActionProcessing");
	GoToTableNewRow(6,  "WizardPageWaitForDataAnalysisExchangeSettingsCreation",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisExchangeSettingsCreationLongAction_LongActionProcessing");
	
	// Getting catalogs from the correspondent infobase
	GoToTableNewRow(7,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessage_LongActionProcessing");
	GoToTableNewRow(8,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongAction_LongActionProcessing");
	GoToTableNewRow(9,  "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongActionEnd_LongActionProcessing");
	
	// Mapping data automatically; Getting mapping statistics.
	GoToTableNewRow(10, "WizardPageWaitForDataAnalysisAutomaticMapping",, "NavigationPageWait",,,, True, "WizardPageWaitForAutomaticMappingDataAnalysis_LongActionProcessing");
	
	// Mapping data manually
	GoToTableNewRow(11, "WizardPageDataMapping",, "NavigationPageContinuationOnlyNext", "WizardPageDataMapping_OnGoNext",, "WizardPageDataMapping_OnOpen");
	
	// Synchronizing catalogs
	GoToTableNewRow(12, "WizardPageWaitForCatalogSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(13, "WizardPageWaitForCatalogSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(14, "WizardPageWaitForCatalogSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(15, "WizardPageWaitForCatalogSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongActionEnd_LongActionProcessing");
	
	// Accounting parameter settings; Default values for data export.
	GoToTableNewRow(16, "WizardPageAddingDocumentDataToAccountingRecordsSettings",, "NavigationPageContinuationOnlyNext", "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnGoNext",, "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnOpen");
	
	// Saving settings; Registering all data to be exported except catalogs.
	GoToTableNewRow(17, "WizardPageWaitForSettingsSaving",, "NavigationPageWait",,,, True, "WizardPageWaitForSettingsSaving_LongActionProcessing");
	GoToTableNewRow(18, "WizardPageWaitForSettingsSaving",, "NavigationPageWait",,,, True, "WizardPageWaitForSettingsSavingLongAction_LongActionProcessing");
	
	// Synchronizing all data except catalogs
	GoToTableNewRow(19, "WizardPageWaitForDataSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(20, "WizardPageWaitForDataSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongAction_LongActionProcessing");
	GoToTableNewRow(21, "WizardPageWaitForDataSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImport_LongActionEndLongActionProcessing");
	GoToTableNewRow(22, "WizardPageWaitForDataSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(23, "WizardPageWaitForDataSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(24, "WizardPageWaitForDataSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongActionEnd_LongActionProcessing");
	
	GoToTableNewRow(25, "WizardPageDataExchangeCreatedSuccessfully",, "NavigationPageEnd",,, "WizardPageDataExchangeCreatedSuccessfully_OnOpen");
	
EndProcedure

&AtServer
Procedure ExtendedExchangeWithServiceSetupGoToTable()
	
	GoToTable.Clear();
	
	// Setting connection parameters; Verifying connection.
	GoToTableNewRow(1, "WizardPageStartExchangeWithServiceSetup", "", "NavigationPageStart");
	GoToTableNewRow(2, "WizardPageWaitForConnectionToServiceCheck", "", "NavigationPageWait",,,,  True, "WizardPageWaitForConnectionViaWebServiceCheck_LongActionProcessing");
	
	// Setting data export parameters (node filters)
	GoToTableNewRow(3, "WizardPageDataExchangeParameterSetup", "", "NavigationPageContinuation",  "WizardPageDataExchangeParameterSetup_OnGoNext",, "WizardPageDataExchangeParameterSetup_OnOpen");
	
	// Creating data exchange settings; Registering catalogs to be exported.
	GoToTableNewRow(4, "WizardPageWaitForDataAnalysisExchangeSettingsCreation", "", "NavigationPageWait",,,,  True, "WizardPageWaitForDataAnalysisExchangeSettingsCreation_LongActionProcessing");
	GoToTableNewRow(5, "WizardPageWaitForDataAnalysisExchangeSettingsCreation",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisExchangeSettingsCreationLongAction_LongActionProcessing");
	
	// Getting catalogs from the correspondent infobase
	GoToTableNewRow(6, "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessage_LongActionProcessing");
	GoToTableNewRow(7, "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongAction_LongActionProcessing");
	GoToTableNewRow(8, "WizardPageWaitForDataAnalysisGetMessage",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisGetMessageLongActionEnd_LongActionProcessing");
	
	// Mapping data automatically; Getting mapping statistics.
	GoToTableNewRow(9, "WizardPageWaitForDataAnalysisAutomaticMapping",, "NavigationPageWait",,,, True, "WizardPageWaitForDataAnalysisAutomaticMapping_LongActionProcessing");
	
	// Mapping data manually
	GoToTableNewRow(10, "WizardPageDataMapping",, "NavigationPageContinuationOnlyNext", "WizardPageDataMapping_OnGoNext",, "WizardPageDataMapping_OnOpen");
	
	// Synchronizing catalogs
	GoToTableNewRow(11, "WizardPageWaitForCatalogSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(12, "WizardPageWaitForCatalogSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(13, "WizardPageWaitForCatalogSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(14, "WizardPageWaitForCatalogSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForCatalogSynchronizationExportLongActionEnd_LongActionProcessing");
	
	// Accounting parameter settings; Default values for data export.
	GoToTableNewRow(15, "WizardPageAddingDocumentDataToAccountingRecordsSettings",, "NavigationPageContinuationOnlyNext", "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnGoNext",, "WizardPageAddingDocumentDataToAccountingRecordsSettings_OnOpen");
	
	// Saving settings; Registering all data to be exported except catalogs.
	GoToTableNewRow(16, "WizardPageWaitForSettingsSaving",, "NavigationPageWait",,,, True, "WizardPageWaitForSettingsSaving_LongActionProcessing");
	GoToTableNewRow(17, "WizardPageWaitForSettingsSaving",, "NavigationPageWait",,,, True, "WizardPageWaitForSettingsSavingLongAction_LongActionProcessing");
	
	// Synchronizing all data except catalogs
	GoToTableNewRow(18, "WizardPageWaitForDataSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImport_LongActionProcessing");
	GoToTableNewRow(19, "WizardPageWaitForDataSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongAction_LongActionProcessing");
	GoToTableNewRow(20, "WizardPageWaitForDataSynchronizationImport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationImportLongActionEnd_LongActionProcessing");
	GoToTableNewRow(21, "WizardPageWaitForDataSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExport_LongActionProcessing");
	GoToTableNewRow(22, "WizardPageWaitForDataSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongAction_LongActionProcessing");
	GoToTableNewRow(23, "WizardPageWaitForDataSynchronizationExport",, "NavigationPageWait",,,, True, "WizardPageWaitForDataSynchronizationExportLongActionEnd_LongActionProcessing");
	
	GoToTableNewRow(24, "WizardPageDataExchangeCreatedSuccessfully",, "NavigationPageEnd",,, "PageDataExchangeWizardCreatedSuccessfully_OnOpen");
	
EndProcedure