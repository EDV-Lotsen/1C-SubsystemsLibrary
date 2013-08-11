
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InfoBasePrefix = GetFunctionalOption("InfoBasePrefix");
	
	InfoBasePrefixSet = Not  IsBlankString(InfoBasePrefix);
	
	Items.Pages.CurrentPage  = ?(InfoBasePrefixSet,
						Items.InfoBasePrefixDisplayingPage,
						Items.EmptyPrefixNotificationPage);
	//
	
EndProcedure
