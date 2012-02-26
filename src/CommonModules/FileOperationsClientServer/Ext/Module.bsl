
////////////////////////////////////////////////////////////////////////////////
// Procedures module, executed at server and at client

// Determines, if file can be taken, and if not - generates error string
Function CanLockFile(FileData, ErrorString = "") Export
	
	If FileData.DeletionMark = True Then
		ErrorString =
		StringFunctionsClientServer.SubstitureParametersInString(
		  NStr("en = 'Can not lock %1 file because it is marked for deletion.'"),
		  String(FileData.Ref));
		Return False;
	EndIf;
	
	
	If FileData.LockedBy.IsEmpty() Or FileData.LockedByCurrentUser Then 
		
		Return True;
		
	Else
		
		ErrorString = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = '%1 file is already locked for editing by the %2 user.'"),
			String(FileData.Ref), String(FileData.LockedBy));
		Return False;
		
	EndIf;
	
EndFunction

// Returns True, if in file or directory name all chars are valid (i.e. folder with such name can be created on disk)
Function FolderOrFileNameConsistsOfValidCharsForFileSystem(FolderName) Export
	
	If Find(FolderName, "/") > 0 Then
		Return False;
	EndIf;
	
	If Find(FolderName, ":") > 0 Then
		Return False;
	EndIf;
		
	If Find(FolderName, "?") > 0 Then
		Return False;
	EndIf;

	If Find(FolderName, "\") > 0 Then
		Return False;
	EndIf;
		
	If Find(FolderName, "|") > 0 Then
		Return False;
	EndIf;
		
	If Find(FolderName, "*") > 0 Then
		Return False;
	EndIf;
		
	If Find(FolderName, """") > 0 Then
		Return False;
	EndIf;
		
	If Find(FolderName, "<") > 0 Then
		Return False;
	EndIf;
		
	If Find(FolderName, ">") > 0 Then
		Return False;
	EndIf;

	If Find(FolderName, "..\") > 0 Then
		Return False;
	EndIf;

	If Find(FolderName, "../") > 0 Then
		Return False;
	EndIf;
	
	If FolderName = "." Then
		Return False;
	EndIf;

	If FolderName = ".." Then
		Return False;
	EndIf;

	Return True;		
EndFunction	

// Get file pictogram index - index in the picture FileIcons
Function GetFilePictogramIndex(Val FileExtensionOnlyText) Export
	
	If FileExtensionOnlyText = Undefined Then
		Return 0;
	EndIf;		
	
	FileExtensionWithoutDot = FileExtensionOnlyText;
	
	If Left(FileExtensionWithoutDot, 1) = "." Then
		FileExtensionWithoutDot = Mid(FileExtensionWithoutDot, 2);
	EndIf;
	
	Extension = "." + Lower(FileExtensionWithoutDot) + ";";
	
	If Find(".dt;.1cd;.cf;.cfu;",Extension) 				<> 0 Then
		Return 6; //Files 1C
	ElsIf Extension 										= ".mxl;" Then
		Return 8; //Spreadsheet File
	ElsIf Find(".txt;.log;.ini;",Extension) 				<> 0 Then
		Return 10; // Text File
	ElsIf Extension 										= ".epf;" Then
		Return 12; //External data processors
	ElsIf Find(".ico;.wmf;.emf;",Extension) 				<> 0 Then
		Return 14; // Pictures
	ElsIf Find(".htm;.html;.url;.mht;.mhtml;",Extension) 	<> 0 Then
		Return 16; // HTML
	ElsIf Find(".doc;.dot;.rtf;.docx;",Extension) 			<> 0 Then
		Return 18; // Microsoft Word File
	ElsIf Find(".xls;.xlw;.xlsx;",Extension) 				<> 0 Then
		Return 20; // Microsoft Excel File
	ElsIf Find(".ppt;.pptx;.pps;",Extension) 				<> 0 Then
		Return 22; // Microsoft PowerPoint File
	ElsIf Find(".vsd;",Extension) 							<> 0 Then
		Return 24; // Microsoft Visio File
	ElsIf Find(".mpp;",Extension) 							<> 0 Then
		Return 26; // Microsoft Visio File
	ElsIf Find(".mdb;.adp;.mda;.mde;.ade;",Extension) 		<> 0 Then
		Return 28; // Microsoft Access databases
	ElsIf Find(".xml;",Extension)							<> 0 Then
		Return 30; // xml
	ElsIf Find(".msg;",Extension) 							<> 0 Then
		Return 32; // Email message
	ElsIf Find(".zip;.rar;.arj;.cab;.lzh;.ace;",Extension)  <> 0 Then
		Return 34; // Archives
	ElsIf Find(".exe;.com;.bat;.cmd;",Extension) 			<> 0 Then
		Return 36; // Executable files
	ElsIf Find(".grs;",Extension) 							<> 0 Then
		Return 38; // Graphic scheme
	ElsIf Find(".geo;",Extension) 							<> 0 Then
		Return 40; // Geographic scheme
	ElsIf Find(".jpg;.jpeg;.jp2;.jpe;",Extension) 			<> 0 Then
		Return 42; // jpg
	ElsIf Find(".bmp;.dib;",Extension) 						<> 0 Then
		Return 44; // bmp
	ElsIf Find(".tif;",Extension)							<> 0 Then
		Return 46; // tif
	ElsIf Find(".gif;",Extension) 							<> 0 Then
		Return 48; // gif
	ElsIf Find(".png;",Extension) 							<> 0 Then
		Return 50; // png
	ElsIf Find(".pdf;",Extension) 							<> 0 Then
		Return 52; // pdf
	ElsIf Find(".odt;",Extension) 							<> 0 Then
		Return 54; // Open Office writer
	ElsIf Find(".odf;",Extension) 							<> 0 Then
		Return 56; // Open Office math
	ElsIf Find(".odp;",Extension) 							<> 0 Then
		Return 58; // Open Office Impress
	ElsIf Find(".odg;",Extension) 							<> 0 Then
		Return 60; // Open Office draw
	ElsIf Find(".ods;",Extension) 							<> 0 Then
		Return 62; // Open Office calc
	ElsIf Find(".mp3;",Extension) 							<> 0 Then
		Return 64;
	ElsIf Find(".erf;",Extension) 							<> 0 Then
		Return 66; // External reports
	Else
		Return 4;
	EndIf;
	
EndFunction 

// Returns True, if file with such extension can be loaded
Function FileExtensionAllowedForLoad(ProhibitFileLoadByExtension, ProhibitedExtensionsList, FileExtension) Export
	If ProhibitFileLoadByExtension = False Then
    	Return True;
	EndIf;
	
	FileExtensionWithoutDot = FileExtension;
	
	If Left(FileExtensionWithoutDot, 1) = "." Then
		FileExtensionWithoutDot = Mid(FileExtensionWithoutDot, 2);
	EndIf;
	
	Extension = Lower(FileExtensionWithoutDot);
	ProhibitedExtensionsListLowerRegister = Lower(ProhibitedExtensionsList);
	
	If Find(ProhibitedExtensionsListLowerRegister, Extension) <> 0 Then
		Return False;
	EndIf;
	
	Return True;
EndFunction // FileExtensionAllowedForLoad()
