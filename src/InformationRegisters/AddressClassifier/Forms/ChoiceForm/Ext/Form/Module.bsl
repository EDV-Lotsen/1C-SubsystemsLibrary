

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	MakeSelection();
	
EndProcedure

&AtClient
Procedure CommandChooseRun()
	
	MakeSelection();
	
EndProcedure

&AtClient
Procedure MakeSelection()
	
	curData = Items.List.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Result = New Structure("Description,Abbreviation", curData.Description, curData.Abbreviation);
	Close(Result);
	
EndProcedure

&AtServer
Function GetFieldsByLevel(Level)
	
	Fields = New Structure;
	Fields.Insert("Region",          ?(Level <= 1, "", Parameters.Region));
	Fields.Insert("District",        ?(Level <= 2, "", Parameters.District));
	Fields.Insert("City",            ?(Level <= 3, "", Parameters.City));
	Fields.Insert("HumanSettlement", ?(Level <= 4, "", Parameters.HumanSettlement));
	Fields.Insert("Street",          ?(Level <= 5, "", Parameters.Street));
	
	Return Fields;
	
EndFunction

&AtServer
Function GetRestrictionsByLevel(Level)
	
	Fields = GetFieldsByLevel(Level);
	Restrictions = ContactInformationManagementClassifiers.ReturnConditionsStructureByParent(Fields.Region, Fields.District, Fields.City, Fields.HumanSettlement, Fields.Street, 0);
	Restrictions.Insert("AddressItemType", Parameters.Level);
	
	Return Restrictions;
	
EndFunction

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	// Apply filter
	Parameters.Filter = GetRestrictionsByLevel(Parameters.Level);
	
	// Set current row
	Fields = GetFieldsByLevel(Parameters.Level + 1);
	FilterStructure = ContactInformationManagementClassifiers.ReturnAddressClassifierStringByAddressItem(Fields.Region, Fields.District, Fields.City, Fields.HumanSettlement, Fields.Street);
	If FilterStructure.AddressItemType = Parameters.Level Then
		Parameters.CurrentRow = InformationRegisters.AddressClassifier.CreateRecordKey(FilterStructure);
	EndIf;
	
EndProcedure

