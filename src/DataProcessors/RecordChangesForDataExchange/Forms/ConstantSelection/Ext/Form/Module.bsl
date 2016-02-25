
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	VerifyAccessRights("Administration", Metadata);
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ConstantList.Clear();
	For CurIndex = 0 To Parameters.MetadataNameArray.UBound() Do
		Row = ConstantList.Add();
		Row.AutoRecordPictureIndex = Parameters.AutoRecordArray[CurIndex];
		Row.PictureIndex           = 2;
		Row.MetaFullName           = Parameters.MetadataNameArray[CurIndex];
		Row.Description            = Parameters.PresentationArray[CurIndex];
	EndDo;
	
	AutoRecordTitle = NStr("en = 'Autorecord for node %1'");
	
	Items.DecorationAutoRecord.Title = StrReplace(AutoRecordTitle, "%1", Parameters.ExchangeNode);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurParameters = SetFormParameters();
	Items.ConstantList.CurrentRow = CurParameters.CurrentRow;
EndProcedure

&AtClient
Procedure OnReopen()
	CurParameters = SetFormParameters();
	Items.ConstantList.CurrentRow = CurParameters.CurrentRow;
EndProcedure

#EndRegion

#Region ConstantListFormTableItemEventHandlers

&AtClient
Procedure ConstantListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	PerformConstantSelection();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Selects a constant.
//
&AtClient
Procedure SelectConstant(Command)
	
	PerformConstantSelection();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Selects a constant and notifies about this.
//
&AtClient
Procedure PerformConstantSelection()
	Data = New Array;
	For Each CurItem In Items.ConstantList.SelectedRows Do
		CurRow = ConstantList.FindByID(CurItem);
		Data.Add(CurRow.MetaFullName);
	EndDo;
	NotifyChoice(Data);
EndProcedure	

&AtServer
Function SetFormParameters()
	Result = New Structure("CurrentRow");
	If Parameters.InitialSelectionValue <> Undefined Then
		Result.CurrentRow = MetaNameRowID(Parameters.InitialSelectionValue);
	EndIf;
	Return Result;
EndFunction

&AtServer
Function MetaNameRowID(FullMetadataName)
	Data = FormAttributeToValue("ConstantList");
	CurRow = Data.Find(FullMetadataName, "MetaFullName");
	If CurRow <> Undefined Then
		Return CurRow.GetID();
	EndIf;
	Return Undefined;
EndFunction

#EndRegion
