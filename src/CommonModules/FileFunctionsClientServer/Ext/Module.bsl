// Searches for the last dot and returns the string after it. Useful to get a file
// name extension.
//
// Parameters:
//  FileName - String - a file name, full or base, but with an extension.
//
// Returns: 
//  String - a file name extension, if no dots found the source string will be returned.
//
Function GetFileExtension(FileName) Export
	Splitted = StrReplace(FileName,".",Chars.LF);
	Occurences = StrOccurrenceCount(Splitted, Chars.LF);
	Return StrGetLine(Splitted, Occurences+1);
EndFunction

// Extracts file name with extension from the full file name.
//
// Parameters:
//  FileName - String - a file name, full or base, but with an extension.
//
// Returns: 
//  String - a file name with extension.
//
Function GetFileName(FileName) Export
	File = New File(FileName);
	Return File.Name;
EndFunction

// Searches for the last slash and returns the string after it till the last dot. 
// Useful to extract the base file name (without an extension) from the full file name.
//
// Parameters:
//  FileName - String - a file name, full or partial, but with a base name.
//
// Returns: 
//  String - a base file name, if no slashes found the source string will be returned.
//
Function GetBaseName(FileName) Export
	Result = "";
	Length = StrLen(FileName);
	Start = 1;
	End = Length;
	For I = 1 To Length Do
		Char = Mid(FileName, I, 1);
		If Char = "\" Or Char = "/" Then
			Start = I+1;
		ElsIf Char = "." Then
			End = I-1;
		EndIf;
	EndDo;
	If End <= Start Or Start > Length Or End < 1 Then
		Return FileName;
	EndIf;
	Return Mid(FileName, Start, End - Start+1);
EndFunction

// Searches for the last slash and returns the string before it. 
// Useful to extract the directory from the full file name.
//
// Parameters:
//  FileName - String - a file name, full or partial, but with a base name.
//
// Returns: 
//  String - a directory path, if no slashes found the source string will be returned.
//
Function GetDirectory(FileName) Export
	Result = "";
	Length = StrLen(FileName);
	End = Length;
	For I = 1 To Length Do
		Char = Mid(FileName, I, 1);
		If Char = "\" Or Char = "/" Then
			End = I-1;
		EndIf;
	EndDo;
	Return Left(FileName, End);
EndFunction

// Defines by a file name extension if the file is a picture or not.
//
// Parameters:
//  FileName - String - a file name, full or partial, but with an extension.
//
// Returns: 
//  True - if the file is a picture and False - otherwise.
//
Function IsPicture(FileName) Export 
	Result = False;
	If Not IsBlankString(FileName) Then
		Extension = Lower(FileFunctionsClientServer.GetFileExtension(FileName));
		If Not IsBlankString(Extension) Then
			If Extension = "gif"
			   Or Extension = "jpg"
			   Or Extension = "jpeg"
			   Or Extension = "png"       
			   Or Extension = "bmp"
			   Or Extension = "tif"
			   Or Extension = "tiff"
			   Or Extension = "xbm" Then
			    Result = True;
			EndIf;
		EndIf;
	EndIf;
	Return Result;
EndFunction

// Defines by a file name extension if the file is supported and can be handled in Texts catalog.
//
// Parameters:
//  FileName - String - a file name, full or partial, but with an extension.
//
// Returns: 
//  True - if the file is a supported file and False - otherwise.
//
Function IsSupportedAsText(FileName) Export 
	Result = False;
	If Not IsBlankString(FileName) Then
		Extension = Lower(FileFunctionsClientServer.GetFileExtension(FileName));
		If Not IsBlankString(Extension) Then
			If Extension = "xml"
			   Or Extension = "xsd"
			   Or Extension = "txt"
			   Or Extension = "html"
			   Or Extension = "htm" Then
			    Result = True;
			EndIf;
		EndIf;
	EndIf;
	Return Result;
EndFunction

