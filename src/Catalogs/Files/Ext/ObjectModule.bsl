

Var SignedObjectRecord Export;


// Handler of event BeforeWrite
//
Procedure BeforeWrite(Cancellation)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(FileOwner) Then
		Raise NStr("en = 'It is impossible to record file with empty field Owner.'");
	EndIf;
	
	If NOT PrivilegedMode() And SignedObjectRecord <> True Then
		
		If ValueIsFilled(Ref) Then
			
			RefSigned = CommonUse.GetAttributeValue(Ref, "Signed");
			If Signed And RefSigned Then
				Raise NStr("en = 'Signed file cannot be edited.'");
			EndIf;	
			
			RefEncrypted = CommonUse.GetAttributeValue(Ref, "Encrypted");
			If Encrypted And RefEncrypted And Signed And NOT RefSigned Then
				Raise NStr("en = 'Encrypted file cannot be signed.'");
			EndIf;	
			
		EndIf;	
		
	EndIf;	
	
	If Not IsNew() Then
		
		If Not CurrentVersion.IsEmpty() Then
			
			// Change picture index, propably, version has appeared or version picture index has been modified
			CurrentVersionAttributes = CommonUse.GetAttributeValues(CurrentVersion, 
				"PictureIndex, Size, CreationDate, Author, Extension, VersionNo, Volume, FilePath, Code, FileName");
			
			PictureIndex = CurrentVersionAttributes.PictureIndex;
			
			// copy attributes to impove RLS operation
			CurrentVersionSize 			= CurrentVersionAttributes.Size;
			CurrentVersionDateCreated 	= CurrentVersionAttributes.CreationDate;
			CurrentVersionAuthor 		= CurrentVersionAttributes.Author;
			CurrentVersionExtension 	= CurrentVersionAttributes.Extension;
			CurrentVersionVersionNumber = CurrentVersionAttributes.VersionNo;
			CurrentVersionVolume 		= CurrentVersionAttributes.Volume;
			CurrentVersionFilePath 	= CurrentVersionAttributes.FilePath;
			CurrentVersionCode 			= CurrentVersionAttributes.Code;
			
			// Check equity of the file name and file current version
			// If names differ - version name should become equal to the file dossier name
			If CurrentVersionAttributes.FileName <> FileName Then
				Object = CurrentVersion.GetObject();
				LockDataForEdit(Object.Ref);
				If Object <> Undefined Then
					SetPrivilegedMode(True);
					Object.FileName = FileName;
					Object.Write();
					SetPrivilegedMode(False);
				EndIf;	
			EndIf;
		Else
			PictureIndex = FileOperationsClientServer.GetFilePictogramIndex(Undefined);
		EndIf;
		
		If DeletionMark And Not DeletionMarkInIB() Then
			
			// Check right "Mark for deletion".
			If NOT FileOperationsOverrided.DeletionMarkSettingPermitted(FileOwner) Then
				Raise StringFunctionsClientServer.SubstitureParametersInString(
				                     NStr("en = 'You do not have the right ""Mark for deletion"" of the file ""%1"".'"),
				                     String(Ref));
			EndIf;
			
			// Try to mark for deletion
			If Not LockedBy.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstitureParametersInString(
				                    NStr("en = 'The file ""%1"" cannot be deleted as it is being edited by user ""%2"".'"),
				                    FileName,
				                    String(LockedBy) );
			EndIf;
			
		EndIf;
		
		VIBDescription = VIBDescription();
		If FileName <> VIBDescription Then 
			If Not LockedBy.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstitureParametersInString(
				                    NStr("en = 'The file ""%1"" cannot be renamed as it is being edited by user ""%2"".'"),
				                    VIBDescription,
				                    String(LockedBy) );
			EndIf;
		EndIf;
		
	EndIf;
	
	
	Description = TrimAll(FileName);
EndProcedure

// Returns current deletion mark value in the infobase
Function DeletionMarkInIB()
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Files.DeletionMark
		|FROM
		|	Catalog.Files AS Files
		|WHERE
		|	Files.Ref = &Ref";

	Query.SetParameter("Ref", Ref);

	Result = Query.Execute();

	If Not Result.IsEmpty() Then
		Selection = Result.Choose();
		Selection.Next();
		Return Selection.DeletionMark;
	EndIf;	
	
	Return Undefined;
EndFunction

// Returns description current value in the infobase
Function VIBDescription()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Files.FileName
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.Ref = &Ref";
	
	Query.SetParameter("Ref", Ref);
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Choose();
		Selection.Next();
		Return Selection.FileName;
	EndIf;
	
	Return Undefined;	
	
EndFunction

Procedure Filling(FillingData, StandardProcessing)
	If IsNew() Then
		CreationDate 	= CurrentDate();
		StoreVersions 	= True;
		PictureIndex 	= FileOperationsClientServer.GetFilePictogramIndex(Undefined);
		
		Author 			= CommonUse.CurrentUser();
		CreationDate 	= CurrentDate();
	EndIf;
EndProcedure

