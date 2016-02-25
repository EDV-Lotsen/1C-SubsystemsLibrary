////////////////////////////////////////////////////////////////////////////////
// Information center subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Retrieves the link to the information being searched.
// For example, a link to the 1c-dn.com site.
//
// Parameters:
//  InformationSearchLink - String - URL.
//
// Comment:
// 	The procedure should implement the following algorithm:
// 	If one adds a search string to the link and then goes to the result URL,
// 	the search window must be activated.
//
Procedure GetInformationSearchLink(InformationSearchLink) Export
	
EndProcedure
