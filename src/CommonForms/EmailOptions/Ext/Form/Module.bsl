
&AtClientAtServerNoContext
Procedure SetFormItemsEnabled(Object, Items)
	If Object.SMTPAuthentication = PredefinedValue("Enum.SMTPAuthenticationSetupType.ManualSetup") Then
		Items.SMTPUser.Enabled = True;
		Items.SMTPPassword.Enabled = True;
	Else
		Items.SMTPUser.Enabled = False;
		Items.SMTPPassword.Enabled = False;
	EndIf;
EndProcedure

&AtClient
Procedure SMTPAuthenticationOnChange(Element)
	SetFormItemsEnabled(Object, Items);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	SetFormItemsEnabled(Object, Items);	
EndProcedure
