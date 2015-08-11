///////////////////////////////////////////////////////////////////////////////////
// UsersServiceMode: Procedures and functions for working with users in the service mode.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Checks whether the infobase user with the specified ID
// is in the shared user list.
//
// Parameters:
//  InfoBaseUserID - UUID - ID of a user to be checked.
//
Function IsSharedInfoBaseUser(Val InfoBaseUserID) Export
	
	If Not ValueIsFilled(InfoBaseUserID) Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SharedUserIDs.InfoBaseUserID
	|FROM
	|	InformationRegister.SharedUsers AS SharedUserIDs
	|WHERE
	|	SharedUserIDs.InfoBaseUserID = &InfoBaseUserID";
	Query.SetParameter("InfoBaseUserID", InfoBaseUserID);
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// In the service mode, writes the current user to the shared user list
// if separators for this user are disabled.
//
Procedure RegisterSharedUser() Export
	
	If Not IsBlankString(InfoBaseUsers.CurrentUser().Name)
		And CommonUseCached.DataSeparationEnabled()
		And InfoBaseUsers.CurrentUser().DataSeparation.Count() = 0 Then
		
		BeginTransaction();
		Try
			Lock = New DataLock;
			LockItem = Lock.Add("InformationRegister.SharedUsers");
			LockItem.SetValue("InfoBaseUserID", 
				InfoBaseUsers.CurrentUser().UUID);
			Lock.Lock();
			
			RecordManager = InformationRegisters.SharedUsers.CreateRecordManager();
			RecordManager.InfoBaseUserID = InfoBaseUsers.CurrentUser().UUID;
			RecordManager.Read();
			If Not RecordManager.Selected() Then
				RecordManager.InfoBaseUserID = InfoBaseUsers.CurrentUser().UUID;
				RecordManager.Write();
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Registering shared user'", Metadata.DefaultLanguage.LanguageCode), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		
	EndIf;
	
EndProcedure

// Shows whether users can be changed.
//
// Returns:
// Boolean - True if users can be changed, otherwise is False.
//
Function CanChangeUsers() Export
	
	Return Constants.InfoBaseUsageMode.Get() 
		<> Enums.InfoBaseUsageModes.Demo;
	
EndFunction

// Adds update handlers required by this subsystem to the Handlers list. 
// 
// Parameters:
// Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable function for details. 
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.14";
	Handler.Procedure = "UsersServiceMode.ReplaceDeleteDataAreaFullAccessWithFullAccess";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Function GetLanguageCodeByName(Val LanguageName)
	
	If IsBlankString(LanguageName) Then
		Return "";
	Else
		Return Metadata.Languages[LanguageName].LanguageCode;
	EndIf;
	
EndFunction

// For internal use only.
//
Procedure BeforeWriteUser(UserObject) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
		// The cache must be filled before writing an infobase user
		ServiceMode.GetServiceManagerProxy();
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure


// For internal use only.
//
Procedure UserOnWrite(UserObject, UserDetails, UserExists, AccessAllowed, CreateServiceUser) Export
	
	Name = UserDetails.Name;
	FullName = UserDetails.FullName;
	Language = UserDetails.Language;
	
	If CreateServiceUser Then
		
		SetPrivilegedMode(True);
		
		Proxy = ServiceMode.GetServiceManagerProxy();
		
		CurrentDataArea = CommonUse.SessionSeparatorValue();
		
		InfoBaseUser = InfoBaseUsers.FindByUUID(UserObject.InfoBaseUserID);
			
		StoredPasswordValue = InfoBaseUser.StoredPasswordValue;
		
		SetPrivilegedMode(False);
		
		ErrorMessage = "";
		
		UserInfoType = Proxy.XDTOFactory.Type("http://1c-dn.com/SaaS/1.0/XMLSchema/ManagementApplication",
			"UserInfo");
		UserInfo = Proxy.XDTOFactory.Create(UserInfoType);
		UserInfo.Name = Name;
		UserInfo.FullName = FullName;
		UserInfo.StoredPasswordValue = StoredPasswordValue;
		UserInfo.Language = GetLanguageCodeByName(Language);
		UserInfo.UserID = UserObject.ServiceUserID;
		
		Result = Proxy.CreateUser(CurrentDataArea, UserInfo, ErrorMessage);
		If Result <> True Then
			MessagePattern = NStr("en = 'Error creating a user service:
				|%1'");
			Raise(StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ErrorMessage));
		EndIf;
			
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() 
		And ValueIsFilled(UserObject.ServiceUserID) Then
		
		// Service details must be updated
		SetPrivilegedMode(True);
		Proxy = ServiceMode.GetServiceManagerProxy();
		
		CurrentDataArea = CommonUse.SessionSeparatorValue();
		SetPrivilegedMode(False);
		
		ErrorMessage = "";
		UserList = Undefined;
		
		Result = Proxy.GetUserList(CurrentDataArea, UserList, ErrorMessage);
		
		If Not Result Then
			MessagePattern = NStr("en = 'Error retrieving the service user list:
				|%1'");
			Raise(StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ErrorMessage));
		EndIf;
		
		CurrentUserInfo = Undefined;
		For Each UserInfo In UserList.User Do
			If UserObject.ServiceUserID = UserInfo.UserID Then
				
				CurrentUserInfo = UserInfo;
				Break;
			EndIf;
		EndDo;
		
		If CurrentUserInfo = Undefined Then
			MessagePattern = NStr("en = 'The user whose ID is %1 from the %2 data area is not found in the service user list.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
				UserObject.ServiceUserID,
				CurrentDataArea);
				
			Raise(MessageText);
		EndIf;
		
		If UserExists <> AccessAllowed Then
		
			If CurrentUserInfo.HasAccess <> AccessAllowed Then
				If AccessAllowed Then
					ErrorMessage = "";
					Result = Proxy.GrantUserAccess(UserObject.ServiceUserID,
						CurrentDataArea, "User", ErrorMessage);
						
					If Not Result Then
						MessagePattern = NStr("en = 'Error providing user access to the service:
							|%1'");
						Raise(StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ErrorMessage));
					EndIf;
				Else
					ErrorMessage = "";
					Result = Proxy.DeleteUserAccess(UserObject.ServiceUserID,
						CurrentDataArea, ErrorMessage);
						
					If Not Result Then
						MessagePattern = NStr("en = 'Error denying user access to the service:
							|%1'");
						Raise(StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ErrorMessage));
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		If AccessAllowed Then
			
			UserInfoType = Proxy.XDTOFactory.Type("http://1c-dn.com/SaaS/1.0/XMLSchema/ManagementApplication", "UserInfo");
			UserDetails = Proxy.XDTOFactory.Create(UserInfoType);
			UserDetails.Name = Name;
			UserDetails.FullName = FullName;
			
			SetPrivilegedMode(True);
			InfoBaseUser = InfoBaseUsers.FindByUUID(UserObject.InfoBaseUserID);
			
			UserDetails.StoredPasswordValue = InfoBaseUser.StoredPasswordValue;
			
			SetPrivilegedMode(False);
			
			UserDetails.Language = GetLanguageCodeByName(Language);
				
			ErrorMessage = "";
			Result = Proxy.SetUserInfo(UserObject.ServiceUserID, UserDetails, ErrorMessage);
			
			If Not Result Then
				MessagePattern = NStr("en = 'Error synchronizing user details with service manager data:
					|%1'");
				Raise(StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ErrorMessage));
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure GetUserFormProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If FormType = "ObjectForm"
		And Parameters.Property("Key") And Not Parameters.Key.IsEmpty() Then
		
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	1
		|FROM
		|	InformationRegister.SharedUsers AS SharedUsers
		|		INNER JOIN Catalog.Users AS Users
		|			ON SharedUsers.InfoBaseUserID = Users.InfoBaseUserID
		|			AND (Users.Ref = &Ref)";
		Query.SetParameter("Ref", Parameters.Key);
		If Not Query.Execute().IsEmpty() Then
			StandardProcessing = False;
			SelectedForm = Metadata.CommonForms.SharedUserInfo;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for updating the infobase.

// Is called when updating the configuration to the version 2.0.1.14;
// Adds the FullAccess role to all users with the DeleteDataAreaFullAccess role.
//
Procedure ReplaceDeleteDataAreaFullAccessWithFullAccess() Export
	
	If UsersOverridable.RoleEditProhibition() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	For Each InfoBaseUser In InfoBaseUsers.GetUsers() Do
		If InfoBaseUser.Roles.Contains(Metadata.Roles.FullAccess) Then
			
			Continue;
		EndIf;
		
		InfoBaseUser.Roles.Add(Metadata.Roles.FullAccess);
		InfoBaseUser.Write();
	EndDo;
	
EndProcedure
