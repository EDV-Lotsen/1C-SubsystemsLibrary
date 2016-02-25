&AtClient
Var CertificateManager Export;

&AtClient
Procedure OnOpen(Cancel)
	Password = CertificateManager.PrivateKeyAccessPassword;
EndProcedure

&AtClient
Procedure OK(Command)
	CertificateManager.PrivateKeyAccessPassword = Password;
	Close(DialogReturnCode.OK);
EndProcedure
