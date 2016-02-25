// The form is parameterized:
//
//      Title        - String  - form header 
//      FieldValues  - String  - serialized contact information value, or empty string used
//                               to enter new contact information value 
//      Presentation - String  - address presentation (used only when working with old data) 
//      ContactInformationKind - CatalogRef.ContactInformationKinds, Structure - description of
//                               information to be edited 
//      Comment      - String  - comment to be placed in the Comment field, optional
//
//      ReturnValueList - Boolean - flag specifying that the returned ContactInformation value 
//                                  has ValueList type (for compatibility purposes), optional
//
//  Selection result:
//      Structure - fields:
//          * ContactInformation - String - Contact information XML string 
//          * Presentation       - String - Presentation
//          * Comment            - String - Comment
//
// -------------------------------------------------------------------------------------------------

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Parameters.Property("ReturnValueList", ReturnValueList);
	
	// Copying parameters to attributes
	ContactInformationKind = Parameters.ContactInformationKind;
	ContactInformationType = ContactInformationKind.Type;
	
	CheckValidity      = ContactInformationKind.CheckValidity;
	ProhibitInvalidEntry = ContactInformationKind.ProhibitInvalidEntry;
	
	Title = ?(IsBlankString(Parameters.Title), String(ContactInformationKind), Parameters.Title);
	
	If ContactInformationClientServer.IsXMLString(Parameters.FieldValues) Then
		ReadResults = New Structure;
		XDTOContactInfo = ContactInformationInternal.ContactInformationDeserialization(Parameters.FieldValues, ContactInformationType, ReadResults);
		If ReadResults.Property("ErrorText") Then
			// Recognition errors encountered, will display warning on open
			WarningTextOnOpen = ReadResults.ErrorText;
			XDTOContactInfo.Presentation   = Parameters.Presentation;
		EndIf;
		
	ElsIf ContactInformationType = Enums.ContactInformationTypes.Phone Then
		XDTOContactInfo = ContactInformationInternal.PhoneDeserialization(Parameters.FieldValues, Parameters.Presentation, ContactInformationType);
		
	Else
		XDTOContactInfo = ContactInformationInternal.FaxDeserialization(Parameters.FieldValues, Parameters.Presentation, ContactInformationType);
		
	EndIf;
	
	If Parameters.Comment <> Undefined Then
		ContactInformationInternal.ContactInformationComment(XDTOContactInfo, Parameters.Comment);
	EndIf;
	
	ContactInformationAttibuteValues(XDTOContactInfo);
	
	// Content of the All actions command group depends on interface selection
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.FormAllActions.Visible = False;
	Else
		Items.ClearPhone.Visible    = False;
		Items.CustomizeForm.Visible = False;
	EndIf;
		
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCommentIcon();

	If Not IsBlankString(WarningTextOnOpen) Then
		AttachIdleHandler("Attachable_WarningOnFormOpen", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CountryCodeOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure AreaCodeOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure PhoneNumberOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure ExtensionOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	SetCommentIcon();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKCommand(Command)
	ConfirmAndClose();
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure ClearPhone(Command)
	
	ClearPhoneServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure Attachable_WarningOnFormOpen()
	
	CommonUseClientServer.MessageToUser(WarningTextOnOpen);
	
EndProcedure

&AtClient
Procedure SetCommentIcon()
	
	If IsBlankString(Comment) Then
		Items.PhonePageComment.Picture = New Picture;
	Else
		Items.PhonePageComment.Picture = PictureLib.Comment;
	EndIf;
		
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	// If data was not modified, emulates Cancel command
	
	If Modified Then
		// Address value modified 
		
		HasFillingErrors = False;
		// Determining whether validity check is necessary.
		If CheckValidity Then
			ErrorList = PhoneFillErrorsServer();
			HasFillingErrors = ErrorList.Count()>0;
		EndIf;
		If HasFillingErrors Then
			NotifyFillErrors(ErrorList);
			If ProhibitInvalidEntry Then
				Return;
			EndIf;
		EndIf;
		Result = ChoiceResult();
		
		ClearModifiedOnChoice();
		NotifyChoice(Result);
		
	ElsIf Comment<>CommentCopy Then
		// Only comment was modified, attempting to revert
		Result = CommentChoiceOnlyResult();
		
		ClearModifiedOnChoice();
		NotifyChoice(Result);
		
	Else
		Result = Undefined;
		
	EndIf;
	
	If (ModalMode Or CloseOnChoice) And IsOpen() Then
		ClearModifiedOnChoice();
		Close(Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearModifiedOnChoice()
	
	Modified = False;
	CommentCopy   = Comment;
	
EndProcedure

&AtServer
Function ChoiceResult()
	XDTOInformation = ContactInformationByAttributeValues();
	
	If ReturnValueList Then
		ChoiceData = ContactInformationInternal.ContactInformationToOldStructure(XDTOInformation);
		ChoiceData = ChoiceData.FieldValues;
	Else
		ChoiceData = ContactInformationInternal.ContactInformationSerialization(XDTOInformation);
	EndIf;
		
	Return New Structure("ContactInformation, Presentation, Comment",
		ChoiceData,
		XDTOInformation.Presentation, 
		XDTOInformation.Comment);
EndFunction

&AtServer
Function CommentChoiceOnlyResult()
	
	ContactInfo = Parameters.FieldValues;
	If IsBlankString(ContactInfo) Then
		If ContactInformationType=Enums.ContactInformationTypes.Phone Then
			ContactInfo = ContactInformationInternal.PhoneDeserialization("", "", ContactInformationType);
		Else
			ContactInfo = ContactInformationInternal.FaxDeserialization("", "", ContactInformationType);
		EndIf;
		ContactInformationInternal.ContactInformationComment(ContactInfo, Comment);
		ContactInfo = ContactInformationInternal.ContactInformationSerialization(ContactInfo);
		
	ElsIf ContactInformationClientServer.IsXMLContactInformation(ContactInfo) Then
		ContactInformationInternal.ContactInformationComment(ContactInfo, Comment);
	EndIf;
	
	Return New Structure("ContactInformation, Presentation, Comment",
		ContactInfo, Parameters.Presentation, Comment);
EndFunction

// Fills form attributes based on XTDO object of Contact information type
&AtServer
Procedure ContactInformationAttibuteValues(InformationToEdit)
	
	Phone = InformationToEdit.Content;
	
	// Common attributes
	Presentation = InformationToEdit.Presentation;
	Comment   = InformationToEdit.Comment;
	
	// Comment copy used to identify data modifications
	CommentCopy = Comment;
	
	CountryCode     = Phone.CountryCode;
	AreaCode     = Phone.AreaCode;
	PhoneNumber = Phone.Number;
	Extension    = Phone.Extension;
	
EndProcedure

// Returns XTDO object of Contact information type based on attribute values
&AtServer
Function ContactInformationByAttributeValues()
	Namespace = ContactInformationClientServerCached.Namespace();
	
	Result = XDTOFactory.Create( XDTOFactory.Type(Namespace, "ContactInformation") );
	
	If ContactInformationType=Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create( XDTOFactory.Type(Namespace, "PhoneNumber") );
		Data.CountryCode    = CountryCode;
		Data.AreaCode       = AreaCode;
		Data.Number         = PhoneNumber;
		Data.Extension      = Extension;
		Result.Presentation = ContactInformationInternal.PhonePresentation(Data);
	Else        
		Data = XDTOFactory.Create( XDTOFactory.Type(Namespace, "FaxNumber") );
		Data.CountryCode    = CountryCode;
		Data.AreaCode       = AreaCode;
		Data.Number         = PhoneNumber;
		Data.Extension      = Extension;
		Result.Presentation = ContactInformationInternal.FaxPresentation(Data);
	EndIf;
	
	Result.Content = Data;
	Result.Comment = Comment;
	
	Return Result;
EndFunction

&AtServer
Procedure FillPhonePresentation(XDTOContactInfo=Undefined)
	Info = ?(XDTOContactInfo=Undefined, ContactInformationByAttributeValues(), XDTOContactInfo);
	Presentation = Info.Presentation;
EndProcedure    

// Returns list of filling errors in value list format:
//      Presentation - error description 
//      Value        - XPath for field
&AtServer
Function PhoneFillErrorsServer() 
	Return New ValueList();
EndFunction    

// Notifies of any filling errors based on PhoneFillErrorsServer function results
&AtClient
Procedure NotifyFillErrors(ErrorList)
	
	If ErrorList.Count()=0 Then
		ShowMessageBox(, NStr("en='Valid phone number entered.'"));
		Return;
	EndIf;
	
	ClearMessages();
	
	// Value - XPath, presentation - error description
	For Each Item In ErrorList Do
		CommonUseClientServer.MessageToUser(Item.Presentation,,,
		PathToFormDataByXPath(Item.Value));
	EndDo;
	
EndProcedure    

&AtClient 
Function PathToFormDataByXPath(XPath) 
	Return XPath;
EndFunction

&AtServer
Procedure ClearPhoneServer()
	CountryCode     = "";
	AreaCode     = "";
	PhoneNumber = "";
	Extension    = "";
	Comment   = "";
	
	FillPhonePresentation();
	Modified = True;
EndProcedure


#EndRegion