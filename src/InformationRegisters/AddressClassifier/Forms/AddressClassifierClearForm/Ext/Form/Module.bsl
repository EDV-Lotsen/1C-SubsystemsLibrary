
////////////////////////////////////////////////////////////////////////////////
// Block of functions - event handlers
//

// Handler of event "OnCreateAtServer" of form
// Fills table using template
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	FillTableByAddressClassifierUnitsLayout();
	
EndProcedure

// Handler of the event "selection" of the form item AddressClassifierUnits
// Inverts flag of address unit choice
//
&AtClient
Procedure AddressClassifierUnitsSelection(Item, RowSelected, Field, StandardProcessing)
	Item.CurrentData.Check = NOT Item.CurrentData.Check;
EndProcedure

// Handler of command bar click event
// of form item AddressClassifierUnits.
// Raises choice flag for all address units in the list
//
&AtClient
Procedure SelectAllRun()
	
	For Each AddressClassifierUnit In AddressClassifierUnits Do
		AddressClassifierUnit.Check = True;
	EndDo;
	
EndProcedure

// Handler of command bar click event
// of form item AddressClassifierUnits.
// Removes choice flag for all address units in the list
//
&AtClient
Procedure CancelSelectAllRun()
	
	For Each AddressClassifierUnit In AddressClassifierUnits Do
		AddressClassifierUnit.Check = False;
	EndDo;
	
EndProcedure

// Handler of button "Clear" click event
// Checks data correctness and calls confirmation dialog
// of address information clearing.
//
&AtClient
Procedure ClearExecute()
	
	ClearMessages();
	
	If NumberOfSelectedAddressClassifierUnits() = 0 Then
		CommonUseClientServer.MessageToUser(
					NStr("en = 'It is required to choose minimum one address unit'"), ,
						 "AddressClassifierUnits");
		Return;
	EndIf;
	
	QuestionText = NStr("en = 'Address data on selected objects will be deleted. Do you want to continue?'");
	ReturnCode = DoQueryBox(QuestionText, QuestionDialogMode.OKCancel);
	
	If ReturnCode = DialogReturnCode.OK Then
		ClearAddressInfo();
		DoMessageBox(NStr("en = 'Address data deleted successfully'"),,
		             NStr("en = 'Deleting address data'"));
		Notify("AddressClassifierUpdate");
		Close(True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Block of service functions
//

// Fill passed value table using values of address units table.
// Select code, description and object type abbreviation.
//
&AtServer
Procedure FillTableByAddressClassifierUnitsLayout()
	
	AddressClassifierUnits.Clear();
	
	AddressClassifierUnitsClassifierXML =
	   InformationRegisters.AddressClassifier.GetTemplate("AddressClassifierUnits").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(AddressClassifierUnitsClassifierXML).Data;
	
	For Each Unit In ClassifierTable Do
		
		Description = Left(Unit.Code, 2)
		             + " - "
		             + Unit.Name
		             + " "
		             + Unit.Abbreviation;
		
		NewRow = AddressClassifierUnits.Add();
		NewRow.Check             = False;
		NewRow.Description = Description;
		
	EndDo;
	
EndProcedure

// Returns the number of marked address units
//
&AtClient
Function NumberOfSelectedAddressClassifierUnits()
	
	NumberOfSelectedAddressClassifierUnits = 0;
	
	For Each AddressClassifierUnit In AddressClassifierUnits Do
		If AddressClassifierUnit.Check Then
			NumberOfSelectedAddressClassifierUnits = NumberOfSelectedAddressClassifierUnits + 1;
		EndIf;
	EndDo;
	
	Return NumberOfSelectedAddressClassifierUnits;
	
EndFunction

// Deletes address info using selected address units
//
&AtServer
Procedure ClearAddressInfo()
	
	// generate list of address units for address information clearing
	
	SelectedAO = New Array;
	
	For Each AddressClassifierUnit In AddressClassifierUnits Do
		If AddressClassifierUnit.Check Then
			SelectedAO.Add(Left(AddressClassifierUnit.Description, 2));
		EndIf;
	EndDo;
	
	AddressClassifier.DeleteAddressInfo(SelectedAO);
	AddressClassifier.LoadFirstLevelAddressClassifierUnits();
	
EndProcedure
