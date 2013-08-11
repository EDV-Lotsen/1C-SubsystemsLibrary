
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
// Procedure inserts text, that is passed as a parameter to the field
// of the spreadsheet document.
//
Procedure InsertTextInFormula(Indicator)
	
	FormulaText = FormulaText + " [" + TrimAll(Indicator) + "] ";
			
EndProcedure // InsertTextInFormula()

&AtServerNoContext
// Function gets indicator id.
//
Function GetIndicatorID(DataStructure)
	
	Return TrimAll(DataStructure.RowSelected.Id);

EndFunction // GetIndicatorID()

&AtServer
// Procedure - handler of event OnCreateAtServer of form.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	TextIndicators = "To add a parameter to the formula, double-click it.";
	
	If Parameters.Property("FormulaText") Then
		
		FormulaText = Parameters.FormulaText;
		
	EndIf;	
	
EndProcedure // OnCreateAtServer()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ITEMS (BUTTONS)

&AtClient
// Procedure - handler of click on button OK
//
Procedure CommandOK(Command)
	
	Close(FormulaText);
	
EndProcedure // CommandOKExecute()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF THE DYNAMIC LIST CALCULATION PARAMETERS

&AtClient
// Procedure - handler of event Selection of dynamic list ParametersOfGoods.
//
Procedure CalculationParametersSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	DataStructure = New Structure("RowSelected", RowSelected);
	
	TextToFormula = GetIndicatorID(DataStructure);
    InsertTextInFormula(TextToFormula);

EndProcedure // CalculationParametersSelection()




