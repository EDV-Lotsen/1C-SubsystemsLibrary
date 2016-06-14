﻿
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Read = True;
	
	ReadOnly = True;
	
	List.Parameters.SetParameterValue("MetadataObject", Parameters.MetadataObject);
	
	If ValueIsFilled(Parameters.MetadataObject) Then
		Items.MetadataObject.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateRegisterData(Command)
	
	HasChanges = False;
	
	UpdateRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'The update is completed.'");
	Else
		Text = NStr("en = 'No update required.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.RoleRights.UpdateRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
