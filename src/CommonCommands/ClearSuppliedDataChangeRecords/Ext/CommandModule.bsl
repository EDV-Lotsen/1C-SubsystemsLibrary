
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ClearSuppliedDataChangeRecords();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure ClearSuppliedDataChangeRecords()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SuppliedDataChanges.Ref AS Ref
	|FROM
	|	ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|WHERE
	|	SuppliedDataChanges.Ref <> &ThisNode";
	Query.SetParameter("ThisNode", ExchangePlans.SuppliedDataChanges.ThisNode());
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		ExchangePlans.DeleteChangeRecords(Selection.Ref);
	EndDo;
	
EndProcedure