

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
// Procedure sets accessibility of form items.
//
// Parameters:
//  No.
//
Procedure SetVisibilityAndAccessibility()
	
	Items.AccountOfExpenses.Visible 	= True;
	Items.GroupFormula.Visible 			= True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure handler events OnCreateAtServer.
// Initial filling of form attributes.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Items.AccountOfExpenses.Visible = True;
	Items.GroupFormula.Visible = True;		
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

&AtClient
// Procedure is called on click button "Edit calculation formula".
//
Procedure CommandEditCalculationFormula(Command)
	                               
	StructureOfParameters = New Structure("FormulaText", Object.Formula);
	CFEForm				  = GetForm("Catalog.PaymentDeductionKinds.Form.CalculationFormulaEdirForm", StructureOfParameters);
    FormulaText 		  = CFEForm.DoModal();
  
	If TypeOf(FormulaText) = Type("String") Then

        Object.Formula = FormulaText;

	EndIf;
	
EndProcedure // CommandEditCalculationFormulaExecute()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure handler of event OnChange of input field BusinessIndividual.
//
Procedure TypeOnChange(Item)
	
	SetVisibilityAndAccessibility();
	
EndProcedure // BusinessIndividualOnChange()

