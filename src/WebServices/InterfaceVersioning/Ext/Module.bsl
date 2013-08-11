
/////////////////////////////////////////////////////////////////////////////////
// Interface versioning
//

// Returns the array of supported by the InterfaceName subsystem relese version names.
//
// Parameters:
// InterfaceName - String - subsystem name.
//
// Returns:
// String array.
//
// Example:
//
// 	// The function returns the file transfer WSProxy object for the specified version.
// 	// If FileTransferVersion = Undefined then it returns the basic version (1.0.1.1) proxy. 
// //
//	Function GetFileTransferProxy(Val ConnectionParameters, Val FileTransferVersion = Undefined)
//		// …………………………………………………
//	EndFunction
//
//	Function GetFromStorage(Val FileID, Val ConnectionParameters) Export
//
//		// common functionality of all versions 
//		// …………………………………………………
//
//		// Considering the versioning.
//		SupportedVersionArray = StandardSubsystemsServer.GetSubsystemVersionArray(
//			ConnectionParameters, "FileTransferServer");
//		If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
//			HasVersion2Support = False;
//			Proxy = GetFileTransferProxy(ConnectionParameters);
//		Else
//			HasVersion2Support = True;
//			Proxy = GetFileTransferProxy(ConnectionParameters, "1.0.2.1");
//		EndIf;
//
//		PartCount = Undefined;
//		PartSize = 20 * 1024; // KB
//		If HasVersion2Support Then
//	 		TransferID = Proxy.PrepareGetFile(FileID, PartSize, PartCount);
//		Else
//			TransferID = Undefined;
//			Proxy.PrepareGetFile(FileID, PartSize, TransferID, PartCount);
//		EndIf;
//
//		// Сommon functionality of all versions
//		// …………………………………………………	
//
//	EndFunction
//
Function GetVersions(InterfaceName)
	
	VersionArray = Undefined;
	
	SupportedVersionStructure = New Structure;
	StandardSubsystemsOverridable.GetSupportedVersions(SupportedVersionStructure);
	
	SupportedVersionStructure.Property(InterfaceName, VersionArray);
	
	If VersionArray = Undefined Then
		Return XDTOSerializer.WriteXDTO(New Array);
	Else	
		Return XDTOSerializer.WriteXDTO(VersionArray);
	EndIf;
	
EndFunction