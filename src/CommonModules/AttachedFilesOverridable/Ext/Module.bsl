////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Overrides file storage catalogs by owner type.
// 
// Parameters:
//  FileOwnerType - Type - object reference type to which to append the file.
//
//  CatalogNames  - Map - where keys contain catalog names.
//                        To override the catalog name, pass
//                        the name and mark it as a default one.
//                        The default catalog
//                        is used for user interaction. To specify
//                        the default catalog, set the map value to True.
//                        The algorithm implies that only one value is True.
//
Procedure OnDefineFileStoringCatalogs(FileOwnerType, CatalogNames) Export
	
EndProcedure

#EndRegion
