
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillNodeList();
	
EndProcedure

&AtServer
Procedure FillNodeList()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataArea AS DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|		LEFT JOIN ExchangePlan.SuppliedDataChanges AS SuppliedDataChanges
	|			ON DataAreas.DataArea = SuppliedDataChanges.DataArea
	|WHERE
	|	SuppliedDataChanges.Ref IS NULL ";
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		SuppliedData.CreateDataAreaNode(Selection.DataArea);
	EndDo;
	
EndProcedure