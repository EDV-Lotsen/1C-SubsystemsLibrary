
&AtClient
Var TemporaryAnchor;

&AtServer
Function GenerateGuideHTML(Section)

	Var RootElement;

	If Not Section = "" Then

		SectionDocument = DataProcessors.DeveloperGuide.GetTemplate(Section).GetHTMLDocument();
		RootElement = SectionDocument.Body;

	Else;

		RootElement = DataProcessors.DeveloperGuide.GetTemplate("HomePage").GetHTMLDocument();
		SectionsMenu = RootElement.GetElementById("MainMenu");

		For Cnt = 0 To ConfigurationSections.Count() - 1 Do

			SectionData = ConfigurationSections.Get(Cnt);
			StrT = RootElement.CreateElement("tr");
			StrT.SetAttribute("style", "padding: 3px");
			ColT = RootElement.CreateElement("td");
			StrT.AppendChild(ColT);
			SectionsMenu.AppendChild(StrT);
			Ref = RootElement.CreateElement("a");
			Ref.SetAttribute("style", "color: #000000; text-decoration: none;");
			Ref.Href = "#";
			Ref.Id = SectionData.Title;
			ColT.AppendChild(Ref);
			Text = RootElement.CreateTextNode(SectionData.Details);
			Ref.AppendChild(Text);

		EndDo;

	EndIf;

	HTMLWriter = new HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter = new DOMWriter;
	DOMWriter.Write(RootElement, HTMLWriter);

	Return HTMLWriter.Close();

EndFunction

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	For Cnt = 1 To Metadata.DataProcessors.DeveloperGuide.Templates.Count() - 1 Do

		MetData = Metadata.DataProcessors.DeveloperGuide.Templates.Get(Cnt);
		Str = ConfigurationSections.Add();
		Str.Title = MetData.Name;
		Str.Details = MetData.Synonym;

	EndDo;

	HTMLField = GenerateGuideHTML("");

EndProcedure

&AtClient
Function GetSectionIndex(Section)

	For Cnt = 0 To ConfigurationSections.Count() - 1 Do

		SectionData = ConfigurationSections.Get(Cnt);

		If SectionData.Title = Section Then

			Return Cnt;

		EndIf;

	EndDo;

	Return -1;

EndFunction

&AtClient
Procedure ShowSection(Document, Section)

	SectionContent = GenerateGuideHTML(Section);
	HTMLElement = Document.getElementById("InformationField");
	If HTMLElement = Undefined Then
		Return;
	EndIf;
	HTMLElement.innerHTML = SectionContent;
	Anchor = Document.getElementById(Section);
	// Depending on the type of browser, must to access the different properties
	If TemporaryAnchor <> Undefined And Anchor <> Undefined Then
		If Anchor.parentElement = Undefined Then
			TemporaryAnchor.parentNode.style.backGroundColor = "#FFFFFF";
		Else
			TemporaryAnchor.parentElement.style.backGroundColor = "#FFFFFF";
		EndIf;
	EndIf;
	TemporaryAnchor = Anchor;
	If Anchor <> Undefined Then
		If Anchor.parentElement = Undefined Then
			Anchor.parentNode.style.backGroundColor = "#FFFFD5";
		Else
			Anchor.parentElement.style.backGroundColor = "#FFFFD5";
		EndIf;
	EndIf;

	Index = GetSectionIndex(Section);

	LeftArrow = Document.getElementById("LeftArrow");
	LeftArrow.href = "#" + String(Index - 1);
	LeftArrow.style.display = "";
	If Index - 1 < 0 Then
		LeftArrow.style.display = "none";
	EndIf;
	
	RightArrow = Document.getElementById("RightArrow");
	RightArrow.href = "#" + String(Index + 1);
	RightArrow.style.display = "";
	If Index + 1 > ConfigurationSections.Count() -1 Then
		RightArrow.style.display = "none";
	EndIf;

EndProcedure

&AtClient
Procedure HTMLFieldOnClick(Element, EventData, StandardProcessing)

	StandardProcessing = False;	
	CurrentDocument = EventData.Document;
	If Not EventData.Anchor = Undefined Then

		If EventData.Anchor.protocol = "v8:" Then

			Position = Find(EventData.Href, "OpenForm=");

			If Position > 0 Then
				OpenForm(Mid(EventData.Href, Position + 9));
			EndIf;

			Position = Find(EventData.Href, "OpenHelp=");

			If Position > 0 Then
				OpenHelp(Mid(EventData.Href, Position + 9));
			EndIf;
			
			Position = Find(EventData.Href, "OpenLink=");

			If Position > 0 Then
				GotoURL(Mid(EventData.Href, Position + 9));
			EndIf;
			
		ElsIf EventData.Anchor.id = "LeftArrow" Then

			Position = Find(EventData.Href, "#");
			Index = Number(Mid(EventData.Href, Position + 1));
			ShowSection(CurrentDocument, ConfigurationSections[Index].Title);

		ElsIf EventData.Anchor.id = "RightArrow" Then

			Position = Find(EventData.Anchor.href, "#");			
			Index = Number(Mid(EventData.Anchor.href, Position + 1));
			ShowSection(CurrentDocument,
			ConfigurationSections.Get(Index).Title);

		Else;
			
			If Not IsBlankString(EventData.Anchor.id) Then
				ShowSection(CurrentDocument, EventData.Anchor.id);
			Else
				StandardProcessing = True;
			EndIf;
			
		EndIf;

	EndIf;

EndProcedure

&AtClient
Procedure HTMLDocumentGeneratedField(Element)
	TemporaryAnchor = Undefined;
	ShowSection(Element.Document, ConfigurationSections[0].Title);
EndProcedure
