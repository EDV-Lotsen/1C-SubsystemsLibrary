//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

// The document copying handler performs also the RegisterRecords copying
Procedure OnCopy(CopiedObject)
	CopiedObject.RegisterRecords.Inventory.Read();
    For Each SrcRecord In CopiedObject.RegisterRecords.Inventory Do
		Write = RegisterRecords.Inventory.Add();
		Write.RecordType = SrcRecord.RecordType;
		Write.Product = SrcRecord.Product;
		Write.Warehouse = SrcRecord.Warehouse;
		Write.Quantity = SrcRecord.Quantity;
	EndDo;
EndProcedure

// The before writing event handler sets the document date for all
// RegisterRecords
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	For Each Write In RegisterRecords.Inventory Do
		Write.Period = Date;
	EndDo;	
	
EndProcedure	
		
	