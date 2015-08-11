////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Loads rules into the register.
//
// Parameters:
// Cancel             - Boolean - cancel recording. 
// Record             - InformationRegisterRecord.DataExchangeRules - register record
//                      where data will be placed.
// TempStorageAddress - String - address of the temporary storage, from which XML rules
//                      will be loaded.
// RuleFileName       - String - Name of the file, from which XML rules will be loaded
//                      (it will also be written to the register).	
// BinaryData         - BinaryData - data, in which XML file is stored (including XML 
//                      files unpacked from a ZIP archive).
// IsArchive          - Boolean - flag that shows whether the rule file is packed in a 
//                      ZIP archive.
//
Procedure ImportRules(Cancel, Record, TempStorageAddress = "", RuleFileName = "", BinaryData = Undefined, IsArchive = False) Export
	
	// Checking whether record mandatory fields is filled
	CheckFieldsFilled(Cancel, Record);
	
	If Cancel Then
		Return;
	EndIf;
	
	If BinaryData = Undefined Then
		
		// Getting rule binary data from file or configuration template
		If Record.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate Then
			
			BinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.RuleTemplateName);
			
		Else
			
			BinaryData = GetFromTempStorage(TempStorageAddress);
			
		EndIf;
		
	EndIf;
	
	// If rules are packed into an archive, unpacking the archive and putting rules into the binary data
	If IsArchive Then
		
		// Getting the archive file from binary data
		TempArchiveName = GetTempFileName("zip");
		BinaryData.Write(TempArchiveName);
		TempArchiveFile = New File(TempArchiveName);
		
		// Extracting data from the archive
		TempFolderName = StrReplace(TempArchiveFile.FullName, TempArchiveFile.Extension, "");
		If DataExchangeServer.UnpackZipFile(TempArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// Putting the resulted rule file back into binary data
			If UnpackedFileList.Count() = 1 Then
				BinaryData = New BinaryData(UnpackedFileList[0].FullName);
				
			// Canceling load if the archive contains more than one file	
			ElsIf UnpackedFileList.Count() > 1 Then
				NString = NStr("en = 'During archive unpack, several files were found. The archive must contain only one rule file.'");
				DataExchangeServer.ReportError(NString, Cancel);
				
			// Canceling load if the archive contains no files	
			ElsIf UnpackedFileList.Count() = 0 Then
				NString = NStr("en = 'During archive unpack, no files was found. The archive must contain one rule file.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
		// Canceling load if unpacking the file failed
		Else
			NString = NStr("en = 'Failed unpacking the file.'");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// Deleting the temporary archive and the temporary directory where the archive was unpacked.
		DeleteTempFile(TempFolderName);
		DeleteTempFile(TempArchiveName);
			
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting the file of rules to be read
	BinaryData.Write(TempFileName);
	
	If Record.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
		
		// Reading conversion rules
		InfoBaseObjectConversion = DataProcessors.InfoBaseObjectConversion.Create();
		
		// Data processor properties
		InfoBaseObjectConversion.ExchangePlanInDEName = Record.ExchangePlanName;
		InfoBaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
		
		// Data processor methods
		ReadRulesAlready = InfoBaseObjectConversion.GetExchangeRuleStructure(TempFileName);
		
		RuleInfo = InfoBaseObjectConversion.GetRuleInformation();
		
		If InfoBaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
	Else // ObjectChangeRecordRules
		
		// Reading record rules
		LoadRecordRules = DataProcessors.ObjectChangeRecordRuleImport.Create();
		
		// Data processor properties
		LoadRecordRules.ExchangePlanNameForImport = Record.ExchangePlanName;
		
		// Data processor methods
		LoadRecordRules.ImportRules(TempFileName);
		
		ReadRulesAlready = LoadRecordRules.ObjectChangeRecordRules;
		
		RuleInfo = LoadRecordRules.GetRuleInformation();
		
		If LoadRecordRules.ErrorFlag Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
	// Deleting the temporary rule file
	DeleteTempFile(TempFileName);
	
	If Not Cancel Then
		
		Record.XMLRules = New ValueStorage(BinaryData, New Deflation());
		Record.ReadRulesAlready = New ValueStorage(ReadRulesAlready);
		
		Record.RuleInfo = RuleInfo;
		
		Record.RuleFileName = RuleFileName;
		
		Record.RulesLoaded = True;
		
		Record.ExchangePlanNameFromRules = Record.ExchangePlanName;
		
	EndIf;
	
EndProcedure

// Retrieves the read object conversion rules from the infobase for the exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - name of the exchange plan as a metadata object.
// 
// Returns:
//  ReadRulesAlready - ValueStorage - read object conversion rules.
//            		 - Undefined if conversion rules for the exchange plan were not loaded
//              	   into the infobase.  
//
Function GetReadObjectConversionRules(Val ExchangePlanName) Export
	
	// Return value
	ReadRulesAlready = Undefined;
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.ReadRulesAlready AS ReadRulesAlready
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.RulesLoaded
	|";
		
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		ReadRulesAlready = Selection.ReadRulesAlready;
		
	EndIf;
	
	Return ReadRulesAlready;
	
EndFunction

Procedure LoadRuleInformation(Cancel, TempStorageAddress, RuleInformationString) Export
	
	Var RuleKind;
	
	RuleInformationString = "";
	
	BinaryData = GetFromTempStorage(TempStorageAddress);
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting the file of rules to be read
	BinaryData.Write(TempFileName);
	
	GetRuleKindForDataExchange(RuleKind, TempFileName, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
		
		// Reading conversion rules
		InfoBaseObjectConversion = DataProcessors.InfoBaseObjectConversion.Create();
		
		InfoBaseObjectConversion.ImportExchangeRules(TempFileName, "XMLFile",, True);
		
		If InfoBaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
		If Not Cancel Then
			RuleInformationString = InfoBaseObjectConversion.GetRuleInformation();
		EndIf;
		
	Else // ObjectChangeRecordRules
		
		// Reading record rules
		LoadRecordRules = DataProcessors.ObjectChangeRecordRuleImport.Create();
		
		LoadRecordRules.ImportRules(TempFileName, True);
		
		If LoadRecordRules.ErrorFlag Then
			Cancel = True;
		EndIf;
		
		If Not Cancel Then
			RuleInformationString = LoadRecordRules.GetRuleInformation();
		EndIf;
		
	EndIf;
	
	// Deleting the temporary rule file
	DeleteTempFile(TempFileName);
	
EndProcedure

Function GetBinaryDataFromConfigurationTemplate(Cancel, ExchangePlanName, TemplateName)
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	ExchangePlanManager = DataExchangeCached.GetExchangePlanManagerByName(ExchangePlanName);
	
	// Getting the template of the standard rules
	Try
		RuleTemplate = ExchangePlanManager.GetTemplate(TemplateName);
	Except
		
		MessageString = NStr("en = 'Error retrieving the template of the %1 configuration for the %2 exchange plan.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, TemplateName, ExchangePlanName);
		DataExchangeServer.ReportError(MessageString, Cancel);
		Return Undefined;
		
	EndTry;
	
	RuleTemplate.Write(TempFileName);
	
	BinaryData = New BinaryData(TempFileName);
	
	// Deleting the temporary rule file
	DeleteTempFile(TempFileName);
	
	Return BinaryData;
EndFunction

Procedure DeleteTempFile(TempFileName)
	
	Try
		If Not IsBlankString(TempFileName) Then
			DeleteFiles(TempFileName);
		EndIf;
	Except
	EndTry;
	
EndProcedure

Procedure CheckFieldsFilled(Cancel, Record)
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		NString = NStr("en = 'Specify the exchange plan.'");
		
		DataExchangeServer.ReportError(NString, Cancel);
		
	ElsIf Record.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate
		    And IsBlankString(Record.RuleTemplateName) Then
		
		NString = NStr("en = 'Specify standard rules.'");
		
		DataExchangeServer.ReportError(NString, Cancel);
		
	EndIf;
	
EndProcedure

Procedure GetRuleKindForDataExchange(RuleKind, FileName, Cancel)
	
	// Opening the file to be read
	Try
		Rules = New XMLReader();
		Rules.OpenFile(FileName);
		Rules.Read();
	Except
		Rules = Undefined;
		
		NString = NStr("en = 'Failed to determine the rule kind because errors occurred during parsing the [FileName] XML file. 
		|Perhaps a wrong file is selected or the XML file has incorrect structure. Select the correct file.'");
		NString = StringFunctionsClientServer.SubstituteParametersInStringByName(NString, New Structure("FileName", FileName));
		DataExchangeServer.ReportError(NString, Cancel);
		Return;
	EndTry;
	
	If Rules.NodeType = XMLNodeType.StartElement Then
		
		If Rules.LocalName = "ExchangeRules" Then
			
			RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules;
			
		ElsIf Rules.LocalName = "RecordRules" Then
			
			RuleKind = Enums.DataExchangeRuleKinds.ObjectChangeRecordRules;
			
		Else
			
			NString = NStr("en = 'Failed to determine the rule kind because of errors in the [FileName] XML file format.
		|Perhaps a wrong file is selected or the XML file has incorrect structure. Select the correct file.'");
			NString = StringFunctionsClientServer.SubstituteParametersInStringByName(NString, New Structure("FileName", FileName));
			DataExchangeServer.ReportError(NString, Cancel);
			
		EndIf;
		
	Else
		
			NString = NStr("en = 'Failed to determine the rule kind because of errors in the [FileName] XML file format.
		|Perhaps a wrong file is selected or the XML file has incorrect structure. Select the correct file.'");
		NString = StringFunctionsClientServer.SubstituteParametersInStringByName(NString, New Structure("FileName", FileName));
		DataExchangeServer.ReportError(NString, Cancel);
		
	EndIf;
	
	Rules.Close();
	Rules = Undefined;
	
EndProcedure

// Adds the record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeRules");
	
EndProcedure







