
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
Procedure ProcessSelection()
	
	Close(Items.RecordsFoundByIndex.CurrentData.Code);
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	ValueToFormAttribute(GetFromTempStorage(Parameters.AddressInStorage), "RecordsFoundByIndex");
	DeleteFromTempStorage(Parameters.AddressInStorage);
	
	LabelAboutRegionAndArea = "" + Parameters.RegionFound + ?(ValueIsFilled(Parameters.RegionFound) And ValueIsFilled(Parameters.AreaFound), ", ", "") + Parameters.AreaFound;
	
	IsDescription = False;
	For Each Str In RecordsFoundByIndex Do
		If Not IsBlankString(Str.Details) Then
			IsDescription = True;
			Break;
		EndIf;
	EndDo;
	
	Items.RecordsFoundByIndex.ChildItems.Details.Visible = IsDescription;

EndProcedure



////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS OF FORM ITEMS

&AtClient
Procedure CommandCloseExecute()
	Close();
EndProcedure

&AtClient
Procedure CommandChooseRun()
	ProcessSelection();
EndProcedure

&AtClient
Procedure RecordsFoundByIndexSelection(Item, RowSelected, Field, StandardProcessing)
	ProcessSelection();
EndProcedure
