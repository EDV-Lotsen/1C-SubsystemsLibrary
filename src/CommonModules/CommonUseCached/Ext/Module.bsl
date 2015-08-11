////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Common use server procedures and functions.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a flag that shows if there are any common separators in the configuration.
//
// Returns:
// Boolean.
//
Function IsSeparatedConfiguration() Export
	
	HasSeparators = False;
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

// Returns list of full names of all metadata objects, that is used in common attributes - separators.
// It identifies separation of sequences and journals by incoming documents.
//
// Returns:
// FixedMap.
//
Function SeparatedMetadataObjects() Export
	
	Result = New Map;
	
	// I. Going over all common attribute content.
	
	For Each CommonAttributeMetadata In Metadata.CommonAttributes Do
		If CommonAttributeMetadata.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			CommonAttributeContent = CommonUseCached.CommonAttributeContent(CommonAttributeMetadata.Name);
			
			For Each ContentItem In CommonAttributeContent Do
				
				If CommonUse.CommonAttributeContentItemUsed(ContentItem, CommonAttributeMetadata) Then
					Result.Insert(ContentItem.Metadata.FullName(), True);
				EndIf;
				
			EndDo;
			
		EndIf;
	EndDo;
	
	// II. Defining separation for sequences and journals by incoming documents.
	
	// 1) Sequences. Going over with first incoming document test. If there are no documents than considering that the configuration is separated.
	For Each SequenceMetadata In Metadata.Sequences Do
		If SequenceMetadata.Documents.Count() = 0 Then
			MessageTemplate = NStr("en = 'There are no documents in %1 sequence.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageTemplate, SequenceMetadata.Name);
			WriteLogEvent(NStr("en = 'CommonUseCached.SeparatedMetadataObjects'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, 
				SequenceMetadata, , MessageText);
			Result.Insert(SequenceMetadata.FullName(), True);
		Else	
			For Each DocumentMetadata In SequenceMetadata.Documents Do
				If Result.Get(DocumentMetadata.FullName()) <> Undefined Then
					Result.Insert(SequenceMetadata.FullName(), True);
				EndIf;
				Break;
			EndDo;
		EndIf;
	EndDo;
	
	// 2) Journals. Going over with first incoming document test. If there are no documents than considering that the configuration is separated.
	For Each DocumentJournalMetadata In Metadata.DocumentJournals Do
		If DocumentJournalMetadata.RegisteredDocuments.Count() = 0 Then
			MessageTemplate = NStr("en = 'There are no documents in %1 journal.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageTemplate, DocumentJournalMetadata.Name);
			WriteLogEvent(NStr("en = 'CommonUseCached.SeparatedMetadataObjects'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, 
				DocumentJournalMetadata, , MessageText);
			Result.Insert(DocumentJournalMetadata.FullName(), True);
		Else
			For Each DocumentMetadata In DocumentJournalMetadata.RegisteredDocuments Do
				If Result.Get(DocumentMetadata.FullName()) <> Undefined Then
					Result.Insert(DocumentJournalMetadata.FullName(), True);
				EndIf;
				Break;
			EndDo;
		EndIf;
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns the common attribute content by the passed name.
//
// Parameters:
// Name - String - common attribute name.
//
// Returns:
// CommonAttributeContent.
//
Function CommonAttributeContent(Val Name) Export
	
	Return Metadata.CommonAttributes[Name].Content;
	
EndFunction

// Returns a flag, shows that metadata object is used in common separators.
//
// Parameters:
// MetadataObjectName - String.
//
// Returns:
// Boolean.
//
Function IsSeparatedMetadataObject(Val MetadataObjectName) Export
	
	Return CommonUse.IsSeparatedMetadataObject(MetadataObjectName);
	
EndFunction

// Returns a data separation enable flag.
// If it is called in shared configuration it returns False.
//
Function DataSeparationEnabled() Export
	
	If Not IsSeparatedConfiguration() Then
		Return False;
	Else
		Return GetFunctionalOption("UseSeparationByDataAreas");
	EndIf;
	
EndFunction

// Returns a flag, shows if called of separated data is allowed from this session.
// If it is called in shared configuration it returns True.
//
// Returns:
// Boolean.
//
Function CanUseSeparatedData() Export
	
	If Not DataSeparationEnabled() Then
		
		Return True;
	Else
		
		SetPrivilegedMode(True);
		Return CommonUse.UseSessionSeparator();
		
	EndIf;
	
EndFunction

// Returns a WSDefinitions object created considering passed parameters.
//
// Parameters corresponds to the object constructor. See details in the Syntax assistant.
//
//
// Note: when getting a definition, cache is used. Cache update take place 
// at configuration version change. If cache update is needed for debugging 
// before version change, it is possible by deletetion of a relevant record in 
// the ProgramInterfaceCache information register.
//
Function GetWSDefinitions(Val WSDLAddress, Val UserName, Val Password) Export
	
	CanGetFilesFromInternet = Undefined;
	StandardSubsystemsOverridable.CanGetFilesFromInternet(CanGetFilesFromInternet);
	If CanGetFilesFromInternet = True Then
	
		ReceptionParameters = New Array;
		ReceptionParameters.Add(WSDLAddress);
		ReceptionParameters.Add(UserName);
		ReceptionParameters.Add(Password);
		
		WSDLData = CommonUseCached.GetVersionCacheData(
			WSDLAddress, 
			Enums.ProgramInterfaceCacheDataTypes.WebServiceDetails, 
			CommonUse.ValueToXMLString(ReceptionParameters),
			False);
			
		WSDLFileName = GetTempFileName("wsdl");
		
		WSDLData.Write(WSDLFileName);
		
		Definitions = New WSDefinitions(WSDLFileName);
		
		Try
			DeleteFiles(WSDLFileName);
		Except
			WriteLogEvent(NStr("en = 'TempFileDeletion'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , , 
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		Return Definitions;
		
	Else
		
		Return New WSDefinitions(WSDLAddress, UserName, Password);
		
	EndIf;
	
EndFunction

// Returns WSProxy object created considering passed parameters.
//
// Parameters corresponds to the object constructor. See details in the Syntax assistant.
//
Function GetWSProxy(Val WSDLAddress, Val NamespaceURI, Val ServiceName,
	Val EndpointName = "", Val UserName, Val Password) Export
	
	WSDefinitions = CommonUseCached.GetWSDefinitions(WSDLAddress, UserName, Password);
	
	If IsBlankString(EndpointName) Then
		EndpointName = ServiceName + "Soap";
	EndIf;
	
	Proxy = New WSProxy(WSDefinitions, NamespaceURI, ServiceName, EndpointName);
	Proxy.User = UserName;
	Proxy.Password = Password;
	
	Return Proxy;
	
EndFunction

// Returns XSLTransform object created of a common template with 
// the passed name.
//
// Parameters:
// CommonTemplateName - String - name of common template that contained 
// XML transform file. Type of template is BinaryData.
//
// Returns:
// Transform - XSLTransform object with a loaded transformation
//
Function GetXSLTransformFromCommonTemplate(Val CommonTemplateName) Export
	
	TemplateData = GetCommonTemplate(CommonTemplateName);
	TransformFileName = GetTempFileName("xsl");
	TemplateData.Write(TransformFileName);
	
	Transform = New XSLTransform;
	Transform.LoadFromFile(TransformFileName);
	
	Try
		DeleteFiles(TransformFileName);
	Except
		
	EndTry;
	
	Return Transform;
	
EndFunction

// Determines if the session was started without separators.
//
// Returns:
// Boolean.
//
Function SessionWithoutSeparator() Export
	
	Return InfoBaseUsers.CurrentUser().DataSeparation.Count() = 0;
	
EndFunction

// Returns the server platform type.
//
// Returns:
// PlatformType; Undefined.
Function ServerPlatformType() Export
	
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType;
	
EndFunction	

// Gets a style color by the style item name
//
// Parameters:
// StyleColorName - String - Style item name.
//
// Returns:
// Color.
//
Function StyleColor(StyleColorName) Export
	
	Return StyleColors[StyleColorName];
	
EndFunction

// Gets a style font by style item name.
//
// Parameters:
// StyleFontName - String - style item name.
//
// Returns:
// Font.
//
Function StyleFont(StyleFontName) Export
	
	Return StyleFonts[StyleFontName];
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Gets cache version data from the ValueStorage resourse of the ProgramInterfaceCache register.
//
// Parameters:
// ID - String - Cache record ID
// DataType - EnumRef.ProgramInterfaceCacheDataTypes.
// ReceptionParameters - String - Parameter array serialized to XML for passing into 
// the cache update procedure;
// UseObsoleteData - Boolean - flag that shows a need of waiting for 
// cache data update, if they are obsolete.
// True - always use cache data, if any. False - wait for data update if data is obsolete.
//
// Returns:
// Arbitrary.
//
Function GetVersionCacheData(Val ID, Val DataType, 
		Val ReceptionParameters, Val UseObsoleteData = True) Export
	
	ReceptionParameters = CommonUse.ValueFromXMLString(ReceptionParameters);
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator()
		And CommonUse.UseSessionSeparator() Then
		
		RestoreSeparation = True;
		
		CommonUse.SetSessionSeparation(False);
		
	Else
		
		RestoreSeparation = False;
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProgramInterfaceCache.UpdateDate AS UpdateDate,
	|	ProgramInterfaceCache.Data AS Data,
	|	ProgramInterfaceCache.DataType AS DataType
	|FROM
	|	InformationRegister.ProgramInterfaceCache AS ProgramInterfaceCache
	|WHERE
	|	ProgramInterfaceCache.ID = &ID
	|	And ProgramInterfaceCache.DataType = &DataType";
	Query.SetParameter("ID", ID);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	// Managed lock is not set that other sessions can change the value while this transaction is active
	Result = Query.Execute();
	CommitTransaction();
	
	JobMethodName = "CommonUse.RefreshVersionCacheData";
	JobKey = ID + "|" + XMLString(DataType);
	JobParameters = New Array;
	JobParameters.Add(ID);
	JobParameters.Add(DataType);
	JobParameters.Add(ReceptionParameters);
	
	JobFilter = New Structure;
	JobFilter.Insert("MethodName", JobMethodName);
	JobFilter.Insert("Key", JobKey);
	JobFilter.Insert("State", BackgroundJobState.Active);
	
	Selection = Undefined;
	
	If Result.IsEmpty() Then
		
		If CommonUse.FileInfoBase() Then
			CommonUse.RefreshVersionCacheData(ID, DataType, ReceptionParameters);
		Else
			Jobs = BackgroundJobs.GetBackgroundJobs(JobFilter);
			If Jobs.Count() = 0 Then
				// Starting a new one
				Job = BackgroundJobs.Execute(JobMethodName, JobParameters, JobKey);
			Else
				Job = Jobs[0];
			EndIf;
			
			Try
				// Waiting for completetion
				Job.WaitForCompletion();
			Except
				Job = BackgroundJobs.FindByUUID(Job.UUID);
				If Job.ErrorInfo <> Undefined Then
					WriteLogEvent(NStr("en = 'UpdateVersionCache'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
						DetailErrorDescription(Job.ErrorInfo));
					Raise(BriefErrorDescription(Job.ErrorInfo));
				Else
					WriteLogEvent(NStr("en = 'UpdateVersionCache'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
						DetailErrorDescription(ErrorInfo()));
					Raise;
				EndIf;
			EndTry;
		EndIf;
		
		BeginTransaction();
		Result = Query.Execute();
		CommitTransaction();
		
		If Result.IsEmpty() Then
			MessageTemplate = NStr("en = 'Error updating cache version data. 
				|Record ID: %1
				|Data type: %2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				MessageTemplate, ID, DataType);
				
			If RestoreSeparation Then
				CommonUse.SetSessionSeparation(True);
			EndIf;
			Raise(MessageText);
		EndIf;
	Else
		
		Selection = Result.Select();
		Selection.Next();
		If CommonUse.VersionCacheRecordObsolete(Selection) Then
			If CommonUse.FileInfoBase() Then
				CommonUse.RefreshVersionCacheData(ID, DataType, ReceptionParameters);
				Selection = Undefined;
			Else
				// Obsolete data
				Jobs = BackgroundJobs.GetBackgroundJobs(JobFilter);
				If Jobs.Count() = 0 Then
					// Starting a new one
					Job = BackgroundJobs.Execute(JobMethodName, JobParameters, JobKey);
				Else
					Job = Jobs[0];
				EndIf;
				
				If Not UseObsoleteData Then
					Try
						// Waiting for completetion
						Job.WaitForCompletion();
					Except
						Job = BackgroundJobs.FindByUUID(Job.UUID);
						If Job.ErrorInfo <> Undefined Then
							WriteLogEvent(NStr("en = 'UpdateVersionCache'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
								DetailErrorDescription(Job.ErrorInfo));
							Raise(BriefErrorDescription(Job.ErrorInfo));
						Else
							WriteLogEvent(NStr("en = 'UpdateVersionCache'", Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error, , ,
								DetailErrorDescription(ErrorInfo()));
							Raise;
						EndIf;
					EndTry;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Selection = Undefined Then
		Selection = Result.Select();
		Selection.Next();
	EndIf;
	
	If RestoreSeparation Then
		CommonUse.SetSessionSeparation(True);
	EndIf;
	
	Return Selection.Data.Get();
	
EndFunction

// Internal use only.
Function InterfaceOptions() Export
	
	InterfaceOptions = New Structure;
	Try
		CommonUseOverridable.OnGetInterfaceFunctionalOptionParameters(InterfaceOptions);
	Except
		ErrorInfo = ErrorInfo();
		EventName = NStr("en = 'Interface setup'", Metadata.DefaultLanguage.LanguageCode);
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The following error occurred during obtaining the interface options:"
"%1'"),
			DetailErrorDescription(ErrorInfo));
		WriteLogEvent(EventName, EventLogLevel.Error,,, ErrorText);
	EndTry;
	
	Return InterfaceOptions;
EndFunction
