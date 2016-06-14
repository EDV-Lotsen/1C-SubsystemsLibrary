///////////////////////////////////////////////////////////////////////////////////
// Access management SaaS subsystem
///////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
//
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"AccessManagementInternalSaaS");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnReceiveTemplateList"].Add(
				"AccessManagementInternalSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\AfterDataImportFromOtherMode"].Add(
				"AccessManagementInternalSaaS");
	EndIf;
	
EndProcedure

// OnReceiveTemplateList event handler.
// Generates a list of queue job templates.
// Parameters:
//  Templates - Array of String - parameter should include names of predefined
// shared scheduled jobs to be used as queue job templates.
//
Procedure OnReceiveTemplateList(Templates) Export
	
	Templates.Add("DataFillingForAccessRestrictions");
	
EndProcedure

// Sets a job queue flag marking for use a job that corresponds to the 
// scheduled job for access restriction data filling.
// Parameters:
//  Use - Boolean - new value of the usage flag.
//
Procedure SetDataFillingForAccessRestrictions(Use) Export
	
	Template = JobQueue.TemplateByName("DataFillingForAccessRestrictions");
	
	JobFilter = New Structure;
	JobFilter.Insert("Template", Template);
	Jobs = JobQueue.GetJobs(JobFilter);
	
	JobParameters = New Structure("Use", Use);
	JobQueue.ChangeJob(Jobs[0].ID, JobParameters);
	
EndProcedure

// Adds update handlers that are required by the subsystem.
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function
//             in the InfobaseUpdate common module.
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.0.4";
	Handler.Procedure = "AccessManagementInternalSaaS.UpdateAdministratorAccessGroupSaaS";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.SharedData = True;
	Handler.Procedure = "AccessManagementInternalSaaS.UpdateDataFillingTemplateScheduleForAccessRestriction";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Moves all users from the Data administrators access group into the 
// Administrators access group.
// Deletes the Data administrator profile and the Data administrators access group.
//
 
Procedure UpdateAdministratorAccessGroupSaaS() Export
	
	SetPrivilegedMode(True);
	
	DataAdministratorProfileRef = Catalogs.AccessGroupProfiles.GetRef(
		New UUID("f0254dd0-3558-4430-84c7-154c558ae1c9"));
		
	AccessGroupDataAdministratorsRef = Catalogs.AccessGroups.GetRef(
		New UUID("c7684994-34c9-4ddc-b31c-05b2d833e249"));
	
	Query = New Query;
	Query.SetParameter("DataAdministratorProfileRef",        DataAdministratorProfileRef);
	Query.SetParameter("AccessGroupDataAdministratorsRef", AccessGroupDataAdministratorsRef);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Ref = &AccessGroupDataAdministratorsRef
	|	AND AccessGroups.Profile = &DataAdministratorProfileRef
	|;
	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.Ref = &DataAdministratorProfileRef";
	
	BeginTransaction();
	Try
		
		QueryResults = Query.ExecuteBatch();
		
		If Not QueryResults[0].IsEmpty() Then
			AdministratorsGroup = Catalogs.AccessGroups.Administrators.GetObject();
			DataAdministratorGroup = AccessGroupDataAdministratorsRef.GetObject();
			
			If DataAdministratorGroup.Users.Count() > 0 Then
				For Each Row In DataAdministratorGroup.Users Do
					If AdministratorsGroup.Users.Find(Row.User, "User") = Undefined Then
						AdministratorsGroup.Users.Add().User = Row.User;
					EndIf;
				EndDo;
				InfobaseUpdate.WriteData(AdministratorsGroup);
			EndIf;
			InfobaseUpdate.DeleteData(DataAdministratorGroup);
		EndIf;
		
		If Not QueryResults[1].IsEmpty() Then
			DataAdministratorProfile = DataAdministratorProfileRef.GetObject();
			InfobaseUpdate.DeleteData(DataAdministratorProfile);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates the job schedule settings.
Procedure UpdateDataFillingTemplateScheduleForAccessRestriction() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Template = JobQueue.TemplateByName("DataFillingForAccessRestrictions");
	TemplateObject = Template.GetObject();
	
	Schedule = New JobSchedule;
	Schedule.WeeksPeriod = 1;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.RepeatPeriodInDay = 300;
	Schedule.RepeatPause = 90;
	
	TemplateObject.Schedule = New ValueStorage(Schedule);
	TemplateObject.Write();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// This procedure is called after data import from a local version to service
// data area (or vice versa) is completed.
//

Procedure AfterDataImportFromOtherMode() Export
	
	Catalogs.AccessGroupProfiles.UpdateSuppliedProfiles(); 
	
EndProcedure

// Called when processing the 
// http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl message.
//
// Parameters:
//  DataAreaUser  - CatalogRef.Users - the user to be added to or removed from
//                  the Administrators group. 
//  AccessAllowed - Boolean - if True, the user is added to the group, if False, 
//                  the user is removed from the group.
//
 
Procedure SetUserBelongingToAdministratorGroup(Val DataAreaUser, Val AccessAllowed) Export
	
	AdministratorsGroup = Catalogs.AccessGroups.Administrators;
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Catalog.AccessGroups");
	LockItem.SetValue("Ref", AdministratorsGroup);
	DataLock.Lock();
	
	ObjectGroup = AdministratorsGroup.GetObject();
	
	UserRow = ObjectGroup.Users.Find(DataAreaUser, "User");
	
	If AccessAllowed And UserRow = Undefined Then
		
		UserRow = ObjectGroup.Users.Add();
		UserRow.User = DataAreaUser;
		ObjectGroup.Write();
		
	ElsIf Not AccessAllowed And UserRow <> Undefined Then
		
		ObjectGroup.Users.Delete(UserRow);
		ObjectGroup.Write();
	Else
		AccessManagement.UpdateUserRoles(DataAreaUser);
	EndIf;
	
EndProcedure

#EndRegion
