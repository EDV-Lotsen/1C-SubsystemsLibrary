

// Procedure of IB update for catalog of contact information kinds.
//
// Instructions:
// For each object, CI owner, for each CI kind corresponding to object add
// string: ContactInformationManagement.RefreshContactInformationKind(.....). Here,
// order of calls is important, the earlier call for CI kind,
// the higher this CI kind will be placed on object form.
//
// Parameters of function ContactInformationManagement.RefreshContactInformationKind:
// 1. CI Kind - Ref to predefined kind of CI.
// 2. CI Type - Ref to enum
// 3. EditMethodEditable     - Defines, if change method can be edited in Enterprise mode,
//                                         for example, for addresses, used in regl. reports, edit option
//                                         should be disabled.
// 4. EditInDialogOnly       - If True, then CI kind value will be editable
//                                         only in input form (makes sense only for
//                                         addresses, phones and faxes).
// 5. AlwaysUseAddressClassifier     - If True, then only address in classifier can be entered
//                                         as an address (makes sense only for addresses).
//
//
Procedure ContactInformationIBUpdate() Export
	
	// StandardSubsystems
	
	// Catalog "Users".
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.UserEmail, Enums.ContactInformationTypes.EmaiAddress, True, False, False);
	
	// Catalog "CustomersAndVendors".
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyEmail,        Enums.ContactInformationTypes.EmaiAddress, False, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyOtherInfo,    Enums.ContactInformationTypes.Another, 	 False, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyMailAddress,  Enums.ContactInformationTypes.Address, 	 False, True, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyPhone,        Enums.ContactInformationTypes.Phone, 		 True, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyFax,          Enums.ContactInformationTypes.Phone, 		 True, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyRealAddress,  Enums.ContactInformationTypes.Address, 	 True, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CounterpartyLegalAddress, Enums.ContactInformationTypes.Address, 	 True, False, False);
	
	// Catalog "Companies".
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyEmail,        Enums.ContactInformationTypes.EmaiAddress, False, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyOtherInfo,    Enums.ContactInformationTypes.Another, 	False, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyMailAddress,  Enums.ContactInformationTypes.Address, 	False, True, True);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyPhone,        Enums.ContactInformationTypes.Phone, 		True, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyFax,          Enums.ContactInformationTypes.Phone, 		True, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyRealAddress,  Enums.ContactInformationTypes.Address, 	False, True, True);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.CompanyLegalAddress, Enums.ContactInformationTypes.Address, 	False, True, True);
	
	// Catalog "Individuals".
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.IndividualNotificationAddress,		 Enums.ContactInformationTypes.Address, False, True, True);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.IndividualAddressOutsideHomeCountry, Enums.ContactInformationTypes.Address, True, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.IndividualRegistrationAddress, 		 Enums.ContactInformationTypes.Address, False, True, True);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.IndividualResidentalAddress,      	 Enums.ContactInformationTypes.Address, False, True, True);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.IndividualOtherInfo,                 Enums.ContactInformationTypes.Another, False, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.IndividualPhone,                  	 Enums.ContactInformationTypes.Phone, 	True, False, False);
	
	// Catalog "Contact persons".
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.ContactPersonEmail, Enums.ContactInformationTypes.EmaiAddress, False, False, False);
	ContactInformationManagement.RefreshContactInformationKind(Catalogs.ContactInformationKinds.ContactPersonPhone, Enums.ContactInformationTypes.Phone, 	   True, False, False);
		
	// End StandardSubsystems
	
EndProcedure // ContactInformationIBUpdate()

