
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not ValueIsFilled(Write.SourceRecordKey) Then
		Write.Period = CurrentSessionDate();
	EndIf;
	
	CompleteCurrency();

	CurrencySelectionAvailable = Not Parameters.FillingValues.Property("Currency") And Not ValueIsFilled(Parameters.Key);
	Items.CurrencyLabel.Visible = Not CurrencySelectionAvailable;
	Items.CurrencyList.Visible = CurrencySelectionAvailable;
	
	WindowOptionsKey = ?(CurrencySelectionAvailable, "WithCurrencyChoice", "WithoutCurrencyChoice");
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_CurrencyRates", WriteParameters, Write);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If Not CurrencySelectionAvailable Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("CurrencyList");
		CommonUse.DeleteNoCheckAttributesFromArray(AttributesToCheck, AttributesToExclude);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CurrencyOnChange(Item)
	Write.Currency = CurrencyList;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure CompleteCurrency()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.Description AS AlphabeticCode,
	|	Currencies.LongDescription AS Description
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.DeletionMark = FALSE
	|
	|ORDER BY
	|	Description";
	
	CurrencySelection = Query.Execute().Select();
	
	While CurrencySelection.Next() Do
		CurrencyPresentation = StringFunctionsClientServer.SubstituteParametersInString("%1 (%2)", CurrencySelection.Description, CurrencySelection.AlphabeticCode);
		Items.CurrencyList.ChoiceList.Add(CurrencySelection.Ref, CurrencyPresentation);
		If CurrencySelection.Ref = Write.Currency Then
			CurrencyLabel = CurrencyPresentation;
			CurrencyList = Write.Currency;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
