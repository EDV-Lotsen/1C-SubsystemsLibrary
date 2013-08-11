////////////////////////////////////////////////////////////////////////////////
//Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// The infobase update handler for the Contact information kind catalog.
//
// Instruction:
// For each contact information owner object and contact information kind pair,
// add the following line: 
// ContactInformationManagement.UpdateCIKind(.....)
//
// ContactInformationManagement.UpdateCIKind function parameters:
// CIKind - reference to the predefined contact information kind.
// CIType - reference to the ContactInformationTypes enumeration.
// CanChangeEditMode - flag that shows whether the edit mode can be changed in
// the 1C:Enterprise mode.
// For example, editing addresses that are used in tax reports must be prohibited.
// EditInDialogOnly - flag that shows whether the contact information kind will be 
// edited in the input form only (is used only for addresses, phones, and faxes).
// HomeCountryAddressOnly - flag that shows whether only a home country address 
// (in this configuration it is an address in the United States) can be entered (is used only for addresses).
// Order - item order on the form.
//
Procedure ContactInformationInfoBaseUpdate() Export
	
	// StandardSubsystems
	
	// The Users catalog
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.UserEmail, 		Enums.ContactInformationTypes.EmailAddress, True, False, False, 1);
	
	// StandardSubsystems.Companies
	
	// The Companies catalog
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyLegalAddress, Enums.ContactInformationTypes.Address, True, False, True, 1);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyActualAddress, Enums.ContactInformationTypes.Address, True, False, False, 2);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyPhone, Enums.ContactInformationTypes.Phone, True, False, False, 3);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyFax, Enums.ContactInformationTypes.Fax, True, False, False, 4);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyEmail, Enums.ContactInformationTypes.EmailAddress, True, False, False, 5);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyPostalAddress, Enums.ContactInformationTypes.Address, True, False, False, 6);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds.CompanyOtherInformation, Enums.ContactInformationTypes.Other, True, False, False, 7);
	// End StandardSubsystems.Companies
	
	// End StandardSubsystems
	
	// _Demo example start
	
	// The Partners catalog
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds._DemoPartnerAddress, Enums.ContactInformationTypes.Address, True, False, False, 1);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds._DemoPartnerPhone, Enums.ContactInformationTypes.Phone, True, False, False, 2);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds._DemoPartnerEmail, Enums.ContactInformationTypes.EmailAddress, True, False, False, 3);
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds._DemoPartnerSalesDepartmentEmail, Enums.ContactInformationTypes.EmailAddress, True, False, False, 4);

	// The Partner contacts catalog
	ContactInformationManagement.UpdateCIKind(Catalogs.ContactInformationKinds._DemoContactEmail, Enums.ContactInformationTypes.EmailAddress, True, False, False, 1);
	
	// _Demo example end
	
EndProcedure

