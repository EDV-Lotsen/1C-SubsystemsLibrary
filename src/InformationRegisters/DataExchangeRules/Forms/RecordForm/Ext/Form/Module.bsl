////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UpdateExchangePlanChoiceList();
	
	UpdateRuleTemplateChoiceList();
	
	SetVisible();
	
	UpdateRuleInfo();
	
	UpdateRuleSource();
	
	DataExchangeRuleLoadingEventLogMessageText = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		
		// The cache of open sessions for the object registration mechanism became obsolet.
		DataExchangeServer.SetORMCachedValueRefreshDate();
		
		RefreshReusableValues();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ExchangePlanNameOnChange(Item)
	
	Record.RuleTemplateName = "";
	
	// Calling the server
	UpdateRuleTemplateChoiceList();
	
EndProcedure

&AtClient
Procedure RuleSourceOnChange(Item)
	
	// Calling the server
	SetVisible();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ImportRules(Command)
	
	Var TempStorageAddress;
	Var SelectedFileName;
	
	Cancel = False;
	
	RuleFileName = "";
	IsArchive = False;
	
	If RuleSource = 1 Then // loading from file

		CommonUseClient.SuggestFileSystemExtensionInstallationNow();
		
		If AttachFileSystemExtension()Then
			
			// Suggesting the user to select a file for loading rules
			Mode = FileDialogMode.Open;
			FileDialog = New FileDialog(Mode);
			FileExtension = Lower(Right(Record.RuleFileName, 4));
			FileNameWithoutExtension = StrReplace(Record.RuleFileName, FileExtension, "");
			FileDialog.FullFileName = FileNameWithoutExtension;
			Filter = NStr("en = 'Rule files'") + " (*.xml)|*.xml|"
			+ NStr("en = 'ZIP archives'") + " (*.zip)|*.zip";
			FileDialog.Filter = Filter;
			If Lower(Right(Record.RuleFileName, 4)) = ".zip" Then
				FileDialog.FilterIndex = 1;
			Else
				FileDialog.FilterIndex = 0;
			EndIf;
			FileDialog.Multiselect = False;
			FileDialog.Title = NStr("en = 'Select a file with rules to be imported.'");
			
			// Putting the file into the temporary storage to load it on the server in future if the file is selected. 
			If FileDialog.Choose() Then
				PutFile(TempStorageAddress, FileDialog.FullFileName, , False, UUID);
				RuleFileName = StrReplace(FileDialog.FullFileName, FileDialog.Directory, "");
				FileExtension = Lower(Right(FileDialog.FullFileName, 4));
				IsArchive = (FileExtension = ".zip");
			Else
				Return;
			EndIf; 
			
		Else
			Return;
		EndIf;
		
	EndIf;
	
	Status(NStr("en = 'Importing rules to the infobase...'"));
	
	// Importing rules on the server
	ImportRulesAtServer(Cancel, TempStorageAddress, RuleFileName, IsArchive);
	
	If Cancel Then
		
		NString = NStr("en = 'Error loading rules.
		|Do you want to open the event log?'"
		);
		
		
		
		
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.Yes Then
			
			Filter = New Structure;
			Filter.Insert("EventLogMessageText", DataExchangeRuleLoadingEventLogMessageText);
			OpenFormModal("DataProcessor.EventLogMonitor.Form", Filter, ThisForm);
			
		EndIf;
		
	Else
		
		DoMessageBox(NStr("en = 'Rules are successfully loaded into the infobase.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportRules(Command)
	
	CommonUseClient.SuggestFileSystemExtensionInstallationNow();
	
	If AttachFileSystemExtension() Then
		
		// Suggesting the user to select a file for unloading rules
		Mode = FileDialogMode.Save;
		FileDialog = New FileDialog(Mode);
		FileExtension = Lower(Right(Record.RuleFileName, 4));
		FileNameWithoutExtension = StrReplace(Record.RuleFileName, FileExtension, "");
		FileDialog.FullFileName = ?(IsBlankString(FileNameWithoutExtension), "DataExchangeRules", FileNameWithoutExtension);
		Filter = NStr("en = 'Rule files'") + "(*.xml)|*.xml|"
		+ NStr("en = 'ZIP archives'") + "(*.zip)|*.zip";
		FileDialog.Filter = Filter;
		If Lower(Right(Record.RuleFileName, 4)) = ".zip" Then
			FileDialog.FilterIndex = 1;
		Else
			FileDialog.FilterIndex = 0;
		EndIf;
		FileDialog.Multiselect = False;
		FileDialog.Title = NStr("en = 'Select a file where rules will be unload.'");
		
		// Saving the file if the path is specified
		If FileDialog.Choose() Then
			FileName = StrReplace(FileDialog.FullFileName, FileDialog.Directory, "");
			FileExtension = Lower(Right(FileDialog.FullFileName, 4));
			FileNameWithoutExtension = StrReplace(FileName, FileExtension, "");
			IsArchive = (FileExtension = ".zip");
			If IsArchive Then
				TempStorageAddress = GetRuleArchiveTempStorageAddressAtServer(FileNameWithoutExtension);
				If IsBlankString(TempStorageAddress) Then
					Return;
				Else
					BinaryData = GetFromTempStorage(TempStorageAddress);
					BinaryData.Write(FileDialog.FullFileName);				
				EndIf;
			Else
				TempStorageAddress = GetURLAtServer();
				GetFile(TempStorageAddress, FileDialog.FullFileName, False);
			EndIf;
		Else
			Return;
		EndIf;
		
	Else
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure RuleFileInfo(Command)
	
	DataExchangeClient.GetRuleInformation(UUID);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure UpdateExchangePlanChoiceList()
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	FillList(ExchangePlanList, Items.ExchangePlanName.ChoiceList);
	
EndProcedure

&AtServer
Procedure UpdateRuleTemplateChoiceList()
	
	If Record.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
		
		TemplateList = DataExchangeCached.GetStandardExchangeRuleList(Record.ExchangePlanName);
		
	Else // ObjectChangeRecordRules
		
		TemplateList = DataExchangeCached.GetStandardChangeRecordRuleList(Record.ExchangePlanName);
		
	EndIf;
	
	ChoiceList = Items.RuleTemplateName.ChoiceList;
	ChoiceList.Clear();
	
	FillList(TemplateList, ChoiceList);
	
EndProcedure

&AtServer
Procedure FillList(SourceList, TargetList)
	
	For Each Item In SourceList Do
		
		FillPropertyValues(TargetList.Add(), Item);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetVisible()
	
	// If the exchange plan was specified previously, it cannot be changed
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
	Items.GroupAdditional.Visible = (Record.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules);
	
	RuleSourcesGroup = Items.RuleSourcesGroup;
	
	RuleSourcesGroup.CurrentPage = ?(RuleSource = 0,
											RuleSourcesGroup.ChildItems.SourceConfigurationTemplate,
											RuleSourcesGroup.ChildItems.SourceFile
	);
	// Specifying the form title
	Title = String(Record.RuleKind);
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RuleFileName, IsArchive)
	
	Record.RuleSource = ?(RuleSource = 0, Enums.DataExchangeRuleSources.ConfigurationTemplate, Enums.DataExchangeRuleSources.File);
	
	Object = FormAttributeToValue("Record");
	
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TempStorageAddress, RuleFileName, , IsArchive);
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	
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
	
	// Creating a temporary directory on the server and generating paths to files and folders
	TempFileName = GetTempFileName();
	TempFile = New File(TempFileName);
	TempFolderName = StrReplace(TempFile.FullName, TempFile.Extension, "");
	CreateDirectory(TempFolderName);
	PathToFile = TempFolderName + "\" + FileName;
	
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
		
		NString = NStr("en = 'Failed to retrieve exchange rules.'");
		DataExchangeServer.ReportError(NString);
		Return "";
		
	Else
		
		Selection = Result.Choose();
		Selection.Next();
		
		// Getting, saving, and archiving the rule file from the temporary directory
		RuleBinaryData = Selection.XMLRules.Get();
		RuleBinaryData.Write(PathToFile + ".xml");
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", PathToFile + ".xml");
		
		// Putting the rule archive into the storage
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TempStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		Return TempStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	If Record.RuleSource = Enums.DataExchangeRuleSources.File Then
		
		RuleInfo = NStr("en = Note that if you load the rules from the file and then update the configuration,
               |the rules might stop working properly and you might have to correct them.
									|
									|[RuleInfo]'"
		);
		
		RuleInfo = StrReplace(RuleInfo, "[RuleInfo]", Record.RuleInfo);
		
	Else
		
		RuleInfo = Record.RuleInfo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateRuleSource()
	
	RuleSource = ?(Record.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate, 0, 1);
	
EndProcedure
