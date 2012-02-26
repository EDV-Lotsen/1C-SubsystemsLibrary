

////////////////////////////////////////////////////////////////////////////////
// SECTION OF FUNCTIONS FOR LOAD OF ADDRESS CLASSIFIER FILES FROM WEB SERVER,
// AND ALSO FUNCTIONS OF UPDATE SUPPORT OF ADDRESS INFORMATION
//

// Calls classifier load form. Can be used as interface.
//
Function LoadAddressClassifier() Export
	
	#If WebClient Then
	DoMessageBox(NStr("en = 'Web Client does not support the Address Classifier loading.'"));
	#Else
	OpenForm("InformationRegister.AddressClassifier.Form.AddressClassifierLoadForm");
	#EndIf
	
EndFunction

// Check availablity of address classifier updates at web server
// for those objects, which has been loaded earlier (for those objects
// that have record in register AddressClassifierUnitVersions).
//
// Value to return:
//   Array of structures, where each structure has following format:
//   key AddressClassifierUnitCode - String - code of address unit
//   key Description       - String - description of address unit
//   key Abbreviation         	   - String - abbreviation of address unit
//   key PostalCode        - String - postal code of address unit
//   key UpdateIsAvailable - Boolean
//
Procedure CheckAddressClassifierUpdate() Export
	
	#If WebClient Then
	Result = AddressClassifier.CheckAddressClassifierUpdatesServer();
	#Else
	Result = AddressClassifierClientServer.CheckAddressClassifierUpdate();
	#EndIf

	If Not Result.Status Then		
		DoMessageBox(Result.ErrorMessage);
		Return;
	EndIf;
	
	If Result.Value.Count() <> 0 Then
		
		NumberOfUpdates = 0;
		
		ListString = "";
		
		AddressClassifierUnits = New Array;
		
		For Each Unit In Result.Value Do
			If Unit.UpdateIsAvailable Then
				NumberOfUpdates = NumberOfUpdates + 1;
				AddressClassifierUnits.Add(Left(Unit.AddressClassifierUnitCode, 2));
				ListString = ListString + Left(Unit.AddressClassifierUnitCode, 2)
				                            + " - " + Unit.Description
				                            + " "   + Unit.Abbreviation + Chars.LF;
			EndIf;
		EndDo;
		
		If NumberOfUpdates > 0 Then
			Text = NStr("en = 'There are updates for the following address units available:'")
						+ Chars.LF
						+ ListString;
						
			#If WebClient Then
			DoMessageBox(Text);
			#Else
			Text = Text + NStr("en = 'Do you want to start updating the address classifier?'");
			Result = DoQueryBox(Text, QuestionDialogMode.YesNo, , DialogReturnCode.No, "Address classifier update");
			
			If Result = DialogReturnCode.Yes Then
				OpenForm("InformationRegister.AddressClassifier.Form.AddressClassifierLoadForm",
							New Structure("AddressClassifierUnits", AddressClassifierUnits) );
			EndIf;
			#EndIf
		Else
			DoMessageBox(NStr("en = 'Update is not necessary. The address data in the Infobase is up to date.'"), , NStr("en = 'Address Classifier'"));
		EndIf;
		
	Else
		
		DoMessageBox(NStr("en = 'Update is not necessary. The address data in the Infobase is up to date.'"), , NStr("en = 'Address Classifier'"));
		
	EndIf;
	
EndProcedure

// Calls form of clearing address classifier information by address units
//
Procedure ClearClassifier() Export
	
	OpenFormModal("InformationRegister.AddressClassifier.Form.AddressClassifierClearForm");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SECTION OF AUXILIARY FUNCTIONS
//

// Contains complete list of Classifier data files
//
Function DataFileList() Export
	
	List = New Array;
	
	List.Add("abbrbase.dbf");
	List.Add("altnames.dbf");
	List.Add("building.dbf");
	List.Add("classif.dbf");
	List.Add("streets.dbf");
	
	Return List;
	
EndFunction

// Replaces file extension from ".DBF" to ".EXE"
//
Function ReplaceDBFExtensionWithEXE(String)
	
	Return StrReplace(String, ".DBF", ".EXE");
	
EndFunction

// Replaces file extension from ".DBF" to ".ZIP"
//
Function ReplaceDBFExtensionWithZIP(String) Export
	
	Return StrReplace(String, ".DBF", ".ZIP");
	
EndFunction

// Replaces file extension from ".EXE" to ".DBF"
//
Function ReplaceEXEExtensionWithDBF(String) Export
	
	Return StrReplace(String, ".EXE", ".DBF");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Block of functions to check if files exist on disk (ITS)
//

// Checks if address classifier files exist on disk ITS.
//
// Parameters:
//   PathToITSDisc - String - path to the root of ITS disc
// 
// Value returned:
//   Boolean - True  - files are there
//             False - no files
//
Function CheckExistenceOfFilesOnITSDisc(Val PathToITSDisc) Export
	
	// if disk has been selected - then remove last char "\"
	If Right(PathToITSDisc, 1) = "\" Then
		PathToITSDisc = Left(PathToITSDisc, StrLen(PathToITSDisc) - 1);
	EndIf;
	
	PathToITSDisc = PathToITSDisc + PathToDirectoryWithClassifierDataOnITSDisc(PathToITSDisc);
	
	DataFileList = DataFileListOnITSDisc();
	
	For Each FilePath In DataFileList Do
		FullFilePath = PathToITSDisc + FilePath;
		If FilePath = "altnames.exe" Then
			Continue;
		EndIf;
		FileOnDisc = New File(FullFilePath);
		If Not FileOnDisc.Exist() Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Function returns relative path on ITS disc where Classifier files are located.
// 
// Parameters:
//   PathToITSDisc - path to the root of ITS disc.
// 
// Value returned:
//   String - relative path on ITS disc to Classifier files (sfx archive).
//            if files are not found, empty string is returned.
//
Function PathToDirectoryWithClassifierDataOnITSDisc(Val PathToITSDisc) Export
	
	PossiblePaths = New Array;
	PossiblePaths.Add("\1CIts\EXE\Classifier\");
	PossiblePaths.Add("\1CitsFr\EXE\Classifier\");
	PossiblePaths.Add("\1CItsB\EXE\Classifier");
	
	If Right(PathToITSDisc, 1) = "\" Then
		PathToITSDisc = Left(PathToITSDisc, StrLen(PathToITSDisc) - 1);
	EndIf;
	
	For Each Path In PossiblePaths Do
		FullFilePath = PathToITSDisc + Path +"street.exe" ;
		FileOnDisk = New File(FullFilePath);
		If FileOnDisk.Exist() Then
			Return Path;
		EndIf;
	EndDo;
	
	Return "";
	
EndFunction

// Contains complete list of Classifier data files (sfx archive)
//
Function DataFileListOnITSDisc() Export
	
	List = DataFileList();
	
	For Each FileName In List Do
		NewName = ReplaceDBFExtensionWithEXE(FileName);
		List.Set(List.Find(FileName), NewName);
	EndDo;
	
	Return List;
	
EndFunction

// Checks existence of data files in the passed directory
//
// Parameters:
//   PathToDirectory - string - path to directory, that has to be checked for presence of files
// 
// Value returned:
//   True        - there are files on disk
//   False       - at least one required file from fileset
//                 is missing on disk
//
Function CheckExistenceOfDataFilesDataInDirectory(Val PathToDirectory) Export
	
	If IsBlankString(PathToDirectory) Then
		Return False;
	EndIf;
	
	If Right(PathToDirectory, 1) <> "\" Then
		PathToDirectory = PathToDirectory + "\";
	EndIf;
	
	For Each FilePath In DataFileList() Do
		FileOnDisk = New File(PathToDirectory+FilePath);
		If Not FileOnDisk.Exist() Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

#If Not WebClient Then

// Extracts Classifier files from ITS disc and archives them into ZIP-archive.
// 
// Parameters:
//   ITSDisc - String - path to the root of ITS disc
// 
// Value to return:
//   String  - path to the temporary directory with files of classifier archive
//
Function ConvertFilesClassifierEXEToZIP(Val ITSDisc) Export
	
	TemporaryDirectory = CommonUseClientServer.GetTempDirectoryPath("addressclassifierfiles");
	
	CreateDirectory(TemporaryDirectory);
	
	If Right(ITSDisc, 1) = "\" Then
		ITSDisc = Left(ITSDisc, StrLen(ITSDisc) - 1);
	EndIf;
	
	FilePathsOnITSDisc = ITSDisc + PathToDirectoryWithClassifierDataOnITSDisc(ITSDisc);
	
	DataFileList = DataFileListOnITSDisc();
	
	For Each FileName In DataFileList Do
		File = New File(FilePathsOnITSDisc + FileName);
		If File.Exist() Then
			FileCopy(FilePathsOnITSDisc + FileName, TemporaryDirectory + FileName);
			File = New File(TemporaryDirectory + FileName);
			File.SetReadOnly(False);
			System(FileName + " -s", TemporaryDirectory);
		EndIf;
		
		DBFFile = New File(TemporaryDirectory+ReplaceEXEExtensionWithDBF(FileName));
		
		If Not DBFFile.Exist() Then
			DeleteFiles(TemporaryDirectory);
			Return Undefined;
		EndIf;
		
		CompressFile(TemporaryDirectory, ReplaceEXEExtensionWithDBF(FileName), TemporaryDirectory);
	EndDo;
	
	Return TemporaryDirectory;
	
EndFunction

// compresses file from Classifier package to ZIP archive.
//
// Parameters:
//   PathToDBFFiles - String - path to the directory with DBF files
//   FileName       - String - name of the file, which has to be compressed
//   TempFilesDir 	- String - directory, where archive file should be saved
//
Procedure CompressFile(Val PathToDBFFiles, FileName, TempFilesDir) Export
	
	If Not ValueIsFilled(TempFilesDir) Then
		TempFilesDir = CommonUseClientServer.GetTempDirectoryPath("addressclassifierfiles");
		CreateDirectory(TempFilesDir);
	EndIf;
	
	DBFFile = PathToDBFFiles + FileName;
	File = New File(DBFFile);
	If File.Exist() Then
		PathToArchive = TempFilesDir + ReplaceDBFExtensionWithZIP(FileName);
		ZIPFile = New ZipFileWriter(PathToArchive, , , 
		                            ZIPCompressionMethod.Deflate,
		                            ZIPCompressionLevel.Maximum);
		ZIPFile.Add(DBFFile);
		ZIPFile.Write();
	EndIf;
	
EndProcedure

// Loads region Classifier files from Web server
// Parameters:
//   Unit 	    - Array - each row is address unit ID in NN format
//   AuthenticationData - Structure - authentication parameters at 1C user site
//                              key - Login - value - user (login)
//                              key - Password - value - user password
// Returned value: 
//   Structure, key Status - Boolean - true or false
//                              key value - string - if Status is false, contains error explanation.
//
Function LoadClassifierFromWebServer(Val Unit, Val AuthenticationData, TempDirectory) Export
	
	URLRow = "http://1c-dn.com/demos/addressclassifier/";
	
	If Not ValueIsFilled(TempDirectory) Then
		TempDirectory = TempFilesDir() + "addressclassifierfiles";
		CreateDirectory(TempDirectory);
	EndIf;
	
	ParametersOfFileLoad = New Structure;
	ParametersOfFileLoad.Insert("User", AuthenticationData.Login);
	ParametersOfFileLoad.Insert("Password", AuthenticationData.Password);
	
	ZIPName = "base" + Unit + ".zip";
	ParametersOfFileLoad.Insert("DownloadFolderPath", TempDirectory + "\" + ZIPName);
	Result = GetFilesFromInternetClient.DownloadFileAtClient(URLRow + ZIPName,
	                                                         ParametersOfFileLoad);
	If Not Result.Status Then
		Return Result;
	EndIf;
	
	File = New File(TempDirectory + "\altnames.zip");
	If Not File.Exist() Then
		ParametersOfFileLoad.Insert("DownloadFolderPath", TempDirectory + "\altnames.zip");
		Result = GetFilesFromInternetClient.DownloadFileAtClient(URLRow + "altnames.zip",
		                                                         ParametersOfFileLoad);
		If Not Result.Status Then
			Return Result;
		EndIf;
	EndIf;
	
	File = New File(TempDirectory + "\abbrbase.zip");
	If Not File.Exist() Then
		ParametersOfFileLoad.Insert("DownloadFolderPath", TempDirectory + "\abbrbase.zip");
		Result = GetFilesFromInternetClient.DownloadFileAtClient(URLRow + "abbrbase.zip",
		                                                         ParametersOfFileLoad);
		If Not Result.Status Then
			Return Result;
		EndIf;
	EndIf;
	
	Return New Structure("Status", True);
	
EndFunction

#EndIf

// Passes compressed Classifier file to server. File is being extracted on server side.
// 
// Parameters:
//   FilePathsAtClient - String - path to directory with file
//   FileName - String - file name of the archive, that has to be passed and extracted at server
//
// Value to return:
//   String - path to a directory at server, where file has been extracted
// 
//
Procedure TransferFileToServer(Val FilePathsAtClient, Val FileName, PathToDirectoryAtServer) Export
	
	PathToArchive = FilePathsAtClient + ReplaceDBFExtensionWithZIP(FileName);
	
	File = New File(PathToArchive);
	
	If File.Exist() Then
		AddressClassifier.SaveFileAtServerAndExtract(New BinaryData(PathToArchive),
													 ReplaceDBFExtensionWithZIP(FileName),
													 PathToDirectoryAtServer);
	Else
		Raise NStr("en = 'It is impossible to transfer data the file to the server. File not found'");
	EndIf;
	
EndProcedure

// Passes compressed Classifier files to server. File is being extracted at server.
// 
// Parameters:
//   FilePathsAtClient 	 - String - path to the directory with file at client
//   PathToDirectoryAtServer - String - path the directory, where file will be extracted at server
//   Unit 			 - String - number of address unit in NN format.
//   PassOnlyMainFiles 		 - Boolean - if true, then only main zip files will be passed,
//                                       if false, also files altnames.zip and abbrbase.zip will passed
//
Procedure TransferFilesToServerByAddressClassifierUnits(Val FilePathsAtClient, PathToDirectoryAtServer, Unit, PassOnlyMainFiles) Export
	
	FileName = "base" + Unit + ".zip";
	AddressClassifier.SaveFileAtServerAndExtract(New BinaryData(FilePathsAtClient + FileName),
	                                             FileName,
	                                             PathToDirectoryAtServer);
	
	If Not PassOnlyMainFiles Then
		AddressClassifier.SaveFileAtServerAndExtract(New BinaryData(FilePathsAtClient + "altnames.zip"),
		                                             "altnames.zip",
		                                             PathToDirectoryAtServer);
		AddressClassifier.SaveFileAtServerAndExtract(New BinaryData(FilePathsAtClient + "abbrbase.zip"),
		                                             "abbrbase.zip",
		                                             PathToDirectoryAtServer);
	EndIf;
	
EndProcedure
