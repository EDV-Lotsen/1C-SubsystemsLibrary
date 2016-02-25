////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// See the procedure of the same name in the AttachedFiles module.
Procedure UpdateAttachedFile(Val AttachedFile, Val FileInfo) Export
	
	AttachedFiles.UpdateAttachedFile(AttachedFile, FileInfo);
	
EndProcedure

// See the procedure of the same name in the AttachedFiles module.
Procedure RecordSingleSignatureDetails(Val AttachedFile, Val SignatureData) Export
	
	AttachedFiles.RecordSingleSignatureDetails(AttachedFile, SignatureData);
	
EndProcedure

// See the procedure of the same name in the AttachedFiles module.
Procedure RecordMultipleSignatureDetails(Val AttachedFile,
                                     Val ArrayOfSignatures) Export
	
	AttachedFiles.RecordMultipleSignatureDetails(
		AttachedFile, ArrayOfSignatures);
	
EndProcedure

// See See the function of the same name in the AttachedFiles module.
Function AppendFile(Val FileOwner,
                     Val BaseName,
                     Val ExtensionWithoutDot = Undefined,
                     Val Modified = Undefined,
                     Val ModifiedUniversalTime = Undefined,
                     Val FileAddressInTempStorage,
                     Val TempTextStorageAddress = "",
                     Val Details = "") Export
	
	Return AttachedFiles.AppendFile(
		FileOwner,
		BaseName,
		ExtensionWithoutDot,
		Modified,
		ModifiedUniversalTime,
		FileAddressInTempStorage,
		TempTextStorageAddress,
		Details);
	
EndFunction

// See See the function of the same name in the AttachedFiles module.
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetBinaryDataRef = True) Export
	
	Return AttachedFiles.GetFileData(
		AttachedFile, FormID, GetBinaryDataRef);
	
EndFunction

// See the procedure of the same name in the AttachedFilesInternal module.
Procedure Encrypt(Val AttachedFile, Val EncryptedData, Val ThumbprintArray) Export
	
	AttachedFilesInternal.Encrypt(
		AttachedFile, EncryptedData, ThumbprintArray);
	
EndProcedure

// See the procedure of the same name in the AttachedFilesInternal module.
Procedure Decrypt(Val AttachedFile, Val DecryptedData) Export
	
	AttachedFilesInternal.Decrypt(AttachedFile, DecryptedData);
	
EndProcedure

// Gets all signature file.
//
// For details - see see DigitalSignature.GetAllSignatures().
//
Function GetAllSignatures(ObjectRef, UUID) Export
	
	//PARTIALLY_DELETED
	//Return DigitalSignature.GetAllSignatures(ObjectRef, UUID);
	Return New Array;
	
EndFunction

// See the procedure of the same name in the AttachedFiles module.
Procedure OverrideAttachedFileForm(Source,
                                                      FormType,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInfo,
                                                      StandardProcessing) Export
	
	AttachedFiles.OverrideAttachedFileForm(Source,
		FormType,
		Parameters,
		SelectedForm,
		AdditionalInfo,
		StandardProcessing);
		
EndProcedure

#EndRegion