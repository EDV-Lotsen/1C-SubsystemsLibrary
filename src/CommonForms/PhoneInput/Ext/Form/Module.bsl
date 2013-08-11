////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	ReadParameterValues();
	
	PresentationWithView = KindDescription + ": " + Presentation;
	Title = KindDescription;
	
	CloseButtonPressed = False;
	
	If Not IsBlankString(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUseClient.RequestCloseFormConfirmation(Cancel, Modified, CloseButtonPressed); 
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure FieldOnChange(Item)
	
	If Not IsBlankString(CountryCode) And Left(CountryCode, 1) <> "+" Then
		CountryCode = "+" + CountryCode;
	EndIf;
	
	Presentation = ContactInformationManagementClient.GeneratePhonePresentation(CountryCode, AreaCode, PhoneNumber, Extension, Comment);
	PresentationWithView = KindDescription + ": " + Presentation;
	
EndProcedure

&AtClient
Procedure OKCommandExecute()
	
	CloseButtonPressed = True;
	Close(GetParameterValues());
	
EndProcedure

&AtClient
Procedure CancelCommandExecute()
	
	CloseButtonPressed = True;
	Close();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure ReadParameterValues()
	
	Presentation = Parameters.Presentation;
	KindDescription = String(Parameters.Kind);
	
	For Each PhoneItem In Parameters.FieldValues Do
		ThisForm[PhoneItem.Presentation] = PhoneItem.Value;
	EndDo;
	
EndProcedure

&AtClient
Function GetParameterValues()
	
	FieldValues = New ValueList;
	FieldValues.Add(CountryCode, "CountryCode");
	FieldValues.Add(AreaCode, "AreaCode");
	FieldValues.Add(PhoneNumber, "PhoneNumber");
	FieldValues.Add(Extension, "Extension");
	FieldValues.Add(Comment, "Comment");
	
	Result = New Structure;
	Result.Insert("FieldValues", FieldValues);
	Result.Insert("Presentation", Presentation);
	
	Return Result;
	
EndFunction

