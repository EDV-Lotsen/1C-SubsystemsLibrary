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
	
	ExchangePlanName = Parameters.ExchangePlanName;
	
	If Not ValueIsFilled(ExchangePlanName) Then
		Return;
	EndIf;
	
	Title = StrReplace(Title, "%1", Metadata.ExchangePlans[ExchangePlanName].Synonym);
	
	UpdateRuleTemplateChoiceList();
	
	UpdateRuleInfo();
	
	Items.DebugGroup.Enabled = (RuleSource = "ImportedFromFile");
	Items.DebugOptionGroup.Enabled = DebugMode;
	Items.SourceFile.Enabled = (RuleSource = "ImportedFromFile");
	
	DataExchangeRuleLoadingEventLogMessageText = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
	ApplicationName = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	RuleSetLocation = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"RuleSetFilePathOnUserSite, RuleSetFilePathInTemplateDirectory");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	TooltipPattern = NStr("en = 'You can download a rule set from %1 or use a rule set from %2'");
	
	UpdateDirectoryPattern = NStr("en = 'the %1 configuration template directory'");
	UpdateDirectoryPattern = StringFunctionsClientServer.SubstituteParametersInString(UpdateDirectoryPattern, ApplicationName);
	If Not IsBlankString(RuleSetLocation.RuleSetFilePathInTemplateDirectory) Then
		
		TemplatesDirectory = TemplatesDirectory();
		
		FileLocation = TemplatesDirectory() + RuleSetLocation.RuleSetFilePathInTemplateDirectory;
		
		If FileExistsOnClient(FileLocation) Then
			UpdateDirectoryPattern = New FormattedString(UpdateDirectoryPattern,,,, FileLocation);
		EndIf;
		
	EndIf;
	
	UserSitePattern = NStr("en = '1C:Enterprise support site'");
	If Not IsBlankString(RuleSetLocation.RuleSetFilePathOnUserSite) Then
		
		UserSitePattern = New FormattedString(UserSitePattern,,,, RuleSetLocation.RuleSetFilePathOnUserSite);
		
	EndIf;
	
	ToolTipText = SubstituteParametersInFormattedString(TooltipPattern, UserSitePattern, UpdateDirectoryPattern);
	
	Items.RuleObtainInfoDecoration.Title = ToolTipText;
	
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	HasBlankFields = False;
	
	If DebugMode Then
		
		If ExportDebugMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(ExportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "ExportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If ImportDebugMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(ImportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "ImportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If DataExchangeLoggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(ExchangeLogFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'Exchange protocol file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "ExchangeLogFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasBlankFields;
	
EndFunction

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure RuleSourceOnChange(Item)
	
	Items.DebugGroup.Enabled = (RuleSource = "ImportedFromFile");
	Items.SourceFile.Enabled = (RuleSource = "ImportedFromFile");
	
	If RuleSource = "StandardFromConfiguration" Then
		
		DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForExportDebug.Enabled = ExportDebugMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor(*.epf)'") + "|*.epf" );
	
	DataExchangeClient.FileChoiceHandler(ThisObject, "ExportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForImportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor(*.epf)'") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileChoiceHandler(ThisObject, "ImportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForImportDebug.Enabled = ImportDebugMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeLoggingOnChange(Item)
	
	Items.ExchangeProtocolFile.Enabled = DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'Text document(*.txt)'")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	DataExchangeClient.FileChoiceHandler(ThisObject, "ExchangeLogFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(ThisObject, "ExchangeLogFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure EnableDebugModeOnChange(Item)
	
	Items.DebugOptionGroup.Enabled = DebugMode;
	
EndProcedure

&AtClient
Procedure RuleObtainInfoDecorationURLProcessing(Item, URL, StandardProcessing)
	
	If Find(URL, "http") = 0 Then
		StandardProcessing = False;
		RunApp(URL);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing from file on the client
	NameParts = CommonUseClientServer.SplitFullFileName(RuleFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("en = 'Select exchange rule archive'"));
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)'") + "|*.zip");
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("RuleImportCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonUseClientServer.SplitFullFileName(RuleFileName);

	// Exporting to an archive
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
	DialogParameters.Insert("Title", NStr("en = 'Specify file to export rules'") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)'") + "|*.zip");
	
	FileToReceive = New Structure("Name, Storage", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileAtClient(FileToReceive, DialogParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	BeforeRuleImport();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateRuleTemplateChoiceList()
	
	Items.SourceConfigurationTemplate.CurrentPage = Items.PageOneTemplate;
	
EndProcedure

&AtClient
Procedure RuleImportCompletion(Val FileStoringResult, Val AdditionalParameters) Export
	
	StoredFileAddress = FileStoringResult.Location;
	ErrorText         = FileStoringResult.ErrorDescription;
	
	If IsBlankString(ErrorText) And IsBlankString(StoredFileAddress) Then
		ErrorText = NStr("en = 'An error occurred while sending data synchronization settings to the server.'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// Importing the file that was sent to the server
	NameParts = CommonUseClientServer.SplitFullFileName(FileStoringResult.Name);
	
	If Lower(NameParts.Extension) <> ".zip" Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Incorrect rule set file format. It must be a ZIP archive with the following three files:
     |ExchangeRules.xml. Сonversion rules for the current application
     |CorrespondentExchangeRules.xml. Conversion rules for the correspondent application 
     |RegistrationRules.xml. Registration rules for the current application'"));
	EndIf;
	
	ErrorDescription = Undefined;
	PerformRuleImport(StoredFileAddress, NameParts.Name, ErrorDescription);
	
EndProcedure

&AtClient
Procedure PerformRuleImport(Val StoredFileAddress, Val FileName, ErrorDescription = Undefined)
	
	Cancel = False;
	
	Status(NStr("en = 'Importing rules to the infobase...'"));
	ImportRulesAtServer(Cancel, StoredFileAddress, FileName, ErrorDescription);
	Status();
	
	If TypeOf(ErrorDescription) <> Type("Boolean") And ErrorDescription <> Undefined Then
		
		Buttons = New ValueList;
		
		If ErrorDescription.ErrorKind = "IncorrectConfiguration" Then
			Buttons.Add("Cancel", NStr("en = 'Close'"));
		Else
			Buttons.Add("Continue", NStr("en = 'Continue'"));
			Buttons.Add("Cancel", NStr("en = 'Cancel'"));
		EndIf;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("StoredFileAddress", StoredFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		Notification = New NotifyDescription("AfterConversionRulesCheckForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.DefaultButton = "Cancel";
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.SuggestDontAskAgain = False;
		If ErrorDescription.ErrorKind = "IncorrectConfiguration" Then
			FormParameters.Title = NStr("en = 'Cannot import rules'");
		Else
			FormParameters.Title = NStr("en = 'Data synchronization might be performed incorrectly'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	ElsIf Cancel Then
		ErrorText = NStr("en = 'Errors occurred during the rule import.
			|Do you want to view the event log?'");
		Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
		ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	Else
		ShowUserNotification(,, NStr("en = 'The rules are imported to the infobase.'"));
	EndIf;
	
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
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RuleFileName, ErrorDescription)
	
	SetRuleSource = ?(RuleSource = "StandardFromConfiguration",
		Enums.DataExchangeRuleSources.ConfigurationTemplate, Enums.DataExchangeRuleSources.File);
	
	CovnersionRuleWriting                               = InformationRegisters.DataExchangeRules.CreateRecordManager();
	CovnersionRuleWriting.RuleKind                      = Enums.DataExchangeRuleKinds.ObjectConversionRules;
	CovnersionRuleWriting.RuleTemplateName              = ConversionRuleTemplateName;
	CovnersionRuleWriting.CorrespondentRuleTemplateName = CorrespondentRuleTemplateName;
	CovnersionRuleWriting.RuleInfo                      = ConversionRuleInfo;
	
	FillPropertyValues(CovnersionRuleWriting, ThisObject);
	CovnersionRuleWriting.RuleSource = SetRuleSource;
	
	RegistrationRuleWriting                  = InformationRegisters.DataExchangeRules.CreateRecordManager();
	RegistrationRuleWriting.RuleKind         = Enums.DataExchangeRuleKinds.ObjectChangeRecordRules;
	RegistrationRuleWriting.RuleTemplateName = RegistrationRuleTemplateName;
	RegistrationRuleWriting.RuleInfo         = RegistrationRuleInfo;
	RegistrationRuleWriting.RuleFileName     = RuleFileName;
	RegistrationRuleWriting.ExchangePlanName = ExchangePlanName;
	RegistrationRuleWriting.RuleSource       = SetRuleSource;
	
	RegisterRecordStructure = New Structure();
	RegisterRecordStructure.Insert("CovnersionRuleWriting", CovnersionRuleWriting);
	RegisterRecordStructure.Insert("RegistrationRuleWriting", RegistrationRuleWriting);
	
	InformationRegisters.DataExchangeRules.ImportRuleSet(Cancel, RegisterRecordStructure,
		ErrorDescription, TempStorageAddress, RuleFileName);
	
	If Not Cancel Then
		
		CovnersionRuleWriting.Write();
		RegistrationRuleWriting.Write();
		
		Modified = False;
		
		// Cached data of the open session used for change recording has become obsolete
		DataExchangeServerCall.ResetObjectChangeRecordMechanismCache();
		RefreshReusableValues();
		UpdateRuleInfo();
		
	EndIf;
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Creating a temporary directory on the server, generating file and directory paths
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	
	PathToFile               = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "ExchangeRules";
	CorrespondentFilePath = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "CorrespondentExchangeRules";
	RegistrationFilePath    = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "RegistrationRules";
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	DataExchangeRules.XMLRules,
		|	DataExchangeRules.RulesXMLCorrespondent,
		|	DataExchangeRules.RuleKind
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		NString = NStr("en = 'Cannot read exchange rules.'");
		DataExchangeServer.ReportError(NString);
		Return "";
		
	Else
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
				
				// Getting, saving, and archiving the conversion rule file to 
      // the temporary directory
				RuleBinaryData = Selection.XMLRules.Get();
				RuleBinaryData.Write(PathToFile + ".xml");
				
				// Getting, saving, and archiving the correspondent conversion 
      // rule file to the temporary directory
				CorrespondentRuleBinaryData = Selection.RulesXMLCorrespondent.Get();
				CorrespondentRuleBinaryData.Write(CorrespondentFilePath + ".xml");
				
			Else
				// Getting, saving, and archiving the registration rule file to the temporary directory
				RegistrationRulesBinaryData = Selection.XMLRules.Get();
				RegistrationRulesBinaryData.Write(RegistrationFilePath + ".xml");
			EndIf;
			
		EndDo;
		
		FilePackingMask = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "*.xml";
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", FilePackingMask);
		
		// Moving the ZIP archive with rules to the storage
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TempStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		
		Return TempStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	RuleInfo();
	
	RuleSource = ?(RegistrationRuleSource = Enums.DataExchangeRuleSources.File
		OR ConversionRuleSource = Enums.DataExchangeRuleSources.File,
		"ImportedFromFile", "StandardFromConfiguration");
	
	CommonRuleInfo = "[UsageInfo] [RegistrationRuleInfo] [ConversionRuleInfo]";
	
	If RuleSource = "ImportedFromFile" Then
		UsageInfo = NStr("en = 'Exchange rules imported from a file are applied.'");
	Else
		UsageInfo = NStr("en = 'Default configuration exchange rules are applied.'");
	EndIf;
	
	CommonRuleInfo = StrReplace(CommonRuleInfo, "[UsageInfo]", UsageInfo);
	CommonRuleInfo = StrReplace(CommonRuleInfo, "[ConversionRuleInfo]", ConversionRuleInfo);
	CommonRuleInfo = StrReplace(CommonRuleInfo, "[RegistrationRuleInfo]", RegistrationRuleInfo);
	
EndProcedure

&AtServer
Procedure RuleInfo()
	
	Query = New Query;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Query.Text = "SELECT
		|	DataExchangeRules.RuleTemplateName AS ConversionRuleTemplateName,
		|	DataExchangeRules.CorrespondentRuleTemplateName AS CorrespondentRuleTemplateName,
		|	DataExchangeRules.ExportDebuggingDataProcessorFileName,
		|	DataExchangeRules.ImportDebuggingDataProcessorFileName,
		|	DataExchangeRules.RuleFileName AS ConversionRuleFileName,
		|	DataExchangeRules.ExchangeLogFileName,
		|	DataExchangeRules.RuleInfo AS ConversionRuleInfo,
		|	DataExchangeRules.UseSelectiveObjectChangeRecordFilter,
		|	DataExchangeRules.RuleSource AS ConversionRuleSource,
		|	DataExchangeRules.DontStopOnError,
		|	DataExchangeRules.DebugMode,
		|	DataExchangeRules.ExportDebugMode,
		|	DataExchangeRules.ImportDebugMode,
		|	DataExchangeRules.DataExchangeLoggingMode
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)";
		
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
	Query.Text = "SELECT
		|	DataExchangeRules.RuleTemplateName AS RegistrationRuleTemplateName,
		|	DataExchangeRules.RuleFileName AS RegistrationRuleFileName,
		|	DataExchangeRules.RuleInfo AS RegistrationRuleInfo,
		|	DataExchangeRules.RuleSource AS RegistrationRuleSource
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectChangeRecordRules)";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeRuleImport()
	
	If Not CheckFillingAtClient() Then
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingNotification = New NotifyDescription("AllowExternalResourceEnd", ThisObject);
		Queries = CreateRequestForUseExternalResources();
		SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
		
		Return;
		
	EndIf;
	
	ExternalResourcesAllowed = False;
	
	If RuleSource = "StandardFromConfiguration" Then
		PerformRuleImport(Undefined, "");
		Close();
	Else
		If ConversionRuleSource = PredefinedValue("Enum.DataExchangeRuleSources.ConfigurationTemplate") Then
			
			ErrorDescription = NStr("en = 'Conversion rules are not imported from a file. If you close the form, the default conversion rules will be applied.
			|Do you want to use the default conversion rules?'");
			
			Notification = New NotifyDescription("CloseRuleImportForm", ThisObject);
			
			Buttons = New ValueList;
			Buttons.Add("Use",    NStr("en = 'Use'"));
			Buttons.Add("Cancel", NStr("en = 'Cancel'"));
			
			FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
			FormParameters.DefaultButton = "Use";
			FormParameters.SuggestDontAskAgain = False;
			
			StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription, Buttons, FormParameters);
		Else
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		BeforeRuleImport();
	EndIf;
	
EndProcedure

&AtServer
Function CreateRequestForUseExternalResources()
	
	PermissionRequests = New Array;
	//InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionRequests, Record);
	Return PermissionRequests;
	
EndFunction

&AtClient
// Returns a formatted string based on a template (for example, "%1 moved to %2").
//
// Parameters:
//    Template - String - template pattern.
//    String1  - String, FormattedString, Picture, Undefined - value to substitute. 
//    String2  - String, FormattedString, Picture, Undefined - value to substitute.
//
// Returns:
//    FormattedString - string generated according to the parameters passed to the function.
//
Function SubstituteParametersInFormattedString(Val Template,
	Val String1 = Undefined, Val String2 = Undefined)
	
	StringPart = New Array;
	AllowedTypes = New TypeDescription("String, FormattedString, Picture");
	Beginning = 1;
	
	While True Do
		
		Fragment = Mid(Template, Beginning);
		
		Position = Find(Fragment, "%");
		
		If Position = 0 Then
			
			StringPart.Add(Fragment);
			
			Break;
			
		EndIf;
		
		Next = Mid(Fragment, Position + 1, 1);
		
		If Next = "1" Then
			
			Value = String1;
			
		ElsIf Next = "2" Then
			
			Value = String2;
			
		ElsIf Next = "%" Then
			
			Value = "%";
			
		Else
			
			Value = Undefined;
			
			Position  = Position - 1;
			
		EndIf;
		
		StringPart.Add(Left(Fragment, Position - 1));
		
		If Value <> Undefined Then
			
			Value = AllowedTypes.AdjustValue(Value);
			
			If Value <> Undefined Then
				
				StringPart.Add( Value );
				
			EndIf;
			
		EndIf;
		
		Beginning = Beginning + Position + 1;
		
	EndDo;
	
	Return New FormattedString(StringPart);
	
EndFunction

// Determining configuration template and configuration update directory
// on the current computer
//
&AtClient
Function TemplatesDirectory()
	
	Postfix = "1C\1Cv8\tmplts\";
	
	DefaultDirectory = AppDataDirectory() + Postfix;
	FileName = AppDataDirectory() + "1C\1CEStart\1CEStart.cfg";
	If Not FileExistsOnClient(FileName) Then 
		Return DefaultDirectory;
	EndIf;
	Text = New TextReader(FileName, TextEncoding.UTF16);
	Str = "";
	While Str <> Undefined Do
		Str = Text.ReadLine();
		If Str = Undefined Then
			Break;
		EndIf;
		If Find(Upper(Str), Upper("ConfigurationTemplatesLocation")) = 0 Then
			Continue;
		EndIf;
		SeparatorPosition = Find(Str, "=");
		If SeparatorPosition = 0 Then
			Continue;
		EndIf;
		FoundDirectory = CommonUseClientServer.AddFinalPathSeparator(TrimAll(Mid(Str, SeparatorPosition + 1)));
		Return ?(FileExistsOnClient(FoundDirectory), FoundDirectory, DefaultDirectory);
	EndDo;
	
	Return DefaultDirectory;

EndFunction

// Determining the "My Documents" directory of the current Windows user
//
&AtClient
Function AppDataDirectory()
	
	App = New COMObject("Shell.Application");
	Folder = App.Namespace(26);
	Result = Folder.Self.Path;
	Return CommonUseClientServer.AddFinalPathSeparator(Result);
	
EndFunction

// Checks whether a file or directory exists.
//
// Parameter:
//   PathToFile - String - file path or directory path to be checked.
//
// Returns:
//  Boolean - flag that shows whether the file or directory exists.
&AtClient
Function FileExistsOnClient(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist();
EndFunction

&AtClient
Procedure AfterConversionRulesCheckForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined And Result.Value = "Continue" Then
		
		ErrorDescription = True;
		PerformRuleImport(AdditionalParameters.StoredFileAddress, AdditionalParameters.FileName, ErrorDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseRuleImportForm(Result, AdditionalParameters) Export
	If Result <> Undefined And Result.Value = "Use" Then
		Close();
	EndIf;
EndProcedure

#EndRegion
