///////////////////////////////////////////////////////////////////////////////////
// "SaaS users" subsystem.
// 
///////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Returns a flag that shows whether user modification is available.
//
// Returns:
// Boolean - True if user modification is available, False otherwise.
//
Function CanChangeUsers() Export
	
	Return Constants.InfobaseUsageMode.Get() 
		<> Enums.InfobaseUsageModes.Demo;
	
EndFunction

// Returns the actions with the specified SaaS user available to the current user.
//
// Parameters:
//  User                - CatalogRef.Users - user whose available actions are retrieved.
//                        If this parameter not specified, the function checks available
//                        actions for the current user.
//  ServiceUserPassword - String - user password for Service Manager.
//  
Function GetActionsWithSaaSUser(Val User = Undefined) Export
	
	If User = Undefined Then
		User = Users.CurrentUser();
	EndIf;
	
	If CanChangeUsers() Then
		
		If InfobaseUsers.CurrentUser().DataSeparation.Count() = 0 Then
			
			Return ActionsWithSaaSUserWhenUserSetupUnavailable();
			
		ElsIf IsExistingUserCurrentDataArea(User) Then
			
			Return ActionsWithExsistingSaaSUser(User);
			
		Else
			
			If HasRightToAddUsers() Then
				Return ActionsWithNewSaaSUser();
			Else
				Raise NStr("en = 'Insufficient access rights for adding users'");
			EndIf;
			
		EndIf;
		
	Else
		
		Return ActionsWithSaaSUserWhenUserSetupUnavailable();
		
	EndIf;
	
EndFunction

// Generates a request for changing SaaS user email address.
//
// Parameters:
//  NewEmail            - String - new email adress of the user. 
//  User                - CatalogRef.Users - user whose email address is changed.
//  ServiceUserPassword - String - user password for Service Manager.
//
Procedure CreateRequestToChangeEmail(Val NewEmail, Val User, Val ServiceUserPassword) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaSOperations.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	ErrorInfo = Undefined;
	Proxy.RequestEmailChange(
		CommonUse.ObjectAttributeValue(User, "ServiceUserID"), 
		NewEmail, 
		ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "RequestEmailChange"); // Do not localize the operation name
	
EndProcedure

// Creates or updates a SaaS user record.
// 
// Parameters:
//  User                - CatalogRef.Users/CatalogObject.Users 
//  CreateSaaSUser      - Boolean - if True, create a SaaS user, otherwise update an existing user.
//  ServiceUserPassword - String - user password for Service Manager.
//
Procedure WriteSaaSUser(Val User, Val CreateServiceUser, Val ServiceUserPassword) Export
	
	If TypeOf(User) = Type("CatalogRef.Users") Then
		UserObject = User.GetObject();
	Else
		UserObject = User;
	EndIf;
	
	SetPrivilegedMode(True);
	Proxy = SaaSOperations.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	If ValueIsFilled(UserObject.InfobaseUserID) Then
		InfobaseUser = InfobaseUsers.FindByUUID(UserObject.InfobaseUserID);
		AccessAllowed = InfobaseUser <> Undefined;
	Else
		AccessAllowed = False;
	EndIf;
	
	SaaSUser = Proxy.XDTOFactory.Create(
		Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationUsers", "User"));
	SaaSUser.Zone = SaaSOperations.SessionSeparatorValue();
	SaaSUser.UserServiceID = UserObject.ServiceUserID;
	SaaSUser.FullName = UserObject.Description;
	
	If AccessAllowed Then
		SaaSUser.Name = InfobaseUser.Name;
		SaaSUser.StoredPasswordValue = InfobaseUser.StoredPasswordValue;
		SaaSUser.Language = GetLanguageCode(InfobaseUser.Language);
		SaaSUser.Access = True;
		SaaSUser.AdmininstrativeAccess = InfobaseUser.Roles.Contains(Metadata.Roles.FullAccess);
	Else
		SaaSUser.Name = "";
		SaaSUser.StoredPasswordValue = "";
		SaaSUser.Language = "";
		SaaSUser.Access = False;
		SaaSUser.AdmininstrativeAccess = False;
	EndIf;
	
	ContactInformation = Proxy.XDTOFactory.Create(
		Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationUsers", "ContactsList"));
		
	CIWriterType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationUsers", "ContactsItem");
	
	For Each CIRow In UserObject.ContactInformation Do
		CIKindXDTO = SaaSOperationsCached.ContactInformationKindAndXDTOUserMap().Get(CIRow.Kind);
		If CIKindXDTO = Undefined Then
			Continue;
		EndIf;
		
		CIWriter = Proxy.XDTOFactory.Create(CIWriterType);
		CIWriter.ContactType = CIKindXDTO;
		CIWriter.Value = CIRow.Presentation;
		CIWriter.Parts = CIRow.FieldValues;
		
		ContactInformation.Item.Add(CIWriter);
	EndDo;
	
	SaaSUser.Contacts = ContactInformation;
	
	ErrorInfo = Undefined;
	If CreateServiceUser Then
		Proxy.CreateUser(SaaSUser, ErrorInfo);
		HandleWebServiceErrorInfo(ErrorInfo, "CreateUser"); // Do not localize the operation name
	Else
		Proxy.UpdateUser(SaaSUser, ErrorInfo);
		HandleWebServiceErrorInfo(ErrorInfo, "UpdateUser"); // Do not localize the operation name
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processing infobase user when writing Users or ExternalUsers catalog items.

// The procedure is called from the StartInfobaseUserProcessing() procedure to add SaaS support.
Procedure BeforeStartInfobaseUserProcessing(UserObject, ProcessingParameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AdditionalProperties = UserObject.AdditionalProperties;
	OldUser              = ProcessingParameters.OldUser;
	AutoAttributes       = ProcessingParameters.AutoAttributes;
	
	If TypeOf(UserObject) = Type("CatalogObject.ExternalUsers")
	   And CommonUseCached.DataSeparationEnabled() Then
		
		Raise NStr("en = 'External users are not supported in SaaS mode.'");
	EndIf;
	
	AutoAttributes.Insert("ServiceUserID", OldUser.ServiceUserID);
	
	If AdditionalProperties.Property("RemoteAdministrationChannelMessageProcessing") Then
		
		If Not CommonUseCached.SessionWithoutSeparators() Then
			Raise
				NStr("en = 'User update with a message via remote administration channel is available to shared users only.'");
		EndIf;
		
		ProcessingParameters.Insert("RemoteAdministrationChannelMessageProcessing");
		AutoAttributes.ServiceUserID = UserObject.ServiceUserID;
		
	ElsIf Not UserObject.Internal Then
		UpdateDetailsServiceManagerWebService();
	EndIf;
	
	If ValueIsFilled(AutoAttributes.ServiceUserID)
	   And AutoAttributes.ServiceUserID <> OldUser.ServiceUserID Then
		
		If ValueIsFilled(OldUser.ServiceUserID) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error writing user %1.
				           |Cannot modify a SaaS user ID in a catalog item.'"),
				UserObject.Description);
			
		EndIf;
		
		FoundUser = Undefined;
		
		If UsersInternal.UserByIDExists(
				AutoAttributes.ServiceUserID,
				UserObject.Ref,
				FoundUser,
				True) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error writing user %1.
				           |Cannot set a SaaS user ID ""%2"" for the catalog item it is used in item %3.'"),
				UserObject.Description,
				AutoAttributes.ServiceUserID,
				FoundUser);
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is called from the StartInfobaseUserProcessing() procedure to add SaaS support.
Procedure AfterStartInfobaseUserProcessing(UserObject, ProcessingParameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AutoAttributes = ProcessingParameters.AutoAttributes;
	
	ProcessingParameters.Insert("CreateServiceUser", False);
	
	If ProcessingParameters.NewInfobaseUserExists
	   And CommonUseCached.DataSeparationEnabled() Then
		
		If Not ValueIsFilled(AutoAttributes.ServiceUserID) Then
			
			ProcessingParameters.Insert("CreateServiceUser", True);
			UserObject.ServiceUserID = New UUID;
			
			//Updating the attribute value.
			AutoAttributes.ServiceUserID = UserObject.ServiceUserID;
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is called from the EndAppDataProcessorUserInfobase() procedure to add SaaS support.
Procedure BeforeCompleteInfobaseUserProcessing(UserObject, ProcessingParameters) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AutoAttributes = ProcessingParameters.AutoAttributes;
	
	If AutoAttributes.ServiceUserID <> UserObject.ServiceUserID Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error writing user %1.
			           |Cannot edit the SaaSUserID attribute.
			           |This attribute is updated automatically.'"),
			UserObject.Ref);
	EndIf;
	
EndProcedure

// The procedure is called from the EndAppDataProcessorUserInfobase() procedure to add SaaS support.
Procedure OnCompleteInfobaseUserProcessing(UserObject, ProcessingParameters, UpdateRoles) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If ProcessingParameters.Property("RemoteAdministrationChannelMessageProcessing") Then
		UpdateRoles = False;
	EndIf;
	
	InfobaseUserDetails = UserObject.AdditionalProperties.InfobaseUserDetails;
	
	If CommonUseCached.DataSeparationEnabled()
	   And TypeOf(UserObject) = Type("CatalogObject.Users")
	   And InfobaseUserDetails.Property("ActionResult")
	   And NOT UserObject.Internal Then
		
		If InfobaseUserDetails.ActionResult = "InfobaseUserDeleted" Then
			
			SetPrivilegedMode(True);
			CancelSaaSUserAccess(UserObject);
			SetPrivilegedMode(False);
			
		Else // InfobaseUserAdded or InfobaseUserChanged
			UpdateSaaSUser(UserObject, ProcessingParameters.CreateServiceUser);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// For internal use only
Procedure UpdateDetailsServiceManagerWebService() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	// The cache must be filled before writing a user to the infobase
	SaaSOperations.GetServiceManagerProxy();
	SetPrivilegedMode(False);
	
EndProcedure

// For the OnCompleteInfobaseUserProcessing procedure
Procedure UpdateSaaSUser(UserObject, CreateServiceUser)
	
	If Not UserObject.AdditionalProperties.Property("SynchronizeWithService")
		OR Not UserObject.AdditionalProperties.SynchronizeWithService Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	WriteSaaSUser(UserObject, 
		CreateServiceUser, 
		UserObject.AdditionalProperties.ServiceUserPassword);
	
EndProcedure

// For internal use only
Function HasRightToAddUsers() Export
	
	SetPrivilegedMode(True);
	Proxy = SaaSOperations.GetServiceManagerProxy();
	SetPrivilegedMode(False);
	
	DataArea = Proxy.XDTOFactory.Create(
		Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "Zone"));
	DataArea.Zone = SaaSOperations.SessionSeparatorValue();
	
	ErrorInfo = Undefined;
	AccessRightsXDTO = Proxy.GetAccessRights(DataArea, 
		CurrentUserServiceID(), ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "GetAccessRights"); // Do not localize the operation name
	
	For Each RightsListItem In AccessRightsXDTO.Item Do
		If RightsListItem.AccessRight = "CreateUser" Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// For internal use only
Function ActionsWithNewSaaSUser() Export
	
	ActionsWithSaaSUser = NewActionsWithSaasUser();
	ActionsWithSaaSUser.ChangePassword = True;
	ActionsWithSaaSUser.ChangeName = True;
	ActionsWithSaaSUser.ChangeFullName = True;
	ActionsWithSaaSUser.ChangeAccess = True;
	ActionsWithSaaSUser.ChangeAdmininstrativeAccess = True;
	
	ActionsWithCI = ActionsWithSaaSUser.ContactInformation; 
	For Each KeyAndValue In SaaSOperationsCached.ContactInformationKindAndXDTOUserMap() Do
		ActionsWithCI[KeyAndValue.Key].Change = True;
	EndDo;
	
	Return ActionsWithSaaSUser;
	
EndFunction

// For internal use only
Function ActionsWithExsistingSaaSUser(Val User) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaSOperations.GetServiceManagerProxy();
	SetPrivilegedMode(False);
	
	AccessObjects = PrepareUserAccessObjects(Proxy.XDTOFactory, User);
	
	ErrorInfo = Undefined;
	ObjectsAccessRightsXDTO = Proxy.GetObjectsAccessRights(AccessObjects, 
		CurrentUserServiceID(), ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "GetObjectsAccessRights"); // Do not localize the operation name
	
	Return ObjectsAccessRightsXDTOInActionsWithSaaSUser(Proxy.XDTOFactory, ObjectsAccessRightsXDTO);
	
EndFunction

// For internal use only
Function ActionsWithSaaSUserWhenUserSetupUnavailable() Export
	
	ActionsWithSaaSUser = NewActionsWithSaasUser();
	ActionsWithSaaSUser.ChangePassword = False;
	ActionsWithSaaSUser.ChangeName = False;
	ActionsWithSaaSUser.ChangeFullName = False;
	ActionsWithSaaSUser.ChangeAccess = False;
	ActionsWithSaaSUser.ChangeAdmininstrativeAccess = False;
	
	ActionsWithCI = ActionsWithSaaSUser.ContactInformation;
	For Each KeyAndValue In SaaSOperationsCached.ContactInformationKindAndXDTOUserMap() Do
		ActionsWithCI[KeyAndValue.Key].Change = False;
	EndDo;
	
	Return ActionsWithSaaSUser;
	
EndFunction

// For internal use only
Function GetSaaSUsers(ServiceUserPassword) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaSOperations.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	ErrorInfo = Undefined;
	
	Try
		
		UserList = Proxy.GetUsersList(SaaSOperations.SessionSeparatorValue(), );
		
	Except
		
		ServiceUserPassword = Undefined;
		Raise;
		
	EndTry;
	
	HandleWebServiceErrorInfo(ErrorInfo, "GetUsersList"); // Do not localize the operation name
	
	Result = New ValueTable;
	Result.Columns.Add("ID", New TypeDescription("UUID"));
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("FullName", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Access", New TypeDescription("Boolean"));
	
	For Each UserInfo In UserList.Item Do
		UserRow = Result.Add();
		UserRow.ID = UserInfo.UserServiceID;
		UserRow.Name = UserInfo.Name;
		UserRow.FullName = UserInfo.FullName;
		UserRow.Access = UserInfo.Access;
	EndDo;
	
	Return Result;
	
EndFunction

// For internal use only
Procedure GrantSaaSUserAccess(Val ServiceUserID, Val ServiceUserPassword) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaSOperations.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	ErrorInfo = Undefined;
	Proxy.GrantUserAccess(
		CommonUse.SessionSeparatorValue(),
		ServiceUserID, 
		ErrorInfo);
	HandleWebServiceErrorInfo(ErrorInfo, "GrantUserAccess"); // Do not localize the operation name
	
EndProcedure

// For the OnCompleteInfobaseUserProcessing procedure
Procedure CancelSaaSUserAccess(UserObject)
	
	If Not ValueIsFilled(UserObject.ServiceUserID) Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Message = MessagesSaaS.NewMessage(
			ApplicationManagementMessagesInterface.MessageCancelUserAccess());
		
		Message.Body.Zone = CommonUse.SessionSeparatorValue();
		Message.Body.UserServiceID = UserObject.ServiceUserID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSOperationsCached.ServiceManagerEndpoint());
			
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks whether the user passed to the function matches the current infobase user in the current data area.
//
// Parameters:
//  User - CatalogRef.Users;
//
// Returns: Boolean.
//
Function IsExistingUserCurrentDataArea(Val User)
	
	SetPrivilegedMode(True);
	
	If ValueIsFilled(User) Then
		
		If ValueIsFilled(User.InfobaseUserID) Then
			
			If InfobaseUsers.FindByUUID(User.InfobaseUserID) <> Undefined Then
				
				Return True;
				
			Else
				
				Return False;
				
			EndIf;
			
		Else
			
			Return False;
			
		EndIf;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Function CurrentUserServiceID()
	
	Return CommonUse.ObjectAttributeValue(Users.CurrentUser(), "ServiceUserID");
	
EndFunction

Function NewActionsWithSaaSUser()
	
	ActionsWithSaaSUser = New Structure;
	ActionsWithSaaSUser.Insert("ChangePassword", False);
	ActionsWithSaaSUser.Insert("ChangeName", False);
	ActionsWithSaaSUser.Insert("ChangeFullName", False);
	ActionsWithSaaSUser.Insert("ChangeAccess", False);
	ActionsWithSaaSUser.Insert("ChangeAdmininstrativeAccess", False);
	
	ActionsWithCI = New Map;
	For Each KeyAndValue In SaaSOperationsCached.ContactInformationKindAndXDTOUserMap() Do
		ActionsWithCI.Insert(KeyAndValue.Key, New Structure("Change", False));
	EndDo;
	ActionsWithSaaSUser.Insert("ContactInformation", ActionsWithCI); // Key - CIKind, Value - Structure of rights
	
	Return ActionsWithSaaSUser;
	
EndFunction

Function PrepareUserAccessObjects(Factory, User)
	
	UserInformation = Factory.Create(
		Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "User"));
	UserInformation.Zone = SaaSOperations.SessionSeparatorValue();
	UserInformation.UserServiceID = CommonUse.ObjectAttributeValue(User, "ServiceUserID");
	
	ListOfObjects = Factory.Create(
		Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "ObjectsList"));
		
	ListOfObjects.Item.Add(UserInformation);
	
	UserCIType = Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "UserContact");
	
	For Each KeyAndValue In SaaSOperationsCached.ContactInformationKindAndXDTOUserMap() Do
		CIKind = Factory.Create(UserCIType);
		CIKind.UserServiceID = CommonUse.ObjectAttributeValue(User, "ServiceUserID");
		CIKind.ContactType = KeyAndValue.Value;
		ListOfObjects.Item.Add(CIKind);
	EndDo;
	
	Return ListOfObjects;
	
EndFunction

Function ObjectsAccessRightsXDTOInActionsWithSaaSUser(Factory, ObjectsAccessRightsXDTO)
	
	UserInformationType = Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "User");
	UserCIType = Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "UserContact");
	
	ActionsWithSaaSUser = NewActionsWithSaasUser();
	ActionsWithCI = ActionsWithSaaSUser.ContactInformation;
	
	For Each ObjectAccessRightsXDTO In ObjectsAccessRightsXDTO.Item Do
		
		If ObjectAccessRightsXDTO.Object.Type() = UserInformationType Then
			
			For Each RightsListItem In ObjectAccessRightsXDTO.AccessRights.Item Do
				ActionsWithUser = SaaSOperationsCached.
					XDTORightAndServiceUserActionMap().Get(RightsListItem.AccessRight);
				ActionsWithSaaSUser[ActionsWithUser] = True;
			EndDo;
			
		ElsIf ObjectAccessRightsXDTO.Object.Type() = UserCIType Then
			CIKind = SaaSOperationsCached.XDTOContactInformationKindAndUserContactInformationKindMap().Get(
				ObjectAccessRightsXDTO.Object.ContactType);
			If CIKind = Undefined Then
				MessagePattern = NStr("en = 'Unknown contact information kind: %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					MessagePattern, ObjectAccessRightsXDTO.Object.ContactType);
				Raise(MessageText);
			EndIf;
			
			ActionsWithCIKind = ActionsWithCI[CIKind];
			
			For Each RightsListItem In ObjectAccessRightsXDTO.AccessRights.Item Do
				If RightsListItem.AccessRight = "Change" Then
					ActionsWithCIKind.Change = True;
				EndIf;
			EndDo;
		Else
			MessagePattern = NStr("en = 'Unknown access object type: %1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				MessagePattern, CommonUse.XDTOTypePresentation(ObjectAccessRightsXDTO.Object.Type()));
			Raise(MessageText);
		EndIf;
		
	EndDo;
	
	Return ActionsWithSaaSUser;
	
EndFunction

Function GetLanguageCode(Val Lang)
	
	If Lang = Undefined Then
		Return "";
	Else
		Return Lang.LanguageCode;
	EndIf;
	
EndFunction

// Handles the web service error info.
// If the error info passed to the procedure is not empty, writes the error details to the
// event log and raises an exception with the brief error description.
//
Procedure HandleWebServiceErrorInfo(Val ErrorInfo, Val OperationName)
	
	SaaSOperations.HandleWebServiceErrorInfo(
		ErrorInfo,
		UsersInternalSaaSCached.SubsystemNameForEventLogEvents(),
		"ManagementApplication", // Do not localize this parameter
		OperationName);
	
EndProcedure

#EndRegion