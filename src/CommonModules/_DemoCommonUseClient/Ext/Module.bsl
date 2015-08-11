

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
Procedure SuggestWorkWithFilesExtensionInstallationNow(Val Notification1, Val Notification, Message = Undefined) Export
	
#If Not WebClient Then
	ExecuteNotifyProcessing(Notification);
	ExecuteNotifyProcessing(Notification1);
	Return;  // works only in web-client
#EndIf

	IsExtensionAttached = AttachFileSystemExtension();
	If IsExtensionAttached Then
		ExecuteNotifyProcessing(Notification);
		ExecuteNotifyProcessing(Notification1);
		Return; // if extension already installed - no reason to ask about it
	EndIf;	

	If _DemoCommonUseClientCashed.ThisIsWebClientWithoutSupportOfWorkWithFilesExtension() Then
		ExecuteNotifyProcessing(Notification);
		ExecuteNotifyProcessing(Notification1);
		Return;
	EndIf;	
	
	SuggestInstallation = _DemoCommonUseClientCashed.GetOfferInstallationOfExtensionOfWorkWithFiles();
	
	If SuggestInstallation = False Then
		ExecuteNotifyProcessing(Notification);
		ExecuteNotifyProcessing(Notification1);
		Return;
	EndIf;
	
	// show dialog here
	FormParameters  = New Structure("Message", Message);
	ReturnCode = Undefined;

	OpenForm("CommonForm.FileSystemExtensionInstallationQuestion", FormParameters,,,,, New NotifyDescription("SuggestWorkWithFilesExtensionInstallationNowEnd", ThisObject, New Structure("Notification, Notification1", Notification, Notification1)), FormWindowOpeningMode.LockWholeInterface);

EndProcedure

Procedure SuggestWorkWithFilesExtensionInstallationNowEnd(Result, AdditionalParameters) Export
	
	Notification = AdditionalParameters.Notification;
	Notification1 = AdditionalParameters.Notification1;
	
	
	ReturnCode 		= Result;
	If ReturnCode 	= Undefined Then
		ReturnCode  = True;
	EndIf;
	
	SuggestInstallation = ReturnCode;
	_DemoCommonUse.SaveSuggestWorkWithFilesExtensionInstallation(SuggestInstallation);
	RefreshReusableValues();
	
	ExecuteNotifyProcessing(Notification);
	
	ExecuteNotifyProcessing(Notification1);
	
EndProcedure
 

