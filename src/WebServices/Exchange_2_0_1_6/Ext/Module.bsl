
#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

// Matches the Upload web service operation
Function ExecuteExport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfobaseNodeViaString(MessageExchangeInternal.ConvertExchangePlanName(ExchangePlanName), InfobaseNodeCode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
EndFunction

// Matches the Download web service operation
Function ExecuteImport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfobaseNodeViaString(MessageExchangeInternal.ConvertExchangePlanName(ExchangePlanName), InfobaseNodeCode, MessageExchangeInternal.ConvertExchangePlanMessageData(ExchangeMessageStorage.Get()));
	
EndFunction

// Matches the UploadData web service operation
Function ExecuteDataExport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDString,
								LongAction,
								ActionID,
								LongActionAllowed)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID;
	FileIDString = String(FileID);
	
	If CommonUse.FileInfobase() Then
		
		DataExchangeServer.ExportToFileTransferServiceForInfobaseNode(ExchangePlanName, InfobaseNodeCode, FileID);
		
	Else
		
		ExecuteDataExportInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, LongAction, ActionID, LongActionAllowed);
		
	EndIf;
	
EndFunction

// Matches the DownloadData web service operation
Function ExecuteDataImport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDString,
								LongAction,
								ActionID,
								LongActionAllowed)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID(FileIDString);
	
	If CommonUse.FileInfobase() Then
		
		DataExchangeServer.ImportForInfobaseNodeFromFileTransferService(ExchangePlanName, InfobaseNodeCode, FileID);
		
	Else
		
		ImportDataInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, LongAction, ActionID, LongActionAllowed);
		
	EndIf;
	
EndFunction

// Matches the GetInfobaseParameters web service operation
Function GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage)
	
	Result = DataExchangeServer.InfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage);
	Return XDTOSerializer.WriteXDTO(Result);
	
EndFunction

// Matches the GetIBData web service operation
Function GetInfobaseData(FullTableName)
	
	Return XDTOSerializer.WriteXDTO(DataExchangeServer.CorrespondentData(FullTableName));
	
EndFunction

// Matches the GetCommonNodsData web service operation
Function GetCommonNodeData(ExchangePlanName)
	
	SetPrivilegedMode(True);
	
	Return XDTOSerializer.WriteXDTO(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// Matches the CreateExchange web service operation
Function CreateDataExchange(ExchangePlanName, ParameterString, FilterSettingsXDTO, DefaultValuesXDTO)
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	// Creating an instance of exchange setup wizard data processor
	DataExchangeCreationWizard = DataProcessors.DataExchangeCreationWizard.Create();
	DataExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
	
	Cancel = False;
	
	// Loading wizard parameters from a string to the wizard data processor
	DataExchangeCreationWizard.ImportWizardParameters(Cancel, ParameterString);
	
	If Cancel Then
		Message = NStr("en = 'Errors occurred in the second infobase during the data exchange setup: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
		Raise Message;
	EndIf;
	
	DataExchangeCreationWizard.WizardRunVariant = "ContinueDataExchangeSetup";
	DataExchangeCreationWizard.IsDistributedInfobaseSetup = False;
	DataExchangeCreationWizard.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS;
	DataExchangeCreationWizard.SourceInfobasePrefixIsSet = ValueIsFilled(GetFunctionalOption("InfobasePrefix"));
	
	// Data exchange setup
	DataExchangeCreationWizard.SetUpNewDataExchangeWebService(
											Cancel,
											XDTOSerializer.ReadXDTO(FilterSettingsXDTO),
											XDTOSerializer.ReadXDTO(DefaultValuesXDTO));
	
	If Cancel Then
		Message = NStr("en = 'Errors occurred in the second infobase during the data exchange setup: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
		Raise Message;
	EndIf;
	
EndFunction

// Matches the UpdateExchange web service operation
Function UpdateDataExchangeSettings(ExchangePlanName, NodeCode, DefaultValuesXDTO)
	
	DataExchangeServer.ExternalConnectionRefreshExchangeSettingsData(ExchangePlanName, NodeCode, XDTOSerializer.ReadXDTO(DefaultValuesXDTO));
	
EndFunction

// Matches the RegisterOnlyCatalogData web service operation
Function RecordCatalogChangesOnly(ExchangePlanName, NodeCode, LongAction, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongAction, ActionID, True);
	
EndFunction

// Matches the RegisterAllDataExceptCatalogs web service operation
Function RecordAllChangesExceptCatalogs(ExchangePlanName, NodeCode, LongAction, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongAction, ActionID, False);
	
EndFunction

// Matches the GetLongActionState web service operation
Function GetLongActionState(ActionID, ErrorMessageString)
	
	BackgroundJobState = New Map;
	BackgroundJobState.Insert(BackgroundJobState.Active,    "Active");
	BackgroundJobState.Insert(BackgroundJobState.Completed, "Completed");
	BackgroundJobState.Insert(BackgroundJobState.Failed,    "Failed");
	BackgroundJobState.Insert(BackgroundJobState.Canceled,  "Canceled");
	
	SetPrivilegedMode(True);
	
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(ActionID));
	
	If BackgroundJob.ErrorInfo <> Undefined Then
		
		ErrorMessageString = DetailErrorDescription(BackgroundJob.ErrorInfo);
		
	EndIf;
	
	Return BackgroundJobState.Get(BackgroundJob.State);
EndFunction

// Matches the GetFunctionalOption web service operation
Function GetFunctionalOptionValue(Name)
	
	Return GetFunctionalOption(Name);
	
EndFunction

// Matches the PrepareGetFile web service operation
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity)
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	File = New File(SourceFileName);
	
	SourceFileNameInTemporaryDirectory = CommonUseClientServer.GetFullFileName(TemporaryDirectory, File.Name);
	SharedFileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	CreateDirectory(TemporaryDirectory);
	
	MoveFile(SourceFileName, SourceFileNameInTemporaryDirectory);
	
	Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(SourceFileNameInTemporaryDirectory);
	Archiver.Write();
	
	If BlockSize <> 0 Then
		// Splitting file into volumes		
   FileNames = SplitFile(SharedFileName, BlockSize * 1024);
		PartQuantity = FileNames.Count();
	Else
		PartQuantity = 1;
		MoveFile(SharedFileName, SharedFileName + ".1");
	EndIf;
	
EndFunction

// Matches the GetFilePart web service operation
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FileNames = FindPartFile(TemporaryExportDirectory(TransferId), PartNumber);
	
	If FileNames.Count() = 0 Then
		
		MessagePattern = NStr("en = 'Volume %1 is not found in the transfer session with the following ID: %2.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	ElsIf FileNames.Count() > 1 Then
		
		MessagePattern = NStr("en = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	EndIf;
	
	FileNamePart = FileNames[0].FullName;
	PartData = New BinaryData(FileNamePart);
	
EndFunction

// Matches the ReleaseFile web service operation
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Matches the PutFilePart web service operation
Function PutFilePart(TransferId, PartNumber, PartData)
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TemporaryDirectory);
		
	EndIf;
	
	FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
EndFunction

// Matches the SaveFileFromParts web service operation
Function SaveFileFromParts(TransferId, PartQuantity, FileId)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	PartFilesToMerge = New Array;
	
	For PartNumber = 1 To PartQuantity Do
		
		FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessagePattern = NStr("en = 'Volume %1 is not found in the transfer session with the following ID: %2.
					|Ensure that the ""Linux synchronization message directory"" and ""Windows synchronization message directory"" parameters are set in the application settings.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
			Raise(MessageText);
		EndIf;
		
		PartFilesToMerge.Add(FileName);
		
	EndDo;
	
	ArchiveName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	MergeFiles(PartFilesToMerge, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	
	If Dearchiver.Items.Count() = 0 Then
		Try
			DeleteFiles(TemporaryDirectory);
		Except
			WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise(NStr("en = 'The archive file does not contain data.'"));
	EndIf;
	
	ExportDirectory = DataExchangeCached.TempFileStorageDirectory();
	
	FileName = CommonUseClientServer.GetFullFileName(ExportDirectory, Dearchiver.Items[0].Name);
	
	Dearchiver.Extract(Dearchiver.Items[0], ExportDirectory);
	Dearchiver.Close();
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
	Try
		DeleteFiles(TemporaryDirectory);
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Matches the PutFileIntoStorage web service operation
Function PutFileIntoStorage(FileName, FileId)
	
	SetPrivilegedMode(True);
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
EndFunction

// Matches the GetFileFromStorage web service operation
Function GetFileFromStorage(FileId)
	
	SetPrivilegedMode(True);
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	File = New File(SourceFileName);
	
	Return File.Name;
EndFunction

// Matches the FileExists web service operation
Function FileExists(FileName)
	
	SetPrivilegedMode(True);
	
	TempFileFullName = CommonUseClientServer.GetFullFileName(DataExchangeCached.TempFileStorageDirectory(), FileName);
	
	File = New File(TempFileFullName);
	
	Return File.Exist();
EndFunction

// Matches the Ping web service operation
Function Ping()
	// Checking connection
	Return "";
EndFunction

// Matches the TestConnection web service operation
Function TestConnection(ExchangePlanName, NodeCode, Result)
	
	// Checking whether a user has rights to perform the data exchange
	Try
		DataExchangeServer.CheckCanSynchronizeData();
	Except
		Result = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// Checking whether the infobase is locked for updating
	Try
		CheckInfobaseLockForUpdate();
	Except
		Result = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	SetPrivilegedMode(True);
	
	// Checking whether the exchange plan node exists (it might be deleted)
	If ExchangePlans[ExchangePlanName].FindByCode(NodeCode).IsEmpty() Then
		Result = NStr("en = 'Data synchronization is disabled by the administrator.'");
		Return False;
	EndIf;
	
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

Procedure CheckInfobaseLockForUpdate()
	
	If ValueIsFilled(InfobaseUpdateInternal.InfobaseLockedForUpdate()) Then
		
		Raise NStr("en = 'Data synchronization is unavailable for the duration of Internet-based update.'");
		
	EndIf;
	
EndProcedure

Procedure ExecuteDataExportInClientServerMode(ExchangePlanName,
														InfobaseNodeCode,
														FileID,
														LongAction,
														ActionID,
														LongActionAllowed)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(InfobaseNodeCode);
	Parameters.Add(FileID);
	
	BackgroundJobKey = ImportExportDataBackgroundJobKey(ExchangePlanName, InfobaseNodeCode);
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("Status", BackgroundJobState.Active);
	If BackgroundJobs.GetBackgroundJobs (Filter).Count() = 1 Then
		Raise NStr("en = 'Synchronization in progress.'");
	EndIf;
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ExportToFileTransferServiceForInfobaseNode",
										Parameters,
										BackgroundJobKey,
										NStr("en = 'Data exchange through a web service.'"));
	
	Try
		Timeout = ?(LongActionAllowed, 5, Undefined);
		
		BackgroundJob.WaitForCompletion(Timeout);
	Except
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
		
		If BackgroundJob.State = BackgroundJobState.Active Then
			
			ActionID = String(BackgroundJob.UUID);
			LongAction = True;
			Return;
			
		Else
			
			If BackgroundJob.ErrorInfo <> Undefined Then
				Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
			EndIf;
			
			Raise;
		EndIf;
		
	EndTry;
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
	
	If BackgroundJob.State <> BackgroundJobState.Completed Then
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		
		Raise NStr("en = 'An error occurred during the data export through the web service.'");
	EndIf;
	
EndProcedure

Procedure ImportDataInClientServerMode(ExchangePlanName,
													InfobaseNodeCode,
													FileID,
													LongAction,
													ActionID,
													LongActionAllowed)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(InfobaseNodeCode);
	Parameters.Add(FileID);
	
	BackgroundJobKey = ImportExportDataBackgroundJobKey(ExchangePlanName, InfobaseNodeCode);
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("Status", BackgroundJobState.Active);
	If BackgroundJobs.GetBackgroundJobs (Filter).Count() = 1 Then
		Raise NStr("en = 'Synchronization in progress.'");
	EndIf;
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ImportForInfobaseNodeFromFileTransferService",
										Parameters,
										BackgroundJobKey,
										NStr("en = 'Data exchange through a web service.'"));
	
	Try
		Timeout = ?(LongActionAllowed, 5, Undefined);
		
		BackgroundJob.WaitForCompletion(Timeout);
	Except
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
		
		If BackgroundJob.State = BackgroundJobState.Active Then
			
			ActionID = String(BackgroundJob.UUID);
			LongAction = True;
			Return;
			
		Else
			
			If BackgroundJob.ErrorInfo <> Undefined Then
				Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
			EndIf;
			Raise;
		EndIf;
		
	EndTry;
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
	
	If BackgroundJob.State <> BackgroundJobState.Completed Then
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		
		Raise NStr("en = 'An error occurred during the data import through the web service.'");
	EndIf;
	
EndProcedure

Function ImportExportDataBackgroundJobKey(ExchangePlan, NodeCode)
	
	Key = "ExchangePlan:[ExchangePlan] NodeCode:[NodeCode]";
	Key = StrReplace(Key, "[ExchangePlan]", ExchangePlan);
	Key = StrReplace(Key, "[NodeCode]", NodeCode);
	
	Return Key;
EndFunction

Function RegisterDataForInitialExport(Val ExchangePlanName, Val NodeCode, LongAction, ActionID, CatalogsOnly)
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("en = 'Exchange plan node not found. Node name: %1, node code: %2.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	If CommonUse.FileInfobase() Then
		
		If CatalogsOnly Then
			
			DataExchangeServer.RegisterOnlyCatalogsForInitialExport(InfobaseNode);
			
		Else
			
			DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport(InfobaseNode);
			
		EndIf;
		
	Else
		
		If CatalogsOnly Then
			MethodName = "DataExchangeServer.RegisterOnlyCatalogsForInitialExport";
		Else
			MethodName = "DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport";
		EndIf;
		
		Parameters = New Array;
		Parameters.Add(InfobaseNode);
		
		BackgroundJob = BackgroundJobs.Execute(MethodName, Parameters,, NStr("en = 'Data exchange setup.'"));
		
		Try
			BackgroundJob.WaitForCompletion(5);
		Except
			
			BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
			
			If BackgroundJob.State = BackgroundJobState.Active Then
				
				ActionID = String(BackgroundJob.UUID);
				LongAction = True;
				
			Else
				If BackgroundJob.ErrorInfo <> Undefined Then
					Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
				EndIf;
				
				Raise;
			EndIf;
			
		EndTry;
		
	EndIf;
	
EndFunction

Function GetPartFileName(PartNumber)
	
	Result = "data.zip.[n]";
	
	Return StrReplace(Result, "[n]", Format(PartNumber, "NG=0"));
EndFunction

Function TemporaryExportDirectory(Val SessionID)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = "{SessionID}";
	TemporaryDirectory = StrReplace(TemporaryDirectory, "SessionID", String(SessionID));
	
	Result = CommonUseClientServer.GetFullFileName(DataExchangeCached.TempFileStorageDirectory(), TemporaryDirectory);
	
	Return Result;
EndFunction

Function FindPartFile(Val Directory, Val FileNumber)
	
	For DigitNumber = NumberDigitNumber(FileNumber) To 5 Do
		
		FormatString = StringFunctionsClientServer.SubstituteParametersInString("ND=%1; NLZ=; NG=0", String(DigitNumber));
		
		FileName = StringFunctionsClientServer.SubstituteParametersInString("data.zip.%1", Format(FileNumber, FormatString));
		
		FileNames = FindFiles(Directory, FileName);
		
		If FileNames.Count() > 0 Then
			
			Return FileNames;
			
		EndIf;
		
	EndDo;
	
	Return New Array;
EndFunction

Function NumberDigitNumber(Val Number)
	
	Return StrLen(Format(Number, "NFD=0; NG=0"));
	
EndFunction

#EndRegion
