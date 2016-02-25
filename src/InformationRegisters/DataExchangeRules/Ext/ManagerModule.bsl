#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

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
Procedure ImportRules(Cancel, Record, TempStorageAddress = "", RuleFileName = "", IsArchive = False) Export
	
	// Checking whether record mandatory fields is filled
	CheckFieldsFilled(Cancel, Record);
	
	If Cancel Then
		Return;
	EndIf;
	
	IsConversionRules = (Record.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules);
	
	// Getting rule binary data from file or configuration template
	If Record.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate Then
		
		BinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.RuleTemplateName);
		
		If IsConversionRules Then
			
			If IsBlankString(Record.CorrespondentRuleTemplateName) Then
				Record.CorrespondentRuleTemplateName = Record.RuleTemplateName + "Correspondent";
			EndIf;
			CorrespondentBinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.CorrespondentRuleTemplateName);
			
		EndIf;
		
	Else
		
		BinaryData = GetFromTempStorage(TempStorageAddress);
		
	EndIf;
	
	// If rules are packed into an archive, unpacking the archive and putting rules into the binary data
	If IsArchive Then
		
		// Getting the archive file from binary data
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Extracting data from the archive
		TempFolderName = GetTempFileName("");
		If DataExchangeServer.UnpackZipFile(TemporaryArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// Canceling import if the archive contains no files
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("en = 'There is no rule file in the archive.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
			If IsConversionRules Then
				
				// Saving received file to the binary data
				If UnpackedFileList.Count() = 2 Then
					
					If UnpackedFileList[0].Name = "ExchangeRules.xml" 
						And UnpackedFileList[1].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[0].FullName);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[1].FullName);
						
					ElsIf UnpackedFileList[1].Name = "ExchangeRules.xml" 
						And UnpackedFileList[0].Name = "CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[1].FullName);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[0].FullName);
						
					Else
						
						NString = NStr("en = 'File names in the archive do not match expected file names. Required files:
							|ExchangeRules.xml, contains conversion rules for the current application.
							|CorrespondentExchangeRules.xml, contains conversion rules for the correspondent application.'");
						DataExchangeServer.ReportError(NString, Cancel);
						
					EndIf;
					
				// Obsolete format
				ElsIf UnpackedFileList.Count() = 1 Then
					NString = NStr("en = 'There is a single conversion rule file in the archive. This archive must contain two files. Required files:
						|ExchangeRules.xml, contains conversion rules for the current application.
						|CorrespondentExchangeRules.xml, contains conversion rules for the correspondent application.'");
					DataExchangeServer.ReportError(NString, Cancel);
				// There are several files in the archive, but a single file is expected. Canceling import.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("en = 'There are several files in the archive. This archive must contain a single rule file.'");
					DataExchangeServer.ReportError(NString, Cancel);
				EndIf;
				
			Else
				
				// Saving received file to the binary data
				If UnpackedFileList.Count() = 1 Then
					BinaryData = New BinaryData(UnpackedFileList[0].FullName);
					
				// There are several files in the archive, but a single file is expected. Canceling import.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("en = 'There are several files in the archive. This archive must contain a single rule file.'");
					DataExchangeServer.ReportError(NString, Cancel);
				EndIf;
				
			EndIf;
			
		Else // Canceling import if unpacking the file failed.
			NString = NStr("en = 'Failed unpacking the file.'");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// Deleting the temporary archive and the temporary directory where the archive was unpacked
		DeleteTempFile(TempFolderName);
		DeleteTempFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting the conversion rule file
	BinaryData.Write(TempFileName);
	
	If IsConversionRules Then
		
		// Reading conversion rules
		InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
		
		// Data processor properties
		InfobaseObjectConversion.ExchangeMode = "Export";
		InfobaseObjectConversion.ExchangePlanInDEName = Record.ExchangePlanName;
		InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
		
		DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, Record.ExchangePlanName, Record.DebugMode);
		
		// Data processor methods
		ReadRulesAlready = InfobaseObjectConversion.GetStructureRulesExchange(TempFileName);
		
		CompatibilityMode = False;
		RuleInfo = InfobaseObjectConversion.GetRuleInformation(False, CompatibilityMode);
		
		If InfobaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
		// Getting the temporary file name in the local file system on the server
		CorrespondentTempFileName = GetTempFileName("xml");
		// Getting the conversion rule file
		CorrespondentBinaryData.Write(CorrespondentTempFileName);
		
		// Reading conversion rules
		InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
		
		// Data processor properties
		InfobaseObjectConversion.ExchangeMode = "Import";
		InfobaseObjectConversion.ExchangePlanInDEName = Record.ExchangePlanName;
		InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
		
		// Data processor methods
		ReadCorrespondentRules = InfobaseObjectConversion.GetStructureRulesExchange(CorrespondentTempFileName);
		
		CorrespondentCompatibilityMode = False;
		CorrespondentRuleInfo = InfobaseObjectConversion.GetRuleInformation(
			True, CorrespondentCompatibilityMode);
		
		If InfobaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
 		RuleInfo = RuleInfo + Chars.LF + Chars.LF + CorrespondentRuleInfo;
		
	Else // ObjectChangeRecordRules
		
		// Reading registration rules
		ChangeRecordRuleImport = DataProcessors.ObjectChangeRecordRuleImport.Create();
		
		// Data processor properties
		ChangeRecordRuleImport.ExchangePlanNameForImport = Record.ExchangePlanName;
		
		// Data processor methods
		ChangeRecordRuleImport.ImportRules(TempFileName);
		
		ReadRulesAlready = ChangeRecordRuleImport.ObjectChangeRecordRules;
		
		RuleInfo = ChangeRecordRuleImport.GetRuleInformation();
		
		If ChangeRecordRuleImport.ErrorFlag Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
	// Deleting the temporary rule file
	DeleteTempFile(TempFileName);
	
	If Not Cancel Then
		
		Record.XMLRules         = New ValueStorage(BinaryData, New Deflation());
		Record.ReadRulesAlready = New ValueStorage(ReadRulesAlready);
		
		If IsConversionRules Then
			
			Record.XMLCorrespondentRules  = New ValueStorage(CorrespondentBinaryData, New Deflation());
			Record.ReadCorrespondentRules = New ValueStorage(ReadCorrespondentRules);
			If CompatibilityMode <> CorrespondentCompatibilityMode Then
				Raise NStr("en = 'The compatibility mode of the current configuration does not match the correspondent configuration compatibility mode.'");
			Else
				Record.CompatibilityMode = CompatibilityMode;
			EndIf;
			
		EndIf;
		
		Record.RuleInfo = RuleInfo;
		Record.RuleFileName = RuleFileName;
		Record.RulesLoaded = True;
		Record.ExchangePlanNameFromRules = Record.ExchangePlanName;
		
	EndIf;
	
EndProcedure

Procedure ImportRuleSet(Cancel, DataToRecord, ErrorDescription, TempStorageAddress = "", RuleFileName = "") Export
	
	CovnersionRuleWriting   = DataToRecord.CovnersionRuleWriting;
	RegistrationRuleWriting = DataToRecord.RegistrationRuleWriting;
	
	// Getting binary data from the file or from the configuration template
	If CovnersionRuleWriting.RuleSource = Enums.DataExchangeRuleSources.ConfigurationTemplate Then
		
		BinaryData              = GetBinaryDataFromConfigurationTemplate(Cancel, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.RuleTemplateName);
		CorrespondentBinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.CorrespondentRuleTemplateName);
		RegistrationBinaryData  = GetBinaryDataFromConfigurationTemplate(Cancel, RegistrationRuleWriting.ExchangePlanName, RegistrationRuleWriting.RuleTemplateName);
		
	Else
		
		BinaryData = GetFromTempStorage(TempStorageAddress);
		
	EndIf;
	
	If CovnersionRuleWriting.RuleSource = Enums.DataExchangeRuleSources.File Then
		
		// Getting the archive file from binary data
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Extracting data from the archive
		TempFolderName = GetTempFileName("");
		If DataExchangeServer.UnpackZipFile(TemporaryArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// Canceling import if the archive contains no files
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("en = 'There is no rule file in the archive.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
			// Number of files in the archive does not match the expected number. Canceling import.
			If UnpackedFileList.Count() <> 3 Then
				NString = NStr("en = 'Incorrect format of the rule set. This archive must contain three files. Required files:
					|ExchangeRules.xml, contains conversion rules for the current application.
					|CorrespondentExchangeRules.xml, contains conversion rules for the correspondent application.
					|RegistrationRules.xml, contains registration rules for the current application.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
				
			// Saving received file to the binary data
			For Each ReceivedFile In UnpackedFileList Do
				
				If ReceivedFile.Name = "ExchangeRules.xml" Then
					BinaryData = New BinaryData(ReceivedFile.FullName);
				ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
					CorrespondentBinaryData = New BinaryData(ReceivedFile.FullName);
				ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
					RegistrationBinaryData = New BinaryData(ReceivedFile.FullName);
				Else
					NString = NStr("en = 'File names in the archive do not match expected file names. Required files:
						|ExchangeRules.xml, contains conversion rules for the current application.
						|CorrespondentExchangeRules.xml, contains conversion rules for the correspondent application.
						|RegistrationRules.xml, contains registration rules for the current application.'");
					DataExchangeServer.ReportError(NString, Cancel);
					Break;
				EndIf;
				
			EndDo;
			
		Else 
			// Canceling import if unpacking the file failed
			NString = NStr("en = 'Failed unpacking the file.'");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// Deleting the temporary archive and the temporary directory where the archive was unpacked
		DeleteTempFile(TempFolderName);
		DeleteTempFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	ConversionRuleInfo = "[SourceRuleInfo] [CorrespondentRuleInfo]";
		
	// Getting the temporary conversion file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting the conversion rule file
	BinaryData.Write(TempFileName);
	
	// Reading conversion rules
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	// Data processor properties
	InfobaseObjectConversion.ExchangeMode = "Data";
	InfobaseObjectConversion.ExchangePlanInDEName = CovnersionRuleWriting.ExchangePlanName;
	InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
	DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.DebugMode);
	
	// Data processor methods
	If CovnersionRuleWriting.RuleSource = Enums.DataExchangeRuleSources.File And ErrorDescription = Undefined
		And Not ConversionRulesCompatibleWithCurrentApplicationVersion(CovnersionRuleWriting.ExchangePlanName, ErrorDescription, RuleInfoFromFile(TempFileName)) Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	ReadRulesAlready = InfobaseObjectConversion.GetStructureRulesExchange(TempFileName);
	
	CompatibilityMode = False;
	SourceRuleInfo = InfobaseObjectConversion.GetRuleInformation(False, CompatibilityMode);
	
	If InfobaseObjectConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	// Getting name of the temporary correspondent conversion file in the local file system on the server
	CorrespondentTempFileName = GetTempFileName("xml");
	// Getting the conversion rule file
	CorrespondentBinaryData.Write(CorrespondentTempFileName);
	
	// Reading conversion rules
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	// Data processor properties
	InfobaseObjectConversion.ExchangeMode = "Import";
	InfobaseObjectConversion.ExchangePlanInDEName = CovnersionRuleWriting.ExchangePlanName;
	InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleLoadingEventLogMessageText();
	
	// Data processor methods
	ReadCorrespondentRules = InfobaseObjectConversion.GetStructureRulesExchange(CorrespondentTempFileName);
	
	CorrespondentCompatibilityMode = False;
	CorrespondentRuleInfo = InfobaseObjectConversion.GetRuleInformation(
		True, CorrespondentCompatibilityMode);
	
	If InfobaseObjectConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	ConversionRuleInfo = StrReplace(ConversionRuleInfo, "[SourceRuleInfo]", SourceRuleInfo);
	ConversionRuleInfo = StrReplace(ConversionRuleInfo, "[CorrespondentRuleInfo]", CorrespondentRuleInfo);
	
	// Getting the temporary registration file name in the local file system on the server
	TempRegistrationFileName = GetTempFileName("xml");
	// Getting the registration rule file
	RegistrationBinaryData.Write(TempRegistrationFileName);

	
	// Reading registration rules
	ChangeRecordRuleImport = DataProcessors.ObjectChangeRecordRuleImport.Create();
	
	// Data processor properties
	ChangeRecordRuleImport.ExchangePlanNameForImport = RegistrationRuleWriting.ExchangePlanName;
	
	// Data processor methods
	ChangeRecordRuleImport.ImportRules(TempRegistrationFileName);
	ReadRegistrationRules = ChangeRecordRuleImport.ObjectChangeRecordRules;
	RegistrationRuleInfo  = ChangeRecordRuleImport.GetRuleInformation();
	
	If ChangeRecordRuleImport.ErrorFlag Then
		Cancel = True;
	EndIf;
	
	// Deleting temporary rule files
	DeleteTempFile(TempFileName);
	DeleteTempFile(CorrespondentTempFileName);
	DeleteTempFile(TempRegistrationFileName);
	
	If Not Cancel Then
		
		// Writing conversion rules 
		CovnersionRuleWriting.XMLRules                  = New ValueStorage(BinaryData, New Deflation());
		CovnersionRuleWriting.ReadRulesAlready          = New ValueStorage(ReadRulesAlready);
		CovnersionRuleWriting.XMLCorrespondentRules     = New ValueStorage(CorrespondentBinaryData, New Deflation());
		CovnersionRuleWriting.ReadCorrespondentRules    = New ValueStorage(ReadCorrespondentRules);
		CovnersionRuleWriting.RuleInfo                  = ConversionRuleInfo;
		CovnersionRuleWriting.RuleFileName              = RuleFileName;
		CovnersionRuleWriting.RulesLoaded               = True;
		CovnersionRuleWriting.ExchangePlanNameFromRules = CovnersionRuleWriting.ExchangePlanName;
		
		If CompatibilityMode <> CorrespondentCompatibilityMode Then
			Raise NStr("en = 'The compatibility mode of the current configuration does not match the correspondent configuration compatibility mode.'");
		Else
			CovnersionRuleWriting.CompatibilityMode = CompatibilityMode;
		EndIf;
		
		// Writing registration rules
		RegistrationRuleWriting.XMLRules                  = New ValueStorage(RegistrationBinaryData, New Deflation());
		RegistrationRuleWriting.ReadRulesAlready          = New ValueStorage(ReadRegistrationRules);
		RegistrationRuleWriting.RuleInfo                  = RegistrationRuleInfo;
		RegistrationRuleWriting.RuleFileName              = RuleFileName;
		RegistrationRuleWriting.RulesLoaded               = True;
		RegistrationRuleWriting.ExchangePlanNameFromRules = RegistrationRuleWriting.ExchangePlanName;
		
	EndIf;
	
EndProcedure

// Retrieves the read object conversion rules from the infobase for the exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - name of the exchange plan as a metadata object.
// 
// Returns:
//  ReadRulesAlready - ValueStorage - read object conversion rules.
//  Undefined        - if conversion rules for the exchange plan were not loaded into the infobase.
//
Function GetReadObjectConversionRules(Val ExchangePlanName, GetCorrespondentRules = False) Export
	
	// Return value
	ReadRulesAlready = Undefined;
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.%1 AS ReadRulesAlready
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind      = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.RulesLoaded
	|";
	
	QueryText = StringFunctionsClientServer.SubstituteParametersInString(QueryText,
		?(GetCorrespondentRules, "ReadCorrespondentRules", "ReadRulesAlready"));
	
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

Function RulesFromFileUsed(ExchangePlanName, DetailedResult = False) Export
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RuleKind AS RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RuleSource = VALUE(Enum.DataExchangeRuleSources.File)
	|	AND DataExchangeRules.RulesLoaded
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	Result = Query.Execute();
	
	If DetailedResult Then
		
		RulesFromFile = New Structure("RecordRules, ConversionRules", False, False);
		
		Selection = Result.Select();
		While Selection.Next() Do
			If Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
				RulesFromFile.ConversionRules = True;
			ElsIf Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectChangeRecordRules Then
				RulesFromFile.RecordRules = True;
			EndIf;
		EndDo;
		
		Return RulesFromFile;
		
	Else
		Return Not Result.IsEmpty();
	EndIf;
	
EndFunction

Procedure LoadRuleInformation(Cancel, TempStorageAddress, RuleInformationString) Export
	
	Var RuleKind;
	
	RuleInformationString = "";
	
	BinaryData = GetFromTempStorage(TempStorageAddress);
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting the conversion rule file
	BinaryData.Write(TempFileName);
	
	GetRuleKindForDataExchange(RuleKind, TempFileName, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
		
		// Reading conversion rules
		InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
		
		InfobaseObjectConversion.ImportExchangeRules(TempFileName, "XMLFile",, True);
		
		If InfobaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
		If Not Cancel Then
			RuleInformationString = InfobaseObjectConversion.GetRuleInformation();
		EndIf;
		
	Else // ObjectChangeRecordRules
		
		// Reading registration rules
		ChangeRecordRuleImport = DataProcessors.ObjectChangeRecordRuleImport.Create();
		
		ChangeRecordRuleImport.ImportRules(TempFileName, True);
		
		If ChangeRecordRuleImport.ErrorFlag Then
			Cancel = True;
		EndIf;
		
		If Not Cancel Then
			RuleInformationString = ChangeRecordRuleImport.GetRuleInformation();
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
	
	// Opening the file for reading
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

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeRules");
	
EndProcedure

Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	ImportedRules = ImportedRules();
	
	While ImportedRules.Next() Do
		
		RequestToUseExternalResources(PermissionRequests, ImportedRules);
		
	EndDo;
	
EndProcedure

Function ImportedRules()
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	DataExchangeRules.RuleSource,
	|	DataExchangeRules.RuleKind,
	|	DataExchangeRules.CompatibilityMode,
	|	DataExchangeRules.DebugMode,
	|	DataExchangeRules.ExportDebugMode,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ImportDebugMode,
	|	DataExchangeRules.ImportDebuggingDataProcessorFileName,
	|	DataExchangeRules.DataExchangeLoggingMode,
	|	DataExchangeRules.ExchangeLogFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesLoaded = TRUE";
	
	QueryResult = Query.Execute();
	Return QueryResult.Select();
	
EndFunction

Function RuleInfoFromFile(RuleFileName)
	
	ExchangeRules = New XMLReader();
	ExchangeRules.OpenFile(RuleFileName);
	ExchangeRules.Read();
	
	If Not ((ExchangeRules.LocalName = "ExchangeRules") And (ExchangeRules.NodeType = XMLNodeType.StartElement)) Then
		Raise NStr("en = 'Exchange rule format error'");
	EndIf;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" And ExchangeRules.NodeType = XMLNodeType.StartElement Then
			
			RuleInfo = New Structure;
			RuleInfo.Insert("ConfigurationVersion", ExchangeRules.GetAttribute("ConfigurationVersion"));
			RuleInfo.Insert("ConfigurationSynonymInRules", ExchangeRules.GetAttribute("ConfigurationSynonym"));
			ExchangeRules.Read();
			RuleInfo.Insert("ConfigurationName", ExchangeRules.Value);
			
		ElsIf (NodeName = "Source") And (ExchangeRules.NodeType = XMLNodeType.EndElement) Then
			
			ExchangeRules.Close();
			Return RuleInfo;
			
		EndIf;
		
	EndDo;
	
	Raise NStr("en = 'Exchange rule format error.'");
	
EndFunction

Procedure RequestToUseExternalResources(PermissionRequests, Record) Export
	
	Permissions = New Array;
	
	If Record.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
		
		If (Not Record.CompatibilityMode Or CommonUseCached.DataSeparationEnabled()) And Not Record.DebugMode Then
			// Requesting the personal profile is not required
		Else
			
			Permissions.Add(SafeMode.PermissionToUsePrivilegedMode());
			
			If Record.DebugMode Then
				
				If Record.ExportDebugMode Then
					
					FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
						FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.ImportDebugMode Then
					
					FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
						FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.DataExchangeLoggingMode Then
					
					FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
						FileNameStructure.Path, True, True));
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else // Registration rules
		
		If Record.RuleSource = Enums.DataExchangeRuleSources.File Then
			Permissions.Add(SafeMode.PermissionToUsePrivilegedMode());
		Else
			// Rules are executed under the configuration profile
		EndIf;
		
	EndIf;
	
	ExchangePlanID = CommonUse.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
	
	CommonUseClientServer.SupplementArray(PermissionRequests,
		SafeModeInternal.ExternalResourceRequestsForExternalModule(ExchangePlanID, Permissions));
	
EndProcedure

Function ConversionRulesCompatibleWithCurrentApplicationVersion(ExchangePlanName, ErrorDescription, RuleData)
	
	If Not DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch") Then
		Return True;
	EndIf;
	
	If RuleData.ConfigurationName <> Metadata.Name Then
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorText", NStr("en = 'The rules cannot be imported because they are intended for the %1 application. Use the rules from the configuration or import the appropriate rule set from a file.'"));
		ErrorDescription.ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription.ErrorText,
		RuleData.ConfigurationSynonymInRules);
		ErrorDescription.Insert("ErrorKind", "IncorrectConfiguration");
		ErrorDescription.Insert("Picture", PictureLib.Error32);
		Return False;
		
	EndIf;
	
	VersionInRulesWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(RuleData.ConfigurationVersion);
	ConfigurationVersionWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(Metadata.Version);
	ComparisonResult = DataExchangeServer.CompareVersionsWithoutAssemblyNumbers(VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
	
	If ComparisonResult <> 0 Then
		
		If ComparisonResult < 0 Then
			
			ErrorText = NStr("en = 'Synchronization may be completed incorrectly because you are importing rules that are intended for the previous application version %1 (%2). We recommend that you use rules from the configuration or import the rule set that is intended for the current application version (%3).'");
			ErrorKind = "ObsoleteConfigurationVersion";
			
		Else
			
			ErrorText = NStr("en = 'Synchronization may be completed incorrectly because you are importing rules that are intended for the newer application version %1 (%2). We recommend that you update the application or use the rule set that is intended for the current application version (%3).'");
			ErrorKind = "ObsoleteRules";
			
		EndIf;
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, Metadata.Synonym,
			VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorText", ErrorText);
		ErrorDescription.Insert("ErrorKind", ErrorKind);
		ErrorDescription.Insert("Picture",   PictureLib.Warning32);
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	If FormType = "RecordForm" Then
		
		StandardProcessing = False;
		
		If Parameters.Key.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectConversionRules";
			
		ElsIf Parameters.Key.RuleKind = Enums.DataExchangeRuleKinds.ObjectChangeRecordRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectChangeRecordRules";
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
