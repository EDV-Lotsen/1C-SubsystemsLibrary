&AtServer
Procedure Fill()
	Query = New Query("SELECT
	                      |	MutualSettlementsBalance.Counterparty,
	                      |	MutualSettlementsBalance.Currency,
	                      |	MutualSettlementsBalance.AmountBalance AS AmountBalance
	                      |FROM
	                      |	AccumulationRegister.MutualSettlements.Balance AS MutualSettlementsBalance
	                      |AUTOORDER");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = BalanceTable.Add();
		NewRow.Counterparty = Selection.Counterparty;
		NewRow.Currency = Selection.Currency;
		If Selection.AmountBalance > 0 Then
			NewRow.CompanyAccountsPayable = Selection.AmountBalance;
		Else
			NewRow.CompanyAccountsReceivable = Selection.AmountBalance * -1;
		EndIf;	
	EndDo;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Fill();
EndProcedure

&AtClient
Procedure BalanceTableChoice(Item, SelectedRow, Field, StandardProcessing)
	ShowValue(, BalanceTable.FindByID(SelectedRow).Counterparty);
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure RefreshExecute()
	BalanceTable.Clear();
	Fill();
EndProcedure
