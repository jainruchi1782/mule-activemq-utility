%dw 1.0
%output application/xml encoding = "utf-8",skipNullOn="everywhere"
%var refdata = flowVars.rdfResponse.value
%var caseData= payload.caseData
%var underwriting= caseData.underwriting
%var quote= caseData.quote
%var parties= caseData.parties
%var insured= (parties filter ($.role == 'Insured'))[0] when parties != null otherwise null
%var owners= (parties filter ($.role == 'Owner' and $.relationship != 'Self')) when parties != null otherwise null
%var lifeParticipantOwners= (parties filter ($.role == 'Owner')) when parties != null otherwise null
%var primary= (parties filter ($.role == 'Primary Bene')) when parties != null otherwise null
%var contingent= (parties filter ($.role == 'Contingent Bene')) when parties != null otherwise null
%var agents= (parties filter ($.role == 'Agent')) when parties != null otherwise null
%var thirdPartyDesignee= (parties filter ($.role == 'Third Party Designee')) when parties != null otherwise null
%var payor= (parties filter ($.role == 'Payor' and $.relationship != 'Self')) when parties != null otherwise null
%var fpayor= (parties filter ($.role == 'Payor')) when parties != null otherwise null
//%var lifeParticipantPayor= (parties filter ($.role == 'Payor' and $.relationship != 'Self')) when parties != null otherwise null
%var coverage= caseData.coverage
%var additional= caseData.additional
%var existingPolicies= caseData.additional.existingPolicies
%var replacementPolicies = (existingPolicies filter ($.isReplacement == 'Yes'))[0] when existingPolicies != null otherwise null
%var internalReplacementPolicies= (existingPolicies filter ($.isInternal == 'Yes' and $.isReplacement == 'Yes'))[0] when existingPolicies != null otherwise null
%var pendingOrPlannedPolicies= caseData.additional.pendingOrPlannedPolicies
%var nonNaturalEntityRelations = ["Trust","Estate"]
%var bankInfo = fpayor[0].details.bankInfo[0]  when fpayor != null and fpayor[0].details != null otherwise null
%var payment =  fpayor[0].details.paymentInfo  when fpayor != null and fpayor[0].details != null otherwise null

%function filterRef(collection, type, input) (collection filter ($.TranslationType == type and (upper $.TranslationOutput) == (upper input)))[0]
%function substituteSpace(str) str replace /[\s]/ with "_"
%function filterArray(collection, type, input) (collection filter ($.TranslationType == type and ((upper $.TranslationOutput) == (upper input))))
%function removeSpaces(str) str replace "  " with " "
%function getNumber(str) str replace /[- )(]/ with ""

---
{
	TXLife @(xmlns: "http://ACORD.org/Standards/Life/2"): {
		TXLifeRequest @(PrimaryObjectID: "Holding_1"): {
			TransRefGUID: caseData.caseId,
			TransType @(tc: "103"): "New Business Submission",
			TransSubType @(tc: "10301"): "New Business Submission - Life",
			TransExeDate: now as :string {format: "yyyy-MM-dd"},
			TransExeTime: now as :string {format: "HH:mm:ss"},
			OLifE: {
				SourceInfo: {
					SourceInfoName: "ESB",
					SourceInfoDescription: "FAST Deliver"
				},
				Holding @(id: "Holding_1"): {
					HoldingTypeCode @(tc: 2): "Policy",
					Policy: {
						PolNumber: caseData.policyNumber,
						LineOfBusiness @(tc: 1) : coverage.lob,
						ProductType @(tc: filterRef(refdata, "ProductType", coverage.productType).TranslationInput) : coverage.productType,
						ProductCode: filterRef(refdata, "ProductCode", coverage.productCode).TranslationInput,
						ProductVersionCode: quote.pricingVersion when  quote != null otherwise null,
						CarrierCode: filterRef(refdata, "PMHCCarrierCode", sessionVars.ClientCode).TranslationInput,
						PlanName: filterRef(refdata, "PlanName", coverage.productCode).TranslationInput,
						ShortName: filterRef(refdata, "PlanShortName", coverage.productCode).TranslationInput,
						PolicyStatus @(tc: (filterRef(refdata, "PolicyStatus", caseData.policyStatus).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PolicyStatus", caseData.policyStatus).TranslationInput splitBy "+")[1],
						IssueType @(tc: filterRef(refdata, "UnderwritingMethod", underwriting.underwritingMethod).TranslationInput) : underwriting.underwritingMethod,
						Jurisdiction @(tc: (filterRef(refdata, "Jurisdiction", coverage.state).TranslationInput splitBy "+")[1]) : coverage.state,
						Life: {
							FaceAmt: coverage.faceAmount,
							Coverage @(id : "Base_Coverage"): {
								IndicatorCode @(tc: 1): "Base",
								DeathBenefitOptType @(tc: (filterRef(refdata, "DeathBenifitOption", coverage.deathBenefitOpt).TranslationInput)) : coverage.deathBenefitOpt,
								//ModalPremAmt: quote.premiumAmount,
								ModalPremAmt: payment.paymentAmount as :number {format: "0.00"} when payment.paymentAmount != null and payment.paymentAmount != "" otherwise null,	
								EffDate: caseData.issueDate,
								PayToYear: quote.paymentTerm when quote != null otherwise null,
								LifeParticipant @(id: "LP_Insured_1", PartyID: "Party_PI_1"): {
									LifeParticipantRoleCode @(tc: filterRef(refdata, "ParticipantRoleCode", insured.role).TranslationInput): insured.role,
									PermFlatExtraAmt: underwriting.permFlatExtraAmt when underwriting.flatextrasDuration == null or underwriting.flatextrasDuration == 0  otherwise 0,
									(TobaccoPremiumBasis @(tc: (filterRef(refdata, "TobaccoPremiumBasis", underwriting.tobaccoPremiumBasis).TranslationInput)): underwriting.tobaccoPremiumBasis ) when  underwriting != null and underwriting.tobaccoPremiumBasis !=null,
									PermTableRating @(tc: filterRef(refdata, "TableRating", underwriting.tableRating).TranslationInput): underwriting.tableRating,
									//PermTableRating @(tc: 1): "Standard",
									TempFlatExtraAmt: underwriting.tempFlatExtraAmt when (underwriting.flatextrasDuration != null and underwriting.flatextrasDuration != 0) otherwise 0,
									(UnderwritingClass  @(tc: filterRef(refdata, "UnderwritingRiskClass", underwriting.underwritingRiskClass).TranslationInput): underwriting.underwritingRiskClass) when underwriting.underwritingRiskClass !=null,
									(UnderwritingStatus @(tc: filterRef(refdata, "UnderWritingStatus", underwriting.decision).TranslationInput): underwriting.decision) when underwriting.decision != null,
									TempFlatExtraDuration: underwriting.flatextrasDuration default 0
								},
								(owners default [] map (owner, indexOfOwner) -> {
									LifeParticipant @(id: "LP_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1, PartyID: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1): {
										LifeParticipantRoleCode @(tc: filterRef(refdata, "ParticipantRoleCode", owner.role).TranslationInput): owner.role
									}
								}) ,
								(primary default [] map (primary, indexOfPrimary) -> {
									LifeParticipant @(id: "LP_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1, PartyID: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1): {
										LifeParticipantRoleCode @(tc: filterRef(refdata, "ParticipantRoleCode", primary.role).TranslationInput): primary.role
									}
								}),
								(contingent default [] map (contingent, indexOfContingent) -> {
									LifeParticipant @(id: "LP_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1, PartyID: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1): {
										LifeParticipantRoleCode @(tc: filterRef(refdata, "ParticipantRoleCode", contingent.role).TranslationInput): contingent.role
									}
								}),
								(payor default [] map (payor, indexOfPayor) -> {
									LifeParticipant @(id: "LP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1, PartyID: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1): {
										LifeParticipantRoleCode @(tc: filterRef(refdata, "ParticipantRoleCode", payor.role).TranslationInput): payor.role
									}
								})
							},
							
							(coverage.riders default [] map (riders, indexOfRiders) -> {
								Coverage @(id: ( "COV_" ++ riders.code ) ) : {
										
									 PlanName: filterRef(refdata, "RiderPlanName", riders.code).TranslationInput,
									 ProductCode: riders.code,
									 IndicatorCode @(tc: 2): "Rider",
									 //PaymentMode @(tc: (filterRef(refdata, "RidersPaymentFrequency", riders.frequency).TranslationInput splitBy "+")[0]): 
									// (filterRef(refdata, "RidersPaymentFrequency", riders.frequency).TranslationInput splitBy "+")[1],					
									 CurrentAmt: riders.amount
								}
							}),	
						    //LifeUSA : {						        
							//	DefLifeInsMethod @(tc: 1) : "Guideline Premium Test"
							//}
							
							(OLifEExtension @(VendorCode:154) :{
								MatchValueVersion: quote.matchVersion when quote != null otherwise null,
								MatchPercentage: quote.matchPercent when quote != null otherwise null
							}) when quote != null and  (quote.matchVersion != null or quote.matchPercent != null)
						},
						ApplicationInfo: {
							ApplicationType @(tc: 1): "New",
							(SignedDate: caseData.policySignedDate) when caseData.policySignedDate != null and  caseData.policySignedDate != "" ,
							MaxRiskAmt: underwriting.approvedMaxFaceAmount default 0,
							//ReplacementInd @(tc: filterRef(refdata, "ReplacementIndicator", insured.details.insured.replaceLifeInsurance).TranslationInput default 0): insured.details.insured.replaceLifeInsurance when insured.details.insured.replaceLifeInsurance == "Yes" otherwise "No",
							SignatureInfo: {
								SignatureRoleCode @(tc: filterRef(refdata, "ParticipantRoleCode", "Owner").TranslationInput): "Owner",
								(SignatureDate: caseData.policySignedDate) when caseData.policySignedDate != null and caseData.policySignedDate != ""
							}
						}
					},
					//Investment: {
					 // SubAccount : {					  
					  //  ProductCode : "SB-1",
					//	ProductFullName : "Security Benefit Client Fixed Fund",
					//	AllocPercent : "100"
					  
					  //}					
					//},
					
                    Arrangement @(id : "Arr_1"): {
                        ArrMode @(tc: (filterRef(refdata, "ArrMode", (payment.paymentFrequency when payment != null and payment.paymentFrequency != null otherwise "m") ).TranslationInput splitBy "+")[0]): (filterRef(refdata, "ArrMode", (payment.paymentFrequency when payment != null and payment.paymentFrequency != null otherwise "m")).TranslationInput splitBy "+")[1],
						ArrType @(tc: 19): "Initial Payment",
						ModalAmt: payment.paymentAmount as :number {format: "0.00"} when payment.paymentAmount != null and payment.paymentAmount != "" otherwise null,
						PaymentMethod @(tc: filterRef(refdata, "PaymentMethod", payment.method).TranslationInput) : payment.method
						//SourceOfFundsInfo : {
                         // SourceOfFundsDetails : "Income"
                        //}
					},
					(Banking : {					  
                        BankAcctType @(tc: filterRef(refdata, "BankAcctType", bankInfo.accountType).TranslationInput): bankInfo.accountType,
                        AccountNumber: bankInfo.accountNumber,
                        RoutingNum: bankInfo.routingNumber,
                        BankName: bankInfo.bankName
					}) when bankInfo != null
				},
				//(Holding @(id: "Holding_1035_1"):{
				//	HoldingTypeCode @(tc :2) : "Policy",
				//	Policy :{
				//		PolNumber : "Replacement Policy",
				//		PolicyValue : 0,
				//		Life : {
				//			QualPlanType @(tc :1) : "Non-Qualified",
				//			LifeUSA :{
				//				 Internal1035 @(tc: 1 when internalReplacementPolicies != null otherwise 0 ) : "" 
				//			}
				//		}
				//	}
				//}) when replacementPolicies != null,
				Party @(id: "Party_PI_1"): {
					PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", insured.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", insured.classification).TranslationInput splitBy "+")[1],
					FullName: (removeSpaces(trim (([insured.firstName, insured.middleName default "" ,insured.lastName] joinBy " ")))) when (insured.firstName? and insured.lastName?) otherwise "",
					GovtID: (getNumber(insured.ss)) when insured.ss != null otherwise null,					
					GovtIDTC @(tc: 1): "Social Security Number" when insured.ss != null otherwise null,
					PrefComm @(tc: filterRef(refdata, "PrefComm", insured.communicationPreference).TranslationInput): insured.communicationPreference,
					IDReferenceNo: caseData.customerId when caseData.customerId != null and (owners == null or owners == []) otherwise null,
					IDReferenceType @(tc: 35): "Customer Number" when caseData.customerId != null and (owners == null or owners == []) otherwise null,
					Person: {
						FirstName: insured.firstName,
						MiddleName: insured.middleName,
						LastName: insured.lastName,
						Suffix: insured.suffix,
						Occupation: insured.occupation,
						Gender @(tc: (filterRef(refdata, "Gender", insured.gender).TranslationInput splitBy "+")[0]): insured.gender,
						BirthDate: (insured.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when insured.dob != null and insured.dob != "" otherwise null,
						DriversLicenseNum: insured.driverNumber,
						DriversLicenseState @(tc: (filterRef(refdata, "Jurisdiction", insured.driverState).TranslationInput splitBy "+")[1]): insured.driverState,
						(BirthCountry @(tc: (filterRef(refdata, "Country", insured.countryOfBirth).TranslationInput splitBy "+")[1]): insured.countryOfBirth) when insured.countryOfBirth?,
						BirthJurisdiction: insured.stateOfBirth,
						BirthJurisdictionTC @(tc: (filterRef(refdata, "Jurisdiction", insured.stateOfBirth).TranslationInput splitBy "+")[1]): insured.stateOfBirth
					} when (filterRef(refdata, "PartyTypeCode", insured.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
					Organization: {
						OrgForm @(tc: filterRef(refdata, "OrgFormCode", insured.classification).TranslationInput) : insured.classification
						//EstabDate: insured.details.trust.trustDate
					} when (filterRef(refdata, "PartyTypeCode", insured.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
					(insured.addresses default [] map (address, indexOfAddress) -> {
						Address @(id: "Party_PI_Address_" ++ indexOfAddress+1): {
							AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
							Line1: address.address,
							Line2: address.unit,
							City: address.city,
							AddressState: address.state,
							AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
							Zip: address.zip,
							AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
							PrefAddr @(tc: 1): true
						},
						Phone @(id: "Party_PI_Phone_" ++ indexOfAddress+1): {
							PhoneTypeCode @(tc: 12): "Mobile",
							PhoneValue: insured.phone
						},
						EMailAddress @(id: "Party_PI_EmailAddress_" ++ indexOfAddress+1): {
							//EMailType @(tc: 2): "Personal",
							(EMailType @(tc: filterRef(refdata, "EmailType", insured.emailType).TranslationInput ): insured.emailType) when insured.emailType != null,
							AddrLine: insured.email
						}
					}),
					(Risk: {
						ExistingInsuranceInd @(tc:filterRef(refdata, "ExistingInsuranceIndicator", insured.details.insured.existingLifeInsurance).TranslationInput): insured.details.insured.existingLifeInsurance
					}) when insured.details != null and insured.details.insured != null and insured.details.insured.existingLifeInsurance != null
				},
				(primary default [] map (primary, indexOfPrimary) -> {
					Party @(id: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1): {
						PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", primary.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", primary.classification).TranslationInput splitBy "+")[1],
						FullName: primary.name,
						GovtID: (getNumber(primary.ss)) when primary.ss != null otherwise null,						
						GovtIDTC @(tc: 1): "Social Security Number" when primary.ss != null otherwise null,
						Person: {
							FirstName: primary.firstName,
							MiddleName: primary.middleName,
							LastName: primary.lastName,
							Gender @(tc: (filterRef(refdata, "Gender", primary.gender).TranslationInput splitBy "+")[0]): primary.gender,
							BirthDate: (primary.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when primary.dob != null and primary.dob != "" otherwise null
						} when (filterRef(refdata, "PartyTypeCode", primary.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
						Organization: {
							OrgForm @(tc: filterRef(refdata, "OrgFormCode", primary.classification).TranslationInput) : primary.classification
							//EstabDate: primary.details.trust.trustDate
						} when (filterRef(refdata, "PartyTypeCode", primary.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
						(primary.addresses default [] map (address, indexOfAddress) -> {
							Address @(id: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1 ++ "_Address" ++ "_" ++ indexOfAddress+1): {
								AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
								Line1: address.address,
								Line2: address.unit,
								City: address.city,
								AddressState: address.state,
								AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
								Zip: address.zip,
								AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
								PrefAddr @(tc: 1): true
							},
							Phone @(id: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1 ++ "_Phone" ++ "_" ++ indexOfAddress+1): {
								PhoneTypeCode @(tc: 12): "Mobile",
								PhoneValue: primary.phone
							},
							EMailAddress @(id: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1 ++ "_EmailAddress" ++ "_" ++ indexOfAddress+1 ): {
								//EMailType @(tc: 2): "Personal",
								(EMailType @(tc: filterRef(refdata, "EmailType", primary.emailType).TranslationInput ): primary.emailType) when primary.emailType != null,
								AddrLine: primary.email
							}
						})
					}
				}),
				(contingent default [] map (contingent, indexOfContingent) -> {
					Party @(id: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1): {
						PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", contingent.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", contingent.classification).TranslationInput splitBy "+")[1],
						FullName: contingent.name,
						GovtID: (getNumber(contingent.ss)) when contingent.ss != null otherwise null,
						GovtIDTC @(tc: 1): "Social Security Number" when contingent.ss != null otherwise null,
						Person: {
							FirstName: contingent.firstName,
							MiddleName: contingent.middleName,
							LastName: contingent.lastName,
							Gender @(tc: (filterRef(refdata, "Gender", contingent.gender).TranslationInput splitBy "+")[0]): contingent.gender,
							BirthDate: (contingent.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when contingent.dob != null and contingent.dob != "" otherwise null
						} when (filterRef(refdata, "PartyTypeCode", contingent.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
						Organization: {
							OrgForm @(tc: filterRef(refdata, "OrgFormCode", contingent.classification).TranslationInput) : contingent.classification
							//EstabDate: contingent.details.trust.trustDate
						} when (filterRef(refdata, "PartyTypeCode", contingent.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
						(contingent.addresses default [] map (address, indexOfAddress) -> {
							Address @(id: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1 ++ "_Address" ++ "_" ++ indexOfAddress+1): {
								AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
								Line1: address.address,
								Line2: address.unit,
								City: address.city,
								AddressState: address.state,
								AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
								Zip: address.zip,
								AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
								PrefAddr @(tc: 1): true
							},
							Phone @(id: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1 ++ "_Phone" ++ "_" ++ indexOfAddress+1): {
								PhoneTypeCode @(tc: 12): "Mobile",
								PhoneValue: contingent.phone
							},
							EMailAddress @(id: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1 ++ "_EmailAddress" ++ "_" ++ indexOfAddress+1 ): {
								//EMailType @(tc: 2): "Personal",
								(EMailType @(tc: filterRef(refdata, "EmailType", contingent.emailType).TranslationInput ): contingent.emailType) when contingent.emailType != null,
								AddrLine: contingent.email
							}
						})
					}
				}),
				(owners default [] map (owner, indexOfOwner) -> {
					Party @(id: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1): {
						PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", owner.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", owner.classification).TranslationInput splitBy "+")[1],
						FullName: owner.name,
						GovtID: (getNumber(owner.ss)) when owner.ss != null otherwise null,
						GovtIDTC @(tc: 1): "Social Security Number" when owner.ss != null otherwise null,
						PrefComm @(tc: filterRef(refdata, "PrefComm", owner.communicationPreference).TranslationInput): owner.communicationPreference,
						IDReferenceNo: caseData.customerId when caseData.customerId != null otherwise null,
					    IDReferenceType @(tc: 35): "Customer Number" when caseData.customerId != null otherwise null,
						Person: {
							FirstName: owner.firstName,
							MiddleName: owner.middleName,
							LastName: owner.lastName,
							Gender @(tc: (filterRef(refdata, "Gender", owner.gender).TranslationInput splitBy "+")[0]): owner.gender,
							BirthDate: (owner.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when owner.dob != null and owner.dob != "" otherwise null
						} when (filterRef(refdata, "PartyTypeCode", owner.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
						Organization: {
							OrgForm @(tc: filterRef(refdata, "OrgFormCode", owner.classification).TranslationInput) : owner.classification
							//EstabDate: owner.details.trust.trustDate
						} when (filterRef(refdata, "PartyTypeCode", owner.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
						(owner.addresses default [] map (address, indexOfAddress) -> {
							Address @(id: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1 ++ "_Address" ++ "_" ++ indexOfAddress+1): {
								AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
								Line1: address.address,
								Line2: address.unit,
								City: address.city,
								AddressState: address.state,
								AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
								Zip: address.zip,
								AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
								PrefAddr @(tc: 1): true
							},
							Phone @(id: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1 ++ "_Phone" ++ "_" ++ indexOfAddress+1): {
								PhoneTypeCode @(tc: 12): "Mobile",
								PhoneValue: owner.phone
							},
							EMailAddress @(id: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1 ++ "_EmailAddress" ++ "_" ++ indexOfAddress+1 ): {
								//EMailType @(tc: 2): "Personal",
								(EMailType @(tc: filterRef(refdata, "EmailType", owner.emailType).TranslationInput ): owner.emailType) when owner.emailType != null,
								AddrLine: owner.email
							}
						})
					}
				}),
				
				(agents default [] map (agent, indexOfAgent) -> {
					Party @(id: "Party_CA_" ++ (substituteSpace(agent.role)) ++ "_" ++ indexOfAgent+1): {
						PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", agent.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", agent.classification).TranslationInput splitBy "+")[1],
						FullName: agent.name,
						GovtID: (getNumber(agent.ss)) when agent.ss != null otherwise null,
						GovtIDTC @(tc: 1): "Social Security Number" when agent.ss != null otherwise null,
						IDReferenceNo: agent.details.agent.carrierAgentId,
						IDReferenceType @(tc: 33): "Agent SAID Code",
						PrefComm @(tc: filterRef(refdata, "PrefComm", agent.communicationPreference).TranslationInput): agent.communicationPreference,
						Person: {
							FirstName: agent.firstName,
							MiddleName: agent.middleName,
							LastName: agent.lastName,
							Gender @(tc: (filterRef(refdata, "Gender", agent.gender).TranslationInput splitBy "+")[0]): agent.gender,
							BirthDate: (agent.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when agent.dob != null and agent.dob != "" otherwise null
						} when (filterRef(refdata, "PartyTypeCode", agent.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
						Organization: {
							OrgForm @(tc: filterRef(refdata, "OrgFormCode", agent.classification).TranslationInput) : agent.classification
							//EstabDate: agent.details.trust.trustDate
						} when (filterRef(refdata, "PartyTypeCode", agent.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
						(agent.addresses default [] map (address, indexOfAddress) -> {
							Address @(id: "Party_CA_" ++ (substituteSpace(agent.role)) ++ "_" ++ indexOfAgent+1 ++ "_Address" ++ "_" ++ indexOfAddress+1): {
								AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
								Line1: address.address,
								Line2: address.unit,
								City: address.city,
								AddressState: address.state,
								AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
								(Zip: address.zip) when address.zip?,
								AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
								PrefAddr @(tc: 1): true
							},
							Phone @(id: "Party_CA_" ++ (substituteSpace(agent.role)) ++ "_" ++ indexOfAgent+1 ++ "_Phone" ++ "_" ++ indexOfAddress+1): {
								PhoneTypeCode @(tc: 12): "Mobile",
								PhoneValue: agent.phone
							},
							Producer: {
								License: {
									LicenseNum: agent.details.agent.licenseId
								},
								CarrierAppointment @(id: "CAPPT_" ++ indexOfAgent+1): {
									CompanyProducerID: agent.details.agent.carrierMasterAgentId,
									CarrierCode: filterRef(refdata, "PMHCCarrierCode", sessionVars.ClientCode).TranslationInput
								}
							},
							EMailAddress @(id: "Party_CA_" ++ (substituteSpace(agent.role)) ++ "_" ++ indexOfAgent+1 ++ "_EmailAddress" ++ "_" ++ indexOfAddress+1 ): {
								//EMailType @(tc: 2): "Personal",
								(EMailType @(tc: filterRef(refdata, "EmailType", agent.emailType).TranslationInput ): agent.emailType) when agent.emailType != null,
								AddrLine: agent.email
							}
						})
					}
				}),
				
				(thirdPartyDesignee default [] map (thirdParty, indexOfThirdParty) -> {
					Party @(id: "Party_TP_" ++ (substituteSpace(thirdParty.role)) ++ "_" ++ indexOfThirdParty+1): {
						PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", thirdParty.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", thirdParty.classification).TranslationInput splitBy "+")[1],
						GovtID: (getNumber(thirdParty.ss)) when thirdParty.ss != null otherwise null,
						GovtIDTC @(tc: 1): "Social Security Number" when thirdParty.ss != null otherwise null,
						PrefComm @(tc: filterRef(refdata, "PrefComm", thirdParty.communicationPreference).TranslationInput): thirdParty.communicationPreference,
						Person: {
							FirstName: thirdParty.firstName,
							MiddleName: thirdParty.middleName,
							LastName: thirdParty.lastName,
							Gender @(tc: (filterRef(refdata, "Gender", thirdParty.gender).TranslationInput splitBy "+")[0]): thirdParty.gender,
							BirthDate: (thirdParty.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when thirdParty.dob != null and thirdParty.dob != "" otherwise null
						} when (filterRef(refdata, "PartyTypeCode", thirdParty.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
						Organization: {
							OrgForm @(tc: filterRef(refdata, "OrgFormCode", thirdParty.classification).TranslationInput) : thirdParty.classification
							//EstabDate: thirdParty.details.trust.trustDate
						} when (filterRef(refdata, "PartyTypeCode", thirdParty.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
						(thirdParty.addresses default [] map (address, indexOfAddress) -> {
							Address @(id: "Party_TP_" ++ (substituteSpace(thirdParty.role)) ++ "_" ++ indexOfThirdParty+1 ++ "_Address" ++ "_" ++ indexOfAddress+1): {
								AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
								Line1: address.address,
								Line2: address.unit,
								City: address.city,
								AddressState: address.state,
								AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
								Zip: address.zip,
								AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
								PrefAddr @(tc: 1): true
							},
							Phone @(id: "Party_TP_" ++ (substituteSpace(thirdParty.role)) ++ "_" ++ indexOfThirdParty+1 ++ "_Phone" ++ "_" ++ indexOfAddress+1): {
								PhoneTypeCode @(tc: 12): "Mobile",
								PhoneValue: thirdParty.phone
							},
							EMailAddress @(id: "Party_TP_" ++ (substituteSpace(thirdParty.role)) ++ "_" ++ indexOfThirdParty+1 ++ "_EmailAddress" ++ "_" ++ indexOfAddress+1 ): {
								//EMailType @(tc: 2): "Personal",
								(EMailType @(tc: filterRef(refdata, "EmailType", thirdParty.emailType).TranslationInput ): thirdParty.emailType) when thirdParty.emailType != null,
								AddrLine: thirdParty.email
							}
						})
					}
				}),
				(payor default [] map (payor, indexOfPayor) -> {
					Party @(id: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1): {
						PartyTypeCode @(tc: (filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[1],
						FullName: payor.name,
						(GovtID: (getNumber(payor.ss))) when payor.ss != null ,
						//(GovtIDTC @(tc: 1): "Tax ID Number" when ((filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[0] == "2") otherwise "Social Security Number") when payor.ss != null ,
						(GovtIDTC @(tc: (filterRef(refdata, "GovtIDType", (filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[0]).TranslationInput splitBy "+")[0]): (filterRef(refdata, "GovtIDType", (filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[0]).TranslationInput splitBy "+")[1]) when payor.ss != null,
						(PrefComm @(tc: filterRef(refdata, "PrefComm", payor.communicationPreference).TranslationInput): payor.communicationPreference) when payor.communicationPreference != null,
						Person: {
							FirstName: payor.firstName,
							MiddleName: payor.middleName,
							LastName: payor.lastName,
							Gender @(tc: (filterRef(refdata, "Gender", payor.gender).TranslationInput splitBy "+")[0]): payor.gender,
							BirthDate: (payor.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"}) when payor.dob != null and payor.dob != "" otherwise null
						} when (filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[0] == "1" otherwise null,
						Organization: {
							OrgForm @(tc: filterRef(refdata, "OrgFormCode", payor.classification).TranslationInput) : payor.classification
							//EstabDate: payor.details.trust.trustDate
						} when (filterRef(refdata, "PartyTypeCode", payor.classification).TranslationInput splitBy "+")[0] == "2" otherwise null,
						(payor.addresses default [] map (address, indexOfAddress) -> {
							Address @(id: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1 ++ "_Address" ++ "_" ++ indexOfAddress+1): {
								AddressTypeCode @(tc: filterRef(refdata, "AddressTypeCode", address.type).TranslationInput): address.type,
								Line1: address.address,
								Line2: address.unit,
								City: address.city,
								AddressState: address.state,
								AddressStateTC @(tc: (filterRef(refdata, "Jurisdiction", address.state).TranslationInput splitBy "+")[1]): address.state,
								Zip: address.zip,
								AddressCountryTC @(tc: (filterRef(refdata, "Country", address.country).TranslationInput splitBy "+")[1]): address.country,
								PrefAddr @(tc: 1): true
							},
							Phone @(id: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1 ++ "_Phone" ++ "_" ++ indexOfAddress+1): {
								PhoneTypeCode @(tc: 12): "Mobile",
								PhoneValue: payor.phone
							},
							EMailAddress @(id: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1 ++ "_EmailAddress" ++ "_" ++ indexOfAddress+1 ): {
								//EMailType @(tc: 2): "Personal",
								(EMailType @(tc: filterRef(refdata, "EmailType", payor.emailType).TranslationInput ): payor.emailType) when payor.emailType != null,
								AddrLine: payor.email
							}
						})
					}
				}),
				Relation @(id: "Relation_PI_Insured", OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_PI_1") : {
					OriginatingObjectType @(tc: 4) : "Holding",
					RelatedObjectType @(tc: 6) : "Party",
					RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", insured.role).TranslationInput splitBy "+")[0]) : insured.role
				},
				Relation @(id: "Relation_PI_Owner", OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_PI_1") : {
					OriginatingObjectType @(tc: 4) : "Holding",
					RelatedObjectType @(tc: 6) : "Party",
					RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", "Owner").TranslationInput splitBy "+")[0]) : "Owner"
				} when (parties filter ($.role == 'Owner'))[0].relationship == "Self" otherwise null,
				Relation @(id: "Relation_Holding_Payor", OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_PI_1") : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", "Payor").TranslationInput splitBy "+")[0]) : "Payor"
				} when (parties filter ($.role == 'Payor'))[0].relationship == "Self" otherwise null,
				
				(primary default [] map (primary, indexOfPrimary) -> {
					Relation @(id: "Relation_Holding_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1, OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1) : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", primary.role).TranslationInput splitBy "+")[0]) : primary.role,
						InterestPercent: primary.percentage
					},
					Relation @(id: "Relation_PI_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1, OriginatingObjectID: "Party_PI_1", RelatedObjectID: "Party_PB_" ++ (substituteSpace(primary.role)) ++ "_" ++ indexOfPrimary+1) : {
						OriginatingObjectType @(tc: 6) : "Party",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "RelationRole", primary.relationship).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "RelationRole", primary.relationship).TranslationInput splitBy "+")[1],
						RelationDescription @(tc: (filterRef(refdata, "RelationRoleDescription", primary.relationship).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "RelationRoleDescription", primary.relationship).TranslationInput splitBy "+")[1]
					} when (not (nonNaturalEntityRelations contains primary.relationship)) otherwise null
				}),
				
				(contingent default [] map (contingent, indexOfContingent) -> {
					Relation @(id: "Relation_Holding_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1, OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1) : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", contingent.role).TranslationInput splitBy "+")[0]) : contingent.role,
						InterestPercent: contingent.percentage
					},
					Relation @(id: "Relation_PI_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1, OriginatingObjectID: "Party_PI_1", RelatedObjectID: "Party_CB_" ++ (substituteSpace(contingent.role)) ++ "_" ++ indexOfContingent+1) : {
						OriginatingObjectType @(tc: 6) : "Party",
						RelatedObjectType @(tc: 6) : "Party",
                        RelationRoleCode @(tc: (filterRef(refdata, "RelationRole", contingent.relationship).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "RelationRole", contingent.relationship).TranslationInput splitBy "+")[1],
                        RelationDescription @(tc: (filterRef(refdata, "RelationRoleDescription", contingent.relationship).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "RelationRoleDescription", contingent.relationship).TranslationInput splitBy "+")[1]
					} when (not (nonNaturalEntityRelations contains contingent.relationship)) otherwise null
				}),
				(owners default [] map (owner, indexOfOwner) -> {
					Relation @(id: "Relation_Holding_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1, OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1) : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", owner.role).TranslationInput splitBy "+")[0]) : owner.role,
						InterestPercent: owner.percentage
					},
					Relation @(id: "Relation_PI_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1, OriginatingObjectID: "Party_PI_1", RelatedObjectID: "Party_PO_" ++ (substituteSpace(owner.role)) ++ "_" ++ indexOfOwner+1) : {
						OriginatingObjectType @(tc: 6) : "Party",
						RelatedObjectType @(tc: 6) : "Party",
                        RelationRoleCode @(tc: (filterRef(refdata, "RelationRole", owner.relationship).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "RelationRole", owner.relationship).TranslationInput splitBy "+")[1]
						
					}					
				}),
				(agents default [] map (agent, indexOfAgent) -> {
					Relation @(id: "Relation_Holding_" ++ (substituteSpace(agent.role)) ++ "_" ++ indexOfAgent+1, OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_CA_" ++ (substituteSpace(agent.role)) ++ "_" ++ indexOfAgent+1) : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", agent.role).TranslationInput splitBy "+")[0]) : agent.role,
						InterestPercent: agent.percentage
					}
				}),
				(thirdPartyDesignee default [] map (thirdParty, indexOfThirdParty) -> {
					Relation @(id: "Relation_Holding_" ++ (substituteSpace(thirdParty.role)) ++ "_" ++ indexOfThirdParty+1, OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_TP_" ++ (substituteSpace(thirdParty.role)) ++ "_" ++ indexOfThirdParty+1) : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", thirdParty.role).TranslationInput splitBy "+")[0]) : thirdParty.role,
						InterestPercent: thirdParty.percentage
					}
				}),
				(payor default [] map (payor, indexOfPayor) -> {
					Relation @(id: "Relation_Holding_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1, OriginatingObjectID: "Holding_1", RelatedObjectID: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1) : {
						OriginatingObjectType @(tc: 4) : "Holding",
						RelatedObjectType @(tc: 6) : "Party",
						RelationRoleCode @(tc: (filterRef(refdata, "PartyRole", payor.role).TranslationInput splitBy "+")[0]) : payor.role,
						InterestPercent: payor.percentage
					},
					Relation @(id: "Relation_PI_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1, OriginatingObjectID: "Party_PI_1", RelatedObjectID: "Party_PP_" ++ (substituteSpace(payor.role)) ++ "_" ++ indexOfPayor+1) : {
						OriginatingObjectType @(tc: 6) : "Party",
						RelatedObjectType @(tc: 6) : "Party",
                        RelationRoleCode @(tc: (filterRef(refdata, "RelationRole", payor.relationship).TranslationInput splitBy "+")[0]) : (filterRef(refdata, "RelationRole", payor.relationship).TranslationInput splitBy "+")[1]
						
					}	
				}),
				(Relation @(id : "Relation_9b2d100c-aa2f-49db-8499-a6bead8b6fb4", OriginatingObjectID: "Holding_1", RelatedObjectID : "Holding_1035_1"):{
					OriginatingObjectType @(tc: 4) : "Holding",
					RelatedObjectType @(tc: 4) : "Holding",
					RelationRoleCode @(tc: 63) : "OLI_REL_REPLACED"
				}) when replacementPolicies != null
			}
		}
	}
}
