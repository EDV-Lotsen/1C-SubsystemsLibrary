
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Parameters.Property("Object") Then
		If Parameters.Object.SignedWithDS Then
			FillOneObjectSignatureList(Parameters.Object, Parameters.UUID);
		EndIf;
	EndIf;
	
	If Parameters.Property("Signatures") Then
		FillSignatureListFromArray(Parameters.Signatures, Parameters.UUID);
	EndIf;
	
	DontAskAgain = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChooseSignature(Command)
	
	ReturnArray = New Array;
	
	For Each Row In SignatureTable Do
		If Row.Check Then
			ReturnStructure = New Structure("SignatureAddress, CertificateOwner, SignatureFileName", 
												Row.SignatureAddress,
												Row.CertificateOwner,
												Row.SignatureFileName);
			ReturnArray.Add(ReturnStructure);
		EndIf;
	EndDo;
	
	If DontAskAgain Then
		RememberDontAskAgain();
		RefreshReusableValues();
	EndIf;
	
	Close(ReturnArray);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignatureTableSignatureAuthor.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignatureTableSignatureDate.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignatureTableComment.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SignatureTable.Incorrect");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

EndProcedure

&AtServer
Procedure FillOneObjectSignatureList(ObjectRef, CallFormUUID)
	
	FullObjectNameWithDigitalSignature = ObjectRef.Metadata().FullName();
	
	QueryText = "SELECT ALLOWED
					|	DigitalSignatures.CertificateOwner AS CertificateOwner,
					|	DigitalSignatures.SignatureDate AS SignatureDate,
					|	DigitalSignatures.Comment AS Comment,
					|	DigitalSignatures.Signature AS Signature,
					|	DigitalSignatures.Thumbprint AS Thumbprint,
					|	DigitalSignatures.Signatory AS Signatory,
					|	DigitalSignatures.LineNumber AS LineNumber,
					|	DigitalSignatures.SignatureFileName AS SignatureFileName
					|FROM
					|	[FullObjectNameWithDigitalSignature].DigitalSignatures AS DigitalSignatures
					|WHERE
					|	DigitalSignatures.Ref = &ObjectRef";
	
	QueryText = StrReplace(QueryText, "[FullObjectNameWithDigitalSignature]", FullObjectNameWithDigitalSignature);
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ObjectRef", ObjectRef);
	
	QuerySelection = Query.Execute().Select();
	
	While QuerySelection.Next() Do
		NewRow = SignatureTable.Add();
		NewRow.CertificateOwner = QuerySelection.CertificateOwner;
		NewRow.SignatureDate = QuerySelection.SignatureDate;
		NewRow.Comment = QuerySelection.Comment;
		NewRow.Thumbprint = QuerySelection.Thumbprint;
		NewRow.Signatory = QuerySelection.Signatory;
		NewRow.SignatureFileName = QuerySelection.SignatureFileName;
		NewRow.Incorrect = False;
		NewRow.PictureIndex = -1;
		NewRow.Check = True;
		NewRow.SignatureAddress = PutToTempStorage(QuerySelection.Signature.Get(), CallFormUUID);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillSignatureListFromArray(Signatures, CallFormUUID)
	
	For Each Signature In Signatures Do
		NewRow = SignatureTable.Add();
		
		NewRow.CertificateOwner = Signature.CertificateOwner;
		NewRow.SignatureDate = Signature.SignatureDate;
		NewRow.Comment = Signature.Comment;
		NewRow.Thumbprint = Signature.Thumbprint;
		NewRow.Signatory = Signature.Signatory;
		NewRow.SignatureFileName = Signature.SignatureFileName;
		NewRow.Incorrect = False;
		NewRow.PictureIndex = -1;
		NewRow.Check = True;
		NewRow.SignatureAddress = PutToTempStorage(Signature.Signature, CallFormUUID);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure RememberDontAskAgain()
	//PARTIALLY_DELETED
	//SettingsSection = New Structure("ActionsOnSavingWithDS", Enums.ActionsOnSavingWithDS.SaveAllSignatures);
	//DigitalSignature.SavePersonalSettings(SettingsSection);
	RefreshReusableValues();
EndProcedure

#EndRegion
