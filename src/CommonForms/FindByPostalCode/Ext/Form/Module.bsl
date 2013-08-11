////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure OnOpen(Cancel)

	Title = ?(HasDetails, NStr("en = 'Select a street and a settlement.'"), NStr("en = 'Select a street.'"));
	Items.FoundByPostalCodeRecords.Header = HasDetails;
	Items.HideObsoleteAddresses.Check = HideObsoleteAddresses;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PostalCode = Parameters.PostalCode;
	
	FoundByPostalCode = ContactInformationManagementClassifiers.FindACRecordsByPostalCode(Parameters.PostalCode);
	Found = FoundByPostalCode.Count;
	If Found = 0 Then
		Cancel = True;
	ElsIf Found > 1 Then
		Parameters.FoundState = FoundByPostalCode.FoundState;
		Parameters.FoundCounty = FoundByPostalCode.FoundCounty;
		Parameters.ActualityFlag = FoundByPostalCode.ActualityFlag;
		Parameters.AddressInStorage = FoundByPostalCode.AddressInStorage;
		HideObsoleteAddresses = Parameters.HideObsoleteAddresses;
		CommonUse.CommonSettingsStorageSave("AddressInput", "HideObsoleteAddresses", HideObsoleteAddresses);
	EndIf;
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	ValueToFormAttribute(GetFromTempStorage(Parameters.AddressInStorage), "FoundByPostalCodeRecords");
	DeleteFromTempStorage(Parameters.AddressInStorage);
	CommonUseClientServer.SupplementTable(FoundByPostalCodeRecords, AllFoundByPostalCodeRecords);
	
	StateAndCountyLabel = "" + Parameters.PostalCode
	+ ?(ValueIsFilled(Parameters.FoundState), ", ", "")	+ Parameters.FoundState 
	+ ?(ValueIsFilled(Parameters.FoundState) And ValueIsFilled(Parameters.FoundCounty), ", ", "") 
	+ Parameters.FoundCounty;
	
	HasDetails = False;
	For Each Str In FoundByPostalCodeRecords Do
		If Not IsBlankString(Str.Details) Then
			HasDetails = True;
			Break;
		EndIf;
	EndDo;
	
	Items.FoundByPostalCodeRecords.ChildItems.Details.Visible = HasDetails;

	// Restoring a value of the Hide obsolete addresses flag
	Value = CommonUse.CommonSettingsStorageLoad("AddressInput", "HideObsoleteAddresses");
	If Value = Undefined Then
		HideObsoleteAddresses = False;
	Else
		HideObsoleteAddresses = Value;
	EndIf;
	
	If HideObsoleteAddresses Then
		
		ObsoleteAddressArray = New Array;
		For Each Str In FoundByPostalCodeRecords Do
			If Str.ActualityFlag <> 0 Then
				ObsoleteAddressArray.Add(Str);
			EndIf;
		EndDo;
		
		For Each ArrayElement In ObsoleteAddressArray Do
			FoundByPostalCodeRecords.Delete(ArrayElement);	
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CommonUse.CommonSettingsStorageSave("AddressInput", "HideObsoleteAddresses", HideObsoleteAddresses);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ChooseCommandExecute()
	ProcessSelection();
EndProcedure

&AtClient
Procedure FoundByPostalCodeRecordsChoice(Item, SelectedRow, Field, StandardProcessing)
	ProcessSelection();
EndProcedure

&AtClient
Procedure HideObsoleteAddresses(Command)
	
	HideObsoleteAddresses = Not HideObsoleteAddresses;
	Items.HideObsoleteAddresses.Check = HideObsoleteAddresses;
	ChangeObsoleteAddressVisibility();
	ThisForm.RefreshDataRepresentation();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure ProcessSelection()
	
	If Items.FoundByPostalCodeRecords.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Items.FoundByPostalCodeRecords.CurrentData.ActualityFlag <> 0 Then
		ButtonList = New ValueList;
		ButtonList.Add("Select");
		ButtonList.Add("Cancel");
		Response = DoQueryBox(NStr("en = '" + Items.FoundByPostalCodeRecords.CurrentData.Street 
		+ ", " + Items.FoundByPostalCodeRecords.CurrentData.Details + " is obsolete."	
		+ Chars.LF + "Are you sure you want to select it?'"), ButtonList);
		If Response = "Cancel" Then
			Return;
		EndIf;
	EndIf;
	
	AddressItemCode = Items.FoundByPostalCodeRecords.CurrentData.Code;
	Result = ProcessSearchByPostalCodeResult(AddressItemCode);
	Close(Result);
	
EndProcedure

&AtServer
Procedure ChangeObsoleteAddressVisibility()
	
	If HideObsoleteAddresses Then
		
		ObsoleteAddressArray = New Array;
		For Each Str In FoundByPostalCodeRecords Do
			If Str.ActualityFlag <> 0 Then
				ObsoleteAddressArray.Add(Str);
			EndIf;
		EndDo;
		
		For Each ArrayElement In ObsoleteAddressArray Do
			FoundByPostalCodeRecords.Delete(ArrayElement);	
		EndDo;
		
	Else
		
		CommonUseClientServer.SupplementTable(AllFoundByPostalCodeRecords, FoundByPostalCodeRecords);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ProcessSearchByPostalCodeResult(AddressItemCode)
	
	// Restores a value of the Hide obsolete addresses flag. 
	Value = CommonUse.CommonSettingsStorageLoad("AddressInput", "HideObsoleteAddresses");
	If Value = Undefined Then
		Result = New Structure("HideObsoleteAddresses", False);
	Else
		Result = New Structure("HideObsoleteAddresses", Value);
	EndIf;
	
	// Filling address items
	If AddressItemCode = Undefined Then
		Result.Insert("ActualityFlag", 0);
		Result.Insert("State", "");
		Result.Insert("Result", "");
		Result.Insert("City", "");
		Result.Insert("Settlement", "");
		Result.Insert("Street", "");
	Else
		ContactInformationManagementClassifiers.GetComponentsToStructureByAddressItemCode(
			AddressItemCode, Result);
		
		ActualityFlag = Result.ActualityFlag;
		State = Result.State;
		County = Result.County;
		City = Result.City;
		Settlement = Result.Settlement;
		Street = Result.Street;
		
		AddressStructure = ContactInformationManagementClassifiers.GetAddressStructureAtServer(AddressItemCode);
	EndIf;
	
	// Filling the imported structure by state
	ImportedStructure = ImportedFieldsByState(AddressStructure);
	Result.Insert("ImportedStructure", ImportedStructure);
	Result.Insert("AddressStructure", AddressStructure);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ImportedFieldsByState(AddressStructure)
	
	If ContactInformationManagementClassifiers.AddressItemImported(AddressStructure.State) Then
		
		ImportedStructure = ContactInformationManagementClassifiers.ImportedAddressItemStructure(
		AddressStructure.State, AddressStructure.County, AddressStructure.City, AddressStructure.Settlement, AddressStructure.Street);
		
		Return ImportedStructure;
		
	Else
		
		Return New Structure("State", False);
		
	EndIf;
	
EndFunction


