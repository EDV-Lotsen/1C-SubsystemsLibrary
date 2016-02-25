////////////////////////////////////////////////////////////////////////////////
// Address classifier subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Calls the classifier import form. Can be used as user interface.
//
// Parameters:
//     ImportParameters - Structure - parameters passed to the form while opening
//
Procedure ImportAddressClassifier(Val ImportParameters = Undefined) Export
	
	If AddressClassifierServerCall.CanChangeAddressClassifier() Then
		OpenForm("InformationRegister.AddressClassifier.Form.LoadAddressClassifier", ImportParameters);
	Else
		ShowMessageBox(, NStr("en='In separated mode, address classifier cannot be imported.'"));
	EndIf;
	
EndProcedure

// Checking website for address classifier updates for previously imported objects.
//
// Parameters:
//     Owner - ManagedForm - form used to perform the check
//
Procedure CheckAddressObjectUpdateRequired(Owner = Undefined) Export
	
	If Not AddressClassifierServerCall.CanChangeAddressClassifier() Then
		ShowMessageBox(, NStr("en='In separated mode, address classifier data version cannot be queried.'"));
		Return;
	EndIf;
	
	If RequestAccessOnUse() Then
		// Security profile request required
		SafeModeClient.ApplyExternalResourceRequests(
			AddressClassifierServerCall.AddressClassifierUpdateCheckSecurityPermissionsQuery(), 
			Owner, 
			New NotifyDescription("AddressObjectUpdateCheckSecurityPermissionGranting", ThisObject)
		);
		
	Else
		// Permissions already granted for the whole application
		Result = AddressClassifierClientServer.CheckForAddressObjectUpdates();
		RequiredAddressObjectUpdateProcessing(Result);
		
	EndIf;
	
EndProcedure

// Calls the address classifier data clearing form by address object
//
// Parameters:
//     Owner - ManagedForm - form used to clear the address classifier.
//
Procedure ClearClassifier(Owner = Undefined) Export
	
	If AddressClassifierServerCall.CanChangeAddressClassifier() Then
		OpenForm("InformationRegister.AddressClassifier.Form.AddressClassifierClearing", , Owner);
	Else
		ShowMessageBox(, NStr("en='In separated mode, address classifier cannot be cleared.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Processing information on available updates
//
Procedure RequiredAddressObjectUpdateProcessing(Val UpdateData)
	
	If Not UpdateData.Status Then
		ShowMessageBox(, UpdateData.ErrorMessage);
		Return;
	EndIf;
	
	If UpdateData.Value.Count()=0 Then
		ShowMessageBox(, NStr("en = 'Address classifier not filled.'"));
		Return;
	EndIf;
	
	UpdateList = "";
	AddressObjectCount = 0;
	AddressObjects  = New Array;
	
	For Each AddressObject In UpdateData.Value Do
		
		If AddressObject.AddressObjectCode <> "AL" And AddressObject.UpdateAvailable Then
			AddressObjects.Add(Left(AddressObject.AddressObjectCode, 2));
			UpdateList = UpdateList + Left(AddressObject.AddressObjectCode, 2)
				+ " - " + AddressObject.Description + " " + AddressObject.Abbr + Chars.LF;
				
			AddressObjectCount = AddressObjectCount + 1;
		EndIf;
		
	EndDo;
		
	If AddressObjectCount = 0 Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Address classifier update not needed.
			           |Latest address data from %1 already imported.'"),
			Format(UpdateData.LatestACUpdateVersion, "DLF=D")));
		Return;
	EndIf;
	
	// Full list
	Title = NStr("en = 'Updating address classifier'");
	Text = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Updates available for states (%1):'"), AddressObjectCount) 
		+ Chars.LF + UpdateList;
	Notification = New NotifyDescription("CheckAddressObjectUpdateRequiredEnd", 
		ThisObject, AddressObjects);
		
	QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionParameters.Title = Title;
	QuestionParameters.SuggestDontAskAgain = False;
	
#If WebClient Then
	// Displaying message. Using standard form instead of warning because the list is extensive.
	
	QuestionParameters.DefaultButton = DialogReturnCode.OK;
	StandardSubsystemsClient.ShowQuestionToUser(Notification, 
		NStr("en = 'To update the address classifier, run the application via thin client.'")
		+ Chars.LF + Chars.LF + Text, QuestionDialogMode.OK, QuestionParameters);
	Return;
#EndIf

	// Asking for confirmation once more
	Buttons = New ValueList;
	Buttons.Add("Yes",  NStr("en='Refresh'"));
	Buttons.Add("None", NStr("en='Cancel'"));
	QuestionParameters.DefaultButton = "Yes";
	StandardSubsystemsClient.ShowQuestionToUser(Notification, 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Start updating address classifier to version %1?'"),
			Format(UpdateData.LatestACUpdateVersion, "DLF=D")
		) + Chars.LF + Chars.LF + Text, Buttons, QuestionParameters);
	
EndProcedure

// Ending modal confirmation for resources assigned to check for classifier updates
//
Procedure AddressObjectUpdateCheckSecurityPermissionGranting(Val CloseResult, Val AdditionalParameters) Export

	If CloseResult <> DialogReturnCode.OK Then
		// Permission not granted
		Return;
	EndIf;
	
	// Permission granted, establishing connection to server
	Result = AddressClassifierServerCall.CheckForAddressObjectUpdatesServer();
	RequiredAddressObjectUpdateProcessing(Result);
	
EndProcedure

// Ending modal dialog on whether update is required
//
Procedure CheckAddressObjectUpdateRequiredEnd(QuestionResult, AdditionalParameters) Export
	
#If WebClient Then
	Return;
#EndIf

	If QuestionResult <> Undefined And QuestionResult.Value = "Yes" Then
		OpenForm("InformationRegister.AddressClassifier.Form.LoadAddressClassifier",	
			New Structure("AddressObjects", AdditionalParameters));
	EndIf;
	
EndProcedure	

// Contains full list of address classifier data files
//
Function DataFileList() Export
	
	List = New Array;
	
	List.Add("ABBRBASE.DBF");
	List.Add("ALTNAMES.DBF");
	List.Add("BUILD.DBF");
	List.Add("CLASS.DBF");
	List.Add("STREET.DBF");
	
	Return List;
	
EndFunction

// Replaces file extension from ".DBF" to ".EXE"
//
// Parameters:
//    String - String - String with "DBF" extension.
//
// Returns:
//    String - String with "EXE" extension.
//
Function ReplaceExtension_DBF_To_EXE(String)
	
	Return StrReplace(String, ".DBF", ".EXE");
	
EndFunction

// Replaces file extension from ".DBF" to ".ZIP"
//
// Parameters:
//    String - String - String with "DBF" extension.
//
// Returns:
//    String - String with "ZIP" extension.
//
Function ReplaceExtension_DBF_To_ZIP(String) Export
	
	Return StrReplace(String, ".DBF", ".ZIP");
	
EndFunction

// Replaces file extension from ".EXE" to ".DBF"
//
// Parameters:
//    String - String - String with "EXE" extension.
//
// Returns:
//    String - String with "DBF" extension.
//
Function ReplaceExtension_EXE_To_DBF(String) Export
	
	Return StrReplace(String, ".EXE", ".DBF");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions related to checking file availability on ITS discs

// Checks the ITS disc for address classifier files.
// 
// Parameters:
//     PathToITSDisc - String - path to ITS disc root directory
// 
// Returns:
//     Boolean - true - files
//              found false   - files not found
//
Function CheckForFilesOnITSDisc(Val PathToITSDisc) Export
	
	// If disc is selected - the trailing "\" must be removed
	RightCharacter = Right(PathToITSDisc, 1);
	If RightCharacter = "\" Or RightCharacter = "/" Then
		PathToITSDisc = Left(PathToITSDisc, StrLen(PathToITSDisc) - 1);
	EndIf;
	
	PathToITSDisc = PathToITSDisc + PathToACDataDirectoryOnITSDisc(PathToITSDisc);
	
	DataFileList = DataFileListOnITSDisc();
	
	For Each PathToFile In DataFileList Do
		FullPathToFile = PathToITSDisc + PathToFile;
		If PathToFile = "ALTNAMES.EXE" Then
			Continue;
		EndIf;
		
		FileOnHardDisk = New File(FullPathToFile);
		If Not FileOnHardDisk.Exist() Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Returns relative path to address classifier files on ITS disc.
// 
// Parameters:
//    PathToITSDisc - String - path to ITS disc root directory.
// 
// Returns:
//    String - relative path to address classifier files on ITS disc 
//             (in self-extracting archive format).
//             Returns empty string if no files were found.
//
Function PathToACDataDirectoryOnITSDisc(Val PathToITSDisc) Export
	
	AllowedPaths = New Array;
	AllowedPaths.Add("\1CIts\EXE\CLASS\");
	AllowedPaths.Add("\1CitsFr\EXE\CLASS\");
	AllowedPaths.Add("\1CItsB\EXE\CLASS");
	
	RightCharacter = Right(PathToITSDisc, 1);
	If RightCharacter = "\" Or RightCharacter = "/" Then
		PathToITSDisc = Left(PathToITSDisc, StrLen(PathToITSDisc) - 1);
	EndIf;
	
	For Each Path In AllowedPaths Do
		FullPathToFile = PathToITSDisc + Path +"STREET.EXE" ;
		FileOnHardDisk = New File(FullPathToFile);
		If FileOnHardDisk.Exist() Then
			Return Path;
		EndIf;
	EndDo;
	
	Return "";
	
EndFunction

// Contains full list of address classifier data files (in self-extracting EXE archive format)
//
// Returns:
//    Array - address classifier data file list.
//
Function DataFileListOnITSDisc() Export
	
	List = DataFileList();
	
	For Each FileName In List Do
		NewName = ReplaceExtension_DBF_To_EXE(FileName);
		List.Set(List.Find(FileName), NewName);
	EndDo;
	
	Return List;
	
EndFunction

// Checks the passed directory for data files
// 
// Parameters:
//    PathToDirectory - String - path to directory to be checked for data files
// 
// Returns:
//    Boolean - True if all files were found, False if at least one file from the list was not found
//
Function CheckDirectoryForDataFiles(Val PathToDirectory) Export
	
	If IsBlankString(PathToDirectory) Then
		Return False;
	EndIf;
	
	If Right(PathToDirectory, 1) <> "\" Then
		PathToDirectory = PathToDirectory + "\";
	EndIf;
	
	For Each PathToFile In DataFileList() Do
		FileOnHardDisk = New File(PathToDirectory+PathToFile);
		If Not FileOnHardDisk.Exist() Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Opens level selection form - breaking system interdependencies
//
Function OpenACSelectionForm(FormParameters = Undefined, Owner = Undefined, Uniqueness = Undefined, Window = Undefined, URL = Undefined, OnCloseNotifyDescription = Undefined) Export
	
	Return OpenForm("InformationRegister.AddressClassifier.Form.ChoiceForm", FormParameters, Owner, 
		Uniqueness, Window, URL, OnCloseNotifyDescription);
		
	EndFunction

#If Not WebClient Then

// Extracts address classifier files from ITS disc and compresses them to ZIP archive.
// 
// Parameters:
//    ITSDisc - String - path to ITS disc root directory
// 
// Returns:
//    String - Path to temporary directory with AC archive files
//
Function ConvertACFilesEXEToZip(Val ITSDisc) Export
	
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
	
	CreateDirectory(TemporaryDirectory);
	
	If Right(ITSDisc, 1) = "\" Then
		ITSDisc = Left(ITSDisc, StrLen(ITSDisc) - 1);
	EndIf;
	
	PathToFilesOnITSDisc = ITSDisc + PathToACDataDirectoryOnITSDisc(ITSDisc);
	
	DataFileList = DataFileListOnITSDisc();
	
	For Each FileName In DataFileList Do
		File = New File(PathToFilesOnITSDisc + FileName);
		If File.Exist() Then
			FileCopy(PathToFilesOnITSDisc + FileName, TemporaryDirectory + FileName);
			File = New File(TemporaryDirectory + FileName);
			File.SetReadOnly(False);
			System(FileName + " -s", TemporaryDirectory);
		EndIf;
		
		DBFFile = New File(TemporaryDirectory+ReplaceExtension_EXE_To_DBF(FileName));
		
		If Not DBFFile.Exist() Then
			DeleteFiles(TemporaryDirectory);
			Return Undefined;
		EndIf;
		
		CompressFile(TemporaryDirectory, ReplaceExtension_EXE_To_DBF(FileName), TemporaryDirectory);
	EndDo;
	
	Return TemporaryDirectory;
	
EndFunction

// Compresses address classifier files to ZIP archive.
//
// Parameters:
//    PathToDBFFiles  - String - path to directory with DBF files 
//    FileName        - String - name of file to be compressed 
//    TempFilesDir    - String - directory where the archive file will be stored
//
Procedure CompressFile(Val PathToDBFFiles, FileName, TempFilesDir) Export
	
	If Not ValueIsFilled(TempFilesDir) Then
		TempFilesDir = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
		CreateDirectory(TempFilesDir);
	EndIf;
	
	DBFFile = PathToDBFFiles + FileName;
	File = New File(DBFFile);
	If File.Exist() Then
		PathToArchiveFile = TempFilesDir + ReplaceExtension_DBF_To_ZIP(FileName);
		ZIPFile = New ZipFileWriter(PathToArchiveFile, , , ZIPCompressionMethod.Deflate, ZIPCompressionLevel.Maximum);
		ZIPFile.Add(DBFFile);
		ZIPFile.Write();
	EndIf;
	
EndProcedure

// Downloads AC state data files from web server
//
// Parameters
//    AddressObject      - Array     - each row contains an address object ID in format NN 
//    AuthenticationData - Structure - 1C user support website authentication parameters 
//                               * UserCode - String - user name (login) 
//                               * Password - String - user password 
//    TemporaryDirectory  - String - path to temporary directory.
//
// Returns:
//     Structure - result description:
//          * Status       - Boolean - data import status
//          * Path         - String - path to the file on server, the key is used only if Status is True 
//          * ErrorMessage - String - error message, if Status is False
//          * Headings     - Map    - see HTTPResponse Object headings parameter description
//
Function ImportACFromWebserver(Val AddressObject, Val AuthenticationData, TemporaryDirectory) Export
	
	URLString = "http://1c-dn.com/demos/addressclassifier/";
	
	If Not ValueIsFilled(TemporaryDirectory) Then
		TemporaryDirectory = GetTempFileName();
		CreateDirectory(TemporaryDirectory);
	EndIf;
	
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(TemporaryDirectory);
	
	FileImportParameters = New Structure;
	FileImportParameters.Insert("User", AuthenticationData.UserCode);
	FileImportParameters.Insert("Password",  AuthenticationData.Password);
	
	If AddressObject = "AL" Then
		File = New File(TemporaryDirectory + "altnames.zip");
		If Not File.Exist() Then
			FileImportParameters.Insert("PathForSaving", TemporaryDirectory + "altnames.zip");
			Result = GetFilesFromInternetClient.DownloadFileAtClient(URLString + "altnames.zip",
			FileImportParameters);
			If Not Result.Status Then
				Return Result;
			EndIf;
		EndIf;
		
	ElsIf AddressObject = "SO" Then
		File = New File(TemporaryDirectory + "abbrbase.zip");
		If Not File.Exist() Then
			FileImportParameters.Insert("PathForSaving", TemporaryDirectory + "abbrbase.zip");
			Result = GetFilesFromInternetClient.DownloadFileAtClient(URLString + "abbrbase.zip",
			FileImportParameters);
			If Not Result.Status Then
				Return Result;
			EndIf;
		EndIf;
		
	Else
		ZIPName = "base" + AddressObject + ".zip";
		FileImportParameters.Insert("PathForSaving", TemporaryDirectory + ZIPName);
		Result = GetFilesFromInternetClient.DownloadFileAtClient(URLString + ZIPName,
		FileImportParameters);
		If Not Result.Status Then
			Return Result;
		EndIf;
		
	EndIf;
	
	// Import successful
	Return Result;
EndFunction

#EndIf

Function RequestAccessOnUse()
	
	Return False;
	
EndFunction

// Calls directory selection dialog
// 
// Parameters:
//     Form - ManagedForm - object used to call the dialog 
//     DataPath           - String  - full name of form attribute containing the directory value. 
//                          Examples: WorkingDirectory, Object.PictureDirectory
//     Title              - String  - Dialog title
//     StandardProcessing - Boolean - used by OnSelectionStart handler. Will be filled by False value.
//
Procedure ChooseDirectory(Val Form, Val DataPath, Val Title = Undefined, StandardProcessing = False) Export
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("SelectDirectoryEndFileSystemExtensionCheck", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form",       Form);
	Notification.AdditionalParameters.Insert("DataPath", DataPath);
	Notification.AdditionalParameters.Insert("Title",   Title);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, , False);
EndProcedure

// Ending non-modal directory selection
//
Procedure SelectDirectoryEndFileSystemExtensionCheck(Val Result, Val AdditionalParameters) Export
	
	If Result <> True Then
		// Extension installation refused
		Return;
		
	ElsIf Not AttachFileSystemExtension() Then
		ShowMessageBox(, NStr("en = 'The file system extension is not attached.'"));
		Return;
	EndIf;
	
	Form       = AdditionalParameters.Form;
	DataPath = AdditionalParameters.DataPath;
	Title   = AdditionalParameters.Title;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	If Title <> Undefined Then
		Dialog.Title = Title;
	EndIf;
	
	ValueOwner = Form;
	CurrentValue  = Form;
	AttributeName     = DataPath;
	
	PathParts = StrReplace(DataPath, ".", Chars.LF);
	For Position = 1 To StrLineCount(PathParts) Do
		AttributeName     = StrGetLine(PathParts, Position);
		ValueOwner = CurrentValue;
		CurrentValue  = CurrentValue[AttributeName];
	EndDo;
	
	Dialog.Directory = CurrentValue;
	
	If Dialog.Choose() Then
		ValueOwner[AttributeName] = Dialog.Directory;
		ChoiceData = Dialog.Directory;
	EndIf;
	
EndProcedure

// Creates and returns a client-based temporary directory.
//
// Returns:
//     String - full name of the created directory
//
Function TemporaryClientDirectory() Export
	
#If WebClient Then
	Separator = GetPathSeparator();
	
	ClientDirectory = CommonUseClientServer.AddFinalPathSeparator(TempFilesDir()) 
		+ Separator + String(New UUID) + Separator;
#Else
	ClientDirectory = GetTempFileName();
#EndIf

	CreateDirectory(ClientDirectory);
	
	Return ClientDirectory;
EndFunction

#EndRegion