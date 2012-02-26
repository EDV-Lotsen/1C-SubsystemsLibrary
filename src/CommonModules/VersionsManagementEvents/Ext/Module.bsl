

// Handler of event OnWrite. Defined for the objects being versioned.
// Object is serialized to XML (Fast Infoset).
//
Procedure ObjectVersioningOnObjectWrite(Source, Cancellation) Export
	
	Var ObjectVersionsNumber;
	
	If ObjectIsVersioning(Source, ObjectVersionsNumber) Then
		XMLWriter = New FastInfosetWriter;
		XMLWriter.SetBinaryData();
		XMLWriter.WriteXMLDeclaration();
		WriteXML(XMLWriter, Source, XMLTypeAssignment.Explicit);
		BinaryData = XMLWriter.Close();
		DataStorage = New ValueStorage(BinaryData, New Deflation(9));
		
		ObjectVersioning.WriteObjectVersion(Source.Ref, ObjectVersionsNumber, DataStorage);
	EndIf;
	
EndProcedure

// Checks versioning settings for the passed object and
// returns versioning variant. If versioning is not enabled for the object
// then it is being versioned according to the rules versioning "by default".
//
Function ObjectIsVersioning(Val Source, ObjectVersionsNumber)
	
	SetPrivilegedMode(True);
	UseObjectVersioningSubsystem = GetFunctionalOption("UseObjectVersioningSubsystem");
	SetPrivilegedMode(False);
	
	// Check, that subsystem versioning is enabled
	If UseObjectVersioningSubsystem Then
		
		FullMetadataObjectName = Source.Metadata().FullName();
		
		SetPrivilegedMode(True);
		VersioningRule = GetFunctionalOption("ObjectVersioningRules",
										New Structure("ConfigurationObjectType", FullMetadataObjectName));
		SetPrivilegedMode(False);
		
		ObjectVersionsNumber = ObjectVersioning.GetObjectVersionsCount(Source.Ref);
		
		PerformObjectVersioning = True;
		
		If VersioningRule = Enums.ObjectVersioningRules.DoNotVersion Then
			PerformObjectVersioning = False;
		ElsIf VersioningRule = Enums.ObjectVersioningRules.VersionOnPosting Then
			If ObjectVersionsNumber = 0 And NOT Source.Posted Then
				PerformObjectVersioning = False;
			EndIf;
		EndIf;
		
	Else
		PerformObjectVersioning = False;
	EndIf;
	
	Return PerformObjectVersioning;
	
EndFunction

// Handler of event OnWrite of IB Catalogs and Documents.
// Prepares object for writing into information register.
//
Procedure ObjectVersioningBeforeDeletingObject(Source, Cancellation) Export
	
	ObjectVersioning.DeleteStoredVersionsByObject(Source.Ref);
	
EndProcedure
