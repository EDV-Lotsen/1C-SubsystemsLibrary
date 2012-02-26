

// Check availablity of address classifier updates at web server
// for those objects, which has been loaded earlier (for those objects
// that have record in register AddressClassifierUnitVersions).
//
// Value to return:
//   Array of structures, where each structure has following format:
//   key AddressClassifierUnitCode - string - code of address unit
//   key Description       - string - description of address unit
//   key Abbreviation         - string - abbreviation of address unit
//   key PostalCode             - string - postal code of address unit
//   key UpdateIsAvailable - Boolean
//
Function CheckAddressClassifierUpdate() Export
	
	StoredInformationVersion = AddressClassifier.GetAddressClassifierUnitsVersions();
	
	URLRow = FilePathClassifierDataDescription();
	
	#If Client Then
	FilesGettingResult = GetFilesFromInternetClient.DownloadFileAtClient(URLRow);
	#Else
	FilesGettingResult = GetFilesFromInternet.DownloadFileAtServer(URLRow);
	#EndIf
	
	If Not FilesGettingResult.Status Then
		Return FilesGettingResult;
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.Read(FilesGettingResult.Path);
	TextXML = TextDocument.GetText();
	
	DeleteFiles(FilesGettingResult.Path);
	
	Updates = AddressClassifier.GetAddressInformationVersions(TextXML);
	
	Result = New Array;
	
	For Each ItemStoredVersion In StoredInformationVersion Do
		AddressInfo = AddressClassifier.InformationAboutAddressUnit(ItemStoredVersion.Key);
		AddressInfo.Insert("UpdateIsAvailable",
		                   Updates[ItemStoredVersion.Key] > ItemStoredVersion.Value);
		Result.Add(AddressInfo);
	EndDo;
	
	Return CommonUseClientServer.GenerateResultStructure(Result);
	
EndFunction

// Function gets data file using versions of address information and updates versions
// of address units in register AddressClassifierUnitVersions
// 
// Parameters:
// 	AddressClassifierUnits - array - every item - string, number of address unit in NN format
//
// Returned value: structure, key Status - boolean - true or false
//                                   key value - string - if Status is false, contains
//                                   error explanation.
//
Function GetFileVersionsAndRefreshAddressInfoVersion(Val AddressClassifierUnits) Export
	
#If Client Then
	Result = GetFilesFromInternetClient.DownloadFileAtClient(FilePathClassifierDataDescription());
#Else
	Result = GetFilesFromInternet.DownloadFileAtServer(FilePathClassifierDataDescription());
#EndIf
	
	If Not Result.Status Then
		Return Result;
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.Read(Result.Path);
	TextXML = TextDocument.GetText();
	
	DeleteFiles(Result.Path);
	
	AddressClassifier.RefreshAddressInfoVersion(TextXML, AddressClassifierUnits);
	
	Return New Structure("Status", True);
	
EndFunction

// Path to the file at web server, containing information about versions of address information
//
Function FilePathClassifierDataDescription() Export
	
	Return "http://1c-dn.com/demos/addressclassifier/versions.xml";
	
EndFunction
