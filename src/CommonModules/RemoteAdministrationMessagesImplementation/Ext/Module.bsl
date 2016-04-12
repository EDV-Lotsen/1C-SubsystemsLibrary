////////////////////////////////////////////////////////////////////////////////
// COMMON IMPLEMENTATION OF REMOTE ADMINISTRATION MESSAGE PROCESSING
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}UpdateUser type
//
// Parameters:
//  Name - String, user name,
//  FullName - String, user full name,
//  PasswordHash - String, stored password value,
//  ApplicationUserID - UUID,
//  ServiceUserID - UUID,
//  PhoneNumber - String, user phone number,
//  EmailAddress - String, user email address,
//  LanguageCode - String, user language code.
//
Procedure UpdateUser(Val Name, Val FullName, Val PasswordHash,
		Val ApplicationUserID,
		Val ServiceUserID,
		Val PhoneNumber = "", Val EmailAddress = "",
		Val LanguageCode = Undefined) Export
	
	SetPrivilegedMode(True);
	
	UserLanguage = GetLanguageByCode(LanguageCode);
	
	Mail = EmailAddress;
	
	Phone = PhoneNumber;
	
	EmailAddressStructure = GetEmailAddressStructure(Mail);
	
	BeginTransaction();
	Try
		If ValueIsFilled(ApplicationUserID) Then
			
			DataAreaUser = Catalogs.Users.GetRef(ApplicationUserID);
			
			DataLock = New DataLock;
			LockItem = DataLock.Add("Catalog.Users");
			LockItem.SetValue("Ref", DataAreaUser);
			DataLock.Lock();
		Else
			Query = New Query;
			Query.Text =
			"SELECT
			|	Users.Ref AS Ref
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.ServiceUserID = &ServiceUserID";
			Query.SetParameter("ServiceUserID", ServiceUserID);
			
			DataLock = New DataLock;
			LockItem = DataLock.Add("Catalog.Users");
			DataLock.Lock();
			
			Result = Query.Execute();
			If Result.IsEmpty() Then
				DataAreaUser = Undefined;
			Else
				Selection = Result.Select();
				Selection.Next();
				DataAreaUser = Selection.Ref;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(DataAreaUser) Then
			UserObject = Catalogs.Users.CreateItem();
			UserObject.ServiceUserID = ServiceUserID;
		Else
			UserObject = DataAreaUser.GetObject();
		EndIf;
		
		UserObject.Description = FullName;
		
		RefreshEmailAddress(UserObject, Mail, EmailAddressStructure);
		
		RefreshPhone(UserObject, Phone);
		
		InfobaseUserDescription = Users.NewInfobaseUserInfo();
		
		InfobaseUserDescription.Name = Name;
		
		InfobaseUserDescription.StandardAuthentication = True;
		InfobaseUserDescription.OpenIDAuthentication = True;
		InfobaseUserDescription.ShowInList = False;
		
		InfobaseUserDescription.StoredPasswordValue = PasswordHash;
		
		InfobaseUserDescription.Language = UserLanguage;
		
		InfobaseUserDescription.Insert("Action", "Write");
		UserObject.AdditionalProperties.Insert("InfobaseUserDescription", InfobaseUserDescription);
		
		UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
		UserObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}PrepareApplication type
//
// Parameters:
//  DataAreaCode - Number(7,0),
//  FromExport - Boolean, shows whether the data area is created from the file with the local mode data export (data_dump.zip), 
//  Option - String, initial data file option for the data area,
//  ExportID - UUID, export file ID in the service manager storage.
//
Procedure PrepareDataArea(Val DataAreaCode, Val FromExport, Val Option, Val ExportID) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If Not ValueIsFilled(Constants.InfobaseUsageMode.Get()) Then
			MessageText = NStr("en = 'The infobase mode is not set'");
			Raise(MessageText);
		EndIf;
		
		DataLock = New DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		DataLock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.Selected() Then
			If RecordManager.Status = Enums.DataAreaStatuses.Deleted Then
				MessagePattern = NStr("en = '%1 data area is deleted'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			ElsIf RecordManager.Status = Enums.DataAreaStatuses.ToDelete Then
				MessagePattern = NStr("en = '%1 data area is being deleted'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			ElsIf RecordManager.Status = Enums.DataAreaStatuses.New Then
				MessagePattern = NStr("en = '%1 data area is being prepared for use'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			ElsIf RecordManager.Status = Enums.DataAreaStatuses.Used Then
				MessagePattern = NStr("en = '%1 data area is used.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaCode);
				Raise(MessageText);
			EndIf;
		EndIf;
		
		RecordManager.Status = Enums.DataAreaStatuses.New;
		RecordManager.ExportID = ExportID;
		RecordManager.Repeat = 0;
		RecordManager.Option = ?(FromExport, "", Option);
		
		ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
		FillPropertyValues(ManagerCopy, RecordManager);
		RecordManager = ManagerCopy;
		
		RecordManager.Write();
		
		MethodParameters = New Array;
		MethodParameters.Add(DataAreaCode);
		
		MethodParameters.Add(RecordManager.ExportID);
		If Not FromExport Then
			MethodParameters.Add(Option);
		EndIf;
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", "SaaSOperations.PrepareDataAreaToUse");
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("Key",        "1");
		JobParameters.Insert("DataArea",   DataAreaCode);
		JobParameters.Insert("ExclusiveExecution", True);
		
		JobQueue.AddJob(JobParameters);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}DeleteApplication type
//
// Parameters:
//  DataAreaCode - Number(7,0)
//
Procedure DeleteDataArea(Val DataAreaCode) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		DataLock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = '%1 data area does not exist.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaCode);
			Raise(MessageText);
		EndIf;
		
		RecordManager.Status = Enums.DataAreaStatuses.ToDelete;
		RecordManager.Repeat = 0;
		
		ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
		FillPropertyValues(ManagerCopy, RecordManager);
		RecordManager = ManagerCopy;
		
		RecordManager.Write();
		
		MethodParameters = New Array;
		MethodParameters.Add(DataAreaCode);
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", "SaaSOperations.ClearDataArea");
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("Key",        "1");
		JobParameters.Insert("DataArea",   DataAreaCode);
		
		JobQueue.AddJob(JobParameters);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetApplicationAccess type
//
// Parameters:
//  Name - String, user name,
//  PasswordHash - String, stored password value,
//  ServiceUserID - UUID,
//  AccessAllowed - Boolean, the flag that shows whether access to the data area should be provided to the user,
//  LanguageCode - String, user language code.
//
Procedure SetAccessToDataArea(Val Name, Val PasswordHash,
		Val ServiceUserID, Val AccessAllowed, Val LanguageCode = Undefined) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(ServiceUserID);
		
		InfobaseUserID = CommonUse.ObjectAttributeValue(DataAreaUser, "InfobaseUserID");
		
		If AccessAllowed Then
			If Not ValueIsFilled(InfobaseUserID)
				Or InfobaseUsers.FindByUUID(InfobaseUserID) = Undefined Then
				
				InfobaseUserLanguage = GetLanguageByCode(LanguageCode);
				
				InfobaseUserDescription = Users.NewInfobaseUserInfo();
				InfobaseUserDescription.Insert("Action", "Write");
				InfobaseUserDescription.Name = Name;
				InfobaseUserDescription.Language = InfobaseUserLanguage;
				InfobaseUserDescription.StoredPasswordValue = PasswordHash;
				InfobaseUserDescription.StandardAuthentication = True;
				InfobaseUserDescription.OpenIDAuthentication = True;
				InfobaseUserDescription.ShowInList = False;
				
				UserObject = DataAreaUser.GetObject();
				UserObject.AdditionalProperties.Insert("InfobaseUserDescription", InfobaseUserDescription);
				UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
				UserObject.Write();
				
			EndIf;
			
		Else
			
			If ValueIsFilled(InfobaseUserID) Then
				InfobaseUserDescription = New Structure;
				InfobaseUserDescription.Insert("Action", "Delete");
				
				UserObject = DataAreaUser.GetObject();
				UserObject.AdditionalProperties.Insert("InfobaseUserDescription", InfobaseUserDescription);
				UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
				UserObject.Write();
			EndIf;
		EndIf;
			
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetServiceManagerEndpoint type
//
// Parameters:
//  MessageExchangeNode - ExchangePlanRef.MessageExchange.
//
Procedure SetServiceManagerEndpoint(MessageExchangeNode) Export
	
	Constants.ServiceManagerEndpoint.Set(MessageExchangeNode);
	CommonUse.SetInfobaseSeparationParameters(True);
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetIBParams type
//
// Parameters:
//  Parameters - Structure containing the parameter values that you must set for the infobase.
//
Procedure SetInfobaseParameters(Parameters) Export
	
	BeginTransaction();
	Try
		ParameterTable = SaaSOperations.GetInfobaseParameterTable();
		
		ParametersToChange = New Structure;
		
		// Checking the correctness of the parameter list
		For Each KeyAndValue In Parameters Do
			
			CurParameterString = ParameterTable.Find(KeyAndValue.Key, "Name");
			If CurParameterString = Undefined Then
				MessagePattern = NStr("en = 'Unknown name of parameter %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, KeyAndValue.Key);
				WriteLogEvent(NStr("en ='RemoteAdministration.SetInfobaseParameters'", 
					CommonUseClientServer.DefaultLanguageCode()),
					EventLogLevel.Warning, , , MessageText);
				Continue;
			ElsIf CurParameterString.WriteProhibition Then
				MessagePattern = NStr("en = '%1 parameter can be used only for reading'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, KeyAndValue.Key);
				Raise(MessageText);
			EndIf;
			
			ParametersToChange.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
		EndDo;
		
		EventHandlers = CommonUse.InternalEventHandlers(
			"StandardSubsystems.SaaSOperations\OnSetInfobaseParameterValues");
		
		For Each Handler In EventHandlers Do
			Handler.Module.OnSetInfobaseParameterValues(ParametersToChange);
		EndDo;
		
		SaaSOperationsOverridable.OnSetInfobaseParameterValues(ParametersToChange);
		
		For Each KeyAndValue In ParametersToChange Do
			
			Constants[KeyAndValue.Key].Set(KeyAndValue.Value);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Infobase parameter setting'", 
			CommonUseClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetApplicationParams type
//
// Parameters:
//  DataAreaCode - Number(7,0),
//  DataAreaPresentation - String,
//  DataAreaTimeZone - String.
//
Procedure SetDataAreaParameters(Val DataAreaCode,
		Val DataAreaPresentation,
		Val DataAreaTimeZone = Undefined) Export
	
	ExternalExclusiveMode = ExclusiveMode();
	
	If Not ExternalExclusiveMode Then
		SaaSOperations.LockCurrentDataArea();
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		RefreshCurrentDataAreaParameters(DataAreaPresentation, DataAreaTimeZone);
		
		If Not IsBlankString(DataAreaPresentation) Then
			RefreshPredefinedNodeProperties(DataAreaPresentation);
		EndIf;
		
		CommitTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
	Except
		
		RollbackTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
		Raise;
		
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl type
//
// Parameters:
//  ServiceUserID - UUID,
//  AccessAllowed - Boolean, the flag that shows whether access to the data area should be provided to the user,
//
Procedure SetDataAreaFullAccess(Val ServiceUserID, Val AccessAllowed) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(ServiceUserID);
		
		If UsersInternal.RoleEditProhibition()
			And CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
			AccessManagementInternalSaaSModule = CommonUse.CommonModule("AccessManagementInternalSaaS");
			AccessManagementInternalSaaSModule.SetUserBelongingToAdministratorGroup(DataAreaUser, AccessAllowed);
			
		Else
			
			IBUser = GetInfobaseUserByDataAreaUser(DataAreaUser);
			
			FullAccessRole = Metadata.Roles.FullAccess;
			If AccessAllowed Then
				If Not IBUser.Roles.Contains(FullAccessRole) Then
					IBUser.Roles.Add(FullAccessRole);
				EndIf;
			Else
				If IBUser.Roles.Contains(FullAccessRole) Then
					IBUser.Roles.Delete(FullAccessRole);
				EndIf;
			EndIf;
			
			UsersInternal.WriteInfobaseUser(IBUser);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetDefaultUserRights type
//
// Parameters:
//  ServiceUserID - UUID
//
Procedure SetDefaultUserRights(Val ServiceUserID) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(ServiceUserID);
		
		EventHandlers = CommonUse.InternalEventHandlers(
			"StandardSubsystems.SaaSOperations\DefaultRightsOnSet");
		For Each Handler In EventHandlers Do
			Handler.Module.DefaultRightsOnSet(DataAreaUser);
		EndDo;
		
		SaaSOperationsOverridable.SetDefaultRights(DataAreaUser);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetApplicationsRating type
//
// Parameters:
//  RatingTable - ValueTable containing the data area activity rating, columns:
//    DataArea - Number(7,0),
//    Rating - Number(7,0),
//  Replace - Boolean, the flag that shows whether existing records in the data area activity rating should be replaced.
//
Procedure SetDataAreaRating(Val RatingTable, Val Replace) Export
	
	SetPrivilegedMode(True);
	
	Set = InformationRegisters.DataAreaActivityRating.CreateRecordSet();
	
	If Replace Then
		Set.Load(RatingTable);
		Set.Write();
	Else
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.DataAreaActivityRating");
		LockItem.DataSource = RatingTable;
		LockItem.UseFromDataSource("DataArea", "DataArea");
		BeginTransaction();
		
		Try
			DataLock.Lock();
			
			For Each RatingString In RatingTable Do
				Set.Clear();
				Set.Filter.DataArea.Set(RatingString.DataArea);
				Write = Set.Add();
				FillPropertyValues(Write, RatingString);
				Set.Write();
			EndDo;
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

// Processing incoming messages of the http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}BindApplication type
//
// Parameters:
//  Parameters - Structure containing the parameter values that you must set for the data area.
//
Procedure AttachDataArea(Parameters) Export
	
	ExternalExclusiveMode = ExclusiveMode();
	
	If Not ExternalExclusiveMode Then
		SaaSOperations.LockCurrentDataArea();
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Setting data area parameters
		DataLock = New DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		DataLock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = '%1 data area does not exist.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Parameters.Zone);
			Raise(MessageText);
		EndIf;
		
		RecordManager.Status = Enums.DataAreaStatuses.Used;
		ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
		FillPropertyValues(ManagerCopy, RecordManager);
		RecordManager = ManagerCopy;
		RecordManager.Write();
		
		RefreshCurrentDataAreaParameters(Parameters.Presentation, Parameters.TimeZone);
		
		// Creating administrators in the area
		For Each UserDetails In Parameters.UsersList.Item Do
			UserLanguage = GetLanguageByCode(UserDetails.Language);
			
			Mail = "";
			Phone = "";
			If ValueIsFilled(UserDetails.EMail) Then
				Mail = UserDetails.EMail;
			EndIf;
			
			If ValueIsFilled(UserDetails.Phone) Then
				Phone = UserDetails.Phone;
			EndIf;
			
			EmailAddressStructure = GetEmailAddressStructure(Mail);
			
			Query = New Query;
			Query.Text =
			"SELECT
			|    Users.Ref AS Ref
			|FROM
			|    Catalog.Users AS Users
			|WHERE
			|    Users.ServiceUserID = &ServiceUserID";
			Query.SetParameter("ServiceUserID", UserDetails.UserServiceID);
			
			DataLock = New DataLock;
			LockItem = DataLock.Add("Catalog.Users");
			DataLock.Lock();
			
			Result = Query.Execute();
			If Result.IsEmpty() Then
				DataAreaUser = Undefined;
			Else
				Selection = Result.Select();
				Selection.Next();
				DataAreaUser = Selection.Ref;
			EndIf;
			
			If Not ValueIsFilled(DataAreaUser) Then
				UserObject = Catalogs.Users.CreateItem();
				UserObject.ServiceUserID = UserDetails.UserServiceID;
			Else
				UserObject = DataAreaUser.GetObject();
			EndIf;
			
			UserObject.Description = UserDetails.FullName;
			
			RefreshEmailAddress(UserObject, Mail, EmailAddressStructure);
			
			RefreshPhone(UserObject, Phone);
			
			InfobaseUserDescription = Users.NewInfobaseUserInfo();
			
			InfobaseUserDescription.Name = UserDetails.Name;
			
			InfobaseUserDescription.StandardAuthentication = True;
			InfobaseUserDescription.OpenIDAuthentication = True;
			InfobaseUserDescription.ShowInList = False;
			
			InfobaseUserDescription.StoredPasswordValue = UserDetails.StoredPasswordValue;
			
			InfobaseUserDescription.Language = UserLanguage;
			
			Roles = New Array;
			Roles.Add("FullAccess");
			InfobaseUserDescription.Roles = Roles;
			
			InfobaseUserDescription.Insert("Action", "Write");
			UserObject.AdditionalProperties.Insert("InfobaseUserDescription", InfobaseUserDescription);
			
			UserObject.AdditionalProperties.Insert("RemoteAdministrationChannelMessageProcessing");
			UserObject.Write();
			
			DataAreaUser = UserObject.Ref;
			
			If UsersInternal.RoleEditProhibition()
				And CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
				AccessManagementInternalSaaSModule = CommonUse.CommonModule("AccessManagementInternalSaaS");
				AccessManagementInternalSaaSModule.SetUserBelongingToAdministratorGroup(DataAreaUser, True);
			EndIf;
		EndDo;
		
		If Not IsBlankString(Parameters.Presentation) Then
			RefreshPredefinedNodeProperties(Parameters.Presentation);
		EndIf;
		
		Message = MessagesSaaS.NewMessage(RemoteAdministrationControlMessagesInterface.MessageDataAreaIsReadyForUse());
			Message.Body.Zone = Parameters.Zone;
		
		MessagesSaaS.SendMessage(Message, SaaSOperationsCached.ServiceManagerEndpoint(), True);
		
		CommitTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
	Except
		
		RollbackTransaction();
		
		If Not ExternalExclusiveMode Then
			SaaSOperations.UnlockCurrentDataArea();
		EndIf;
		
		Raise;
		
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function GetLanguageByCode(Val LanguageCode)
	
	If ValueIsFilled(LanguageCode) Then
		
		For Each Language In Metadata.Languages Do
			If Language.LanguageCode = LanguageCode Then
				Return Language.Name;
			EndIf;
		EndDo;
		
		MessagePattern = NStr("en = 'Unsupported language code: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, LanguageCode);
		Raise(MessageText);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

Function GetEmailAddressStructure(Val EmailAddress)
	
	If ValueIsFilled(EmailAddress) Then
		
		Try
			EmailAddressStructure = CommonUseClientServer.SplitStringWithEmailAddresses(EmailAddress);
		Except
			MessagePattern = NStr("en = 'An incorrect email address is specified: %1
				|Error: %2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
				EmailAddress, ErrorInfo().Description);
			Raise(MessageText);
		EndTry;
		
		Return EmailAddressStructure;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Procedure RefreshEmailAddress(Val UserObject, Val Address, Val EmailAddressStructure)
	
	CIKind = Catalogs.ContactInformationKinds.UserEmail;
	
	TabularSectionRow = UserObject.ContactInformation.Find(CIKind, "Kind");
	If EmailAddressStructure = Undefined Then
		If TabularSectionRow <> Undefined Then
			UserObject.ContactInformation.Delete(TabularSectionRow);
		EndIf;
	Else
		If TabularSectionRow = Undefined Then
			TabularSectionRow = UserObject.ContactInformation.Add();
			TabularSectionRow.Kind = CIKind;
		EndIf;
		TabularSectionRow.Type = Enums.ContactInformationTypes.EmailAddress;
		TabularSectionRow.Presentation = Address;
		
		If EmailAddressStructure.Count() > 0 Then
			TabularSectionRow.EmailAddress = EmailAddressStructure[0].Address;
			
			Pos = Find(TabularSectionRow.EmailAddress, "@");
			If Pos <> 0 Then
				TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EmailAddress, Pos + 1);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure RefreshPhone(Val UserObject, Val Phone)
	
	CIKind = Catalogs.ContactInformationKinds.UserPhone;
	
	TabularSectionRow = UserObject.ContactInformation.Find(CIKind, "Kind");
	If TabularSectionRow = Undefined Then
		TabularSectionRow = UserObject.ContactInformation.Add();
		TabularSectionRow.Kind = CIKind;
	EndIf;
	TabularSectionRow.Type = Enums.ContactInformationTypes.Phone;
	TabularSectionRow.Presentation = Phone;
	
EndProcedure

Function GetAreaUserByServiceUserID(Val ServiceUserID)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.ServiceUserID = &ServiceUserID";
	Query.SetParameter("ServiceUserID", ServiceUserID);
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Catalog.Users");
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		MessagePattern = NStr("en = 'The user with service user ID %1 is not found'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ServiceUserID);
		Raise(MessageText);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

Function GetInfobaseUserByDataAreaUser(Val DataAreaUser)
	
	InfobaseUserID = CommonUse.ObjectAttributeValue(DataAreaUser, "InfobaseUserID");
	IBUser = InfobaseUsers.FindByUUID(InfobaseUserID);
	If IBUser = Undefined Then
		MessagePattern = NStr("en = 'There is no infobase user for the data area user with %1 ID'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaUser.UUID());
		Raise(MessageText);
	EndIf;
	
	Return IBUser;
	
EndFunction

Procedure RefreshCurrentDataAreaParameters(Val Presentation, Val TimeZone)
	
	Constants.DataAreaPresentation.Set(Presentation);
	
	If ValueIsFilled(TimeZone) Then
		SetInfobaseTimeZone(TimeZone);
	Else
		SetInfobaseTimeZone();
	EndIf;
	
	Constants.DataAreaTimeZone.Set(TimeZone);
	
EndProcedure

Procedure RefreshPredefinedNodeProperties(Val Description)
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If DataExchangeCached.ExchangePlanUsedInSaaS(ExchangePlan.Name) Then
			
			ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
			
			NodeProperties = CommonUse.ObjectAttributeValues(ThisNode, "Code, Description");
			
			If IsBlankString(NodeProperties.Code) Then
				
				ThisNodeObject = ThisNode.GetObject();
				ThisNodeObject.Code = DataExchangeSaaS.ExchangePlanNodeCodeInService(SaaSOperations.SessionSeparatorValue());
				ThisNodeObject.Description = Description;
				ThisNodeObject.Write();
				
			ElsIf NodeProperties.Description <> Description Then
				
				ThisNodeObject = ThisNode.GetObject();
				ThisNodeObject.Description = Description;
				ThisNodeObject.Write();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion
