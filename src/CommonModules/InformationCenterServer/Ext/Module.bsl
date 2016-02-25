////////////////////////////////////////////////////////////////////////////////
// Information center subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Information links

// Displays information links on form
//
// Parameters:
//  Form             - ManagedForm - form context.
//  FormGroup        - FormItem - form group where the information links is displayed.
//  GroupCount       - Number - number of information link groups on form.
//  LinkCountInGroup - Number - number of information links in group.
//  DisplayAllLink   - Boolean - flag that shows whether the All link is displayed.
//
Procedure DisplayContextLinks(Form, FormGroup, GroupCount = 3, LinkCountInGroup = 1, DisplayAllLink = True, PathToForm = "") Export
	
	Try
		If IsBlankString(PathToForm) Then 
			PathToForm = Form.FormName;
		EndIf;
		
		FormLinkTable = InformationCenterServerCached.GetInformationLinkTableForForm(PathToForm);
		If FormLinkTable.Count() = 0 Then 
			Return;
		EndIf;
		
		// Changing the form parameters
		FormGroup.ShowTitle = False;
		FormGroup.ToolTip   = "";
		FormGroup.Representation = UsualGroupRepresentation.None;
		FormGroup.Grouping = ChildFormItemsGroup.Horizontal;
		
		// Adding the list of information links 
		AttributeName = "InformationLinks";
		AttributesToBeAdded = New Array;
		AttributesToBeAdded.Add(New FormAttribute(AttributeName, New TypeDescription("ValueList")));
		Form.ChangeAttributes(AttributesToBeAdded);
		
		GenerateOutputGroups(Form, FormLinkTable, FormGroup, GroupCount, LinkCountInGroup, DisplayAllLink);
	Except
		EventName = GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Common procedures

// Retrieves the event log event name.
//
// Returns:
// String - event log event name.
//
Function GetEventNameForEventLog() Export
	
	Return NStr("en = 'Information center'");
	
EndFunction

// Retrieves a proxy for managing the forum.
//
// Returns:
//  WSProxy - forum management proxy.
//
Function GetForumManagementProxy() Export
	
	SetPrivilegedMode(True);
	URL          = Constants.ForumManagementURL.Get() + "/ForumService?wsdl";
	UserName     = Constants.InformationCenterForumUserName.Get();
	UserPassword = Constants.InformationCenterForumPassword.Get();
	SetPrivilegedMode(False);
	
	Proxy = CTLAndSLIntegration.WSProxy(URL,
		"http://ws.forum.saas.onec.ru/",
		"ForumIntegrationWSImplService",
		"ForumIntegrationWSImplPort",
		UserName,
		UserPassword);
	
	Return Proxy;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Retrieves the proxy of the Service manager information center.
//
// Returns:
// WSProxy - information center proxy.
//
Function GetInformationCenterProxy() Export
	
	If Not CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		Raise(NStr("en = 'A connection to the Service manager cannot be established.'"));
	EndIf;
	
	SaaSOperationsModule = CTLAndSLIntegration.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerURL = SaaSOperationsModule.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	ServiceURL   = ServiceManagerURL + "/ws/ManageInfoCenter?wsdl";
	UserName     = SaaSOperationsModule.AuxiliaryServiceManagerUserName();
	UserPassword = SaaSOperationsModule.AuxiliaryServiceManagerUserPassword();
	SetPrivilegedMode(False);
	
	InformationCenterProxy = CTLAndSLIntegration.WSProxy(ServiceURL,
															"http://1c-dn.com/SaaS/1.0/WS",
															"ManageInfoCenter", 
															, 
															UserName, 
															UserPassword, 
															7);
	
	Return InformationCenterProxy;
	
EndFunction

// Returns Proxy information center Manager service.
//
// Returns:
// WSProxy - proxy information center.
//
Function GetInformationCenterProxy_1_0_1_1() Export
	
	If Not CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		Raise(NStr("en = 'A connection to the Service manager cannot be established.'"));
	EndIf;
	
	SaaSOperationsModule = CTLAndSLIntegration.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerURL = SaaSOperationsModule.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	ServiceURL       = ServiceManagerURL + "/ws/ManageInfoCenter_1_0_1_1?wsdl";
	UserName    = SaaSOperationsModule.AuxiliaryServiceManagerUserName();
	UserPassword = SaaSOperationsModule.AuxiliaryServiceManagerUserPassword();
	SetPrivilegedMode(False);
	
	InformationCenterProxy = CTLAndSLIntegration.WSProxy(ServiceURL,
															"http://1c-dn.com/SaaS/1.0/WS",
															"ManageInfoCenter_1_0_1_1", 
															, 
															UserName, 
															UserPassword, 
															7);
	
	Return InformationCenterProxy;
	
EndFunction

// Returns Proxy information center Manager service.
//
// Returns:
// WSProxy - proxy information center.
//
Function GetInformationCenterProxy_1_0_1_2() Export
	
	If Not CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		Raise(NStr("en = 'A connection to the Service manager cannot be established.''"));
	EndIf;
	
	SaaSOperationsModule = CTLAndSLIntegration.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerURL = SaaSOperationsModule.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	ServiceURL   = ServiceManagerURL + "/ws/ManageInfoCenter_1_0_1_2?wsdl";
	UserName     = SaaSOperationsModule.AuxiliaryServiceManagerUserName();
	UserPassword = SaaSOperationsModule.AuxiliaryServiceManagerUserPassword();
	SetPrivilegedMode(False);
	
	InformationCenterProxy = CTLAndSLIntegration.WSProxy(ServiceURL,
															"http://1c-dn.com/SaaS/1.0/WS",
															"ManageInfoCenter_1_0_1_2", 
															, 
															UserName, 
															UserPassword, 
															7);
	
	Return InformationCenterProxy;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// User notifications in the information center form.

// Retrieves the link to the InformationCenterInformationType catalog item by Description.
//
// Parameters:
// Description - String - news item type description.
//
// Returns:
// CatalogRef.InformationCenterInformationType - information type.
//
Function DetermineInformationTypeRef(Val Description) Export
	
	SetPrivilegedMode(True);
	Description = TrimAll(Description);
	
	FoundReference = Catalogs.InformationCenterInformationType.FindByDescription(Description);
	
	If FoundReference.IsEmpty() Then 
		InformationType = Catalogs.InformationCenterInformationType.CreateItem();
		InformationType.Description = Description;
		InformationType.Write();
		
		Return InformationType.Ref;
	Else
		Return FoundReference;
	EndIf;
	
EndFunction

// Generates the list with all news.
//
// Returns:
// ValueTable with the following fields:
// 	Description - String - news item title.
// 	ID - UUID - News item ID.
// 	Criticality - Number - News item criticality.
// 	ExternalLink - Row - URL.
//
Function GenerateAllNewsList() Export
	
	AllNewsQuery = New Query;
	
	AllNewsQuery.Text = 
	"SELECT
	|	CommonInformationCenterData.Description AS Description,
	|	CommonInformationCenterData.Criticality AS Criticality,
	|	CommonInformationCenterData.ID AS ID,
	|	CommonInformationCenterData.ExternalLink AS ExternalLink,
	|	CommonInformationCenterData.InformationType AS InformationType
	|FROM
	|	Catalog.CommonInformationCenterData AS CommonInformationCenterData
	|WHERE
	|	NOT CommonInformationCenterData.DeletionMark
	|
	|ORDER  BY
	|	CommonInformationCenterData.StartDate DESC";
	
	Return AllNewsQuery.Execute().Unload();
	
EndFunction

// Generates list news.
//
// Parameters:
//  NewsTable - ValueTable with the following columns:
// 	 Description - String - news item title.
// 	 ID - UUID - news item ID.
// 	 Criticality - Number - News item criticality.
// 	 ExternalLink - String - URL.
//  NewsCountToDisplay - Number - number of news to be displayed.
//
Procedure GenerateNewsListOnDesktop(NewsTable, Val NewsCountToDisplay = 3) Export
	
	CriticalNews = GenerateActualCriticalNews();
	
	CriticalNewsCount = ?(CriticalNews.Count() >= NewsCountToDisplay, NewsCountToDisplay, CriticalNews.Count());
	
	// Adding news to the common table.
	If CriticalNewsCount > 0 Then 
		For Iteration = 0 to CriticalNewsCount - 1 Do
			NewsItem = NewsTable.Add();
			FillPropertyValues(NewsItem, CriticalNews.Get(Iteration));
		EndDo;	
	EndIf;
	
	If CriticalNewsCount = NewsCountToDisplay Then 
		Return;
	EndIf;
	
	NoCriticalNews = GenerateActualNoCriticalNews();
	
	NotCriticalNewsDisplayCount = NewsCountToDisplay - CriticalNewsCount;
	
	NotCriticalNewsDisplayCount = ?(NoCriticalNews.Count() < NotCriticalNewsDisplayCount, NoCriticalNews.Count(), NotCriticalNewsDisplayCount);
	
	If NoCriticalNews.Count() > 0 Then 
		For Iteration = 0 to NotCriticalNewsDisplayCount - 1 Do
			NewsItem = NewsTable.Add();
			FillPropertyValues(NewsItem, NoCriticalNews.Get(Iteration));
		EndDo;
	EndIf;
	
	Return;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Send messages in support service

// Returns the email address of the current user.
//
// Returns:
//  String- email address of the current user.
//
Function GetUserEmailAddress() Export 
	
	CurrentUser = Users.CurrentUser();
	
	If CTLAndSLIntegration.SubsystemExists("ContactInformation") Then 
		
		Module = CTLAndSLIntegration.CommonModule("ContactInformationManagement");
		If Module = Undefined Then 
			Return "";
		EndIf;
		
		Return Module.ObjectContactInformation(CurrentUser, PredefinedValue("Catalog.ContactInformationKinds.UserEmail"));
		
	EndIf;
	
	Return "";
	
EndFunction

// Retrieves a pattern of a message to support.
//
// Returns:
// String - pattern of a message to support.
//
Function GenerateTextToSupportPattern() Export
	
	Template = NStr("en = 'Hello!
		|<p/>
		|<p/>PointerPosition
		|<p/>
		|Kind regards, %1.'");
	Template = StringFunctionsClientServer.SubstituteParametersInString(Template, 
			Users.CurrentUser().FullDescr());
	
	Return Template;
	
EndFunction

// Retrieves the name of the file where the tech parameters for support are placed.
//
// Returns:
//  String - file name.
//
Function GetTechParameterFileNameForMessagesToSupport() Export
	
	Return "TechnicalParameters.xml";
	
EndFunction

// Retrieves tech parameters as text.
//
// Returns:
//  Map:
// 	Key - String - Attachment description.
// 	Value - BinaryData - Attachment file.
//
Function GenerateXMLWithTechParameters(Parameters = Undefined) Export
	
	ParameterArray = GetTechParameterArray(Parameters);
	
	XMLFile = GetTempFileName("xml");
	
	XMLText = New XMLWriter;
	XMLText.OpenFile(XMLFile);
	XMLText.WriteXMLDeclaration();
	WriteParametersToXMLFile(XMLText, ParameterArray);
	XMLText.Close();
	
	FileBinaryData = New BinaryData(XMLFile);
	
	Try
		DeleteFiles(XMLFile);
	Except
		WriteLogEvent(NStr("en = 'Information center. Sending message to support. Cannot delete temporary file with tech parameters.'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Attachment = New ValueList;
	Attachment.Add(FileBinaryData, GetTechParameterFileNameForMessagesToSupport(), True);
	
	Return Attachment;
	
EndFunction

// Retrieves the string with URL.
//
// Parameters:
//  ID - UUID - news item UUID.
//
// Returns:
//  String - external resource URL.
//
Function GetExternalLinkByNewsID(ID) Export
	
	SetPrivilegedMode(True);
	LinkToData	= Catalogs.CommonInformationCenterData.FindByAttribute("ID", ID);
	If LinkToData.IsEmpty() Then 
		Return "";
	EndIf;
	
	Return LinkToData.ExternalLink;
	
EndFunction
 
////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional call to other subsystem.

// Sends the user message to support.
//
// Parameters:
//  MessageParameters - Structure - message parameters.
//  Result            - Boolean - True if message is sent, otherwise is False.
//
Procedure UserMessageToSupportOnSend(MessageParameters, Result) Export
	
	If Not CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		
		Result = True;
		Return;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		CTLAndSLIntegration.SendMessage("InformationCenter\SendMessage\Support",
						MessageParameters,
						CTLAndSLIntegration.ServiceManagerEndpoint());
		CommitTransaction();
		Result = True;
		Return;
	Except
		RollbackTransaction();
		Result = False;
		Return;
	EndTry;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// User notifications in the information center form.

// Retrieves the list of actual critical news (Criticality > 5).
//
// Returns:
//  ValueTable with the fields of NewsTable from the GenerateNewsListOnDesktop procedure.
//
Function GenerateActualCriticalNews()
	
	CriticalNewsQuery = New Query;
	
	CriticalNewsQuery.SetParameter("CurrentDate",     CurrentSessionDate());
	CriticalNewsQuery.SetParameter("CriticalityFive", 5);
	CriticalNewsQuery.SetParameter("BlankDate",       '00010101');
	
	CriticalNewsQuery.Text = 
	"SELECT
	|	CommonInformationCenterData.Reference AS LinkToData
	|FROM
	|	Catalog.CommonInformationCenterData AS CommonInformationCenterData
	|WHERE
	|	CommonInformationCenterData.StartDate <= &CurrentDate
	|	AND CommonInformationCenterData.Criticality > &CriticalityFive
	|	AND (CommonInformationCenterData.EndDate >= &CurrentDate
	|			OR CommonInformationCenterData.EndDate = &BlankDate)
	|	AND NOT CommonInformationCenterData.DeletionMark
	|
	|ORDER  BY
	|	CommonInformationCenterData.Criticality DESC,
	|	CommonInformationCenterData.StartDate DESC";
	
	Return CriticalNewsQuery.Execute().Unload();
	
EndFunction

// Retrieves the list of actual non-critical news (Criticality <= 5).
//
// Returns:
//  ValueTable with the fields of NewsTable from the GenerateNewsListOnDesktop procedure.
//
Function GenerateActualNoCriticalNews()
	
	SetPrivilegedMode(True);
	
	NotCriticalNewsQuery = New Query;
	
	NotCriticalNewsQuery.SetParameter("CurrentDate",     CurrentDate()); // SL project decision
	NotCriticalNewsQuery.SetParameter("CriticalityFive", 5);
	NotCriticalNewsQuery.SetParameter("BlankDate",       '00010101');
	NotCriticalNewsQuery.SetParameter("Reviewed",        False);
	NotCriticalNewsQuery.SetParameter("User",            Users.CurrentUser().Reference);
	
	NotCriticalNewsQuery.Text =
	"SELECT
	|	CommonInformationCenterData.Reference AS LinkToData
	|INTO ICData
	|FROM
	|	Catalog.CommonInformationCenterData AS CommonInformationCenterData
	|WHERE
	|	CommonInformationCenterData.StartDate <= &CurrentDate
	|	AND CommonInformationCenterData.Criticality <= &CriticalityFive
	|	AND (CommonInformationCenterData.EndDate >= &CurrentDate
	|			OR CommonInformationCenterData.EndDate = &BlankDate)
	|	AND NOT CommonInformationCenterData.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ViewedInformationCenterData.InformationCenterData,
	|	ViewedInformationCenterData.Reviewed
	|INTO ViewedByUser
	|FROM
	|	InformationRegister.ViewedInformationCenterData AS ViewedInformationCenterData
	|WHERE
	|	ViewedInformationCenterData.User = &User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ICData.LinkToData,
	|	ISNULL(ViewedByUser.Reviewed, &Reviewed) AS Reviewed
	|INTO Prepared
	|FROM
	|	ICData AS ICData
	|		FULL JOIN ViewedByUser AS ViewedByUser
	|			ON ICData.LinkToData = ViewedByUser.InformationCenterData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepared.LinkToData
	|FROM
	|	Prepared AS Prepared
	|WHERE
	|	Prepared.Reviewed = &Reviewed";
	
	Return NotCriticalNewsQuery.Execute().Unload();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Message sending to service support.

// Retrieves array of tech parameters.
//
// Returns:
//  Array  - array of tech parameter structure with the following fields:
// 	         Name  - String - parameter name.
// 	         Value - String - parameter value.
// 
Function GetTechParameterArray(Parameters)
	
	InformationSystem = New SystemInfo;
	
	ParameterArray = New Array;
	ParameterArray.Add(New Structure("Name, Value", "ConfigurationName",    Metadata.Name));
	ParameterArray.Add(New Structure("Name, Value", "ConfigurationVersion", Metadata.Version));
	ParameterArray.Add(New Structure("Name, Value", "PlatformVersion",     InformationSystem.AppVersion));
	ParameterArray.Add(New Structure("Name, Value", "DataArea",            String(Format(CTLAndSLIntegration.SessionSeparatorValue(), "NG=0"))));
	ParameterArray.Add(New Structure("Name, Value", "Login",               UserName()));
	
	If Parameters <> Undefined Then 
		For Each Parameter In Parameters Do
			ParameterArray.Add(New Structure("Name, Value", Parameter.Reference, String(Parameter.Value)));
		EndDo;
	EndIf;
	
	Return ParameterArray;
	
EndFunction	

// Writes parameters in the XML format.
//
// Parameters:
//  XMLText        - XMLWriter - XML writer.
//  ParameterArray - Array of parameters.
//
Procedure WriteParametersToXMLFile(XMLText, ParameterArray)
	
	XMLText.WriteStartElement("parameters");
	For Iteration = 0 to ParameterArray.Count() - 1 Do 
		XMLText.WriteStartElement("parameter");
		Item = ParameterArray.Get(Iteration);
		XMLText.WriteAttribute(Item.Name, Item.Value);
		XMLText.WriteEndElement();
	EndDo;
	XMLText.WriteEndElement();
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Information links

// Generates information link form items in the group.
//
// Parameters:
// Form             - ManagedForm - form context.
// FormGroup        - FormItem - form group where the information links is displayed.
// GroupCount       - Number - number of information link groups on the form.
// LinkCountInGroup - Number - number of information links per group.
// DisplayAllLink   - Boolean - flags that shows whether the All link is displayed.
//
Procedure GenerateOutputGroups(Form, RefsTable, FormGroup, GroupCount, LinkCountInGroup, DisplayAllLink)
	
	RefsTable.Sort("Weight Desc");
	
	LinkCount = ?(RefsTable.Count() > GroupCount * LinkCountInGroup, GroupCount * LinkCountInGroup, RefsTable.Count());
	
	GroupCount = ?(LinkCount < GroupCount, LinkCount, GroupCount);
	
	ShortGroupName = "InformationLinkGroup";
	
	For Iteration = 1 to GroupCount Do 
		
		FormItemName               = ShortGroupName + String(Iteration);
		ParentGroup                = Form.Items.Add(FormItemName, Type("FormGroup"), FormGroup);
		ParentGroup.Kind           = FormGroupType.UsualGroup;
		ParentGroup.ShowTitle      = False;
		ParentGroup.Grouping       = ChildFormItemsGroup.Vertical;
		ParentGroup.Representation = UsualGroupRepresentation.None;
		
	EndDo;
	
	For Iteration = 1 to LinkCount Do 
		
		LinkGroup = GetLinkGroup(Form, GroupCount, ShortGroupName, Iteration);
		
		LinkName = RefsTable.Get(Iteration - 1).Description;
		URL      = RefsTable.Get(Iteration - 1).URL;
		ToolTip  = RefsTable.Get(Iteration - 1).ToolTip;
		
		LinkItem                   = Form.Items.Add("LinkItem" + String(Iteration), Type("FormDecoration"), LinkGroup);
		LinkItem.Kind              = FormDecorationType.Label;
		LinkItem.Title             = LinkName;
		LinkItem.HorizontalStretch = True;
		LinkItem.Height          = 1;
		LinkItem.Hyperlink         = True;
		LinkItem.SetAction("Click", "Attachable_InformationLinkClick");
		
		Form.InformationLinks.Add(LinkItem.Name, URL);
		
	EndDo;
	
	If DisplayAllLink Then 
		Item                    = Form.Items.Add("AllInformationLinksLink", Type("FormDecoration"), FormGroup);
		Item.Kind               = FormDecorationType.Label;
		Item.Title              = NStr("en = 'All'");
		Item.Hyperlink          = True;
		Item.TextColor          = WebColors.Black;
		Item.HorizontalLocation = ItemHorizontalLocation.Right;
		Item.SetAction("Click", "Attachable_AllInformationLinksLinkClick")
	EndIf;
	
EndProcedure

// Retrieves the group where information links are displayed.
//
// Parameters:
//  Form             - ManagedForm - Form context.
//  GroupCount       - Number - number of information link groups on the form.
//  ShortGroupName   - String - short group description.
//  CurrentIteration - Number - current iteration.
//
// Returns:
//  FormItem - information link  group or Undefined.
//
Function GetLinkGroup(Form, GroupCount, ShortGroupName, CurrentIteration)
	
	GroupName = "";
	
	For GroupIteration = 1 to GroupCount Do
		
		If CurrentIteration % GroupIteration  = 0 Then 
			GroupName = ShortGroupName + String(GroupIteration);
		EndIf;
		
	EndDo;
	
	Return Form.Items.Find(GroupName);
	
EndFunction

// Deletion procedures and functions 

// Describes the site link for publishing applications through the Internet.
// 
// Returns:
//  Structure - structure with the following fields that describes site link. 
//	
Function NewSiteLinkDetailsForPublishingApplicationsThroughInternet() Export 
	
	Return New Structure("Name, URL");
	
EndFunction

// Describes the structure of the link.
//	
// Returns:
// Structure - structure with the following fields:
// 	Name          - String - link description.
// 	URL           - String - link URL.
// 	Explanation   - String - link explanation.
// 	ActionOnClick - String - link handler.
//	
// Comment:
//  ActionOnClick can be empty if clicking opens the target page.
//
Function NewUsefulLinkDetails() Export
	
	Return New Structure("Name, URL, Explanation, ActionOnClick");
	
EndFunction

// Describes the article structure.
// 
// Returns:
//  Structure - structure with fields that describe the article. 
//	
Function NewArticleDetails() Export
	
	Return New Structure("Name, URL");
	
EndFunction	
