Procedure PrintCheck(Spreadsheet, Ref) Export

	Template = Documents.Check.GetTemplate("PrintCheck");
	Query = New Query;
	Query.Text =
	"SELECT
	|	Check.Date,
	|	Check.Counterparty,
	|	Check.DocumentTotalRC,
	|	Check.Memo
	|FROM
	|	Document.Check AS Check
	|WHERE
	|	Check.Ref IN (&Ref)";
	Query.Parameters.Insert("Ref", Ref);
	Selection = Query.Execute().Choose();

	AreaCaption = Template.GetArea("Caption");
	Header = Template.GetArea("Header");
	Spreadsheet.Clear();
	
	InsertPageBreak = False;
	While Selection.Next() Do
		If InsertPageBreak Then
			Spreadsheet.PutHorizontalPageBreak();
		EndIf;

		ThemBill = _DemoPrintTemplates.ContactInfoDataset(Selection.Counterparty, "ThemBill", Catalogs.Addresses.EmptyRef());
		
		Spreadsheet.Put(AreaCaption);

		Header.Parameters.Fill(Selection);
		Header.Parameters.Fill(ThemBill);
		
		Header.Parameters.WrittenAmount = NumberInWords(Selection.DocumentTotalRC);
		
		Spreadsheet.Put(Header, Selection.Level());

		InsertPageBreak = True;
	EndDo;

EndProcedure
