#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

// The procedure creates an initial image of a standalone workstation
// according to the passed settings and puts it to the temporary storage.
// 
// Parameters:
// Settings                           - Structure - filter settings for node.
// InitialImageTempStorageAddress     - String.
// SetupPackageInfoTempStorageAddress - String.
// 
Procedure CreateStandaloneWorkstationInitialImage(
						Val Settings,
						Val SelectedSynchronizationUsers,
						Val InitialImageTempStorageAddress,
						Val InstallPackageInfoTempStorageAddress
	) Export
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	// Checking exchange plan content
	StandardSubsystemsServer.ValidateExchangePlanContent(StandaloneModeInternal.StandaloneModeExchangePlan());
	
	BeginTransaction();
	Try
		
		// Assigning rights to perform synchronization to selected users
		If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
			CommonModuleAccessManagementInternal = CommonUse.CommonModule("AccessManagementInternal");
			
			For Each User In SelectedSynchronizationUsers Do
				
				CommonModuleAccessManagementInternal.AddUserToAccessGroup(User,
					DataExchangeServer.DataSynchronizationAccessProfileWithOtherApplications());
			EndDo;
			
		EndIf;
		
		// Generating prefix for new standalone workstation
		DataLock = New DataLock;
		LockItem = DataLock.Add("Constant.LastStandaloneWorkstationPrefix");
		LockItem.Mode = DataLockMode.Exclusive;
		DataLock.Lock();
		
		LastPrefix = Constants.LastStandaloneWorkstationPrefix.Get();
		StandaloneWorkstationPrefix = StandaloneModeInternal.GenerateStandaloneWorkstationPrefix(LastPrefix);
		
		Constants.LastStandaloneWorkstationPrefix.Set(StandaloneWorkstationPrefix);
		
		// Creating standalone workstation node
		StandaloneWorkstation = CreateNewStandaloneWorkstation(Settings);
		
		InitialImageCreationDate = CurrentSessionDate();
		
		// Importing settings to standalone workstation initial image
		ImportParametersToInitialImage(StandaloneWorkstationPrefix, InitialImageCreationDate, StandaloneWorkstation);
		
		// Setting initial image creation date as the date of the first
   // successful synchronization.
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", StandaloneWorkstation);
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataExport);
		RecordStructure.Insert("EndDate", InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", StandaloneWorkstation);
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataImport);
		RecordStructure.Insert("EndDate", InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangeStates.AddRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	InitialImageDirectory = CommonUseClientServer.GetFullFileName(
		TempFilesDir(),
		InitialImageTemporaryDirectoryName());
	
	SetupDirectory = CommonUseClientServer.GetFullFileName(
		InitialImageDirectory,
		"1");
	
	ArchiveDirectory = CommonUseClientServer.GetFullFileName(
		SetupDirectory,
		"Infobase");
	
	InitialImageDataFileName = CommonUseClientServer.GetFullFileName(
		ArchiveDirectory,
		"data.xml");
	
	CreateDirectory(ArchiveDirectory);
	
	// Creating standalone workstation initial image
	ConnectionString = "File = ""&InfobaseDirectory""";
	ConnectionString = StrReplace(ConnectionString, "&InfobaseDirectory", TrimAll(InitialImageDirectory));
	
	ExportedData = New XMLWriter;
	ExportedData.OpenFile(InitialImageDataFileName);
	ExportedData.WriteXMLDeclaration();
	ExportedData.WriteStartElement("Data");
	ExportedData.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	ExportedData.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	ExportedData.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
	
	StandaloneWorkstationObject = StandaloneWorkstation.GetObject();
	StandaloneWorkstationObject.AdditionalProperties.Insert("ExportedData", ExportedData);
	StandaloneWorkstationObject.AdditionalProperties.Insert("AllocateFilesToInitialImage");
	
	// Updating cached object registration values
	DataExchangeServerCall.CheckObjectChangeRecordMechanismCache();
	
	Try
		ExchangePlans.CreateInitialImage(StandaloneWorkstationObject, ConnectionString);
	Except
		WriteLogEvent(EventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		
		// Storing standalone workstation settings in the infobase is unsafe.
		Constants.SubordinateDIBNodeSettings.Set("");
		ExportedData = Undefined;
		
		Try
			DeleteFiles(InitialImageDirectory);
		Except
			WriteLogEvent(EventLogMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		// Deleting standalone workstation
		StandaloneModeInternal.DeleteStandaloneWorkstation(New Structure("StandaloneWorkstation", StandaloneWorkstation), "");
		
		Raise;
	EndTry;
	
	ExportedData.WriteEndElement(); // Data
	ExportedData.Close();
	
	InitialImageFileName = CommonUseClientServer.GetFullFileName(
		InitialImageDirectory, "1Cv8.1CD");
	
	InitialImageFileNameInArchiveDirectory = CommonUseClientServer.GetFullFileName(
		ArchiveDirectory, "1Cv8.1CD");
	
	InstallPackageFileName = CommonUseClientServer.GetFullFileName(
		InitialImageDirectory, StandaloneModeInternal.InstallPackageFileName());
	
	InstructionFileName = CommonUseClientServer.GetFullFileName(
		ArchiveDirectory, "ReadMe.html");
	
	InstructionText = StandaloneModeInternal.InstructionTextFromTemplate("StandaloneWorkstationSetupInstruction");
	
	Text = New TextWriter(InstructionFileName);
	Text.Write(InstructionText);
	Text.Close();
	
	MoveFile(InitialImageFileName, InitialImageFileNameInArchiveDirectory);
	
	Archiver = New ZipFileWriter(InstallPackageFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(CommonUseClientServer.GetFullFileName(SetupDirectory, "*.*"),
			ZIPStorePathMode.StoreRelativePath,
			ZIPSubDirProcessingMode.ProcessRecursively);
	Archiver.Write();
	
	SetupPackageData = New BinaryData(InstallPackageFileName);
	
	InstallPackageFileSize = Round(SetupPackageData.Size() / 1024 / 1024, 1); // setup package size in MB, for example, 155.2 MB
	
	InstallPackageInfo = New Structure;
	InstallPackageInfo.Insert("InstallPackageFileSize", InstallPackageFileSize);
	
	PutToTempStorage(SetupPackageData, InitialImageTempStorageAddress);
	
	PutToTempStorage(InstallPackageInfo, InstallPackageInfoTempStorageAddress);
	
	Try
		DeleteFiles(InitialImageDirectory);
	Except
		WriteLogEvent(EventLogMessageText(), EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Storing standalone workstation settings in the infobase is unsafe.
	Constants.SubordinateDIBNodeSettings.Set("");
	
EndProcedure


Procedure ImportParametersToInitialImage(StandaloneWorkstationPrefix, InitialImageCreationDate, StandaloneWorkstation)
	
	Constants.SubordinateDIBNodeSettings.Set(ExportParametersInXMLString(StandaloneWorkstationPrefix, InitialImageCreationDate, StandaloneWorkstation));
	
EndProcedure

Function CreateNewStandaloneWorkstation(Settings)
	
	// Updating SaaS application node if necessary
	If IsBlankString(CommonUse.ObjectAttributeValue(StandaloneModeInternal.ApplicationInSaaS(), "Code")) Then
		
		ApplicationInSaaSObject = CreateApplicationInSaaS();
		ApplicationInSaaSObject.AdditionalProperties.Insert("Load");
		ApplicationInSaaSObject.Write();
		
	EndIf;
	
	// Creating standalone workstation node
	StandaloneWorkstationObject = CreateStandaloneWorkstation();
	StandaloneWorkstationObject.Description = StandaloneWorkstationDescription;
	StandaloneWorkstationObject.RegisterChanges = True;
	StandaloneWorkstationObject.AdditionalProperties.Insert("Load");
	
	// Specifying filter values for standalone workstation
	DataExchangeEvents.SetNodeFilterValues(StandaloneWorkstationObject, Settings);
	
	StandaloneWorkstationObject.Write();
	
	Return StandaloneWorkstationObject.Ref;
EndFunction

Function ExportParametersInXMLString(StandaloneWorkstationPrefix, Val InitialImageCreationDate, StandaloneWorkstation)
	
	StandaloneWorkstationParameters = CommonUse.ObjectAttributeValues(StandaloneWorkstation, "Code, Description");
	ApplicationParametersInSaaS = CommonUse.ObjectAttributeValues(StandaloneModeInternal.ApplicationInSaaS(), "Code, Description");
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	XMLWriter.WriteStartElement("Parameters");
	XMLWriter.WriteAttribute("FormatVersion", ExchangeDataSettingsFileFormatVersion());
	
	XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	XMLWriter.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
	
	XMLWriter.WriteStartElement("StandaloneWorkstationParameters");
	
	WriteXML(XMLWriter, InitialImageCreationDate,    "InitialImageCreationDate", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, StandaloneWorkstationPrefix, "Prefix", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, SystemTitle(),              "SystemTitle", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, WSURL,                 "URL", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, InfobaseUsers.CurrentUser().Name, "OwnerName", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, String(Users.AuthorizedUser().UUID()), "Owner", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, StandaloneWorkstationParameters.Code,          "StandaloneWorkstationCode", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, StandaloneWorkstationParameters.Description, "StandaloneWorkstationDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, ApplicationParametersInSaaS.Code,                "ApplicationCodeInSaaS", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, ApplicationParametersInSaaS.Description,       "ApplicationDescriptionInSaaS", XMLTypeAssignment.Explicit);
	
	XMLWriter.WriteEndElement(); // StandaloneWorkstationParameters
	XMLWriter.WriteEndElement(); // Parameters
	
	Return XMLWriter.Close();
EndFunction

Function ExchangeDataSettingsFileFormatVersion()
	
	Return "1.0";
	
EndFunction

Function EventLogMessageText()
	
	Return StandaloneModeInternal.StandaloneWorkstationCreationEventLogMessageText();
	
EndFunction

Function InitialImageTemporaryDirectoryName()
	
	Return StrReplace("Replica {GUID}", "GUID", String(New UUID));
	
EndFunction

Function CreateApplicationInSaaS()
	
	Result = ExchangePlans[StandaloneModeInternal.StandaloneModeExchangePlan()].ThisNode().GetObject();
	Result.Code = String(New UUID);
	Result.Description = GenerateApplicationDescriptionInSaaS();
	
	Return Result;
EndFunction

Function CreateStandaloneWorkstation()
	
	Result = ExchangePlans[StandaloneModeInternal.StandaloneModeExchangePlan()].CreateNode();
	Result.Code = String(New UUID);
	
	Return Result;
EndFunction

Function GenerateApplicationDescriptionInSaaS()
	
	ApplicationDescription = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	
	Result = "[ApplicationDescription] ([Explanation])";
	Result = StrReplace(Result, "[ApplicationDescription]", ApplicationDescription);
	Result = StrReplace(Result, "[Explanation]", NStr("en = 'web application'"));
	
	Return Result;
EndFunction

Function SystemTitle()
	
	Result = "";
	
	Parameters = New Structure;
	StandardSubsystemsServer.AddClientParameters(Parameters);
	
	Result = Parameters.ApplicationPresentation;
	
	If IsBlankString(Result) Then
		
		If Parameters.Property("DataAreaPresentation") Then
			
			Result = Parameters.DataAreaPresentation;
			
		EndIf;
		
	EndIf;
	
	Return ?(IsBlankString(Result), NStr("en = 'Standalone workstation'"), Result);
EndFunction

#EndIf
