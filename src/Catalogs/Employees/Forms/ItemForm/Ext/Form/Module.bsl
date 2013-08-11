
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
// Procedure adjusts visibility of the form attributes.
//
// Parameters:
//  No.
//
Procedure SetAttributesVisibility()
	
	If FillVariant = "1" Then
	
		CurrentVariant 				= "1";
		Items.IndOfFilling.Visible 	= False;
		
		Items.PersonalData.Visible 	= True;
		Items.IndView.Visible 		= True;	
	    Items.Individual.Visible 			= False;
		
	ElsIf FillVariant = "2" Then
	
		CurrentVariant 				= "2";
		Items.IndOfFilling.Visible  = True;
		
		Items.PersonalData.Visible 	= False;
		Items.IndView.Visible 		= False;	
	    Items.Individual.Visible 			= False;
		
	EndIf; 	
	
EndProcedure // SetAttributesVisibility()

&AtServerNoContext
// Procedure returns ind description.
//
// Parameters:
//  No.
//
Procedure GetDataOfIndividual(Structure)
	
	Structure.Insert("Description", Structure.Individual.Description); 
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure handler events OnCreateAtServer.
// Initial filling of form attributes.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		FillVariant = "1";
		CurrentVariant = "1";
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		Items.PersonalData.Visible = True;
		
		Items.DataAboutReception.Visible = True;
		Items.PagesPaymentDeductionKinds.CurrentPage = Items.OneLine;
		
		CurrencyByDefault = Catalogs.Currencies.USD;
		
		NewRow = PaymentDeductionKinds.Add();
		NewRow.Currency = CurrencyByDefault;
		Items.PaymentDeductionKinds.CurrentRow = NewRow.GetID();
		
		Period = CurrentDate();
		User = Users.CurrentUser();
		SettingValue = _DemoPayrollAndHRServerCached.GetValueByDefaultUser(User, "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Company = SettingValue;
		Else
			Company = Catalogs.Companies.MainCompany;	
		EndIf;
		
		CreateRecruitment = True;
		
	Else
		
		FillVariant 					 = "0";
		
		Items.Pages.PagesRepresentation  = FormPagesRepresentation.None;
		Items.PersonalData.Visible 		 = False;		
		Items.DataAboutReception.Visible = False;
	
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtServer
// Procedure handler events BeforeWriteAtServer.
// Initial filling of form attributes.
//
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
EndProcedure

&AtServer
// Procedure handler of the event AfterWriteAtServer.
// Initial filling of form attributes.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CreateRecruitment Then
		
		Manager = InformationRegisters.EmployeePositionsAndPayRates.CreateRecordSet();
		Manager.Filter.Employee.Set(Object.Ref);
		Manager.Filter.Company.Set(Company);
		For Each PaymentDeductionKind In PaymentDeductionKinds Do
			NewLine = Manager.Add();
			NewLine.Position = Position;
			NewLine.Employee = Object.Ref;
			NewLine.Company = Company;
			NewLine.Period = Period;
			NewLine.PaymentDeductionKind = PaymentDeductionKind.PaymentDeductionKind;
			NewLine.Amount = PaymentDeductionKind.Amount;
			NewLine.Currency = PaymentDeductionKind.Currency;
			NewLine.AccountOfExpenses = PaymentDeductionKind.AccountOfExpenses;
		EndDo;
		Manager.Write();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure handler of event AfterWrite.
// Initial filling of form attributes.
//
Procedure AfterWrite(WriteParameters)
	
	Items.PersonalData.ReadOnly = True;
	Items.DataAboutReception.ReadOnly = true;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - handler of event OnChange of attribute FillVariant.
//
Procedure FillVariantOnChange(Item)
	
	If CurrentVariant <> FillVariant Then
		SetAttributesVisibility();
	EndIf; 
		
EndProcedure 

&AtClient
// Procedure - handler of command EditInList.
//
Procedure EditInList(Command)
	
	RowsCount = PaymentDeductionKinds.Count();
	
	If Items.PagesPaymentDeductionKinds.CurrentPage = Items.ListView
		  And PaymentDeductionKinds.Count() > 1 Then
		
		Response = DoQueryBox(
			NStr("en = 'All rows except the first will be deleted. Do you want to continue?'"),
			QuestionDialogMode.YesNo
		);
			
		If Response = DialogReturnCode.No Then
			Return;
		EndIf;

		While RowsCount > 1 Do
			PaymentDeductionKinds.Delete(PaymentDeductionKinds[RowsCount - 1]);
			RowsCount = RowsCount - 1;
		EndDo;
		Items.PaymentDeductionKinds.CurrentRow = PaymentDeductionKinds[0].GetID();
	EndIf;
	
	If Items.PagesPaymentDeductionKinds.CurrentPage = Items.OneLine Then
		Items.PagesPaymentDeductionKinds.CurrentPage = Items.ListView;
	Else
		Items.PagesPaymentDeductionKinds.CurrentPage = Items.OneLine;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of attribute IndOfFilling.
//
Procedure IndOfFillingOnChange(Item)
	
	If Not ValueIsFilled(Object.Individual) Then
		Return;
	EndIf; 
	
	Structure = New Structure("Individual", Object.Individual);
	GetDataOfIndividual(Structure);
	Object.Description = Structure.Description;
	
EndProcedure

// Procedure - handler of event BeforeDelete of tabular section PaymentDeductionKinds.
//
&AtClient
Procedure PaymentDeductionKindsBeforeDelete(Item, Cancellation)
	
	If PaymentDeductionKinds.Count() = 1 Then
		Cancellation = True;
	EndIf;
	
EndProcedure // PaymentDeductionKindsBeforeDelete()

&AtClient
// Procedure - handler of event OnStartEdit of tabular section PaymentsDeductions.
//
Procedure PaymentDeductionKindsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		TabularSectionLine = Items.PaymentDeductionKinds.CurrentData;
		TabularSectionLine.Currency = CurrencyByDefault;
	EndIf;

EndProcedure

&AtClient
// Procedure - handler of event OnChange PaymentDeductionKind of tabular section PaymentsDeductions.
//
Procedure PaymentDeductionKindsPaymentDeductionKindOnChange(Item)
	
	TabularSectionLine = Items.PaymentDeductionKinds.CurrentData;
	
    If ValueIsFilled(TabularSectionLine.PaymentDeductionKind) Then

		Structure = New Structure("PaymentDeductionKind, AccountOfExpenses", TabularSectionLine.PaymentDeductionKind);
		_DemoPayrollAndHRServer.GetPaymentKindAccountOfExpenses(Structure);
    	TabularSectionLine.AccountOfExpenses = Structure.AccountOfExpenses;
	
	EndIf;
	
EndProcedure



