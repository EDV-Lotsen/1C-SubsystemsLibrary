////////////////////////////////////////////////////////////////////////////////
// Performance monitor subsystem.
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BaseFunctionality\BeforeExit"].Add(
		"PerformanceMonitorClient");
	
	// SERVER HANDLERS.
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SessionParameterSettingHandlersOnAdd"].Add(
		"PerformanceMonitorInternal");
		
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnFillPermissionsToAccessExternalResources"].Add(
			"PerformanceMonitorInternal");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers.

// Returns the mapping between session parameter names and their initialization handlers.
//
Procedure SessionParameterSettingHandlersOnAdd(Handlers) Export
	
	Handlers.Insert("CurrentTimeMeasurement", "PerformanceMonitorServerCall.SessionParametersSetting");
	
EndProcedure

// Fills a list of requests for external permissions that must be granted when an infobase is created or an application is updated.
//
// Parameters:
//  PermissionRequests - Array - list of values
//                      returned by SafeMode.RequestToUseExternalResources() method.
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If CommonUseCached.DataSeparationEnabled() And CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	DirectoriesForExport = PerformanceMonitorDataExportDirectories();
	If DirectoriesForExport = Undefined Then
		Return;
	EndIf;
	
	URLStructure = CommonUseClientServer.URIStructure(DirectoriesForExport.FTPExportDirectory);
	DirectoriesForExport.Insert("FTPExportDirectory", URLStructure.ServerName);
	If ValueIsFilled(URLStructure.Port) Then
		DirectoriesForExport.Insert("FTPExportDirectoryPort", URLStructure.Port);
	EndIf;
	
	PermissionRequests.Add(
		SafeMode.RequestToUseExternalResources(
			PermissionsToUseServerResources(DirectoriesForExport), 
				CommonUse.MetadataObjectID("Constant.EnablePerformanceMeasurements")));
	
EndProcedure

// For internal use only.
Function RequestToUseExternalResources(Directories) Export
	
	Return SafeMode.RequestToUseExternalResources(
				PermissionsToUseServerResources(Directories), 
					CommonUse.MetadataObjectID("Constant.EnablePerformanceMeasurements"));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Finds and returns a scheduled job that exports time measurement results.
//
// Returns:
//  ScheduledJob - ScheduledJob.PerformanceMonitorDataExport, scheduled job.
//
Function PerformanceMonitorDataExportScheduledJob() Export
	
	SetPrivilegedMode(True);
	Jobs = ScheduledJobs.GetScheduledJobs(
		New Structure("Metadata", "PerformanceMonitorDataExport"));
	If Jobs.Count() = 0 Then
		Job = ScheduledJobs.CreateScheduledJob(
			Metadata.ScheduledJobs.PerformanceMonitorDataExport);
		Job.Write();
		Return Job;
	Else
		Return Jobs[0];
	EndIf;
		
EndFunction

// Returns directories for exporting files with measurement results.
//
// Parameters:
// None
//
// Returns:
//    Structure:
//        "ExecuteExportToFTP"            - Boolean - Flag that shows whether measurement results are exported to an FTP directory.  
//        "FTPExportDirectory"            - String  - FTP directory for exporting measurement results. 
//        "ExecuteExportToLocalDirectory" - Boolean - Flag that shows whether measurement results are exported to a local directory.  
//        "LocalExportDirectory"          - String  - Local directory for exporting measurement results.
//
Function PerformanceMonitorDataExportDirectories() Export
	
	Job = PerformanceMonitorDataExportScheduledJob();
	Directories = New Structure;
	If Job.Parameters.Count() > 0 Then
		Directories = Job.Parameters[0];
	EndIf;
	
	If TypeOf(Directories) <> Type("Structure") Or Directories.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ReturnValue = New Structure;
	ReturnValue.Insert("ExecuteExportToFTP");
	ReturnValue.Insert("FTPExportDirectory");
	ReturnValue.Insert("ExecuteExportToLocalDirectory");
	ReturnValue.Insert("LocalExportDirectory");
	
	JobKeyToItems = New Structure;
	FTPItems = New Array;
	FTPItems.Add("ExecuteExportToFTP");
	FTPItems.Add("FTPExportDirectory");
	
	LocalItems = New Array;
	LocalItems.Add("ExecuteExportToLocalDirectory");
	LocalItems.Add("LocalExportDirectory");
	
	JobKeyToItems.Insert(PerformanceMonitorClientServer.FTPExportDirectoryJobKey(), FTPItems);
	JobKeyToItems.Insert(PerformanceMonitorClientServer.LocalExportDirectoryJobKey(), LocalItems);
	ExecuteExport = False;
	For Each ItemsKeyName In JobKeyToItems Do
		KeyName = ItemsKeyName.Key;
		ItemsToEdit = ItemsKeyName.Value;
		ItemNumber = 0;
		For Each ItemName In ItemsToEdit Do
			Value = Directories[KeyName][ItemNumber];
			ReturnValue[ItemName] = Value;
			If ItemNumber = 0 Then 
				ExecuteExport = ExecuteExport Or Value;
			EndIf;
			ItemNumber = ItemNumber + 1;
		EndDo;
	EndDo;
	
	Return ReturnValue;
	
EndFunction

// Returns a reference to "Overall performance" item.
// If the OverallSystemPerformance predefined item exists,
// returns this item. Otherwise returns an empty reference.
//
// Parameters:
//  None
// Returns:
//  CatalogRef.KeyOperations
//
Function GetOverallSystemPerformanceItem() Export
	
	PredefinedKO = StandardSubsystemsServer.PredefinedDataNames("Catalog.KeyOperations");
	HasPredefinedItem = ?(PredefinedKO.Find("OverallSystemPerformance") <> Undefined, True, False);
	
	QueryText = 
	"SELECT TOP 1
	|	KeyOperations.Ref,
	|	2 AS Priority
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.Name = ""OverallSystemPerformance""
	|	AND NOT KeyOperations.DeletionMark
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	VALUE(Catalog.KeyOperations.EmptyRef),
	|	3
	|
	|ORDER BY
	|	Priority";
	
	If HasPredefinedItem Then
		QueryText = 
		"SELECT TOP 1
		|	KeyOperations.Ref,
		|	1 AS Priority
		|FROM
		|	Catalog.KeyOperations AS KeyOperations
		|WHERE
		|	KeyOperations.PredefinedDataName = ""OverallSystemPerformance""
		|	AND NOT KeyOperations.DeletionMark
		|
		|UNION ALL
		|" + QueryText;
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("KeyOperations", PredefinedKO);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.Ref;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Generates an array of permissions for exporting measurement data.
// 
// Parameters - DirectoriesForExport - Structure.
//
// Returns:
//	Array
Function PermissionsToUseServerResources(Directories)
	
	Permissions = New Array;
	
	If Directories <> Undefined Then
		If Directories.Property("ExecuteExportToLocalDirectory") And Directories.ExecuteExportToLocalDirectory = True Then
			If Directories.Property("LocalExportDirectory") And ValueIsFilled(Directories.LocalExportDirectory) Then
				Item = SafeMode.PermissionToUseFileSystemDirectory(
					Directories.LocalExportDirectory,
					True,
					True,
					NStr("en = 'Network directory for exporting performance measurement results.'"));
				Permissions.Add(Item);
			EndIf;
		EndIf;
		
		If Directories.Property("ExecuteExportToFTP") And Directories.ExecuteExportToFTP = True Then
			If Directories.Property("FTPExportDirectory") And ValueIsFilled(Directories.FTPExportDirectory) Then
				Item = SafeMode.PermissionToUseInternetResource(
					"FTP",
					Directories.FTPExportDirectory,
					?(Directories.Property("FTPExportDirectoryPort"), Directories.FTPExportDirectoryPort, Undefined),
					NStr("en = 'FTP resource for exporting performance measurement results.'"));
				Permissions.Add(Item);
			EndIf;
		EndIf;
	EndIf;
	
	Return Permissions;
EndFunction

#EndRegion
