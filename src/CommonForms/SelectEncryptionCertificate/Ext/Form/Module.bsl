
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	CertificateStructureArray = Parameters.CertificateStructureArray;
	
	FileRef = Undefined;
	
	If Parameters.Property("FileRef") Then
		FileRef = Parameters.FileRef;
	EndIf;
	
	PersonalCertificateThumbprintForEncryption = "";
	If Parameters.Property("PersonalCertificateThumbprintForEncryption") Then
		PersonalCertificateThumbprintForEncryption = Parameters.PersonalCertificateThumbprintForEncryption;
	EndIf;
	
	Title = 
		StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Encrypt %1'"),
				String(FileRef) );
	
	For Each CertificateStructure In CertificateStructureArray Do
		NewRow = CertificateTable.Add();
		
		NewRow.Owner = CertificateStructure.Owner;
		NewRow.IssuedBy = CertificateStructure.IssuedBy;
		NewRow.ExpirationDate = CertificateStructure.ExpirationDate;
		NewRow.Thumbprint = CertificateStructure.Thumbprint;
		
		If CertificateStructure.Property("Mark") Then
			NewRow.Check = CertificateStructure.Check;
		EndIf;
		
		If NewRow.Thumbprint = PersonalCertificateThumbprintForEncryption Then
			NewRow.PersonalEncryptionCertificate = True;
			NewRow.Check = True;
		EndIf;
		//PARTIALLY_DELETED
		//DigitalSignature.FillCertificatePurpose(CertificateStructure.Purpose, NewRow.Purpose);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	ChoiceProcessing();
EndProcedure

&AtClient
Procedure OpenCertificate(Command)
	
	CurrentData = Items.CertificateTable.CurrentData;
	
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	//PARTIALLY_DELETED
	//SelectedCertificate = DigitalSignatureClient.GetCertificateByThumbprint(CurrentData.Thumbprint);
	//
	//CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(SelectedCertificate);
	//If CertificateStructure <> Undefined Then
	//	FormParameters = New Structure("CertificateStructure, Thumbprint", CertificateStructure, CurrentData.Thumbprint);
	//	OpenForm("CommonForm.DSCertificate", FormParameters, ThisObject);
	//EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CertificateTableOwner.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CertificateTableIssuedBy.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CertificateTableExpirationDate.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CertificateTableCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CertificateTablePurpose.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("CertificateTable.PersonalEncryptionCertificate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure ChoiceProcessing()
	
	ReturnArray = New Array;
	For Each ValueTableRow In CertificateTable Do
		If ValueTableRow.Check Then
			//PARTIALLY_DELETED
			//SelectedCertificate = DigitalSignatureClient.GetCertificateByThumbprint(ValueTableRow.Thumbprint);
			//ReturnArray.Add(SelectedCertificate);
		EndIf;
	EndDo;
	
	If ReturnArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No certificate selected.'"));
		Return;
	EndIf;
	
	Close(ReturnArray);
	
EndProcedure

#EndRegion