////////////////////////////////////////////////////////////////////////////////
// Address classifier subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Checks web server for address classifier updates 
// for previously downloaded objects.
//
// Returns - Array - Contains structures with fields:
//     * AddressObjectCode - String - Address object code
//     * Description       - String - Address object description
//     * Abbreviation      - String - Address object abbreviation
//     * PostalCode        - String - Address object ZIP/postal code
//     * UpdateAvailable   - Boolean
//
Function CheckForAddressObjectUpdatesServer() Export
	
	Return AddressClassifierClientServer.CheckForAddressObjectUpdates();
	
EndFunction

// Returns the address object version saved during the latest update
// If no address object record found, returns 09/01/2008
// 
// Returns:
//     Array - Containg mapping where key - address object number, 
//                                    value - version release date
//
Function AddressObjectVersions() Export
	
	Return AddressClassifier.AddressObjectVersions();
	
EndFunction

// Returns a structure containing address object data
// 
// Parameters:
//     AddressObjectCode - String - Address object number in range from 1 to 89 + 99 in NN format
//
// Returns:
//     Structure - Address object description including fields:
//         * AddressObjectCode - String - Address object code.
//         * Description       - String - Address object description.
//         * Abbreviation      - String - Address object abbreviation.
//         * PostalCode        - String - ZIP/postal code.
//
Function AddressObjectInformation(AddressObjectCode) Export
	
	Return AddressClassifier.AddressObjectInformation(AddressObjectCode);
	
EndFunction

// Reads the address object version file
// and returns address object data versions
//
// Parameters:
//     XMLText - String - String containing text in XML format.
//
// Returns:
//    Map - Version file description: Key - String - address object, 
//     Value - Date - address object expiration date.
//
Function GetAddressDataVersions(XMLText) Export
	
	Return AddressClassifier.GetAddressDataVersions(XMLText);
	
EndFunction

// Data needed for security profile permissions query for address classifier update 
// checks at 1C website
//
// Returns:
//     Array - required permission IDs
// 
Function AddressClassifierUpdateCheckSecurityPermissionsQuery() Export
	
	PermissionOwner = CommonUse.MetadataObjectID("InformationRegister.AddressClassifier"); 
	Permissions     = AddressClassifier.UpdateCheckSecurityPermissions();
	
	Result = New Array;
	Result.Add(
		SafeMode.RequestToUseExternalResources(Permissions, PermissionOwner, True)
	);
	
	Return Result;
EndFunction

// Returns a flag that allows to import or clear the address classifier
//
Function CanChangeAddressClassifier() Export
	
	Return Not CommonUseCached.DataSeparationEnabled();
	
EndFunction

#EndRegion
