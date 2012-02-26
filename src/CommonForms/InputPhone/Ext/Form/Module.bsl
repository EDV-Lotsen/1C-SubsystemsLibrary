
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
Procedure ReadParameterValues()
	
	Presentation     = Parameters.Presentation;
	KindDescription1 = String(Parameters.Kind);
	
	For Each PhoneItem In Parameters.FieldValues Do
		ThisForm[PhoneItem.Presentation] = PhoneItem.Value;
	EndDo;
	
EndProcedure

&AtClient
Function GetValuesOfParameters()
	
	FieldValues = New ValueList;
	FieldValues.Add(CountryCode,     	"CountryCode");
	FieldValues.Add(CityCode,     		"CityCode");
	FieldValues.Add(PhoneNumber, 		"PhoneNumber");
	FieldValues.Add(Extension,    		"Extension");
	FieldValues.Add(Comment,   			"Comment");
	
	Result = New Structure;
	Result.Insert("FieldValues", FieldValues);
	Result.Insert("Presentation", Presentation);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	ReadParameterValues();
	
	PresentationWithView = KindDescription1 + ": " + Presentation;
	Title 				 = KindDescription1;
	
	WerePressedClosingButtons = False;
	
	If NOT IsBlankString(Parameters.Title) Then
		AutoTitle 	= False;
		Title 		= Parameters.Title;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancellation, StandardProcessing)
	
	If Modified And Not WerePressedClosingButtons Then
		
		QuestionText = NStr("en = 'Data has been changed. Discard your changes?'");
		
		Response = DoQueryBox(QuestionText,  QuestionDialogMode.OKCancel);
		
		If Response = DialogReturnCode.Cancel Then
			Cancellation = True;
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS OF FORM ITEMS

&AtClient
Procedure FieldOnChange(Item)
	
	If Not IsBlankString(CountryCode) And Left(CountryCode, 1) <> "+" Then
		CountryCode = "+" + CountryCode;
	EndIf;
	
	Presentation 		 = ContactInformationManagementClient.GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment);
	PresentationWithView = KindDescription1 + ": " + Presentation;
	
EndProcedure

&AtClient
Procedure CommandOKExecute()
	
	WerePressedClosingButtons = True;
	Close(GetValuesOfParameters());
	
EndProcedure

&AtClient
Procedure CommandCancelExecute()
	
	WerePressedClosingButtons = True;
	Close();
	
EndProcedure

