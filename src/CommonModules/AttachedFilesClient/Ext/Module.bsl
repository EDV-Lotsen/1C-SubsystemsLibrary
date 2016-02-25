////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface
 
// Opens the file for viewing or editing.
//  If the file is opened for viewing, the procedure searches for
// the file in the user working directory and suggest to open it or to get the file from the server.
//  When the file is opened for editing, the procedure opens it in the
// working directory (if it exist) or retrieves the file from the server.
//
// Parameters:
//  FileData   - Structure - file data.
//  ForEditing - Boolean - True to open the file for editing, False otherwise.
//
Procedure OpenFile(Val FileData, Val ForEditing = True) Export
	
	Parameters = New Structure;
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("ForEditing", ForEditing);
	
	NotifyDescription = New NotifyDescription("OpenFileAddInSuggested", AttachedFilesInternalClient, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure
 
// File adding command handler.
// Suggests the user to select files using the file selection dialog and attempts to place the
// selected files into the file storage, when:
//  - file does not exceed the maximum allowed size,
//  - file has a valid extension,
//  - volume has enough space (when storing files in volumes),
//  - other conditions are met.
//
// Parameters:
//  FileOwner      - Ref - file owner.
//  FormID - UUID - managed form ID.
//  Filter         - String - optional parameter that lets you set the filter for the file to
//                   be select, for example, when you select a picture for a product.
//
Procedure AddFiles(Val FileOwner, Val FormID, Val Filter = "") Export
	
	Parameters = New Structure;
	Parameters.Insert("FileOwner", FileOwner);
	Parameters.Insert("FormID", FormID);
	Parameters.Insert("Filter", Filter);
	
	NotifyDescription = New NotifyDescription("AddFilesAddInSuggested", AttachedFilesInternalClient, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure
 
// Signs the attached file.
//
// Parameters:
//  AttachedFile         - CatalogRef - reference to the catalog named *AttachedFiles.
//  FormID       - UUID - managed form ID.
//  AdditionalParameters - Undefined - default procedure behavior (see below).
//                       - Structure - with the following properties:
//                         * FileData         - Structure - file data. If the property is not
//                                              filled, it is filled automatically in the
//                                              procedure.
//                         * UserNotification - Structure - parameters of a notification that
//                                              the user receives when the file is signed:
//                                              Text, URL, Explanation, Picture,
//                                            - Undefined - use the default notification. If
//                                              the property is not filled, the notification
//                                              does not shown. If AdditionalParameters is not
//                                              filled, the value is considered Undefined.
//                         * ResultProcessing - NotifyDescription - filled with a Boolean
//                                              value, True means the file is signed, otherwise
//                                              the file is not signed. If the value is not
//                                              filled, the notification does not called.
//
Procedure SignFile(AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	If Not ValueIsFilled(AttachedFile) Then
		ShowMessageBox(, NStr("en = 'File to be signed is not selected.'"));
		Return;
	EndIf;
	
	//PARTIALLY_DELETED
	Return;
	//If Not DigitalSignatureClient.UseDigitalSignatures() Then
	//	ShowMessageBox(, 
	//		NStr("en = 'To add the digital
	//		           |signature, enable digital signatures in the application settings.'"));
	//	Return;
	//EndIf;
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("UserNotification");
	EndIf;
	
	If Not AdditionalParameters.Property("FileData") Then
		AdditionalParameters.Insert("FileData", GetFileData(
			AttachedFile, FormID));
	EndIf;
	
	#If WebClient Then
		ExecutionParameters = CommonUseClientServer.CopyStructure(AdditionalParameters);
	#Else
		ExecutionParameters = New Structure(New FixedStructure(AdditionalParameters));
	#EndIf
	ExecutionParameters.Insert("AttachedFile", AttachedFile);
	AttachedFilesInternalClient.GenerateFileSignature(ExecutionParameters);
	
EndProcedure
 
// Saves the file with a digital signature.
// Used in the file saving command handler.
//
// Parameters:
//  AttachedFile   - CatalogRef - reference to the catalog named *AttachedFiles.
//  FileData       - Structure - file data.
//  FormID - UUID - managed form ID.
//
Procedure SaveWithDigitalSignature(Val AttachedFile, Val FileData, Val FormID) Export
	
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("SaveWithDigitalSignatureExtensionSuggested", AttachedFilesInternalClient, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure
 
// Places file data from the server to the working directory on the disk.
// The file system extention must be installed.
//
// Parameters:
//  FileBinaryDataAddress     - String - address in a temporary storage with binary data or a
//                              link to the file data in the infobase.
//  RelativePath              - String - path to the file relative to the working directory.
//  ModificationDateUniversal - Date - universal file modification date.
//  FileName                  - String - file name (with extension).
//  UserWorkingDirectory      - String - path to the working directory.
//  FullFileNameAtClient      - String - (return value) set when the file is retrieved and saved.
//
// Returns:
//  Boolean - True if the file has been retrieved and saved, False otherwise.
//
Function GetFileToWorkingDirectory(Val FileBinaryDataAddress,
                                    Val RelativePath,
                                    Val ModificationDateUniversal,
                                    Val FileName,
                                    Val UserWorkingDirectory = "",
                                    FullFileNameAtClient) Export
	
	If UserWorkingDirectory = Undefined
	 Or IsBlankString(UserWorkingDirectory) Then
		
		Return False;
	EndIf;
	
	DirectoryForSaving = UserWorkingDirectory + RelativePath;
	
	Try
		CreateDirectory(DirectoryForSaving);
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessage = NStr("en = 'Cannot create the directory on disk:'") + " " + ErrorMessage;
		CommonUseClientServer.MessageToUser(ErrorMessage);
		Return False;
	EndTry;
	
	File = New File(DirectoryForSaving + FileName);
	If File.Exist() Then
		File.SetReadOnly(False);
		DeleteFiles(DirectoryForSaving + FileName);
	EndIf;
	
	FileToReceive = New TransferableFileDescription(DirectoryForSaving + FileName, FileBinaryDataAddress);
	FilesToBeObtained = New Array;
	FilesToBeObtained.Add(FileToReceive);
	
	ObtainedFiles = New Array;
	
	If GetFiles(FilesToBeObtained, ObtainedFiles, , False) Then
		FullFileNameAtClient = ObtainedFiles[0].Name;
		File = New File(FullFileNameAtClient);
		File.SetModificationUniversalTime(ModificationDateUniversal);
		Return True;
	EndIf;
	
	Return False;
	
EndFunction
 

// Puts a file on the client disk in a temporary storage.
//
// Parameters:
//  PathToFile     - String - full path to the file.
//  FormID - UUID - managed form ID.
//
// Returns:
//  Structure - data of the file placed in a temporary storage.
//
Function PutFileToStorage(Val PathToFile, Val FormID) Export
	
	Result = New Structure;
	Result.Insert("FilePlacedToStorage", False);
	
	File = New File(PathToFile);
	FileFunctionsInternalClientServer.CheckCanImportFile(File);
	
	TempTextStorageAddress = "";
	If Not FileFunctionsInternalClientServer.CommonFileOperationSettings().ExtractFileTextsAtServer Then
		TempTextStorageAddress = FileFunctionsInternalClientServer.ExtractTextToTempStorage(PathToFile, FormID);
	EndIf;
	
	FilesToBePlaced = New Array;
	FilesToBePlaced.Add(New TransferableFileDescription(PathToFile));
	PlacedFiles = New Array;
	
	If Not PutFiles(FilesToBePlaced, PlacedFiles, , False, FormID) Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot place file
				           |""%1""
				           |in a temporary storage.'"),
				PathToFile) );
		Return Result;
	EndIf;
	
	Result.Insert("FilePlacedToStorage",       True);
	Result.Insert("ModificationDateUniversal", File.GetModificationUniversalTime());
	Result.Insert("FileAddressInTempStorage",  PlacedFiles[0].Location);
	Result.Insert("TempTextStorageAddress",    TempTextStorageAddress);
	Result.Insert("Extension",                 Right(File.Extension, StrLen(File.Extension)-1));
	
	Return Result;
	
EndFunction
 
// Saves a file to the directory on disk.
// Also used as an auxiliary function when saving a file with digital signature.
//
// Parameters:
//  FileData  - Structure - file data.
//
// Returns:
//  String - name of the file to be saved.
//
Procedure SaveFileAs(Val FileData) Export
	
	Parameters = New Structure;
	Parameters.Insert("FileData", FileData);
	
	NotifyDescription = New NotifyDescription("SaveFileAsExtensionSuggested", AttachedFilesInternalClient, Parameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure
 
// Opens the common form of attached file from the attached file catalog item form.
// Closes the item form.
// 
// Parameters:
//  Form - ManagedForm - attached file catalog form.
//
Procedure GoToAttachedFileForm(Val Form) Export
	
	AttachedFile = Form.Key;
	
	Form.Close();
	
	For Each CurWindow In GetWindows() Do
		
		Content = CurWindow.GetContent();
		
		If Content = Undefined Then
			Continue;
		EndIf;
		
		If Content.FormName = "CommonForm.AttachedFile" Then
			If Content.Parameters.Property("AttachedFile")
			   And Content.Parameters.AttachedFile = AttachedFile Then
				CurWindow.Activate();
				Return;
			EndIf;
		EndIf;
		
	EndDo;
	
	OpenAttachedFileForm(AttachedFile);
	
EndProcedure
 
// Opens the file selection form.
// Used in selection handler for overriding the default behavior.
//
// Parameters:
//  FilesOwner         - Ref - reference to an object with files.
//  FormItem           - FormTable, FormField - form item that will receive the selection 
//                       notification.
//  StandardProcessing - Boolean - (return value) always set to False.
//
Procedure OpenFileChoiceForm(Val FilesOwner, Val FormItem, StandardProcessing = False) Export
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("FileOwner", FilesOwner);
	
	OpenForm("CommonForm.AttachedFiles", FormParameters, FormItem);
	
EndProcedure
 
// Opens the form of the attached file.
// Can be used as an attached file opening handler.
//
// Parameters:
//  AttachedFile       - CatalogRef - reference to the catalog named *AttachedFiles.
//  StandardProcessing - Boolean - (return value) always set to False.
//
Procedure OpenAttachedFileForm(Val AttachedFile, StandardProcessing = False) Export
	
	StandardProcessing = False;
	
	If ValueIsFilled(AttachedFile) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("AttachedFile", AttachedFile);
		
		OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
	EndIf;
	
EndProcedure
 
// See the function of the same name in the AttachedFiles module.
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetBinaryDataRef = True) Export
	
	Return AttachedFilesInternalServerCall.GetFileData(
		AttachedFile, FormID, GetBinaryDataRef);
	
EndFunction
	
#EndRegion