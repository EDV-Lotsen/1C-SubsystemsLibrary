////////////////////////////////////////////////////////////////////////////////
// Users subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Disables the standard method of setting infobase user roles.
// If this function returns True, role editing becomes prohibited (for all users 
// including an administrator).
//
// Returns:
//  Boolean.
//
Function RoleEditProhibition() Export
	
	Return False;
	
EndFunction

// Overrides the role that provides infobase administrator rights.
//
// Parameters:
//  Role         - MetadataObject: Role.
//
Procedure ChangeFullAdministratorRole(Role) Export
	
	
	
EndProcedure

// Overrides actions of a user, external user, and external user group form. 
// Is used when creating the form.          
//           
//  Ref           - CatalogRef.Users,
//                  CatalogRef.ExternalUsers,
//                  CatalogRef.ExternalUserGroups -
//                  reference to a user, external user, or external user group.
//           
//  ActionsOnForm - Structure with the following fields of String:
//                  Roles                  = "", "View",    "Edit"
//                  ContactInformation     = "", "View",    "Edit"
//                  InfoBaseUserProperties = "", "ViewAll", "EditAll", EditOwn"
//                  ItemProperties         = "", "View",    "Edit"
//           
//                  ContactInformation and InfoBaseUserProperties does not exist for 
//                  external user groups.
//
Procedure ChangeActionsOnForm(Val Ref = Undefined, Val ActionsOnForm) Export
	
EndProcedure

// Defines extra actions when writing an infobase user.
// Is called from the WriteIBUser procedure if the user has been modified.
//
// Parameters:
//  OldProperties - Structure - see Users.ReadInfoBaseUser function return parameters for details.
//  NewProperties - Structure - see Users.WriteIBUser function return parameters for details.
//
Procedure OnWriteInfoBaseUser(Val OldProperties, Val NewProperties) Export
	
EndProcedure

// Defines extra actions to be done after deleting infobase users.
//  Is called from the DeleteInfoBaseUser procedure if a user has been deleted.
//
// Parameters:
// OldProperties - Structure - see Users.ReadInfoBaseUser function return parameters for details.
//
Procedure AfterInfoBaseUserDelete(Val OldProperties) Export
	
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers for writing the first administrator

// Overrides question text to be displayed before writing the first administrator.
// Is called from the user form BeforeWrite handler if RoleEditProhibition() is True 
// and infobase user number is 0.
// 
Procedure QuestionTextBeforeWriteFirstAdministrator(QuestionText) Export
	
EndProcedure

// Defines extra actions when writing an administrator.
// Is called when writing an administrator in the authorization procedure.
// Usually it happens when writing the first administrator, but it also can occur when 
// relating an infobase user with a Users catalog item.
// 
// Parameters:
//  User - CatalogRef.Users (object change is prohibited).
//
Procedure OnWriteFirstAdministrator(User) Export
		
EndProcedure

// Overrides the comment text when authorizing an infobase user that has been created
// in the designer mode with administrative rights.
// Is called from Users.AuthenticateCurrentUser
// Comment are logged in the event log.
// 
// Parameters:
//  Comment - String - initial value has been set.
//
Procedure AfterWriteAdministratorOnAuthorization(Comment) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Service mode.

// Sets default user rights.
// Is called when working in the service mode in case of updating rights of a not administrative user in the service manager.
//
// Parameters:
//  User - CatalogRef.Users - user whose rights will be set by default.
//
Procedure SetDefaultRights(User) Export
	
	// _Demo Start Example
	BeginTransaction();
	
	If Not User.Roles.Contains(Metadata.Roles.Operator) Then
		User.Roles.Add(Metadata.Roles.Operator);
	EndIf;
	
	User.Write();
	
	CommitTransaction();
	// _Demo End Example
	
EndProcedure
