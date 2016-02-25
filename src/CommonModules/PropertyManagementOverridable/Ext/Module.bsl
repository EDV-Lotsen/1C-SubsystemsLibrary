
////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Fills object property sets. Usually required if the object has multiple property sets.
//
// Parameters:
//  Object       - The reference to the property owner.
//                 Property owner object.
//                 FormStructureData (by type of the property owner object).
//
//  RefType      - Type - the type of reference to the property owner.
//
//  PropertySets - ValueTable with the following columns:
//                    Set - CatalogRef.AdditionalDataAndAttributeSets.
//
//                    // Next, item properties of the FormGroup type of the usual group
//                    // or page kind, which is created without considering the empty 
//                    // set if there are more than one set. The empty set describes
//                    // properties of a group of deleted attributes.
//                    
//                    // If value is Undefined then use the default value. 
//                    
//                    // For any controlled form group.
//                    Height                     - Number.
//                    Title                      - String.
//                    ToolTip                    - String.
//                    VerticalStretch            - Boolean.
//                    HorizontalStretch          - Boolean.
//                    ReadOnly                   - Boolean.
//                    TitleTextColor             - Color.
//                    Width                      - Number.
//                    TitleFont                  - Font.
//                    
//                    // For ordinary group and page.
//                    Grouping                   - ChildFormItemsGroup.
//                    
//                    // For ordinary group.
//                    Representation  - UsualGroupRepresentation.
//                    SlaveItemsWidth - ChildFormItemsWidth.
//                    
//                    // For page.
//                    Picture                    - Picture.
//                    ShowTitle                  - Boolean.
//
//  StandardProcessing - Boolean - The initial value is True. Specifies if to receive 
//                       main set when PropertySets.Count() equals to zero.
//
//  PurposeUseKey   - Undefined - (initial value) - forces to calculate purpose use 
//                     key automatically and add to the value of the PurposeUseKey 
//                     attribute of the form to force changes of the form to be saved 
//                     separately for different set contents.
//                     For example for each kind of products and services will have
//                     own set contents.
//
//                  - String - (not more than 32 symbols) - use the specified purpose  
//                     use key to add it to the value of the PurposeUseKey property 
//                     of the form.
//                     Empty string - do not change PurposeUseKey as it is set in  
//                     the form and already considers differences of content of sets.
//                    
//                    The postfix has the "KeyPropertySets<PurposeUseKey>" format. To 
//                    update <PurposeUseKey> without repeated postfix addition.
//                    When calculated automatically, <PurposeUseKey> contains hash of 
//                    reference identifiers of ordered property sets.
//
Procedure FillObjectPropertySets(Object, RefType, PropertySets, StandardProcessing, PurposeUseKey) Export
	
	// _Demo begin example
	If RefType = Type("CatalogRef.Products") Then
		FillPropertySetByProductsKind(Object, RefType, PropertySets);
	EndIf;
	// _Demo end example
	
EndProcedure

// Obsolete. Will be removed in next SL editorial.
// 
// Now instead of determining props name containing property owner type 
// for example ProductOrServiceType CatalogRef type.ProductAndServiceTypes 
// should have PropertySet attribute  CatalogRef type AdditionalDataAndAttributeSets  
// in properties set for  CatalogRef object should be filled.Items 
// in FillObjectPropertySets procedure as in case of several properties sets. 
// The only difference is that set will be received from owner type object 
// props independently that allows you to use several different details with 
// convenient names for objects different types which have one object type. 
// For example Reference Table.Projects are owner properties type in Catalog.Errors 
// and Reference Table.Which tasks will be attributes in  Projects 
// handbook PropertiesErrorsSet TasksPropertiesSet.
//
Function GetObjectTypeAttributeName(Ref) Export
	
	Return "";
	
EndFunction

// _Demo begin example

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions

// Gets object property set by item kind.
Procedure FillPropertySetByProductsKind(Products, RefType, PropertySets)
	
	Row = PropertySets.Add();
	Row.Set = Catalogs.AdditionalDataAndAttributeSets.Catalog_Products;
	Row.Representation = UsualGroupRepresentation.NormalSeparation;
	Row.ShowTitle = True;
	Row.Title = NStr("en='Products'");
	
	//If TypeOf(Products) = RefType Then
	//	Products = CommonUse.ObjectAttributeValues(
	//		Products, "IsFolder Kind");
	//EndIf;
	//
	//If Products.IsFolder = False Then
	//	Row = PropertySets.Add();
	//	Row.Set = CommonUse.ObjectAttributeValue(
	//		Products.Kind, "PropertySet");
	//EndIf;
	
EndProcedure

// _Demo end example

#EndRegion
