////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// The handler for closing the setup form of multiple exchange plan nodes. 
//
// Parameters:
//  Form – managed form, where the procedure is called from.
// 
Procedure NodesSetupFormCloseFormCommand(Form) Export
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	Form.Modified = False;
	Form.Close(UnloadContextFromForm(Form));
	
EndProcedure

// The handler for closing the setup form of a single exchange plan node.
//
// Parameters:
//  Form – managed form, where the procedure is called from.
// 
Procedure NodeSettingsFormCloseFormCommand(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "NodeFilterStructure");
	
EndProcedure

// The handler for closing the default value setup form of an exchange plan node.
//
// Parameters:
//  Form – managed form, where the procedure is called from.
// 
Procedure DefaultValueSetupFormCloseFormCommand(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "NodeDefaultValues");
	
EndProcedure

// The handler for closing the setup form of a single exchange plan node.
//
// Parameters:
//  Cancel – cancel flag.
//  Form   – managed form, where the procedure is called from.
// 
Procedure SetupFormBeforeClose(Cancel, Form) Export
	
	If Form.Modified Then
		
		Response = DoQueryBox(NStr("en = 'Data has been changed. Do you want to close the form without saving your changes?'"), QuestionDialogMode.YesNo,, DialogReturnCode.No);
		
		If Response = DialogReturnCode.No Then
			
			Cancel = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Opens the data exchange setup wizard form for the specified exchange plan.
//
// Parameters:
//  ExchangePlanName – String – name of the plan exchange, as a metadata object, for
//                     which the wizard will be opened.
// 
Procedure OpenDataExchangeSetupWizard(Val ExchangePlanName, ExchangeWithServiceSetup = False) Export
	
	If Find(ExchangePlanName, "ExchangePlanUsedInServiceMode") > 0 Then
		
		ExchangePlanName = StrReplace(ExchangePlanName, "ExchangePlanUsedInServiceMode", "");
		
		ExchangeWithServiceSetup = True;
		
	EndIf;
	
	FormParameters = New Structure("ExchangePlanName", ExchangePlanName);
	
	If ExchangeWithServiceSetup Then
		
		FormParameters.Insert("ExchangeWithServiceSetup");
		
	EndIf;
	
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.Form", FormParameters);
	
EndProcedure

// Is called when the user starts choosing an item for the correspondent infobase node
// setup during setting up the exchange via the external connection.
//
Procedure CorrespondentInfoBaseItemChoiceHandlerStartChoice(AttributeName, 
																TableName, 
																Owner, 
																StandardProcessing, 
																ExternalConnectionParameters
	) Export
	
	//ChoiceInitialValue = "";
	//
	//If TypeOf(Owner) = Type("FormTable") Then
	//	
	//	CurrentData = Owner.CurrentData;
	//	
	//	If CurrentData <> Undefined Then
	//		
	//		ChoiceInitialValue = CurrentData[AttributeName + "_Key"];
	//		
	//	EndIf;
	//	
	//ElsIf TypeOf(Owner) = Type("ManagedForm") Then
	//	
	//	ChoiceInitialValue = Owner[AttributeName + "_Key"];
	//	
	//EndIf;
	//
	//StandardProcessing = False;
	//
	//FormParameters = New Structure;
	//FormParameters.Insert("ExternalConnectionParameters",        ExternalConnectionParameters);
	//FormParameters.Insert("CorrespondentInfoBaseTableFullName", TableName);
	//FormParameters.Insert("ChoiceInitialValue", ChoiceInitialValue);
	//FormParameters.Insert("AttributeName", AttributeName);
	//
	//OpenForm("CommonForm.CorrespondentInfoBaseItemChoice", FormParameters, Owner,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

// Is called when the user is filling items for the correspondent infobase node setup
// during setting up the exchange via the external connection.
//
Procedure CorrespondentInfoBaseItemChoiceHandlerFill(AttributeName, 
														TableName, 
														Owner, 
														ExternalConnectionParameters
	) Export
	
	//ChoiceInitialValue = "";
	//
	//CurrentData = Owner.CurrentData;
	//
	//If CurrentData <> Undefined Then
	//	
	//	ChoiceInitialValue = CurrentData[AttributeName + "_Key"];
	//	
	//EndIf;
	//
	//StandardProcessing = False;
	//
	//FormParameters = New Structure;
	//FormParameters.Insert("ExternalConnectionParameters",        ExternalConnectionParameters);
	//FormParameters.Insert("CorrespondentInfoBaseTableFullName", TableName);
	//FormParameters.Insert("ChoiceInitialValue", ChoiceInitialValue);
	//FormParameters.Insert("CloseOnChoice", False);
	//FormParameters.Insert("AttributeName", AttributeName);
	//
	//OpenForm("CommonForm.CorrespondentInfoBaseItemChoice", FormParameters, Owner,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

// Is called when the user has chosen the item for the correspondent infobase node setup
// during setting up the exchange via the external connection.
//
Procedure CorrespondentInfoBaseItemChoiceProcessingHandler(Item, SelectedValue, FormDataCollection = Undefined) Export
	
	If TypeOf(SelectedValue) = Type("Structure") Then
		
		If TypeOf(Item) = Type("FormTable") Then
			
			If SelectedValue.FillMode Then
				
				If FormDataCollection <> Undefined
					And FormDataCollection.FindRows(New Structure(SelectedValue.AttributeName + "_Key", SelectedValue.ID)).Count() > 0 Then
					
					Return;
					
				EndIf;
				
				Item.AddRow();
				
			EndIf;
			
			CurrentData = Item.CurrentData;
			
			If CurrentData <> Undefined Then
				
				CurrentData[SelectedValue.AttributeName]          = SelectedValue.Presentation;
				CurrentData[SelectedValue.AttributeName + "_Key"] = SelectedValue.ID;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("ManagedForm") Then
			
			Item[SelectedValue.AttributeName]          = SelectedValue.Presentation;
			Item[SelectedValue.AttributeName + "_Key"] = SelectedValue.ID;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function AllRowsMarkedInTable(Table) Export
	
	For Each Item In Table Do
		
		If Item.Use = False Then
			
			Return False;
			
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal functions for retrieving properties.

// Returns the maximum number of fields to be displayed in the infobase object mapping
// wizard.
//
// Returns:
//  Number.
//
Function MaxObjectMappingFieldCount() Export
	
	Return 5;
	
EndFunction

// Returns a data import state structure.
//
Function DataImportStatusPages() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ImportStateUndefined");
	Structure.Insert("Error",     "ImportStateError");
	Structure.Insert("Success",   "ImportStateSuccess");
	Structure.Insert("Execution", "ImportStateExecution");
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", "ImportStateWarning");
	Structure.Insert("CompletedWithWarnings",                     "ImportStateWarning");
	Structure.Insert("Error_MessageTransport",                    "ImportStateError");
	
	Return Structure;
EndFunction

// Returns a data export state structure.
//
Function DataExportStatePages() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ExportStateUndefined");
	Structure.Insert("Error",     "ExportStateError");
	Structure.Insert("Success",   "ExportStateSuccess");
	Structure.Insert("Execution", "ExportStateExecution");
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", "ExportStateWarning");
	Structure.Insert("CompletedWithWarnings",                     "ExportStateWarning");
	Structure.Insert("Error_MessageTransport",                    "ExportStateError");
	
	Return Structure;
EndFunction

// Returns a structure with data import field hyperlink name.
//
Function DataImportHyperlinkHeaders() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined",             NStr("en = 'Data was not imported.'"));
	Structure.Insert("Error",                 NStr("en = 'Errors occur during the data import'"));
	Structure.Insert("CompletedWithWarnings", NStr("en = 'Data has been imported with warnings'"));
	Structure.Insert("Success",               NStr("en = 'Data has been imported successfully'"));
	Structure.Insert("Execution",             NStr("en = 'Data is being imported...'"));
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", NStr("en = 'The exchange message was already received before'"));
	Structure.Insert("Error_MessageTransport",                    NStr("en = 'The exchange message transport error occurs during the data import'"));
	
	Return Structure;
EndFunction

// Returns a structure with data export field hyperlink name.
//
Function DataExportHyperlinkHeaders() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", NStr("en = 'Data was not exported.'"));
	Structure.Insert("Error",     NStr("en = 'Errors occur during the data export"));
	Structure.Insert("Success",   NStr("en = 'Data has been exported successfully'"));
	Structure.Insert("Execution", NStr("en = 'Data is being exported...'"));
	
	Structure.Insert("Warning_ExchangeMessageReceivedPreviously", NStr("en = 'The exchange message was already received before'"));
	Structure.Insert("CompletedWithWarnings",                     NStr("en = 'Data has been exported with warnings'"));
	Structure.Insert("Error_MessageTransport",                    NStr("en = 'The exchange message transport error occurs during the data export"));
	
	Return Structure;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Opens a file using the associated operating system application.
// Directories are opened with Windows Explorer.
//
// Parameters:
//  Object             - object where a name of the file to be opened will be 
//                       retrieved from by the property name.
//  PropertyName       - String - name of the object property where a name of the 
//                       file to be opened will be retrieved from.
//  StandardProcessing - Boolean - standard processing flag. It will be set to False.
// 
Procedure FileOrDirectoryOpenHandler(Object, PropertyName, StandardProcessing) Export
	
	StandardProcessing = False;
	
	FullFileName = Object[PropertyName];
	
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	BeginRunningApplication(Undefined, FullFileName);
	
EndProcedure

// Opens dialog for selecting a file directory.
//
Procedure FileDirectoryChoiceHandler(Object, PropertyName, StandardProcessing) Export
	
	StandardProcessing = False;
	
	BeginAttachingFileSystemExtension(New NotifyDescription("FileDirectoryChoiceHandlerEnd", ThisObject, New Structure("Object, PropertyName", Object, PropertyName)));
	
EndProcedure

Procedure FileDirectoryChoiceHandlerEnd(Attached, AdditionalParameters) Export
	
	Object = AdditionalParameters.Object;
	PropertyName = AdditionalParameters.PropertyName;
	
	
	If Not Attached Then
		ShowMessageBox(,NStr("en = 'This action requires the file system extension to be installed.'"));  
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	
	Dialog.Title = NStr("en = 'Select a directory'");
	Dialog.Directory = Object[PropertyName];
	
	If Dialog.Choose() Then
		
		Object[PropertyName] = Dialog.Directory;
		
	EndIf;

EndProcedure

// Opens dialog for selecting a file directory.
//
Procedure FileChoiceHandler(Object,
								PropertyName,
								StandardProcessing,
								Filter = "",
								CheckFileExist = True) Export
	
	StandardProcessing = False;
	
	BeginAttachingFileSystemExtension(New NotifyDescription("FileChoiceHandlerEnd", ThisObject, New Structure("CheckFileExist, Filter, Object, PropertyName", CheckFileExist, Filter, Object, PropertyName)));
	
EndProcedure

Procedure FileChoiceHandlerEnd(Attached, AdditionalParameters) Export
	
	CheckFileExist = AdditionalParameters.CheckFileExist;
	Filter = AdditionalParameters.Filter;
	Object = AdditionalParameters.Object;
	PropertyName = AdditionalParameters.PropertyName;
	
	
	If Not Attached Then
		ShowMessageBox(,NStr("en = 'This action requires the file system extension to be installed.'"));
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	
	Dialog.Title          = NStr("en = 'Select a file'");
	Dialog.FullFileName   = Object[PropertyName];
	Dialog.Multiselect	  = False;
	Dialog.Preview        = False;
	Dialog.CheckFileExist = CheckFileExist;
	Dialog.Filter         = Filter;
	
	If Dialog.Choose() Then
		
		Object[PropertyName] = Dialog.FullFileName;
		
	EndIf;

EndProcedure

// Opens the information register record form by the specified filter.
// 
Procedure OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, Val RegisterName, OwnerForm) Export
	Var RecordKey;
	
	EmptyRecordSet = DataExchangeServer.RegisterRecordSetEmpty(Filter, RegisterName);
	
	If Not EmptyRecordSet Then
		
		ValueType = Type("InformationRegisterRecordKey." + RegisterName);
		Parameters = New Array(1);
		Parameters[0] = Filter;
		
		RecordKey = New(ValueType, Parameters);
		
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("Key",               RecordKey);
	WriteParameters.Insert("FillingValues", FillingValues);
	
	// Opening the information register record form
	OpenFormModal("InformationRegister." + RegisterName + ".RecordForm", WriteParameters, OwnerForm);
	
EndProcedure

// Opens dialog for selecting a file that contains rules, shows information about
// exchange rules or data record rules to the user.
//
Procedure GetRuleInformation(UUID) Export
	
	Var TempStorageAddress;
	Var RuleInformationString;
	
	Cancel = False;
	
	CommonUseClient.SuggestFileSystemExtensionInstallationNow();
	
	If AttachFileSystemExtension()Then
		
		// Suggesting the user to select a rule file whose data will be retrieved.
		Mode = FileDialogMode.Open;
		FileDialog = New FileDialog(Mode);
		FileDialog.FullFileName = "";
		Filter = NStr("en = 'Rule files'") + "(*.xml)|*.xml|";
		FileDialog.Filter = Filter;
		FileDialog.Multiselect = False;
		FileDialog.Title = NStr("en = 'Select a file of rules whose data you want to be retrieved.'");
		
		// If the file has been selected, putting it into a store for importing data from it on the server in future
		If FileDialog.Choose() Then
			BeginPutFile(
				New NotifyDescription("GetRuleInformationEnd", ThisObject, 
					New Structure("Cancel, RuleInformationString, TempStorageAddress", Cancel, RuleInformationString, TempStorageAddress)), 
				TempStorageAddress, FileDialog.FullFileName, False, UUID);
            Return;
		Else
			Return;
		EndIf; 
		
	Else
		Return;
	EndIf;
	
	GetRuleInformationPart(Cancel, RuleInformationString, TempStorageAddress);
EndProcedure

Procedure GetRuleInformationEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	Cancel = AdditionalParameters.Cancel;
	RuleInformationString = AdditionalParameters.RuleInformationString;
	TempStorageAddress = AdditionalParameters.TempStorageAddress;
	
	
	GetRuleInformationPart(Cancel, RuleInformationString, TempStorageAddress);

EndProcedure

Procedure GetRuleInformationPart(Cancel, RuleInformationString, Val TempStorageAddress)
	
	Var NString, WindowTitle;
	
	NString = NStr("en = 'Importing rule info...'");
	Status(NString);
	
	// Importing rules on the server
	DataExchangeServer.LoadRuleInformation(Cancel, TempStorageAddress, RuleInformationString);
	
	If Cancel Then
		
		NString = NStr("en = 'Error retrieving rule info.'");
		
		ShowMessageBox(,NString);
		
	Else
		
		WindowTitle = NStr("en = 'Rule info'");
		
		ShowMessageBox(,RuleInformationString,, WindowTitle);
		
	EndIf;

EndProcedure

// Opens the event log with the filter by import and export events for the specified
// exchange plan node.
// 
Procedure GoToDataEventLog(InfoBaseNode, CommandExecuteParameters, ExchangeActionString) Export
	
	EventLogMessageText = DataExchangeServer.GetEventLogMessageKeyByActionString(InfoBaseNode, ExchangeActionString);
	
	FormParameters = New Structure;
	FormParameters.Insert("EventLogMessageText", EventLogMessageText);
	
	OpenForm("DataProcessor.EventLogMonitor.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

// Opens the event log modally with the filter by import and export events for the 
// specified exchange plan node.
//
Procedure GoToDataEventLogModally(InfoBaseNode, Owner, ActionOnExchange) Export
	
	// Calling the server
	FormParameters = DataExchangeServer.GetEventLogFilterDataStructure(InfoBaseNode, ActionOnExchange);
	
	OpenForm("DataProcessor.EventLogMonitor.Form", FormParameters, Owner,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

// Opens the data exchange execution form for the specified exchange plan node.
//
// Parameters:
//  InfoBaseNode - ExchangePlanRef - exchange plan node whose form will be opened.
//  Owner        – form that will be the open form owner.
// 
Procedure ExecuteDataExchangeCommandProcessing(InfoBaseNode, Owner) Export
	
	QuestionText = NStr("en = 'Do you want to execute the data exchange with [InfoBaseNode]?'");
	QuestionText = StrReplace(QuestionText, "[InfoBaseNode]", String(InfoBaseNode));
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("ExecuteDataExchangeCommandProcessingEnd", ThisObject, New Structure("InfoBaseNode, Owner", InfoBaseNode, Owner)), QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

Procedure ExecuteDataExchangeCommandProcessingEnd(QuestionResult, AdditionalParameters) Export
	
	InfoBaseNode = AdditionalParameters.InfoBaseNode;
	Owner = AdditionalParameters.Owner;
	
	
	Response = QuestionResult;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("InfoBaseNode", InfoBaseNode);
	
	OpenForm("CommonForm.DataExchangeExecution", FormParameters, Owner, InfoBaseNode);

EndProcedure

// Opens the form of the interactive data exchange execution for the specified exchange
// plan node.
//
// Parameters:
//  InfoBaseNode - ExchangePlanRef - exchange plan node whose form will be opened.
//  Owner        – form that will be the open form owner.
//
Procedure OpenObjectMappingWizardCommandProcessing(InfoBaseNode, Owner) Export
	
	// Opening the object mapping wizard form.
	// Passing the infobase node as a form parameter.
	FormParameters = New Structure("InfoBaseNode", InfoBaseNode);
	
	OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, Owner, InfoBaseNode);
	
EndProcedure

// Opens the data exchange execution script list form for the specified exchange plan node.
//
// Parameters:
//  InfoBaseNode - ExchangePlanRef - exchange plan node whose form will be opened.
//  Owner – form that will be the open form owner.
//
Procedure SetupExchangeExecutionScheduleCommandProcessing(InfoBaseNode, Owner) Export
	
	FormParameters = New Structure("InfoBaseNode", InfoBaseNode);
	
	OpenForm("Catalog.DataExchangeScenarios.Form.DataExchangeScheduleSetup", FormParameters, Owner);
	
EndProcedure

// The handler for starting the client session of the application.
// If the subordinate distributed infobase that corresponds to the node runs for the
// first time, the data exchange creation wizard form opens.
// 
Procedure OnStart() Export
	
	If Not CommonUseCached.CanUseSeparatedData() 
		Or CommonUseCached.DataSeparationEnabled() Then
		
		Return;
	EndIf;
	
	ClientParameters = StandardSubsystemsClientCached.ClientParameters();

	If ClientParameters.IsSubordinateDIBNode
		// The subordinate distributed infobase that corresponds to the node runs for the first time
		And Not ClientParameters.SubordinateDIBNodeSetupCompleted Then
		
		FormParameters = New Structure("ExchangePlanName, ThisIsContinuationOfSettingsInSubordinateNodeRIB", ClientParameters.DIBExchangePlanName);
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.Form", FormParameters);
		
	EndIf;
	
EndProcedure

// Checks whether the exchange message with configuration changes was loaded.
// Loading a message of this type to a subordinate node consists of two stages: 
//  1) Configuration changes are imported;
//  2) Data are imported.
// This function is used in the scenario where message data is imported before executing
// infobase update handlers.
// 
//  Returns:
//   True if loading the message is not required, message data was imported successfully
//   or was canceled.
//   False if errors occurred during the import.
//
Function CheckExchangeMessageWithConfigurationChangesForSubordinateNodeImport() Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return True;
	EndIf;
	
	Result = True;
	
	ClientParameters = StandardSubsystemsClientCached.ClientParameters();
	
	If  ClientParameters.IsSubordinateDIBNode
		And ClientParameters.InfoBaseUpdateRequired
		And ClientParameters.SubordinateDIBNodeSetupCompleted Then
		
		Result = OpenFormModal("CommonForm.ImportExchangeMessageWithConfigurationChanges") = True;
		
	EndIf;
	
	If Not Result Then
		
		Exit(False);
		
	EndIf;
	
	Return Result;
EndFunction

// Handles start parameters.
//
// Parameters
//  LaunchParameterValue  – String – main start parameter.
//  LaunchParameters      – Array – semicolon-separated additional start parameters.
//
// Returns:
//   Boolean – True if system start must be canceled.
//
Function ProcessLaunchParameters(Val LaunchParameterValue, Val LaunchParameters) Export
	
	If LaunchParameterValue = Upper("InteractiveDataImportExecute") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ExchangePlanName", LaunchParameters[1]);
		FormParameters.Insert("InfoBaseNodeCode", LaunchParameters[2]);
		
		OpenFormModal("DataProcessor.InteractiveDataExchangeWizard.Form.Form", FormParameters);
		
		// Exit the application
		Exit(False);
		
		Return True;
	EndIf;
	
	Return False;
EndFunction

// Starts the 1C:Enterprise application and imports data interactively using the wizard.
// Exits the application once the wizard is complete.
//
Procedure RunPlatformAppAndExecuteInteractiveDataImport(ConnectionParameters, ExchangePlanName) Export
	
#If WebClient Then
	
	ShowMessageBox(,NStr("en = 'The operation is not supported in the web client.'"));
	
#Else
	
	SecondInfoBaseNewNodeCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	ApplicationExecutablePath = CommonUseClientServer.GetFullFileName(BinDir(), "1cv8.exe");
	
	If ConnectionParameters.InfoBaseOperationMode = 0 Then // file mode
		
		CommandString = "%1 ENTERPRISE /F""%2"" /N""%3"" /P""%4"" CInteractiveDataImportExecute;%5;%6";
		
		CommandString = StringFunctionsClientServer.SubstituteParametersInString(CommandString,
						ApplicationExecutablePath,
						ConnectionParameters.InfoBaseDirectory,
						ConnectionParameters.UserName,
						ConnectionParameters.UserPassword,
						ExchangePlanName,
						SecondInfoBaseNewNodeCode
		);
		
	Else // client/server mode
		
		CommandString = "%1 ENTERPRISE /S%2\%3 /N""%4"" /P""%5"" CInteractiveDataImportExecute;%6;%7";
		
		CommandString = StringFunctionsClientServer.SubstituteParametersInString(CommandString,
						ApplicationExecutablePath,
						ConnectionParameters.PlatformServerName,
						ConnectionParameters.InfoBaseNameAtPlatformServer,
						ConnectionParameters.UserName,
						ConnectionParameters.UserPassword,
						ExchangePlanName,
						SecondInfoBaseNewNodeCode
		);
		
	EndIf;
	
	BeginRunningApplication(Undefined, CommandString,, True);
	
#EndIf
	
EndProcedure

// Notifies all opened dynamic lists that data that is shown must be refreshed.
//
Procedure RefreshAllOpenDynamicLists() Export
	
	Types = DataExchangeServer.AllConfigurationReferenceTypes();
	
	For Each Type In Types Do
		
		NotifyChanged(Type);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function UnloadContextFromForm(Form)
	
	// Return value
	Context = New Structure;
	
	Attributes = StringFunctionsClientServer.SplitStringIntoSubstringArray(Form.Attributes);
	
	For Each Attribute In Attributes Do
		
		If Find(Attribute, ".") > 0 Then
			
			Columns = StringFunctionsClientServer.SplitStringIntoSubstringArray(Attribute, ".");
			
			If Columns.Count() > 0 Then
				
				TableName = Columns[0];
				
				Columns.Delete(0);
				
				ColumnString = StringFunctionsClientServer.GetStringFromSubstringArray(Columns);
				
				Table = New Array;
				
				For Each Item In Form[TableName] Do
					
					TableRow = New Structure(ColumnString);
					
					FillPropertyValues(TableRow, Item);
					
					Table.Add(TableRow);
					
				EndDo;
				
				Context.Insert(TableName, Table)
				
			EndIf;
			
		Else
			
			Context.Insert(Attribute, Form[Attribute])
			
		EndIf;
		
	EndDo;
	
	Return Context;
EndFunction

Procedure OnCloseExchangePlanNodeSettingsForm(Form, FormAttributeName)
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	For Each FilterSettings In Form[FormAttributeName] Do
		
		If TypeOf(Form[FilterSettings.Key]) = Type("FormDataCollection") Then
			
			TabularSectionStructure = Form[FormAttributeName][FilterSettings.Key];
			
			For Each Item In TabularSectionStructure Do
				
				TabularSectionStructure[Item.Key].Clear();
				
				For Each CollectionRow In Form[FilterSettings.Key] Do
					
					TabularSectionStructure[Item.Key].Add(CollectionRow[Item.Key]);
					
				EndDo;
				
			EndDo;
			
		Else
			
			Form[FormAttributeName][FilterSettings.Key] = Form[FilterSettings.Key];
			
		EndIf;
		
	EndDo;
	
	Form.Modified = False;
	Form.Close(Form[FormAttributeName]);
	
EndProcedure

// Internal use only.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If Not ClientParameters.Property("RetryDataExchangeMessageImportBeforeStart") Then
		Return;
	EndIf;
	
	Parameters.InteractiveProcessing = New NotifyDescription(
		"RetryDataExchangeMessageImportBeforeStartInteractiveProcessing", ThisObject);
	
EndProcedure
