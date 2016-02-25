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
	
	UpdateRuleSource();
	
	DataExchangeRuleLoadingEventLogMessageText = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingNotification = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, WriteParameters);
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

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing rules from file on the client
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RuleFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("en = 'Select rule file'"));
	DialogParameters.Insert("Filter",
		  NStr("en = 'Rule file (*.xml)'") + "|*.xml|"
		+ NStr("en = 'ZIP archive (*.zip)'")   + "|*.zip"
	);
	
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	DialogParameters.Insert("FilterIndex", ?( Lower(NameParts.Extension) = ".zip", 1, 0) ); 
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
EndProcedure

&AtClient
Procedure ExportRules(Command)
	
	ExportVariants = New ValueList;
	ExportVariants.Add(False,   NStr("en = 'Uncompressed file'") );
	ExportVariants.Add(True, NStr("en = 'ZIP archive'")   );
	
	Notification = New NotifyDescription("ExportRulesCompletion", ThisObject);
	ShowChooseFromMenu(Notification, ExportVariants);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMessageText", DataExchangeRuleLoadingEventLogMessageText);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

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
	
	TemplateList = DataExchangeCached.GetStandardChangeRecordRuleList(Record.ExchangePlanName);
	
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
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtServer
Function GetURLAtServer()
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", Record.ExchangePlanName);
	Filter.Insert("RuleKind",         Record.RuleKind);
	
	RecordKey = InformationRegisters.DataExchangeRules.CreateRecordKey(Filter);
	
	Return GetURL(RecordKey, "XMLRules");
	
EndFunction

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer(FileName)
	
	// Creating a temporary directory on the server and generating 
  // file paths
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	PathToFile = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + FileName;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DataExchangeRules.XMLRules
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
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", PathToFile + ".xml");
		
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

&AtServer
Procedure UpdateRuleSource()
	
	RuleSource = ?(Record.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate,
		"StandardFromConfiguration", "ImportedFromFile");
	
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
Procedure ExportRulesCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then 
		Return;
	EndIf;
	
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RuleFileName);
	
	If SelectedItem.Value Then
		// Exporting rules to an archive
		StorageAddress = GetRuleArchiveTempStorageAddressAtServer(NameParts.BaseName);
		NameFilter   = NStr("en = 'ZIP archive (*.zip)'") + "|*.zip";
	Else
		StorageAddress = GetURLAtServer();
		NameFilter = NStr("en = 'Rule file (*.xml)'") + "|*.xml";
	EndIf;
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Data exchange rules'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Mode", FileDialogMode.Save);
	DialogParameters.Insert("Title", NStr("en = 'Specify rule file name'") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NameFilter);
	
	FileToReceive = New Structure("Name, Storage", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileAtClient(FileToReceive, DialogParameters);
EndProcedure

&AtClient
Procedure ImportRulesCompletion(Val FileStoringResult, Val AdditionalParameters) Export
	
	StoredFileAddress = FileStoringResult.Location;
	ErrorText         = FileStoringResult.ErrorDescription;
	
	If IsBlankString(ErrorText) And IsBlankString(StoredFileAddress) Then
		ErrorText = NStr("en = 'An error occurred while sending synchronization data to the server'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// The file is successfully transferred, importing the file to the server
	NameParts = CommonUseClientServer.SplitFullFileName(FileStoringResult.Name);
	
	PerformRuleImport(StoredFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
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