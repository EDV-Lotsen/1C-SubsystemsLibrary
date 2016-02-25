
&AtClient
Var ExternalResourcesAllowed;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be 
 // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	UpdateExchangePlanChoiceList();
	
	UpdateRuleTemplateChoiceList();
	
	UpdateRuleInfo();
	
	RuleSource = ?(Record.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate,
		"StandardFromConfiguration", "ImportedFromFile");
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
	Items.DebugGroup.Enabled = (RuleSource = "ImportedFromFile");
	Items.DebugSetupGroup.Enabled = Record.DebugMode;
	Items.SourceFile.Enabled = (RuleSource = "ImportedFromFile");
	
	DataExchangeRuleLoadingEventLogMessageText = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not CheckFillingAtClient() Then
		Cancel = True;
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingNotification = New NotifyDescription("AllowExternalResourceEnd", ThisObject, WriteParameters);
		Queries = CreateRequestForUseExternalResources(Record);
		SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
		
		Cancel = True;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	If Not Cancel And RuleSource = "StandardFromConfiguration" Then
		// Importing rules from configuration
		PerformRuleImport(Undefined, "", False);
	EndIf;
	
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	HasBlankFields = False;
	
	If RuleSource = "ImportedFromFile" And IsBlankString(Record.RuleFileName) Then
		
		MessageString = NStr("en = 'Exchange rule file name  is not specified.'");
		CommonUseClientServer.MessageToUser(MessageString,,,, HasBlankFields);
		
	EndIf;
	
	If Record.DebugMode Then
		
		If Record.ExportDebugMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "Record.ExportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If Record.ImportDebugMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ImportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "Record.ImportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If Record.DataExchangeLoggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExchangeLogFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'Exchange protocol file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "Record.ExchangeLogFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasBlankFields;
	
EndFunction

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ExchangePlanNameOnChange(Item)
	
	Record.RuleTemplateName = "";
	
	// Server call
	UpdateRuleTemplateChoiceList();
	
EndProcedure

&AtClient
Procedure RuleSourceOnChange(Item)
	
	Items.DebugGroup.Enabled = (RuleSource = "ImportedFromFile");
	Items.SourceFile.Enabled = (RuleSource = "ImportedFromFile");
	
	If RuleSource = "StandardFromConfiguration" Then
		
		Record.DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForExportDebug.Enabled = Record.ExportDebugMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor (*.epf)'") + "|*.epf" );
	
	DataExchangeClient.FileChoiceHandler(Record, "ExportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForImportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor (*.epf)'") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileChoiceHandler(Record, "ImportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForImportDebug.Enabled = Record.ImportDebugMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeLoggingOnChange(Item)
	
	Items.ExchangeProtocolFile.Enabled = Record.DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'Text document (*.txt)'")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	StandardProcessing = False;
	DataExchangeClient.FileChoiceHandler(Record, "ExchangeLogFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "ExchangeLogFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure RuleTemplateNameOnChange(Item)
	Record.CorrespondentRuleTemplateName = Record.RuleTemplateName + "Correspondent";
EndProcedure

&AtClient
Procedure EnableDebugModeOnChange(Item)
	
	Items.DebugSetupGroup.Enabled = Record.DebugMode;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing rules from file on the client
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RuleFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("en = 'Select exchange rule archive file'"));
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)'") + "|*.zip");
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("ImportRuleCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RuleFileName);

	// Exporting rules to an archive
	StorageAddress = GetRuleArchiveTempStorageAddressAtServer();
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Conversion rules'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Mode", FileDialogMode.Save);
	DialogParameters.Insert("Title", NStr("en = 'Specify rule archive file name'") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)'") + "|*.zip");
	
	FileToReceive = New Structure("Name, Storage", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileAtClient(FileToReceive, DialogParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateExchangePlanChoiceList()
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	FillList(ExchangePlanList, Items.ExchangePlanName.ChoiceList);
	
EndProcedure

&AtServer
Procedure UpdateRuleTemplateChoiceList()
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		Items.MainGroup.Title = NStr("en = 'Conversion rules'");
		
	Else
		
		Items.MainGroup.Title = StringFunctionsClientServer.SubstituteParametersInString(
			Items.MainGroup.Title, Metadata.ExchangePlans[Record.ExchangePlanName].Synonym);
		
	EndIf;
	
	TemplateList = DataExchangeCached.GetStandardExchangeRuleList(Record.ExchangePlanName);
	
	ChoiceList = Items.RuleTemplateName.ChoiceList;
	ChoiceList.Clear();
	
	FillList(TemplateList, ChoiceList);
	
	Items.SourceConfigurationTemplate.CurrentPage = ?(TemplateList.Count() = 1,
		Items.PageOneTemplate, Items.PageSeveralTemplates);
	
EndProcedure

&AtServer
Procedure FillList(SourceList, TargetList)
	
	For Each Item In SourceList Do
		
		FillPropertyValues(TargetList.Add(), Item);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ImportRuleCompletion(Val FileStoreResult, Val AdditionalParameters) Export
	
	StoredFileAddress = FileStoreResult.Location;
	ErrorText         = FileStoreResult.ErrorDescription;
	
	If IsBlankString(ErrorText) And IsBlankString(StoredFileAddress) Then
		ErrorText = NStr("en = 'An error occurred while sending synchronization data to the server'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// The file is successfully transferred, importing the file on the server
	NameParts = CommonUseClientServer.SplitFullFileName(FileStoreResult.Name);
	
	PerformRuleImport(StoredFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
	
EndProcedure

&AtClient
Procedure PerformRuleImport(Val StoredFileAddress, Val FileName, Val IsArchive)
	Cancel = False;
	
	Status(NStr("en = 'Importing rules to the infobase...'"));
	ImportRulesAtServer(Cancel, StoredFileAddress, FileName, IsArchive);
	Status();
	
	If Not Cancel Then
		ShowUserNotification(,, NStr("en = 'Rules imported to the infobase.'"));
		Return;
	EndIf;
	
	ErrorText = NStr("en = 'Errors occurred during the rule import.
	                         |Do you want to view the event log?'");
	
	Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
EndProcedure

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMessageText", DataExchangeRuleLoadingEventLogMessageText);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RuleFileName, IsArchive)
	
	Record.RuleSource = ?(RuleSource = "StandardFromConfiguration",
		Enums.DataExchangeRuleSources.ConfigurationTemplate, Enums.DataExchangeRuleSources.File);
	
	Object = FormAttributeToValue("Record");
	
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TempStorageAddress, RuleFileName, IsArchive);
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
		// Open session data cached for change registration has become obsolete
		DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
		RefreshReusableValues();
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Creating a temporary directory on the server and generating file
  // paths
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	PathToFile = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "ExchangeRules";
	CorrespondentFilePath = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "CorrespondentExchangeRules";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.XMLRules,
	|	DataExchangeRules.XMLCorrespondentRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = &RuleKind";
	Query.SetParameter("ExchangePlanName", Record.ExchangePlanName); 
	Query.SetParameter("RuleKind", Record.RuleKind);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		NString = NStr("en = 'Cannot read exchange rules.'");
		DataExchangeServer.ReportError(NString);
		Return "";
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		// Getting, saving, and archiving the rule file in the temporary directory
		RuleBinaryData = Selection.XMLRules.Get();
		RuleBinaryData.Write(PathToFile + ".xml");
		
		CorrespondentRuleBinaryData = Selection.XMLCorrespondentRules.Get();
		CorrespondentRuleBinaryData.Write(CorrespondentFilePath + ".xml");
		
		FilePackingMask = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "*.xml";
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", FilePackingMask);
		
		// Putting the ZIP archive with the rules to the storage
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TempStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		Return TempStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	If Record.RuleSource = Enums.DataExchangeRuleSources.File Then
		
		RuleInfo = NStr("en = 'Ensure that the rules you are about to import are created in the current application version. Using rules created in previous versions can cause errors.
		|
		|[RuleInformation]'");
		
		RuleInfo = StrReplace(RuleInfo, "[RuleInformation]", Record.RuleInfo);
		
	Else
		
		RuleInfo = Record.RuleInfo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestForUseExternalResources(Val Record)
	
	PermissionRequests = New Array;
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionRequests, Record);
	Return PermissionRequests;
	
EndFunction

#EndRegion
