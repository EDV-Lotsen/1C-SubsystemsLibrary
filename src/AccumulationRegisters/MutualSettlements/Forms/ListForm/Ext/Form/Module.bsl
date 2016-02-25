
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

// The AllMutualSettlements command handler
&AtClient
Procedure AllMutualSettlementsExecute()
	CurrentRow = Items.List.CurrentRow;
	ParametersStructure = New Structure("CurrentRow", CurrentRow);
	OpenForm("AccumulationRegister.MutualSettlements.ListForm", ParametersStructure, , True);
EndProcedure

