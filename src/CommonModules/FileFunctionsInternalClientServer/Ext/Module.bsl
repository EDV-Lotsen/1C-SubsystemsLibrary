////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// The personal settings include FileFunctions subsystem settings
// (see FileFunctionsInternalCached.FileOperationSettings),
// FileOperations subsystem settings, and AttachedFiles subsystem settings.
//
Function PersonalFileOperationSettings() Export

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return FileFunctionsInternalCached.FileOperationSettings().PersonalSettings;
#Else
	Return FileFunctionsInternalClientCached.PersonalFileOperationSettings();
#EndIf

EndFunction

// The common settings include FileFunctions subsystem settings
// (see FileFunctionsInternalCached.FileOperationSettings), 
// FileOperations subsystem settings, and AttachedFiles subsystem settings.
//
Function CommonFileOperationSettings() Export

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return FileFunctionsInternalCached.FileOperationSettings().CommonSettings;
#Else
	Return FileFunctionsInternalClientCached.CommonFileOperationSettings();
#EndIf

EndFunction

// Extracts text from a file and returns it as a string.
Function ExtractText(FullFileName, Cancel = False, Encoding = Undefined) Export
	
	ExtractedText = "";
	
	Try
		File = New File(FullFileName);
		If Not File.Exist() Then
			Cancel = True;
			Return ExtractedText;
		EndIf;
	Except
		Cancel = True;
		Return ExtractedText;
	EndTry;
	
	Stop = False;
	
	CommonSettings = CommonFileOperationSettings();
	
#If Not WebClient Then
	
	FileNameExtension =
		CommonUseClientServer.GetFileNameExtension(FullFileName);
	
	FileExtensionInList = FileExtensionInList(
		CommonSettings.TextFileExtensionList, FileNameExtension);
	
	If FileExtensionInList Then
		Return ExtractTextFromTextFile(FullFileName, Encoding, Cancel);
	EndIf;
	
	Try
		Extracting = New TextExtraction(FullFileName);
		ExtractedText = Extracting.GetText();
	Except
		// If there is no handler to extract the text, this is not an error but a normal scenario.
		ExtractedText = "";
		Stop = True;
	EndTry;
#EndIf
	
	If IsBlankString(ExtractedText) Then
		
		FileNameExtension =
			CommonUseClientServer.GetFileNameExtension(FullFileName);
		
		FileExtensionInList = FileExtensionInList(
			CommonSettings.OpenDocumentFileExtensionList, FileNameExtension);
		
		If FileExtensionInList Then
			Return ExtractOpenDocumentText(FullFileName, Cancel);
		EndIf;
		
	EndIf;
	
	If Stop Then
		Cancel = True;
	EndIf;
	
	Return ExtractedText;
	
EndFunction

// Extracts text from a file and stores it to a temporary storage.
Function ExtractTextToTempStorage(FullFileName, UUID = "", Cancel = False,
	Encoding = Undefined) Export
	
	TempStorageAddress = "";
	
	#If Not WebClient Then
		
		Text = ExtractText(FullFileName, Cancel, Encoding);
		
		If IsBlankString(Text) Then
			Return "";
		EndIf;
		
		TempFileName = GetTempFileName();
		TextFile = New TextWriter(TempFileName, TextEncoding.UTF8);
		TextFile.Write(Text);
		TextFile.Close();
		
		#If Client Then
			UploadResult = FileFunctionsInternalClient.PutFileFromDiskInTempStorage(TempFileName, , UUID);
			If UploadResult <> Undefined Then
				TempStorageAddress = UploadResult;
			EndIf;
		#Else
			Return Text;
		#EndIf
		
		DeleteFiles(TempFileName);
		
	#EndIf
	
	Return TempStorageAddress;
	
EndFunction

// Gets a unique file name for using it in the working directory.
//  If the generated file name is not unique, adds a randomly generated direcotry,
// for example: A1\Order.doc.
//
Function GetUniqueNameWithPath(DirectoryName, FileName) Export
	
	FinalPath = "";
	
	Counter = 0;
	DoNumber = 0;
	Done = False;
	
	RandomValueGenerator = Undefined;
	
#If Not WebClient Then
	// CurrentDate() is only used for random number generation,
	// so conversion to CurrentSessionDate is not required
	RandomValueGenerator = New RandomNumberGenerator(Second(CurrentDate()));
#EndIf
	
	While Not Done And DoNumber < 100 Do
		DirectoryNumber = 0;
#If Not WebClient Then
		DirectoryNumber = RandomValueGenerator.RandomNumber(0, 25);
#Else
		// CurrentDate() is only used for random number generation,
		// so conversion to CurrentSessionDate is not required
		DirectoryNumber = Second(CurrentDate()) % 26;
#EndIf
		
		CodeLetterA = CharCode("A", 1); 
		DirectoryCode = CodeLetterA + DirectoryNumber;
		
		DirectoryLetter = Char(DirectoryCode);
		
		Subdirectory = ""; // Partial path.
		
		// Use the root directory by default. If it is impossible,
		// add A, B, ... Z,  A1, B1, ... Z1, ..,  A2, B2, and so on.
		If  Counter = 0 Then
			Subdirectory = "";
		Else
			Subdirectory = DirectoryLetter; 
			DoNumber = Round(Counter / 26);
			
			If DoNumber <> 0 Then
				DoNumberString = String(DoNumber);
				Subdirectory = Subdirectory + DoNumberString;
			EndIf;
			
			Subdirectory = CommonUseClientServer.AddFinalPathSeparator(Subdirectory);
		EndIf;
		
		FullSubdirectory = DirectoryName + Subdirectory;
		
		// Creating file directory
		DirectoryOnHardDisk = New File(FullSubdirectory);
		If Not DirectoryOnHardDisk.Exist() Then
			Try
				CreateDirectory(FullSubdirectory);
			Except
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Error creating
					           |directory %1: 
                   |%2.'"),
					FullSubdirectory,
					BriefErrorDescription(ErrorInfo()) );
			EndTry;
		EndIf;
		
		AttemptFile = FullSubdirectory + FileName;
		Counter = Counter + 1;
		
		// Checking whether the file name is unique
		FileOnHardDisk = New File(AttemptFile);
		If Not FileOnHardDisk.Exist() Then  // Unique
			FinalPath = Subdirectory + FileName;
			Done = True;
		EndIf;
	EndDo;
	
	Return FinalPath;
	
EndFunction

// Returns True if the file extension is in the extension list.
Function FileExtensionInList(ExtensionList, FileExtention) Export
	
	FileExtentionWithoutDot = CommonUseClientServer.ExtensionWithoutDot(FileExtention);
	
	ExtensionArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(
		Lower(ExtensionList), " ");
	
	If ExtensionArray.Find(FileExtentionWithoutDot) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks file extension and size.
Function CheckCanImportFile(File,
                            RaiseException = True,
                            ErrorFileNameArray = Undefined) Export
	
	CommonSettings = CommonFileOperationSettings();
	
	// The file is too big
	If File.Size() > CommonSettings.MaxFileSize Then
		
		SizeInMB     = File.Size() / (1024 * 1024);
		SizeInMBMax = CommonSettings.MaxFileSize / (1024 * 1024);
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The size of %1 file (%2 MB)
			           |exceeds the maximum size (%3 MB).'"),
			File.Name,
			GetStringWithFileSize(SizeInMB),
			GetStringWithFileSize(SizeInMBMax));
		
		If RaiseException Then
			Raise ErrorDescription;
		EndIf;
		
		Write = New Structure;
		Write.Insert("FileName", File.FullName);
		Write.Insert("Error",   ErrorDescription);
		
		ErrorFileNameArray.Add(Write);
		Return False;
	EndIf;
	
	// Checking file extension
	If Not CheckExtentionOfFileToDownload(File.Extension, False) Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Importing files with %1 extension is prohibited.
			           |Contact the application administrator.'"),
			File.Extension);
		
		If RaiseException Then
			Raise ErrorDescription;
		EndIf;
		
		Write = New Structure;
		Write.Insert("FileName", File.FullName);
		Write.Insert("Error",   ErrorDescription);
		
		ErrorFileNameArray.Add(Write);
		Return False;
	EndIf;
	
	// Temporary Word files are not imported
	If Left(File.Name, 1) = "~"
	   And File.GetHidden() = True Then
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns True if a file with a specified extension can be imported.
Function CheckExtentionOfFileToDownload(FileExtention, RaiseException = True) Export
	
	CommonSettings = CommonFileOperationSettings();
	
	If Not CommonSettings.ProhibitImportFilesByExtension Then
		Return True;
	EndIf;
	
	If FileExtensionInList(CommonSettings.ProhibitedFileExtensionList, FileExtention) Then
		
		If RaiseException Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Importing files with %1 extension is prohibited.
				           |Contact the application administrator.'"),
				FileExtention);
		Else
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Raises an exception if the file cannot be imported due to exceeding the maximum size.
Procedure CheckFileSizeForImport(File) Export
	
	CommonSettings = CommonFileOperationSettings();
	
	If TypeOf(File) = Type("File") Then
		Size = File.Size();
	Else
		Size = File.Size;
	EndIf;
	
	If Size > CommonSettings.MaxFileSize Then
	
		SizeInMB     = Size / (1024 * 1024);
		SizeInMBMax = CommonSettings.MaxFileSize / (1024 * 1024);
		
		If TypeOf(File) = Type("File") Then
			Name = File.Name;
		Else
			Name = CommonUseClientServer.GetNameWithExtension(
				File.FullDescr, File.Extension);
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The size of %1 file (%2 MB)
			           |exceeds the maximum size (%3 MB).'"),
			Name,
			GetStringWithFileSize(SizeInMB),
			GetStringWithFileSize(SizeInMBMax));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For user interface

// Returns a string with a message that a locked file cannot be signed.
//
Function FileUsedByAnotherProcessCannotBeSignedMessageString(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("en = 'Cannot sign a locked file.'");
	Else
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot sign locked file: %1.'"),
			String(FileRef) );
	EndIf;
	
EndFunction

// Returns a string with a message that an encrypted file cannot be signed.
//
Function EncryptedFileCannotBeSignedMessageString(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("en = 'Cannot sign an encrypted file.'");
	Else
		Return StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Cannot sign encrypted file: %1.'"),
						String(FileRef) );
	EndIf;
	
EndFunction

// Returns a message informing about a file creation error.
//
// Parameters:
//  ErrorInfo - ErrorInfo.
//
Function ErrorCreatingNewFile(ErrorInfo) Export
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Cannot create file.
		           |
		           |%1'"),
		BriefErrorDescription(ErrorInfo));

EndFunction

// Returns a standard error text.
Function ErrorFileNotFoundInFileStorage(FileName, SearchVolume = True) Export
	
	If SearchVolume Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot open file:
			           |%1.
			           |
			           |The file is not found in the file storage.
			           |The file was probably deleted by antivirus software.
			           |Contact the application administrator.'"),
			FileName);
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot open file:
			           |%1.
			           |
			           |The file is not found in the file storage.
			           |Contact the application administrator.'"),
			FileName);
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Gets a string with file size presentation.
// You can display the string in the Status field while file transfer is in progress.
Function GetStringWithFileSize(Val SizeInMB) Export
	
	If SizeInMB < 0.1 Then
		SizeInMB = 0.1;
	EndIf;	
	
	SizeString = ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0"));
	Return SizeString;
	
EndFunction	

// Gets a file icon index (the index in FileIconCollection picture).
Function GetFileIconIndex(Val FileExtention) Export
	
	If TypeOf(FileExtention) <> Type("String")
	 Or IsBlankString(FileExtention) Then
		
		Return 0;
	EndIf;
	
	FileExtention = CommonUseClientServer.ExtensionWithoutDot(FileExtention);
	
	Extension = "." + Lower(FileExtention) + ";";
	
	If Find(".dt;.1Cd;.cf;.cfu;", Extension) <> 0 Then
		Return 6; // 1C file
		
	ElsIf Extension = ".mxl;" Then
		Return 8; // Spreadsheet file
		
	ElsIf Find(".txt;.log;.ini;", Extension) <> 0 Then
		Return 10; // Text file
		
	ElsIf Extension = ".epf;" Then
		Return 12; //External data processor
		
	ElsIf Find(".ico;.wmf;.emf;",Extension) <> 0 Then
		Return 14; // Image
		
	ElsIf Find(".htm;.html;.url;.mht;.mhtml;",Extension) <> 0 Then
		Return 16; // HTML
		
	ElsIf Find(".doc;.dot;.rtf;",Extension) <> 0 Then
		Return 18; // Microsoft Word file
		
	ElsIf Find(".xls;.xlw;",Extension) <> 0 Then
		Return 20; // Microsoft Excel file
		
	ElsIf Find(".ppt;.pps;",Extension) <> 0 Then
		Return 22; // Microsoft PowerPoint file
		
	ElsIf Find(".vsd;",Extension) <> 0 Then
		Return 24; // Microsoft Visio file
		
	ElsIf Find(".mpp;",Extension) <> 0 Then
		Return 26; // Microsoft Project file
		
	ElsIf Find(".mdb;.adp;.mda;.mde;.ade;",Extension) <> 0 Then
		Return 28; // Microsoft Access database
		
	ElsIf Find(".xml;",Extension) <> 0 Then
		Return 30; // XML
		
	ElsIf Find(".msg;",Extension) <> 0 Then
		Return 32; // Email message
		
	ElsIf Find(".zip;.rar;.arj;.cab;.lzh;.ace;",Extension) <> 0 Then
		Return 34; // Archive
		
	ElsIf Find(".exe;.com;.bat;.cmd;",Extension) <> 0 Then
		Return 36; // Executable file
		
	ElsIf Find(".grs;",Extension) <> 0 Then
		Return 38; // Graphical schema
		
	ElsIf Find(".geo;",Extension) <> 0 Then
		Return 40; // Geographical schema
		
	ElsIf Find(".jpg;.jpeg;.jp2;.jpe;",Extension) <> 0 Then
		Return 42; // JPG
		
	ElsIf Find(".bmp;.dib;",Extension) <> 0 Then
		Return 44; // BMP
		
	ElsIf Find(".tif;.tiff;",Extension) <> 0 Then
		Return 46; // TIF
		
	ElsIf Find(".gif;",Extension) <> 0 Then
		Return 48; // GIF
		
	ElsIf Find(".png;",Extension) <> 0 Then
		Return 50; // PNG
		
	ElsIf Find(".pdf;",Extension) <> 0 Then
		Return 52; // PDF
		
	ElsIf Find(".odt;",Extension) <> 0 Then
		Return 54; // Open Office Writer
		
	ElsIf Find(".odf;",Extension) <> 0 Then
		Return 56; // Open Office Math
		
	ElsIf Find(".odp;",Extension) <> 0 Then
		Return 58; // Open Office Impress
		
	ElsIf Find(".odg;",Extension) <> 0 Then
		Return 60; // Open Office Draw
		
	ElsIf Find(".ods;",Extension) <> 0 Then
		Return 62; // Open Office Calc
		
	ElsIf Find(".mp3;",Extension) <> 0 Then
		Return 64;
		
	ElsIf Find(".erf;",Extension) <> 0 Then
		Return 66; // External reports
		
	ElsIf Find(".docx;",Extension) <> 0 Then
		Return 68; // Microsoft Word DOCX file
		
	ElsIf Find(".xlsx;",Extension) <> 0 Then
		Return 70; // Microsoft Excel XLSX file
		
	ElsIf Find(".pptx;",Extension) <> 0 Then
		Return 72; // Microsoft PowerPoint PPTX file
		
	ElsIf Find(".p7s;",Extension) <> 0 Then
		Return 74; // Signature file
		
	ElsIf Find(".p7m;",Extension) <> 0 Then
		Return 76; // Encrypted message
	Else
		Return 4;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other

// Removes files after importing.
Procedure DeleteFilesAfterAdd(AllFilesStructureArray, AllFoldersArray, ImportMode) Export
	
	For Each Item In AllFilesStructureArray Do
		SelectedFile = New File(Item.FileName);
		SelectedFile.SetReadOnly(False);
		DeleteFiles(SelectedFile.FullName);
	EndDo;
	
	If ImportMode Then
		For Each Item In AllFoldersArray Do
			FoundFiles = FindFiles(Item, "*.*");
			If FoundFiles.Count() = 0 Then
				SelectedFile = New File(Item);
				SelectedFile.SetReadOnly(False);
				DeleteFiles(SelectedFile.FullName);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure	

// Returns a file array, emulating the FindFiles method (searches the Map instead of the file system.
//  If PseudoFileSystem is empty, searches the real file system.
Function FindFilesPseudo(Val PseudoFileSystem, Path) Export
	
	If PseudoFileSystem.Count() = 0 Then
		Files = FindFiles(Path, "*.*");
		Return Files;
	EndIf;
	
	Files = New Array;
	
	ValueFound = PseudoFileSystem.Get(String(Path));
	If ValueFound <> Undefined Then
		For Each FileName In ValueFound Do
			Try
				FileFromList = New File(FileName);
				Files.Add(FileFromList);
			Except
			EndTry;
		EndDo;
	EndIf;
	
	Return Files;
	
EndFunction

// Attempts to map file names to data files and file signatures.
// The mapping is based on the signature name generation rule
// and signature file extension (p7s). 
// Example:
// Data file name:      example.txt
// Signature file name: example-Smith John.p7s
// Signature file name: example-Smith John (1).p7s
//
// Returns a map with the following fields:
// key   - file name.
// Value - array of found signature mappings.
// 
Function GetFileAndSignatureMap(FileNames, ExtensionForSignatureFiles) Export
	
	Result = New Map;
	
	// Dividing files by extension
	DataFileNames = New Array;
	SignatureFileNames = New Array;
	
	For Each FileName In FileNames Do
		If Right(FileName, 3) = ExtensionForSignatureFiles Then
			SignatureFileNames.Add(FileName);
		Else
			DataFileNames.Add(FileName);
		EndIf;
	EndDo;
	
	// Sorting data file names by their length in characters, descending
	
	For IndexA = 1 To DataFileNames.Count() Do
		IndexMAX = IndexA; // Considering the current file name to have the biggest number of characters
		For IndexB = IndexA+1 To DataFileNames.Count() Do
			If StrLen(DataFileNames[IndexMAX-1]) > StrLen(DataFileNames[IndexB-1]) Then
				IndexMAX = IndexB;
			EndIf;
		EndDo;
		swap = DataFileNames[IndexA-1];
		DataFileNames[IndexA-1] = DataFileNames[IndexMAX-1];
		DataFileNames[IndexMAX-1] = swap;
	EndDo;
	
	// Searching for file name mapping
	For Each DataFileName In DataFileNames Do
		Result.Insert(DataFileName, FindSignatureFileNames(DataFileName, SignatureFileNames));
	EndDo;
	
	// The remaining signature files are not recognized as signatures related to specific files
	For Each SignatureFileName In SignatureFileNames Do
		Result.Insert(SignatureFileName, New Array);
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Extracts text in the specified encoding.
// If the encoding is not set, determines the encoding automatically.
//
Function ExtractTextFromTextFile(FullFileName, Encoding, Cancel)
	
	ExtractedText = "";
	
#If Not WebClient Then
	
	// Determining encoding
	If Not ValueIsFilled(Encoding) Then
		Encoding = Undefined;
	EndIf;
	
	Try
		TextReader = New TextReader(FullFileName, Encoding);
		ExtractedText = TextReader.Read();
	Except
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extracts text from an OpenDocument file and returns it as a string.
//
Function ExtractOpenDocumentText(PathToFile, Cancel)
	
	ExtractedText = "";
	
#If Not WebClient Then
	
	TemporaryFolderForUnzipping = GetTempFileName("");
	TemporaryZIPFile = GetTempFileName("zip"); 
	
	FileCopy(PathToFile, TemporaryZIPFile);
	File = New File(TemporaryZIPFile);
	File.SetReadOnly(False);

	Try
		Archive = New ZipFileReader();
		Archive.Open(TemporaryZIPFile);
		Archive.ExtractAll(TemporaryFolderForUnzipping, ZIPRestoreFilePathsMode.Restore);
		Archive.Close();
		XMLReader = New XMLReader();
		
		XMLReader.OpenFile(TemporaryFolderForUnzipping + "/content.xml");
		ExtractedText = ExtractTextFromXMLContent(XMLReader);
		XMLReader.Close();
	Except
		// This is not an error because the OTF extension, for example, is related both to OpenDocument format and OpenType font format
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
	DeleteFiles(TemporaryFolderForUnzipping);
	DeleteFiles(TemporaryZIPFile);
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extracts text from an XMLReader object (which is read from an OpenDocument file).
Function ExtractTextFromXMLContent(XMLReader)
	
	ExtractedText = "";
	LastTagName = "";
	
#If Not WebClient Then
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			
			LastTagName = XMLReader.Name;
			
			If XMLReader.Name = "text:p" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:line-break" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:tab" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.Tab;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:s" Then
				
				SupplementString = " "; // Space
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.Name = "text:c"  Then
							SpaceCount = Number(XMLReader.Value);
							SupplementString = "";
							For Index = 0 To SpaceCount - 1 Do
								SupplementString = SupplementString + " "; // Space
							EndDo;
						EndIf;
					EndDo
				EndIf;
				
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + SupplementString;
				EndIf;
			EndIf;
			
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			
			If Find(LastTagName, "text:") <> 0 Then
				ExtractedText = ExtractedText + XMLReader.Value;
			EndIf;
			
		EndIf;
		
	EndDo;
	
#EndIf

	Return ExtractedText;
	
EndFunction	

Function FindSignatureFileNames(DataFileName, SignatureFileNames)
	
	SignatureNames = New Array;
	
	File = New File(DataFileName);
	BaseName = File.BaseName;
	
	For Each SignatureFileName In SignatureFileNames Do
		If Find(SignatureFileName, BaseName) > 0 Then
			SignatureNames.Add(SignatureFileName);
		EndIf;
	EndDo;
	
	For Each SignatureFileName In SignatureNames Do
		SignatureFileNames.Delete(SignatureFileNames.Find(SignatureFileName));
	EndDo;
	
	Return SignatureNames;
	
EndFunction

#EndRegion
