#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalInterface

// Updates register data if the developer has changed dependencies in the overridable module. 
// Parameters:
//  HasChanges - Boolean (return value) - True if data is changed; not set otherwise.

Procedure UpdateRegisterData(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly Or ExclusiveMode() Then
		DisableExclusiveMode = False;
	Else
		DisableExclusiveMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	AccessRightDependencies = InformationRegisters.AccessRightDependencies.CreateRecordSet();
	
	Table = New ValueTable;
	Table.Columns.Add("SubordinateTable", New TypeDescription("String"));
	Table.Columns.Add("LeadingTable",     New TypeDescription("String"));
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.AccessManagement\OnFillAccessRightDependencies");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillAccessRightDependencies(Table);
	EndDo;
	
	AccessManagementOverridable.OnFillAccessRightDependencies(Table);
	
	AccessRightDependencies = InformationRegisters.AccessRightDependencies.CreateRecordSet().Unload();
	For Each Row In Table Do
		NewRow = AccessRightDependencies.Add();
		
		MetadataObject = Metadata.FindByFullName(Row.SubordinateTable);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in OnFillAccessRightDependencies procedure
				           |from AccessManagementOverridable common module.
				           |
				           |Subordinate table ""%1"" is not found.'"),
				Row.SubordinateTable);
		EndIf;
		NewRow.SubordinateTable = CommonUse.MetadataObjectID(
			Row.SubordinateTable);
		
		MetadataObject = Metadata.FindByFullName(Row.LeadingTable);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error in OnFillAccessRightDependencies procedure
				           |from AccessManagementOverridable common module.
				           |
				           |Leading table ""%1"" is not found.'"),
				Row.LeadingTable);
		EndIf;
		NewRow.LeadingTableType = CommonUse.ObjectManagerByFullName(
			Row.LeadingTable).EmptyRef();
	EndDo;
	
	TemporaryTableQueryText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.LeadingTableType
	|INTO NewData
	|FROM
	|	&AccessRightDependencies AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.LeadingTableType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing selectable fields with optional selection
	Fields = New Array;
	Fields.Add(New Structure("SubordinateTable"));
	Fields.Add(New Structure("LeadingTableType"));
	
	Query = New Query;
	AccessRightDependencies.GroupBy("SubordinateTable, LeadingTableType");
	Query.SetParameter("AccessRightDependencies", AccessRightDependencies);
	
	Query.Text = AccessManagementInternal.ChangeSelectionQueryText(
	QueryText, Fields, "InformationRegister.AccessRightDependencies", TemporaryTableQueryText);
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.AccessRestrictionParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = DataLock.Add("InformationRegister.AccessRightDependencies");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Changes = Query.Execute().Unload();
		
		AccessManagementInternal.UpdateInformationRegister(
			InformationRegisters.AccessRightDependencies, Changes, HasChanges, , , CheckOnly);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If DisableExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If DisableExclusiveMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf