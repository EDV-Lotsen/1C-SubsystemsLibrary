// Form parameters:
//     PostalCode               - Number  - postal code used to search for address options
//     HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be hidden
//
// Selection result:
//     Structure - with the following fields:
//         * Code - Number - Address data 
//         * Presentation  - Address data
//
// ---------------------------------------------------------------------------------------------------------------------
//
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	PostalCode = Parameters.PostalCode;
	SearchParameters = New Structure("HideObsolete", Parameters.HideObsoleteAddresses);
	ClassifierData = ContactInformationInternal.ClassifierAddressesByPostalCode(PostalCode, SearchParameters);
	
	If ClassifierData.Data.Count() = 0 Then
		// No data, selection functionality not applicable
		Cancel = True;
		Return;
	EndIf;
	
	AddressOptions.Load(ClassifierData.Data);
	
	PresentationCommonPart = ClassifierData.PresentationCommonPart;
	PresentationCommonPart = PostalCode + ?(IsBlankString(PresentationCommonPart), "", ", ") + PresentationCommonPart;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure AddressOptionsSelection(Item, SelectedRow, Field, StandardProcessing)
	MakeSelection(SelectedRow);
EndProcedure

&AtClient
Procedure AddressOptionsValueSelection(Item, Value, StandardProcessing)
	MakeSelection(Value);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure MakeSelection(Val LineNumber)
	
	Data = AddressOptions.FindByID(LineNumber);
	If Data = Undefined Then
		Return;
	EndIf;
	
	If Not Data.Obsolete Then
		PassSelectionDataToOwner(Data);
		Return;
	EndIf;
	
	If IsBlankString(PresentationCommonPart) Then
		QuestionText = NStr("en = 'Address ""%1"" obsolete.
		                          |Do you want to continue?'");
	Else
		QuestionText = NStr("en = 'Address ""%2, %1"" obsolete.
		                          |Do you want to continue?'");
	EndIf;
	
	ObsoleteWarning = StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText, Data.Presentation, PresentationCommonPart);
		
	WarningTitle = NStr("en = 'Confirmation'");
	
	Notification = New NotifyDescription("MakeSelectionQuestionEnd", ThisObject, Data);
	ShowQueryBox(Notification, ObsoleteWarning, QuestionDialogMode.YesNo, , ,WarningTitle);
		
EndProcedure

&AtClient
Procedure MakeSelectionQuestionEnd(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		PassSelectionDataToOwner(AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure PassSelectionDataToOwner(Val Data)
	Result = New Structure("PostalCode, Code, Presentation");
	
	FillPropertyValues(Result, Data);
	Result.PostalCode= PostalCode;
	
	NotifyChoice(Result);
EndProcedure

#EndRegion
