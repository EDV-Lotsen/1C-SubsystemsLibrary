////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Operation handlers.

// Corresponds to the ExecuteExport operation.
//
Function ExecuteExport (ExchangePlanName, InfoBaseNodeCode, ExchangeMessageStorage)
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfoBaseNodeViaString(ExchangePlanName, InfoBaseNodeCode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
EndFunction

// Corresponds to the ExecuteImport operation. 
//
Function ExecuteImport(ExchangePlanName, InfoBaseNodeCode, ExchangeMessageStorage)
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfoBaseNodeViaString(ExchangePlanName, InfoBaseNodeCode, ExchangeMessageStorage.Get());
	
EndFunction

// Corresponds to the ExecuteDataExport operation.
//
Function ExecuteDataExport(ExchangePlanName,
								InfoBaseNodeCode,
								FileIDString,
								LongAction,
								ActionID,
								LongActionAllowed
	)
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID;
	FileIDString = String(FileID);
	
	If CommonUse.FileInfoBase() Then
		
		DataExchangeServer.ExportToFileTransferServiceForInfoBaseNode(ExchangePlanName, InfoBaseNodeCode, FileID);
		
	Else
		
		ExecuteDataExportInClientServerMode(ExchangePlanName, InfoBaseNodeCode, FileID, LongAction, ActionID, LongActionAllowed);
		
	EndIf;
	
EndFunction

// Corresponds to the ExecuteDataImport operation.
//
Function ExecuteDataImport(ExchangePlanName,
								InfoBaseNodeCode,
								FileIDString,
								LongAction,
								ActionID,
								LongActionAllowed
	)
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID(FileIDString);
	
	If CommonUse.FileInfoBase() Then
		
		DataExchangeServer.ImportForInfoBaseNodeFromFileTransferService(ExchangePlanName, InfoBaseNodeCode, FileID);
		
	Else
		
		ImportDataInClientServerMode(ExchangePlanName, InfoBaseNodeCode, FileID, LongAction, ActionID, LongActionAllowed);
		
	EndIf;
	
EndFunction

// Corresponds to the GetInfoBaseParameters operation. 
//
Function GetInfoBaseParameters(ExchangePlanName, NodeCode, ErrorMessage)
	
	Return DataExchangeServer.GetInfoBaseParameters(ExchangePlanName, NodeCode, ErrorMessage);
	
EndFunction

// Corresponds to the GetInfoBaseData operation.
//
Function GetInfoBaseData(FullTableName)
	
	Result = New Structure("MetadataObjectProperties, CorrespondentInfoBaseTable");
	
	Result.MetadataObjectProperties = ValueToStringInternal(DataExchangeServer.MetadataObjectProperties(FullTableName));
	Result.CorrespondentInfoBaseTable = ValueToStringInternal(DataExchangeServer.GetTableObjects(FullTableName));
	
	Return ValueToStringInternal(Result);
EndFunction

// Corresponds to the GetCommonNodeData operation.
//
Function GetCommonNodeData(ExchangePlanName)
	
	SetPrivilegedMode(True);
	
	Return ValueToStringInternal(DataExchangeServer.DataForThisInfoBaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// Corresponds to the CreateDataExchange operation.
//
Function CreateDataExchange(ExchangePlanName, ParameterString, FilterStructureString, DefaultValueString)
	
	SetPrivilegedMode(True);
	
	// Getting the data exchange creation wizard processor in the second infobase
	DataExchangeCreationWizard = DataProcessors.DataExchangeCreationWizard.Create();
	DataExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
	
	Cancel = False;
	
	// Importing wizard parameters to the wizard processor from the string
	DataExchangeCreationWizard.ImportWizardParameters(Cancel, ParameterString);
	
	If Cancel Then
		Message = NStr("en = 'Error generating exchange settings in the second infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
		Raise Message;
	EndIf;
	
	DataExchangeCreationWizard.WizardRunVariant = "ContinueDataExchangeSetUp";
	DataExchangeCreationWizard.IsDistributedInfoBaseSetup = False;
	DataExchangeCreationWizard.ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS;
	DataExchangeCreationWizard.SourceInfoBasePrefixIsSet = ValueIsFilled(GetFunctionalOption("InfoBasePrefix"));
	
	// Generating exchange settings
	DataExchangeCreationWizard.SetUpNewWebServiceModeDataExchange(
											Cancel,
											ValueFromStringInternal(FilterStructureString),
											ValueFromStringInternal(DefaultValueString)
	);
	
	If Cancel Then
		Message = NStr("en = 'Error generating exchange settings in the second infobase: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
		Raise Message;
	EndIf;
	
	If GetFunctionalOption("UseDataExchange") = False Then
		
		Constants.UseDataExchange.Set(True);
		
	EndIf;
	
EndFunction

// Corresponds to the UpdateDataExchangeSettings operation.
//
Function UpdateDataExchangeSettings(ExchangePlanName, NodeCode, DefaultValueString)
	
	DataExchangeServer.ExternalConnectionRefreshExchangeSettingsData(ExchangePlanName, NodeCode, DefaultValueString);
	
EndFunction

// Corresponds to the RecordCatalogChangesOnly operation.
//
Function RecordCatalogChangesOnly(ExchangePlanName, NodeCode, LongAction, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongAction, ActionID, True);
	
EndFunction

// Corresponds to the RecordAllChangesExceptCatalogs operation.
//
Function RecordAllChangesExceptCatalogs(ExchangePlanName, NodeCode, LongAction, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongAction, ActionID, False);
	
EndFunction

// Corresponds to the GetLongActionState operation.
//
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

// Corresponds to the GetFunctionalOptionValue operation.
//
Function GetFunctionalOptionValue(Name)
	
	Return GetFunctionalOption(Name);
	
EndFunction

// Corresponds to the PrepareGetFile operation.
//
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
		// Splitting the file
		FileNames = SplitFile(SharedFileName, BlockSize * 1024);
		PartQuantity = FileNames.Count();
	Else
		PartQuantity = 1;
		MoveFile(SharedFileName, SharedFileName + ".1");
	EndIf;
	
EndFunction

// Corresponds to the GetFilePart operation.
//
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FileName = "data.zip.[n]";
	FileName = StrReplace(FileName, "[n]", Format(PartNumber, "NG=0"));
	
	FileNames = FindFiles(TemporaryExportDirectory(TransferId), FileName);
	If FileNames.Count() = 0 Then
		
		MessagePattern = NStr("en = 'The %1 transfer session fragment with the %2 ID has not been found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	ElsIf FileNames.Count() > 1 Then
		
		MessagePattern = NStr("en = 'Several %1 transfer session fragments with the %2 ID have been found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	EndIf;
	
	FileNamePart = FileNames[0].FullName;
	PartData = New BinaryData(FileNamePart);
	
EndFunction

// Corresponds to the ReleaseFile operation.
//
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(NStr("en = 'Deleting temporary file'"),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
EndFunction

// Corresponds to the PutFilePart operation.
//
Function PutFilePart(TransferId, PartNumber, PartData)
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TemporaryDirectory);
		
	EndIf;
	
	FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
EndFunction

// Corresponds to the SaveFileFromParts operation.
//
Function SaveFileFromParts(TransferId, PartQuantity, FileId)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	PartFilesToMerge = New Array;
	
	For PartNumber = 1 to PartQuantity Do
		
		FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessagePattern = NStr("en = 'The %1 transfer session fragment with the %2 ID has not been found.
					|Make sure constant values are specified on the
					|ExchangeMessageTempFileDirForLinux and ExchangeMessageTempFileDirForWindows 
					|application setup forms.'"
			);
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
			WriteLogEvent(NStr("en = 'Deleting temporary file'"),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
			);
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
		WriteLogEvent(NStr("en = 'Deleting temporary file'"),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Corresponds PutFileIntoStorage operation.
//
Function PutFileIntoStorage(FileName, FileId)
	
	SetPrivilegedMode(True);
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
EndFunction

// Corresponds to the GetFileFromStorage operation.
//
Function GetFileFromStorage(FileId)
	
	SetPrivilegedMode(True);
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	File = New File(SourceFileName);
	
	Return File.Name;
EndFunction

// Corresponds to the FileExists operation.
//
Function FileExists(FileName)
	
	SetPrivilegedMode(True);
	
	TempFileFullName = CommonUseClientServer.GetFullFileName(DataExchangeCached.TempFileStorageDirectory(), FileName);
	
	File = New File(TempFileFullName);
	
	Return File.Exist();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Procedure ExecuteDataExportInClientServerMode(ExchangePlanName,
														InfoBaseNodeCode,
														FileID,
														LongAction,
														ActionID,
														LongActionAllowed
	)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(InfoBaseNodeCode);
	Parameters.Add(FileID);
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ExportToFileTransferServiceForInfoBaseNode",
										Parameters,
										ImportExportDataBackgroundJobKey(ExchangePlanName, InfoBaseNodeCode),
										NStr("en = 'Exchanging data via the web service.'")
	);
	
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
		
		Raise NStr("en = 'Error exporting data via the web service.'");
	EndIf;
	
EndProcedure

Procedure ImportDataInClientServerMode(ExchangePlanName,
													InfoBaseNodeCode,
													FileID,
													LongAction,
													ActionID,
													LongActionAllowed
	)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(InfoBaseNodeCode);
	Parameters.Add(FileID);
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ImportForInfoBaseNodeFromFileTransferService",
										Parameters,
										ImportExportDataBackgroundJobKey(ExchangePlanName, InfoBaseNodeCode),
										NStr("en = 'Exchanging data via the web service.'")
	);
	
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
		
		Raise NStr("en = 'Error importing data via the web service.'");
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
	
	InfoBaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfoBaseNode) Then
		Message = NStr("en = 'The exchange plan node named %1 with the %2 node code is not  found.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	Data = ?(CatalogsOnly,
				DataExchangeServer.ExchangePlanCatalogs(ExchangePlanName),
				DataExchangeServer.AllExchangePlanDataExceptCatalogs(ExchangePlanName)
	);
	
	If CommonUse.FileInfoBase() Then
		
		DataExchangeServer.RegisterDataForInitialExport(InfoBaseNode, Data);
		
	Else
		
		Parameters = New Array;
		Parameters.Add(InfoBaseNode);
		Parameters.Add(Data);
		
		BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.RegisterDataForInitialExport",
											Parameters,
											,
											NStr("en = 'Creating the data exchange.'")
		);
		
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







