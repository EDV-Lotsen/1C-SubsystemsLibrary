////////////////////////////////////////////////////////////////////////////////
// RemoteAdministrationMessageChannelHandler.
//
////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves a handler list of messages that the current subsystem handles.
// 
// Parameters:
// Handlers - ValueTable - see MessageExchange.NewMessageHandlerTable
// for details.
// 
Procedure GetMessageChannelHandlers(Val Handlers) Export
	
	ChannelNames = RemoteAdministrationMessagesCached.GetPackageChannels(
		RemoteAdministrationMessagesCached.RemoteAdministrationPackage());
	
	For Each ChannelName In ChannelNames Do
		Handler = Handlers.Add();
		Handler.Channel = ChannelName;
		Handler.Handler = RemoteAdministrationMessageChannelHandler;
	EndDo;
	
EndProcedure

// Handles the body of the message from the channel according to the current message
// channel algorithm. 
//
// Parameters:
// MessageChannel - String - ID of message channel where the message is received from;
// Body - Arbitrary - message body to be handled;
// Sender - ExchangePlanRef.MessageExchange - end point that is a sender.
//
Procedure HandleMessage(Val MessageChannel, Val Body, Val Sender) Export
	
	MessageType = RemoteAdministrationMessages.MessageTypeByChannelName(MessageChannel);
	
	Content = RemoteAdministrationMessages.GetMessageContent(Body);
	
	Dictionary = RemoteAdministrationMessagesCached;
	
	If MessageType = Dictionary.MessageUpdateUser() Then
		UpdateUser(Content, Sender);
	ElsIf MessageType = Dictionary.MessagePrepareDataArea() Then
		PrepareDataArea(Content, Sender);
	ElsIf MessageType = Dictionary.MessageDeleteDataArea() Then
		DeleteDataArea(Content, Sender);
	ElsIf MessageType = Dictionary.MessageSetAccessToDataArea() Then
		SetAccessToDataArea(Content, Sender);
	ElsIf MessageType = Dictionary.MessageSetServiceManagerEndPoint() Then
		SetServiceManagerEndPoint(Content, Sender);
	ElsIf MessageType = Dictionary.MessageSetInfoBaseParameters() Then
		SetInfoBaseParameters(Content, Sender);
	ElsIf MessageType = Dictionary.MessageSetDataAreaParameters() Then
		SetDataAreaParameters(Content, Sender);
	ElsIf MessageType = Dictionary.MessageSetDataAreaFullAccess() Then
		SetDataAreaFullAccess(Content, Sender);
	ElsIf MessageType = Dictionary.MessageSetDefaultUserRights() Then
		SetDefaultUserRights(Content, Sender);
	Else
		
		RemoteAdministrationMessages.UnknownChannelNameError(MessageChannel);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

///////////////////////////////////////////////////////////////////////////////////
// User management.

// Message includes:
//  Name;
//  FullName;
//  StoredPasswordValue;
//  Language;
//  Email;
//  DataArea;
//  ServiceUserID;
//  DataAreasUserID.
//
Procedure UpdateUser(Content, Sender)
	
	UserDetails = Content;
	
	SetPrivilegedMode(True);
	
	UserLanguage = GetLanguageByCode(UserDetails.Language);
	
	If UserDetails.IsSet("Email") Then
		EmailValue = UserDetails.Email;
	Else
		EmailValue = "";
	EndIf;
	
	EmailAddressStructure = GetEmailAddressStructure(EmailValue);
	
	CommonUse.SetSessionSeparation(True, UserDetails.DataArea);
	
	BeginTransaction();
	Try
		If UserDetails.IsSet("DataAreasUserID")
			And ValueIsFilled(UserDetails.DataAreasUserID) Then
			
			DataAreaUser = Catalogs.Users.GetRef(UserDetails.DataAreasUserID);
			
			Lock = New DataLock;
			
			LockItem = Lock.Add("Catalog.Users");
			
			LockItem.SetValue("Ref", DataAreaUser);
			
			Lock.Lock();
			
			InfoBaseUserID = CommonUse.GetAttributeValue(DataAreaUser, "InfoBaseUserID");
		Else
			Query = New Query;
			Query.Text =
			"SELECT
			|	Users.Ref AS Ref,
			|	Users.InfoBaseUserID AS InfoBaseUserID
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.ServiceUserID = &ServiceUserID";
			Query.SetParameter("ServiceUserID", UserDetails.ServiceUserID);
			Result = Query.Execute();
			If Result.IsEmpty() Then
				InfoBaseUserID = Undefined;
				DataAreaUser = Undefined;
			Else
				Selection = Result.Select();
				Selection.Next();
				InfoBaseUserID = Selection.InfoBaseUserID;
				DataAreaUser = Selection.Ref;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(DataAreaUser) Then
			UserObject = Catalogs.Users.CreateItem();
			UserObject.ServiceUserID = UserDetails.ServiceUserID;
		Else
			UserObject = DataAreaUser.GetObject();
		EndIf;
		
		UserObject.Description = UserDetails.FullName;
		
		UpdateEmailAddress(UserObject, EmailValue, EmailAddressStructure);
		
		InfoBaseUserStructure = Users.NewInfoBaseUserInfo();
		If ValueIsFilled(InfoBaseUserID)
			And Users.UserByIDExists(InfoBaseUserID) Then
			InfoBaseUserStructure.InfoBaseUserUUID = InfoBaseUserID;
		EndIf;
		
		InfoBaseUserStructure.InfoBaseUserName = UserDetails.Name;
		
		InfoBaseUserStructure.InfoBaseUserFullName = UserDetails.FullName;
		
		InfoBaseUserStructure.InfoBaseUserStandardAuthentication = True;
		InfoBaseUserStructure.InfoBaseUserShowInList = False;

		InfoBaseUserStructure.InfoBaseUserStoredPasswordValue = UserDetails.StoredPasswordValue;
		
		InfoBaseUserStructure.InfoBaseUserLanguage = UserLanguage;
		
		UserObject.AdditionalProperties.Insert("InfoBaseAccessAllowed", True);
		UserObject.AdditionalProperties.Insert("InfoBaseUserInfoStructure", InfoBaseUserStructure);
		
		UserObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'User update'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function GetEmailAddressStructure(Val EmailAddress)
	
	If ValueIsFilled(EmailAddress) Then
		
		Try
			EmailAddressStructure = CommonUseClientServer.SplitStringWithEmailAddresses(EmailAddress);
		Except
			MessagePattern = NStr("en = 'Email is specified incorrectly: %1
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

Procedure UpdateEmailAddress(Val UserObject, Val Address, Val EmailAddressStructure)
	
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

// Message includes:
//  ServiceUserID;
//  DataArea;
//  Value.
//
Procedure SetDataAreaFullAccess(Content, Sender)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, Content.DataArea);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(Content.ServiceUserID);
		
		InfoBaseUser = GetInfoBaseUserByDataAreaUser(DataAreaUser);
		
		FullAccessRole = Metadata.Roles.FullAccess;
		If Content.Value Then
			If Not InfoBaseUser.Roles.Contains(FullAccessRole) Then
				InfoBaseUser.Roles.Add(FullAccessRole);
			EndIf;
		Else
			If InfoBaseUser.Roles.Contains(FullAccessRole) Then
				InfoBaseUser.Roles.Delete(FullAccessRole);
			EndIf;
		EndIf;
			
		Users.WriteInfoBaseUser(InfoBaseUser);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Setting data area full rights'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
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
	
	BeginTransaction();
	Try
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Receiving data area user'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		MessagePattern = NStr("en = 'The user with %1 ID is not found.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ServiceUserID);
		Raise(MessageText);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

Function GetInfoBaseUserByDataAreaUser(Val DataAreaUser)
	
	InfoBaseUserID = CommonUse.GetAttributeValue(DataAreaUser, "InfoBaseUserID");
	InfoBaseUser = InfoBaseUsers.FindByUUID(InfoBaseUserID);
	If InfoBaseUser = Undefined Then
		MessagePattern = NStr("en = 'The infobase user for the data area user with %1 ID does not exist.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataAreaUser.UUID());
		Raise(MessageText);
	EndIf;
	
	Return InfoBaseUser;
	
EndFunction

Function GetLanguageByCode(Val LanguageCode)
	
	If ValueIsFilled(LanguageCode) Then
		
		For Each Language In Metadata.Languages Do
			If Language.LanguageCode = LanguageCode Then
				Return Language.Name;
			EndIf;
		EndDo;
		
		MessagePattern = NStr("en = 'The language code %1 is not supported.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, LanguageCode);
		Raise(MessageText);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

// Message includes:
//  ServiceUserID;
//  Name*;
//  StoredPasswordValue*;
//  Language*;
//  DataArea;
//  Value.
//
Procedure SetAccessToDataArea(Content, Sender)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, Content.DataArea);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(Content.ServiceUserID);
		
		InfoBaseUserID = CommonUse.GetAttributeValue(DataAreaUser, "InfoBaseUserID");
		
		If Content.Value Then
			If Not ValueIsFilled(InfoBaseUserID)
				Or InfoBaseUsers.FindByUUID(InfoBaseUserID) = Undefined Then
				
				InfoBaseUserLanguage = GetLanguageByCode(Content.Language);
				
				InfoBaseUser = InfoBaseUsers.CreateUser();
				InfoBaseUser.Name = Content.Name;
				InfoBaseUser.Language = InfoBaseUserLanguage;
				InfoBaseUser.StoredPasswordValue = Content.StoredPasswordValue;
				InfoBaseUser.FullName = CommonUse.GetAttributeValue(DataAreaUser, "Description");
				InfoBaseUser.Write();
				
				UserObject = DataAreaUser.GetObject();
				UserObject.InfoBaseUserID = InfoBaseUser.UUID;
				UserObject.Write();
				
			EndIf;
			
		Else
			
			If ValueIsFilled(InfoBaseUserID) Then
				InfoBaseUser = InfoBaseUsers.FindByUUID(InfoBaseUserID);
				If InfoBaseUser <> Undefined Then
					InfoBaseUser.Delete();
				EndIf;
				
				UserObject = DataAreaUser.GetObject();
				UserObject.InfoBaseUserID = Undefined;
				UserObject.Write();
				
			EndIf;
		EndIf;
			
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Setting access to the data area'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SetDefaultUserRights(Content, Sender)
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(True, Content.DataArea);
	
	BeginTransaction();
	Try
		DataAreaUser = GetAreaUserByServiceUserID(Content.ServiceUserID);
		UsersOverridable.SetDefaultRights(DataAreaUser);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Setting user rights'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Data area management.

// Message includes:
// DataArea;
// DataFileIdentifier.
//
Procedure PrepareDataArea(Content, Sender)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If Not ValueIsFilled(Constants.InfoBaseUsageMode.Get()) Then
			MessageText = NStr("en = 'The application usage mode is not set.'");
			Raise(MessageText);
		EndIf;
		
		Lock = New DataLock;
		Item = Lock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataArea", Content.DataArea);
		Lock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataArea = Content.DataArea;
		RecordManager.DataAreaAuxiliaryData = Content.DataArea;
		RecordManager.Read();
		If RecordManager.Selected() Then
			If RecordManager.State = Enums.DataAreaStates.Deleted Then
				MessagePattern = NStr("en = 'The data area %1 was deleted.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Content.DataArea);
				Raise(MessageText);
			ElsIf RecordManager.State = Enums.DataAreaStates.ToDelete Then
				MessagePattern = NStr("en = 'The data area %1 is being deleted.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Content.DataArea);
				Raise(MessageText);
			ElsIf RecordManager.State = Enums.DataAreaStates.New Then
				MessagePattern = NStr("en = 'The data area %1 is in preparation to use.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Content.DataArea);
				Raise(MessageText);
			ElsIf RecordManager.State = Enums.DataAreaStates.Used Then
				MessagePattern = NStr("en = 'The data area %1 is used.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Content.DataArea);
				Raise(MessageText);
			EndIf;
		EndIf;
		
		RecordManager.DataArea = Content.DataArea;
		RecordManager.DataAreaAuxiliaryData = Content.DataArea;
		RecordManager.State = Enums.DataAreaStates.New;
		If ValueIsFilled(Content.DataFileIdentifier) Then
			RecordManager.ExportID = Content.DataFileIdentifier;
		EndIf;
		RecordManager.Repeat = 0;
		
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Preparing data area'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	MethodParameters = New Array;
	MethodParameters.Add(Content.DataArea);
	
	If ValueIsFilled(RecordManager.ExportID) Then
		MethodParameters.Add(RecordManager.ExportID);
	EndIf;
	
	JobQueue.ScheduleJobExecution(
		"ServiceMode.PrepareDataAreaToUse", MethodParameters, "1",, Content.DataArea);
	
EndProcedure

// Message includes:
// DataArea.
//
Procedure DeleteDataArea(Content, Sender)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		Item = Lock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataArea", Content.DataArea);
		Lock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataArea = Content.DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = 'The data area %1 does not exist.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Content.DataArea);
			Raise(MessageText);
		EndIf;
		
		RecordManager.DataArea = Content.DataArea;
		RecordManager.State = Enums.DataAreaStates.ToDelete;
		RecordManager.Repeat = 0;
		
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Deleting data area'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	MethodParameters = New Array;
	MethodParameters.Add(Content.DataArea);
	
	JobQueue.ScheduleJobExecution(
		"ServiceMode.ClearDataArea", MethodParameters, "1",, Content.DataArea);
	
EndProcedure

// Message includes:
//  DataArea;
//  TimeZone;
//  Description.
//
Procedure SetDataAreaParameters(Content, Sender)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		Item = Lock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataArea", Content.DataArea);
		Lock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataArea = Content.DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = 'The data area %1 does not exist.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Content.DataArea);
			Raise(MessageText);
		EndIf;
		
		RecordManager.Presentation = Content.Description;
		
		CommonUse.SetSessionSeparation(True, Content.DataArea);
		
		RecordManager.TimeZone = Content.TimeZone;
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Setting data area parameters'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	SetExclusiveMode(True);
	
	If ValueIsFilled(Content.TimeZone) Then
		SetInfoBaseTimeZone(Content.TimeZone);
	Else
		SetInfoBaseTimeZone();
	EndIf;
	
	SetExclusiveMode(False);
	
	If Not IsBlankString(Content.Description) Then
		
		UpdatePredefinedNodeProperties(Content.Description);
		
	EndIf;
	
EndProcedure

Procedure UpdatePredefinedNodeProperties(Val Description)
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		ExchangePlanUsedInServiceMode = False;
		
		Try
			ExchangePlanUsedInServiceMode = ExchangePlans[ExchangePlan.Name].ExchangePlanUsedInServiceMode();
		Except
			ExchangePlanUsedInServiceMode = False;
		EndTry;
		
		If ExchangePlanUsedInServiceMode Then
			
			ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
			
			NodeProperties = CommonUse.GetAttributeValues(ThisNode, "Code, Description");
			
			If IsBlankString(NodeProperties.Code) Then
				
				ThisNodeObject = ThisNode.GetObject();
				ThisNodeObject.Code = DataExchangeServiceMode.ExchangePlanNodeCodeInService(ServiceMode.SessionSeparatorValue());
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

///////////////////////////////////////////////////////////////////////////////////
// Infobase management.

// Message includes:
// Parameters.
//
Procedure SetInfoBaseParameters(Content, Sender)
	
	Parameters = XDTOSerializer.ReadXDTO(Content.Parameters);
	
	BeginTransaction();
	Try
		ParameterTable = ServiceMode.GetInfoBaseParameterTable();
		
		ParametersToChange = New Structure;
		
		// Checking parameter list correctness
		For Each KeyAndValue In Parameters Do
			
			CurParameterString = ParameterTable.Find(KeyAndValue.Key, "Name");
			If CurParameterString = Undefined Then
				MessagePattern = NStr("en = 'Unknown parameter name %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, KeyAndValue.Key);
				WriteLogEvent(NStr("en = 'RemoteAdministration.SetInfoBaseParameters'", Metadata.DefaultLanguage.LanguageCode),
					EventLogLevel.Warning, , , MessageText);
				Continue;
			ElsIf CurParameterString.WriteProhibition Then
				MessagePattern = NStr("en = 'Parameter %1 is read-only.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, KeyAndValue.Key);
				Raise(MessageText);
			EndIf;
			
			ParametersToChange.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
		EndDo;
		
		StandardSubsystemsOverridable.OnSetInfoBaseParameterValues(ParametersToChange);
		ServiceModeOverridable.OnSetInfoBaseParameterValues(ParametersToChange);
		
		For Each KeyAndValue In ParametersToChange Do
			
			Constants[KeyAndValue.Key].Set(KeyAndValue.Value);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Setting infobase parameters'", Metadata.DefaultLanguage.LanguageCode), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SetServiceManagerEndPoint(Content, Sender)
	
	Constants.ServiceManagerEndPoint.Set(Sender);
	CommonUse.SetInfoBaseSeparationParameters(True);
	
EndProcedure
