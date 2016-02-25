////////////////////////////////////////////////////////////////////////////////
// Companies subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"CompaniesInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillMetadataObjectAccessRestrictionKinds"].Add(
			"CompaniesInternal");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessKinds"].Add(
			"CompaniesInternal");
	EndIf;
	
EndProcedure

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of the NewUpdateHandlerTable 
//                          function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.16";
	Handler.InitialFilling = True;
	Handler.Procedure = "CompaniesInternal.UpdateCompanyContactInfoPredefinedTypes";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.12";
	Handler.InitialFilling = True;
	Handler.Procedure = "Catalogs.Companies.FillConstantUseSeveralCompanies";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SL event handlers

// Fills the list of access kinds that are used to set metadata object right restrictions.
// If the access type content is not filled, the Access rights report will display 
// incorrect data.
//
// It is required to fill only access types that are explicitly used
// in access restriction templates, while access types used in access value sets can
// be obtained from the current state of the AccessValueSets data registry.
//
// To generate the procedure script automatically, it is recommended that you use the developer
// tools from the Access management subsystem.
//
// Parameters:
//  Details - String, multiline string of following format:
//            <Table>.<Right>.<AccessKind>[.Object table] 
//            For example,
//                 Document.IncomingInvoice.Read.Companies 
//                 Document.IncomingInvoice.Read.Counterparties
//                 Document.IncomingInvoice.Update.Companies
//                 Document.IncomingInvoice.Update.Counterparties
//                 Document.EmailMessages.Read.Object.Document.EmailMessages
//                 Document.EmailMessages.Update.Object.Document.EmailMessages
//                 Document.Files.Read.Object.Catalog.FileFolders 
//                 Document.Files.Read.Object.Document.EmailMessage
//                 Document.Files.Update.Object.Catalog.FileFolders 
//                 Document.Files.Update.Object.Document.EmailMessage 
//            The Object access type is not defined as a literal. It is not listed in
//            predefined items of CharacteristicTypeCharts.AccessKinds. This access kind is
//            used in access restriction templates as a reference to another object used to
//            apply a restriction to the table.
//            When the Object access type is set, you must also set the table types
//            to be used for this access type, i.e. list the type - field associations
//            that correspond to the fields listed in the access restriction template, 
//            together with the Object access type. 
//            In enumerating the types of Object access types, only those field types
//            should be listed that the DataRegistries.AccessValueSets.Object field 
//            has, and other types are superfluous.
// 
Procedure OnFillMetadataObjectAccessRestrictionKinds(Details) Export
	
	
	
EndProcedure

// Fills access types that are used in access restrictions.
// Users and ExternalUsers access kinds are already filled.
// They can be deleted if they are not used in access restrictions.
//
// Parameters:
//  AccessKinds - ValueTable with fields:
//  - Name               - String - name used in definitions of supplied access group profiles
//                         and in RLS texts.
//  - Presentation       - String - access kind presentation in profiles and access groups.
//  - ValueType          - Type - access value reference type For example, 
///                        Type("CatalogRef.ProductsAndServices").
//  - ValueGroupType     - Type - access value group reference type. For example,
//                         Type("CatalogRef.ProductsAndServicesAccessGroups").
//  - MultipleValueGroups - Boolean - The truth is that for
//                         the access value (products and services), it is possible to 
//                         select several value groups (products and services access groups)
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "Companies";
	AccessKind.Presentation = NStr("en = 'Companies'");
	AccessKind.ValueType    = Type("CatalogRef.Companies");
	
EndProcedure

// The procedure is called on update to SL version 2.1.3.16
//
Procedure UpdateCompanyContactInfoPredefinedTypes() Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	CheckAddressesParameters = New Structure;
	CheckAddressesParameters.Insert("DomesticAddressOnly",       True);
	CheckAddressesParameters.Insert("CheckValidity",                False);
	CheckAddressesParameters.Insert("ProhibitInvalidEntry",         False);
	CheckAddressesParameters.Insert("HideObsoleteAddresses",        False);
	CheckAddressesParameters.Insert("IncludeCountryInPresentation", False);
	
	CIModule = CommonUse.CommonModule("ContactInformationManagement");
	
	CIModule.RefreshContactInformationKind("CompanyLegalAddress", "Address", NStr("en='Company legal address'"),
		True, False, False, 1, , CheckAddressesParameters);
		
	CIModule.RefreshContactInformationKind("CompanyActualAddress", "Address", NStr("en='Company physical address'"),
		True, False, False, 2);
		
	CIModule.RefreshContactInformationKind("CompanyPhone", "Phone", NStr("en='Company phone'"),
		True, False, False, 3, True);
		
	CIModule.RefreshContactInformationKind("CompanyFax", "Fax", NStr("en='Company fax'"),
		True, False, False, 4, True);
		
	CIModule.RefreshContactInformationKind("CompanyEmail", "EmailAddress", NStr("en='Company email'"),
		True, False, False, 5, True);
		
	CIModule.RefreshContactInformationKind("CompanyPostalAddress", "Address", NStr("en='Company postal address'"),
		True, False, False, 6);
		
	CIModule.RefreshContactInformationKind("CompanyOtherInformation", "Other", NStr("en='Other contact information'"),
		True, False, False, 7);
	
EndProcedure

// The subscription handler for the CheckUseSeveralCompaniesOptionValue event.
// is called on writing a Companies catalog element.
//
Procedure CheckUseSeveralCompaniesOptionValueOnWrite(Source, Cancel) Export
	
	If Not Source.IsFolder
		And Not GetFunctionalOption("UseSeveralCompanies")
		And Catalogs.Companies.CompaniesCount() > 1 Then
		
		SetPrivilegedMode(True);
		Constants.UseSeveralCompanies.Set(True);
		SetPrivilegedMode(False);
		
	EndIf;
	
EndProcedure

#EndRegion