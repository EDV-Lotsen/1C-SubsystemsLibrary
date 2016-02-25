
&AtClient
Var CertificatesMap;
&AtClient
Var ChoiceParameters;
&AtClient
Var SelectedCertificate;

//////////////////////////////////////////////////////////////////////////////// 
// Common procedures and functions 
// 

// defines types of the certificate storages, the certificates from which is required to be
// placed into the list ChoiceParameters_Input - the list of certificate storages
&AtClient
Procedure Set(ChoiceParameters_Input) Export
	ChoiceParameters = ChoiceParameters_Input;
EndProcedure

// Returns the choice results in the form
// - When a multiple choice - an array of certificates
// - in a single choice mode - the selected cryptography certificate 
&AtClient
Function GetChoiceResult() Export
	If Parameters.Multiselect Then
		Redo = New Array;
		For Each ValueTableRow In TableForChoice Do
			If ValueTableRow.Selected Then 
				Redo.Add(CertificatesMap[ValueTableRow]);
			EndIf;
		EndDo;
		Return Redo;
	Else
		Return SelectedCertificate;
	EndIf;
EndFunction

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

&AtClient
Procedure OnOpen(Cancel)
	CertificatesMap = New Map;
	// Filling the certificates table
	CryptoManager = New CryptoManager("Microsoft Enhanced Cryptographic Provider v1.0", "", 1);
	For Each Parameter In ChoiceParameters Do
		Storage = CryptoManager.GetCertificateStore(Parameter.Value);
		StorageCertificates = Storage.GetAll();
		ParameterPresentation = Parameter;
		
		CurrentDate = CurrentDate();
		For Each Certificate In StorageCertificates Do
			If Certificate.ValidTo < CurrentDate Then 
				Continue; // filtering out expired certificates
			EndIf;
			NewRow = TableForChoice.Add();
			CertificatesMap.Insert(NewRow, Certificate);
			NewRow.CertificatePresentation = Certificate.Subject.CN + NStr("en = ' issued by '") + Certificate.Issuer.CN + NStr("en = ' valid until '") + Certificate.ValidTo;
			NewRow.StorageType = ParameterPresentation;
		EndDo;
	EndDo;
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Multiselect Then
		Items.ChoiceProcess.Visible = False;
		Title = NStr("en = 'Recipient certificates list'");
	Else
		Items.OKButton.DefaultButton = False;
		Items.ChoiceProcess.DefaultButton = True;
		Items.OKButton.Visible = False;
		Items.Cancel.Visible = False;
		Items.TableForChoiceSelected.Visible = False;
		Title = NStr("en = 'The certificate for the signature creation'");
	EndIf;
EndProcedure

&AtClient
Procedure TableForChoiceChoice(Element, SelectedRow, Field, StandardProcessing)
	If Not Parameters.Multiselect Then
		StandardProcessing = False;
		If Not SelectedRow = Undefined Then 
			SelectedCertificate = CertificatesMap[ TableForChoice[SelectedRow] ];
			Close(SelectedCertificate);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure PerformingChoiceClick(Command)
	If Not Parameters.Multiselect Then
		CurrentData = Items.TableForChoice.CurrentData;
		If Not CurrentData = Undefined Then 
			SelectedCertificate = CertificatesMap[ CurrentData ];
			Close(SelectedCertificate);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OK(Command)
	Close(GetChoiceResult());
EndProcedure