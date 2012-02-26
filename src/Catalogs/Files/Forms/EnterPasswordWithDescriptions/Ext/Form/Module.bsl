

&AtClient
Procedure OK(Command)
	ReturnPassword = Password;
	
	If IsBlankString(Password) And NOT IsBlankString(Items.Password.EditText) Then
		ReturnPassword = Items.Password.EditText;
	EndIf;	
	
	Close(ReturnPassword);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Title = Parameters.Title;
	File  = Parameters.File;
	
	If Parameters.Property("PresentationsOfCertificates") Then
		PresentationsOfCertificates = Parameters.PresentationsOfCertificates;
	Else
		Items.PresentationsOfCertificates.Visible = False;
	EndIf;
	
EndProcedure
