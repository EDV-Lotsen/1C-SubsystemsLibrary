

//////////////////////////////////////////////////////////////////////////////////
//// Client procedures of common use

// Suggests to user to install the extension of work with files in web-client.
// At the same time initializing session parameter SuggestWorkWithFilesExtensionInstallationByDefault.
//
// Procedure is designated to be used in the beginning of code locks, where work with files is performed.
// For example:
//
//    SuggestWorkWithFilesExtensionInstallationNow("For document printing extension of work with files has to be installed");
//    // below document print code is located
//    //...
//
// Parameters
//  Message  - String - message text. If not specified, then default text being shown.
//
Procedure SuggestWorkWithFilesExtensionInstallationNow(Message = Undefined) Export
	
#If Not WebClient Then
	Return;  // works only in web-client
#EndIf

	IsExtensionAttached = AttachFileSystemExtension();
	If IsExtensionAttached Then
		Return; // if extension already installed - no reason to ask about it
	EndIf;	

	If _DemoCommonUseClientCashed.ThisIsWebClientWithoutSupportOfWorkWithFilesExtension() Then
		Return;
	EndIf;	
	
	SuggestInstallation = _DemoCommonUseClientCashed.GetOfferInstallationOfExtensionOfWorkWithFiles();
	
	If SuggestInstallation = False Then
		Return;
	EndIf;
	
	// show dialog here
	FormParameters  = New Structure("Message", Message);
	ReturnCode 		= OpenFormModal("CommonForm.FileSystemExtensionInstallationQuestion", FormParameters);
	If ReturnCode 	= Undefined Then
		ReturnCode  = True;
	EndIf;
	
	SuggestInstallation = ReturnCode;
	_DemoCommonUse.SaveSuggestWorkWithFilesExtensionInstallation(SuggestInstallation);
	RefreshReusableValues();

EndProcedure 

