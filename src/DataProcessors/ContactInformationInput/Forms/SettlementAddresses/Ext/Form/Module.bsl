// Form parametrization utilizes the following parameters:
//      
//  SettlementCode         - Number    - code of current address classifier used to
//                                       determine and edit form parts (if specified)
//
//  SettlementDetails      - Structure - varies depending on address classifier, 
//                                       describes settlement parts.
//                                       Used only if SettlementCode has zero value specified
//
//  HideObsoleteAddresses  - Boolean   - flag specifying that obsolete addresses 
//                                       should be hidden when editing
//
// -------------------------------------------------------------------------------------------------

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CanImportClassifier = ContactInformationInternal.CanChangeAddressClassifier();
	
	AddressPartNamePrefix = "Term";
	
	// Setting form attributes
	If Parameters.SettlementCode>0 Then
		AddressParts = ContactInformationInternal.AttributeListSettlement(Parameters.SettlementCode);
	Else
		AddressParts = Parameters.SettlementDetails;
	EndIf;
	
	If AddressParts=Undefined Or AddressParts.Count()=0 Then
		AddressParts = ContactInformationInternal.AttributeListSettlement();
	EndIf;
	
	HideObsoleteAddresses = Parameters.HideObsoleteAddresses;
	CreateFormByAddressParts();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKCommand(Command)
	// If data was not modified, emulates Cancel command
	If Modified Then
		Result = New Structure("Code, Presentation, SettlementDetails", 
			SettlementCodeByAddressParts(AddressParts), 
			ContactInformationManagementClient.SettlementNameByAddressParts(AddressParts), 
			AddressParts);
		
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) And IsOpen() Then        
		Close(Result);
	EndIf;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure CreateFormByAddressParts()
	Add = New Array;
	
	StringType = New TypeDescription("String");
	For Each KeyValue In AddressParts Do
		Term = KeyValue.Value;
		Name = KeyValue.Key;
		Add.Add( New FormAttribute(AddressPartNamePrefix + Name, StringType, , Term.Title));
	EndDo;
	ChangeAttributes(Add);
	
	For Each KeyValue In AddressParts Do
		Term = KeyValue.Value;
		Name = KeyValue.Key;
		
		Item = Items.Add(AddressPartNamePrefix + Name, Type("FormField"));
		Item.DataPath     = Item.Name;
		Item.Type         = FormFieldType.InputField;
		Item.ChoiceButton = True;
		
		Term.Property("ToolTip", Item.ToolTip);
		If IsBlankString(Item.ToolTip) Then
			Item.ToolTip = Term.Title;
		EndIf;
			
		Item.SetAction("OnChange",         "Attachable_FieldOnChange");
		Item.SetAction("StartChoice",      "Attachable_FieldStartChoice");
		Item.SetAction("Clearing",         "Attachable_Clearing");
		Item.SetAction("ChoiceProcessing", "Attachable_FieldChoiceProcessing");
		Item.SetAction("AutoComplete",     "Attachable_FieldAutoComplete");
		Item.SetAction("TextEditEnd",      "Attachable_FieldTextInputEnd");
		
		ThisObject[Item.Name] = Term.Value;
	EndDo;
	
EndProcedure

// -------------------------------------------------------------------------------------------------

&AtClient 
Function ItemAddressPartName(Item)
	Return Mid(Item.Name, 1 + StrLen(AddressPartNamePrefix));
EndFunction

&AtClient 
Function ItemAddressPart(Item)
	Return AddressParts[ItemAddressPartName(Item)];
EndFunction

&AtClient
Function SetAddressPartValue(Item, SelectedValue)
	AddressPart = ItemAddressPart(Item);
	
	If TypeOf(SelectedValue)=Type("Structure") Then
		PartStructure = ?(SelectedValue.Property("Value"), SelectedValue.Value, SelectedValue);
		AddressPart.ClassifierCode = PartStructure.Code;
		AddressPart.Value          = PartStructure.FullDescr;
		AddressPart.Description    = PartStructure.Description;
		AddressPart.Abbr           = PartStructure.Abbr;
	Else
		AddressPart.ClassifierCode = Undefined;
		AddressPart.Value          = TrimAll(SelectedValue);
		
		Parts = ContactInformationClientServer.DescriptionAbbreviation(AddressPart.Value);
		AddressPart.Description    = Parts.Description;
		AddressPart.Abbr           = Parts.Abbr;
	EndIf;
	
	// Placing data to form; automatically generated item and attribute names match
	ThisObject[Item.Name] = AddressPart.Value;
	
	Return AddressPart.Value;
EndFunction

// -------------------------------------------------------------------------------------------------

&AtClient
Procedure Attachable_FieldOnChange(Item)
	Modified = True;
EndProcedure

&AtClient
Procedure Attachable_FieldStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	FormParameters = New Structure("HideObsoleteAddresses", HideObsoleteAddresses);
	ContactInformationManagementClient.AddressItemStartChoice(
		Item, ItemAddressPartName(Item), AddressParts, FormParameters
	);
EndProcedure

&AtClient
Procedure Attachable_Clearing(Item, StandardProcessing)
	Modified = True;
EndProcedure

&AtClient
Procedure Attachable_FieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	Var CanImportState;
	
	If TypeOf(SelectedValue)=Type("Structure") Then
		
		StateNotImported = (SelectedValue.Property("CanImportState") And SelectedValue.CanImportState)
		               Or (SelectedValue.Property("AddressStructure") And SelectedValue.AddressStructure.CanImportState);
		
		If CanImportClassifier And StateNotImported Then
			// Suggesting classifier import
			ContactInformationManagementClient.ClassifierImportSuggestion(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Data for ""%1"" not imported.'"), SelectedValue.Presentation));
		EndIf;
		
		SelectedValue = SetAddressPartValue(Item, SelectedValue);
		Modified = True;
	ElsIf TypeOf(SelectedValue)=Type("String") Then
		SetAddressPartValue(Item, SelectedValue);
		Modified = True;
	Else
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_FieldAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	ChoiceData = New ValueList;
	
	If Waiting = 0 Then
		// Creating quick choice list; no changes to standard processing procedure
		Return;
	EndIf;
	
	If StrLen(Text) < 3 Then 
		// No options, list is empty; no changes to standard processing procedure
		Return;
	EndIf;
	
	ChoiceData = AddressItemAutoCompleteList(Text, ItemAddressPartName(Item), AddressParts, True);
	
	// Disabling standard processing procedure only if other options are available
	StandardProcessing = ChoiceData.Count() = 0;
EndProcedure

&AtClient
Procedure Attachable_FieldTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	Modified = True;
	
	VariantList = AddressItemVariantListByText(Text, ItemAddressPartName(Item), AddressParts, 50);
	
	If VariantList<>Undefined And VariantList.Count()=1 Then
		StandardProcessing = False;
		Text = SetAddressPartValue(Item, VariantList[0].Value);
		ChoiceData = New ValueList;
		ChoiceData.Add(Text);
	Else
		SetAddressPartValue(Item, Text);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SettlementCodeByAddressParts(AddressParts)
	Return ContactInformationInternal.SettlementCodeByAddressParts(AddressParts);
EndFunction

&AtServerNoContext
Function AddressItemAutoCompleteList(Text, AddressPartCode, Val AddressParts, WarnObsolete)
	
	Return ContactInformationInternal.AddressItemAutoCompleteList(
		Text, AddressPartCode, AddressParts, WarnObsolete
	);
	
EndFunction

&AtServerNoContext
Function AddressItemVariantListByText(Text, AddressPartCode, AddressParts, SelectStrings)
	Return ContactInformationInternal.AddressItemOptionListByText(
		Text, AddressPartCode, AddressParts, SelectStrings);
EndFunction

#EndRegion