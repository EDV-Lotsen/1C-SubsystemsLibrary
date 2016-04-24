////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// The procedure is called when the performer selection form is open.
// It overrides the standard selection form.
//
// Parameters:
//   PerformerItem        - FormItem         - form item where the performer is selected. The selected performer is specified
//                                             as the owner of the performer selection form.
//   PerformerAttribute   - CatalogRef.Users - previously selected performer value. It is used for setting the current row
//                                             in the performer selection form. 
//   SimpleRolesOnly      - Boolean          - if True, only roles without addressing objects are used in the selection.
//   WithoutExternalRoles - Boolean          - if True, only roles without the ExternalRole flag are used in the selection.
//   StandardProcessing   - Boolean          - if False, displaying the standard performer selection form is not required.
//
Procedure OnSelectPerformer(PerformerItem, PerformerAttribute, SimpleRolesOnly, WithoutExternalRoles,
	StandardProcessing) Export
	
EndProcedure	

// Fills the list of exchange plan nodes (available infobases where external roles can be defined).
//
// Parameters:
//   ExchangePlansForChoice - Array - exchange plan node list. If you do not specify this parameter,
//   all exchange plan nodes specified in the configuration will be available.
//
Procedure FillExchangePlanArray(ExchangePlansForChoice) Export
	
EndProcedure

#EndRegion