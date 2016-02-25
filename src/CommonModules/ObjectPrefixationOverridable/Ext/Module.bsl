////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// The handler on the object number change.
// The handler is intended for computing the object base number,
// when it can not be acquired without information loss.
// The handler is called only if the processed object codes and numbers
// have been formed in a non-standard way, i.e. not in the SL format.
//
// Parameters:
//  Object - DocumentObject, BusinessProcessObject, TaskObject - Data object
//           the base number of which should be defined.
//  Number - String - Current object number the base number of which should be extracted.
//  BaseNumber - String - Base object number.
//           A base number is an object number
//           without prefixes (infobase prefix, company prefix, unit prefix, 
//           custom prefix, and etc.).
//  StandardProcessing - Boolean - Standard processing flag. Default values are True.
//           If the parameter in the handler is set to the value of False,
//           standard processing will not be performed.
//           Standard processing gets the base code to the right of the first non-numeric symbol.
//           For example, for the code "AA00005/12/368" the standard processing will return "368".
//           However, the base object code will equal "5/12/368".
//
Procedure OnNumberChange(Object, Val Number, BaseNumber, StandardProcessing) Export
	
	// _Demo begin example
	//If TypeOf(Object) = Type("DocumentObject._DemoGoodsSales") Then
	//	
	//	If Mid(Number, 5, 1) <> "-" Then
	//		
	//		// The document number has the old format: "ABCD0012345".
	//		// Therefore, override standard number processing.
	//		StandardProcessing = False;
	//		
	//		// Get the previous infobase prefix from the infobase
	//		PreviousInfobasePrefix = "A";
	//		
	//		// Get the previous company prefix from the infobase
	//		PreviousCompanyPrefix = "B";
	//		
	//		// Get the previous unit prefix from the infobase
	//		PreviousUnitPrefix = "C";
	//		
	//		// Get custom prefix from the document
	//		AdvancePayment = Find(Lower(Object.Comment), "advance payment") > 0;
	//		
	//		CustomPrefix = ?(AdvancePayment, "D", "");
	//		
	//		BaseNumber = Mid(Number,
	//			  StrLen(PreviousInfobasePrefix)
	//			+ StrLen(PreviousCompanyPrefix)
	//			+ StrLen(PreviousUnitPrefix)
	//			+ StrLen(CustomPrefix)
	//			+ 1);
	//		
	//	EndIf;
	//	
	//EndIf;
	// _Demo end example
	
EndProcedure

// The handler on the object code change.
// The handler is intended for computing the object base code, when it can not be
// acquired without information loss.
// The handler is called only if the processed object codes and numbers
// have been formed in a non-standard way, i.e. not in the SL format.
//
// Parameters:
//  Object - CatalogObject, ChartOfCharacteristicTypesObject - Data object
//           the base code of which should be defined.
//  Code - String - Current object code the base code of which should be extracted.
//  BaseCode - String - Base object code. A base code is an object code
//           without prefixes (infobase prefix, company prefix, unit prefix, 
//           custom prefix, and etc.).
//  StandardProcessing - Boolean - Standard processing flag. Default values are True.
//           If the parameter in the handler is set to the value of False,
//           standard processing will not be performed.
//           Standard processing gets the base code to the right of the first non-numeric symbol.
//           For example, for the code "AA00005/12/368" the standard processing will return "368".
//           However, the base object code will equal "5/12/368".
//
Procedure OnCodeChange(Object, Val Code, BaseCode, StandardProcessing) Export
	
EndProcedure

// Set the value of the Objects parameter for those metadata objects the attributes
// of which contain references to companies with non-standard company names.
//
// Parameters:
//  Objects - ValueTable.
//     * Object - MetadataObject - Metadata object the attribute of which 
//                contains a reference to the company.
//     * Attribute - String - Attribute name containing a reference to the company.
//
Procedure GetPrefixFormingAttributes(Objects) Export
	
	// _Demo begin example
	//TableRow = Objects.Add();
	//TableRow.Object = Metadata.Documents._DemoProductSales;
	//TableRow.Attribute = "ParentCompany";
	// _Demo end example
	
EndProcedure

#EndRegion
