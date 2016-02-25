////////////////////////////////////////////////////////////////////////////////
// Item order setup subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// See the function in the ItemOrderSetupInternal module.
Function ChangeItemOrder(Ref, DynamicList, ListView, Direction) Export
	
	Return ItemOrderSetupInternal.ChangeItemOrder(
		Ref, DynamicList, ListView, Direction);
	
EndFunction

#EndRegion
