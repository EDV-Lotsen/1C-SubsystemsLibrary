﻿
&AtClient
Procedure LineItemsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	Return;
EndProcedure

&AtServer
// Selects cash receipts and cash sales to be deposited and fills in the document's
// line items.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.BankAccount.IsEmpty() Then
		Object.BankAccount = Constants.BankAccount.Get();
	Else
	EndIf; 
	
	Items.BankAccountLabel.Title =
		CommonUse.GetAttributeValue(Object.BankAccount, "Description");
	
	If Object.Ref.IsEmpty() Then
			
		Query = New Query;
		Query.Text = "SELECT
		             |	CashReceipt.Ref,
					 |	CashReceipt.Currency,
					 |  CashReceipt.CashPayment,
		             |	CashReceipt.DocumentTotal,
		             |	CashReceipt.DocumentTotalRC AS DocumentTotalRC
		             |FROM
		             |	Document.CashReceipt AS CashReceipt
		             |WHERE
		             |	CashReceipt.DepositType = &Undeposited
		             |	AND CashReceipt.Deposited = &InDeposits
					 |
					 |UNION ALL
					 |
					 |SELECT
					 |	CashSale.Ref,
					 |  CashSale.Currency,
					 |  NULL,
		             |	CashSale.DocumentTotal,
		             |	CashSale.DocumentTotalRC
		             |FROM
		             |	Document.CashSale AS CashSale
		             |WHERE
		             |	CashSale.DepositType = &Undeposited
		             |	AND CashSale.Deposited = &InDeposits";

		Query.SetParameter("Undeposited", "1");
		Query.SetParameter("InDeposits", False);

					 
		Result = Query.Execute().Select();
		
		While Result.Next() Do
			
			DataLine = Object.LineItems.Add();
			
			If Result.CashPayment > 0 Then // if there is a credit memo in a cash receipt
				
				DataLine.Document = Result.Ref;
				DataLine.Currency = Result.Currency;
				DataLine.DocumentTotal = Result.CashPayment;
				DataLine.DocumentTotalRC = Result.CashPayment;
				DataLine.Payment = False;
				
			Else
				
				DataLine.Document = Result.Ref;
				DataLine.Currency = Result.Currency;
				DataLine.DocumentTotal = Result.DocumentTotal;
				DataLine.DocumentTotalRC = Result.DocumentTotalRC;
				DataLine.Payment = False;
				
			EndIf;
				
		EndDo;

	EndIf;
	//
	// AdditionalReportsAndDataProcessors
	//AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End AdditionalReportsAndDataProcessors
	
EndProcedure

&AtClient
// Writes deposit data to the originating documents
//
Procedure BeforeWrite(Cancel, WriteParameters)
							
	// deletes from this document lines that were not marked as deposited
	
	NumberOfLines = Object.LineItems.Count() - 1;
	
	While NumberOfLines >=0 Do
		
		If Object.LineItems[NumberOfLines].Payment = False Then
			Object.LineItems.Delete(NumberOfLines);
		Else
		EndIf;
		
		NumberOfLines = NumberOfLines - 1;
		
	EndDo;
	
EndProcedure

&AtClient
// Calculates document total
// 
Procedure LineItemsPaymentOnChange(Item)
	
	TabularPartRow = Items.LineItems.CurrentData;
	
	If TabularPartRow.Payment Then
		Object.DocumentTotal = Object.DocumentTotal + TabularPartRow.DocumentTotal;
		Object.DocumentTotalRC = Object.DocumentTotalRC + TabularPartRow.DocumentTotalRC;
		
		Object.TotalDeposits = Object.TotalDeposits + TabularPartRow.DocumentTotal;
		Object.TotalDepositsRC = Object.TotalDepositsRC + TabularPartRow.DocumentTotalRC;
	EndIf;

    If TabularPartRow.Payment = False Then
		Object.DocumentTotal = Object.DocumentTotal - TabularPartRow.DocumentTotal;
		Object.DocumentTotalRC = Object.DocumentTotalRC - TabularPartRow.DocumentTotalRC;
		
		Object.TotalDeposits = Object.TotalDeposits - TabularPartRow.DocumentTotal;
		Object.TotalDepositsRC = Object.TotalDepositsRC - TabularPartRow.DocumentTotalRC;
	EndIf;

EndProcedure

&AtClient
// Retrieve the account's description
//
Procedure BankAccountOnChange(Item)
	
	Items.BankAccountLabel.Title =
		CommonUse.GetAttributeValue(Object.BankAccount, "Description");
		
EndProcedure

&AtClient
Procedure LineItemsBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	Cancel = True;
	Return;
EndProcedure

&AtClient
Procedure AccountsOnChange(Item)
	
	Object.DocumentTotal = Object.TotalDeposits + Object.Accounts.Total("Amount");
	Object.DocumentTotalRC = Object.TotalDepositsRC + Object.Accounts.Total("Amount");

EndProcedure

&AtClient
Procedure AccountsAmountOnChange(Item)
	Object.DocumentTotal = Object.TotalDeposits + Object.Accounts.Total("Amount");
	Object.DocumentTotalRC = Object.TotalDepositsRC + Object.Accounts.Total("Amount");
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	HasBankAccounts = False;
	
	For Each CurRowLineItems In Object.Accounts Do
		
		If CurRowLineItems.Account.AccountType = Enums.AccountTypes.Bank Then
			
			HasBankAccounts = True;
			
		EndIf;
				
	EndDo;	
	
	If HasBankAccounts Then
		
		Message = New UserMessage();
		Message.Text=NStr("en='Deposit document cannot be used for bank transfers. Use the Bank Transfer document instead.'");
		Message.Message();
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure


