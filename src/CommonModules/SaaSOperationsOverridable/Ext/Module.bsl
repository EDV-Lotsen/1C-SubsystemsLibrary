///////////////////////////////////////////////////////////////////////////////////
// SaaSOperationsOverridable.
//
///////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Is called on the data area deletion.
// All data that cannot be deleted by the standard way should be deleted in this
// procedure.
//
// Parameters:
//  DataArea - Separator value type - deleted data area separator value.
//
Procedure DataAreaOnDelete(Val DataArea) Export
	
EndProcedure
 
// Generates the infobase parameter list.
//
// Parameters:
//  ParameterTable - ValueTable - parameter details table.
//  For column content details see SaaSOperations.GetInfobaseParameterTable().
//
Procedure GetInfobaseParameterTable(Val ParameterTable) Export
	
EndProcedure
 
// Is called before the attempt of retrieving infobase parameter value from 
// constants that have equal names.
//
// Parameters:
// ParameterNames - string array - parameter names of required values.
// If this procedure gets parameter value, parameter name must be deleted.
// ParameterValues - Structure - parameter value.
//
Procedure OnReceiveInfobaseParameterValues(Val ParameterNames, Val ParameterValues) Export
	
EndProcedure
 
// Is called before the attempt of writing infobase parameter values to
// constants with equal names.
//
// Parameters:
//  ParameterValues - Structure - setting parameter values.
//  If this procedure sets parameter value, the corresponding KeyAndValue must be 
//  deleted.
//
Procedure OnSetInfobaseParameterValues(Val ParameterValues) Export
	
EndProcedure

// Is called on enabling the data area separation at the initial run with
// InitSeparatedInfobase parameter.
// 
// Specifically, you should place here the script for enabling scheduled jobs
// that are only used when data separation is enabled
// (and disabling scheduled jobs that are only used when data separation is disabled).
//
// You may see an example in
// StandardSubsystemsOverridable.OnEnableSeparationByDataAreas(). 
//
Procedure OnEnableSeparationByDataAreas() Export
	
EndProcedure
 
// Sets default rights to the user.
// Is called in service mode when user rights without administrative rights are
// updated in the service manager.
//
// Parameters:
//  User -  CatalogRef.Users - user to set default rights.
//
Procedure SetDefaultRights(User) Export
	
	// _Demo start example
	//NewAccessGroups = New Array;
	//NewAccessGroups.Add(Catalogs.AccessGroups.FindByDescription("Users"));
	//
	//BeginTransaction();
	//
	//Query = New  Query;
	//Query.Text =
	//"SELECT
	//|	AccessGroupsUsers.Ref
	//|FROM
	//|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	//|WHERE
	//|	AccessGroupsUsers.User = &User
	//|	AND (NOT AccessGroupsUsers.Ref IN (&NewGroups))
	//|;
	//|
	//|////////////////////////////////////////////////////////////////////////////////
	//|SELECT
	//|	AccessGroups.Ref
	//|FROM
	//|	Catalog.AccessGroups  AS AccessGroups
	//|		LEFT JOIN Catalog.AccessGroups.Users AS  AccessGroupsUsers
	//|			ON AccessGroups.Ref =  AccessGroupsUsers.Ref
	//|			AND (AccessGroupsUsers.User = &User)
	//|WHERE
	//|	AccessGroups.Ref IN(&NewGroups)
	//|	AND  AccessGroupsUsers.Ref IS NULL";
	//Query.SetParameter("User", User);
	//Query.SetParameter("NewGroups", NewAccessGroups);
	//Results = Query.ExecuteBatch();
	//
	//SelectionExclude = Results[0].StartChoosing();
	//While SelectionExclude.Next() Do
	//	ObjectGroup = SelectionExclude.Ref.GetObject();
	//	ObjectGroup.Users.Delete(ObjectGroup.Users.Find(User, "User"));
	//	ObjectGroup.Write();
	//EndDo;
	//
	//SelectionAdd = Results[1].StartChoosing();
	//While SelectionAdd.Next() Do
	//	ObjectGroup = SelectionAdd.Ref.GetObject();
	//	UserRow = ObjectGroup.Users.Add();
	//	UserRow.User = User;
	//	ObjectGroup.Write();
	//EndDo;
	//
	//CommitTransaction();
	// _Demo end example
	
EndProcedure

#EndRegion
