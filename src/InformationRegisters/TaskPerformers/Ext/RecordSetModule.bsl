#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// StandardSubsystems.AccessManagement
Var ModifiedPerformerGroups; // Performer groups with modified content.
// End StandardSubsystems.AccessManagement

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() > 0 Then
		NewTaskPerformers = Unload();
		SetPrivilegedMode(True);
		TaskPerformerGroups = BusinessProcessesAndTasksServer.TaskPerformerGroups(NewTaskPerformers);
		SetPrivilegedMode(False);
		Index = 0;
		For Each Record In ThisObject Do
			Record.TaskPerformerGroup = TaskPerformerGroups[Index];
			Index = Index + 1;
		EndDo
	EndIf;
		
	// StandardSubsystems.AccessManagement
	FillModifiedTaskPerformerGroups();
	// End StandardSubsystems.AccessManagement
	
EndProcedure

// StandardSubsystems.AccessManagement

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AccessManagementInternalModule = CommonUse.CommonModule("AccessManagementInternal");
	AccessManagementInternalModule.UpdatePerformerGroupUsers(ModifiedPerformerGroups);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure FillModifiedTaskPerformerGroups()
	
	Query = New Query;
	Query.SetParameter("NewRecords", 
Unload());
	Query.Text =
	"SELECT
	|	NewRecords.PerformerRole,
	|	NewRecords.Performer,
	|	NewRecords.MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject,
	|	NewRecords.TaskPerformerGroup
	|INTO NewRecords
	|FROM
	|	&NewRecords AS NewRecords
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Total.TaskPerformerGroup
	|FROM
	|	(SELECT DISTINCT
	|		Differences.TaskPerformerGroup AS TaskPerformerGroup
	|	FROM
	|		(SELECT
	|			TaskPerformers.PerformerRole AS PerformerRole,
	|			TaskPerformers.Performer AS Performer,
	|			TaskPerformers.MainAddressingObject AS MainAddressingObject,
	|			TaskPerformers.AdditionalAddressingObject AS AdditionalAddressingObject,
	|			TaskPerformers.TaskPerformerGroup AS TaskPerformerGroup,
	|			-1 AS RowChangeKind
	|		FROM
	|			InformationRegister.TaskPerformers AS TaskPerformers
	|		WHERE
	|			&FilterConditions
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			NewRecords.PerformerRole,
	|			NewRecords.Performer,
	|			NewRecords.MainAddressingObject,
	|			NewRecords.AdditionalAddressingObject,
	|			NewRecords.TaskPerformerGroup,
	|			1
	|		FROM
	|			NewRecords AS NewRecords) AS Differences
	|	
	|	GROUP BY
	|		Differences.PerformerRole,
	|		Differences.Performer,
	|		Differences.MainAddressingObject,
	|		Differences.AdditionalAddressingObject,
	|		Differences.TaskPerformerGroup
	|	
	|	HAVING
	|		SUM(Differences.RowChangeKind) <> 0) AS Total
	|WHERE
	|	Total.TaskPerformerGroup <> VALUE(Catalog.TaskPerformerGroups.EmptyRef)";
	
	FilterConditions = "True";
	For Each FilterItem In Filter Do
		If FilterItem.Use Then
			FilterConditions = FilterConditions + "And TaskPerformers." + FilterItem.Name + " = &" + FilterItem.Name;
			Query.SetParameter(FilterItem.Name, FilterItem.Value);
		EndIf;
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditions", FilterConditions);
	
	ModifiedPerformerGroups = Query.Execute(
   ).Unload().UnloadColumn("TaskPerformerGroup");
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndIf