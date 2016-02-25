
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Title = Parameters.Title;
	File = Parameters.File;
	
	If Parameters.Property("CertificatePresentations") Then
		CertificatePresentations = Parameters.CertificatePresentations;
	Else
		Items.CertificatePresentations.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ReturnPassword = Password;
	
	If IsBlankString(Password) And Not IsBlankString(Items.Password.EditText) Then
		ReturnPassword = Items.Password.EditText;
	EndIf;
	
	Close(ReturnPassword);
	
EndProcedure

#EndRegion
