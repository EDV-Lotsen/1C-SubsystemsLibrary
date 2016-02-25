////////////////////////////////////////////////////////////////////////////////
// Performance monitor subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Checks whether performance measurement is required.
//
// Returns:
//  Boolean - if True, performance measurement is required. If False, performance measurement is not required.
//
Function EnablePerformanceMeasurements() Export
	
	SetPrivilegedMode(True);
	Return Constants.EnablePerformanceMeasurements.Get();
	
EndFunction

// Returns a reference to a key operation by name.
// If a key operation with the specified name is not found in the catalog, creates a new item.
//
// Parameters:
//  KeyOperationName - String - key operation name.
//
// Returns:
// CatalogRef.KeyOperations
//
Function GetKeyOperationByName(KeyOperationName) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	KeyOperations.Ref AS Ref
	               |FROM
	               |	Catalog.KeyOperations AS KeyOperations
	               |WHERE
	               |	KeyOperations.Name = &Name
	               |
	               |ORDER BY
	               |	Ref";
	
	Query.SetParameter("Name", KeyOperationName);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		KeyOperationRef = PerformanceMonitorServerCallFullAccess.CreateKeyOperation(KeyOperationName);
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		KeyOperationRef = Selection.Ref;
	EndIf;
	
	Return KeyOperationRef;
	
EndFunction

#EndRegion
