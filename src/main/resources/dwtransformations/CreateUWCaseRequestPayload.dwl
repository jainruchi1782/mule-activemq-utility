%dw 1.0
%output application/xml encoding="utf-8", skipNullOn="everywhere",inlineCloseOn="empty"
%var refdata = flowVars.rdfResponse.value
%var documentURL = payload.documentURL
%var caseData = payload.caseData
%var parties= caseData.parties
%var agents= (parties filter ($.role == 'Agent'))[0] when parties != null otherwise null
%var physicians= (parties filter ($.role == 'Primary Physician'))[0] when parties != null otherwise null
%var insured= (parties filter ($.role == 'Insured'))[0] when parties != null otherwise null
%var owners= (parties filter ($.role == 'Owner')) when (parties != null and (sizeOf (parties filter ($.role == 'Owner'))) <= 5) otherwise (parties filter ($.role == 'Owner'))[0..4]
%var primary= (parties filter ($.role == 'Primary Bene') or ($.role == 'Contingent Bene')) when (parties != null and (sizeOf (parties filter (($.role == 'Primary Bene') or ($.role == 'Contingent Bene')))) <= 6) otherwise (parties filter ($.role == 'Primary Bene') or ($.role == 'Contingent Bene'))[0..5]
%var coverage= caseData.coverage
%var additional= caseData.additional
%var quote= caseData.quote
%var existingPolicies= caseData.additional.existingPolicies when (caseData.additional.existingPolicies != null and (sizeOf caseData.additional.existingPolicies) <= 3) otherwise caseData.additional.existingPolicies[0..2]
%var pendingOrPlannedPolicies= caseData.additional.pendingOrPlannedPolicies when (caseData.additional.pendingOrPlannedPolicies != null and (sizeOf caseData.additional.pendingOrPlannedPolicies) <= 3) otherwise caseData.additional.pendingOrPlannedPolicies[0..2]
%var StartsWith = ((now - (insured.dob as :date)) find "P-")[0]
%var EndsWith = ((now - (insured.dob as :date)) find "Y")[0]
%var mrasOtherCountryFields = ["AX","BQ","CW","BL","MF","SX","Other"]
%var ownerStart = (sizeOf (parties filter ($.role == 'Owner'))) + 1 when (sizeOf (parties filter ($.role == 'Owner'))) < 5 otherwise 5
%var ownerEnd = 5
%var primaryStart = (sizeOf (parties filter ($.role == 'Primary Bene') or ($.role == 'Contingent Bene'))) + 1 when (sizeOf (parties filter ($.role == 'Primary Bene') or ($.role == 'Contingent Bene'))) < 6 otherwise 6
%var primaryEnd = 6
%function getNumber(str) str replace /[- )(]/ with ""
%function filterRef(collection, type, input) (collection filter ($.TranslationType == type and  (upper $.TranslationOutput) == (upper input)))[0]
%function removeSpaces(str) str replace "  " with " "
---
{
	case @(caseId:caseData.caseId, externalReference: caseData.policyNumber): {
		caseProperties: {
			property @(name:'URErbName', ("__text": 'BITESIZED')): '',
			property @(name:'locale', ("__text": 'en')): ''
		},
		caseData: {
			entity @(type:'case', name:'1'): {
				attribute @(name: 'AGENT_CODE', value: agents.details.agent.carrierAgentId): '' when agents.details.agent.carrierAgentId != null otherwise null,
				attribute @(name: 'AGENT_NAME', value: agents.name): '' when agents.name != null otherwise attribute @(name: 'AGENT_NAME', value: (agents.firstName when agents.firstName != null otherwise '') ++ " " ++ (agents.middleName when agents.middleName != null otherwise '') ++ " " ++ (agents.lastName when agents.lastName != null otherwise '' )): '',	
				attribute @(name: 'AGENCY', value: agents.details.agent.carrierAgencyName): '' when agents.details.agent.carrierAgencyName != null otherwise null,	
				attribute @(name: 'CHANNEL', value: agents.details.agent.channel): '' when agents.details.agent.channel != null otherwise null,
				attribute @(name: 'PRODUCT_NAME', value: coverage.productName): '' when coverage.productName != null otherwise null,
				attribute @(name: 'PRODUCT_TYPE', value: (filterRef(refdata, "ProductType", coverage.productType).TranslationInput)): '' when coverage.productType != null otherwise null,
				attribute @(name: 'POLICY_NUMBER', value: caseData.policyNumber): '' when caseData.policyNumber != null otherwise null,
				attribute @(name: 'WEALTHY_GLOBAL_CITIZEN', value: false): '',
				attribute @(name: 'BUSINESS_AREA', value: 'PRIME'): '',
				attribute @(name: 'PAPERS_TO_APP_REF', value: ' '): '',
				attribute @(name: 'COMPETING_PRODUCER', value: false): '',
				attribute @(name: 'BD_NAME', value: agents.details.agent.brokerDealerName): '' when agents.details.agent.brokerDealerName != null otherwise null,
				attribute @(name: 'LIFE_COVERAGE_OPTION', value: 'Lif'): '',
				attribute @(name: 'ALTERNATE_CASE_INDICATOR', value: false): '',
				attribute @(name: 'ADDITIONAL_CASE_INDICATOR', value: false): '',
				attribute @(name: 'GROUP_INDICATOR', value: 'false'): '',
				attribute @(name: 'SURVIVORSHIP', value: 'false'): '',
				attribute @(name: 'CASE_SOURCE', value: caseData.caseSource): '' when caseData.caseSource != null otherwise null,
				attribute @(name: 'STP_CASE_TYPE', value: caseData.caseType): '' when caseData.caseType != null otherwise null
				
			},
			entity @(type:'life', name:'1', parentEntity:'case_1'): {
				attribute @(name: 'RISK_TYPES', value: 'Lif'): '',
				(attribute @(name: 'NAME', value: (removeSpaces((trim (upper ([insured.firstName, insured.middleName default "", insured.lastName] joinBy " ")))))): '') when insured.firstName != null and insured.lastName != null,
				attribute @(name: 'FIRST_NAME', value: upper insured.firstName when insured.firstName != null otherwise null): '' when insured.firstName != null otherwise null,
				attribute @(name: 'MIDDLE_NAME', value: upper insured.middleName when insured.middleName != null otherwise null): '' when insured.middleName != null otherwise null,
				attribute @(name: 'LAST_NAME', value: upper insured.lastName when insured.lastName != null otherwise null): '' when insured.lastName != null otherwise null,
				attribute @(name: 'FORMER_FIRST_NAME', value: upper insured.formerName.firstName when insured.formerName.firstName != null otherwise null): '' when insured.formerName.firstName != null otherwise null,
				attribute @(name: 'FORMER_MIDDLE_NAME', value: upper insured.formerName.middleName when insured.formerName.middleName != null otherwise null): '' when insured.formerName.middleName != null otherwise null,
				attribute @(name: 'FORMER_LAST_NAME', value: upper insured.formerName.lastName when insured.formerName.lastName != null otherwise null): '' when insured.formerName.lastName != null otherwise null,
				attribute @(name: 'FORMER_SUFFIX', value: upper insured.formerName.suffix when insured.formerName.suffix != null otherwise null): '' when insured.formerName.suffix != null otherwise null,
				attribute @(name: 'GENDER', value: (filterRef(refdata, "Gender", insured.gender).TranslationInput)): '' when insured.gender != null otherwise null,
				attribute @(name: 'DATE_OF_BIRTH', value: insured.dob as :date {format: "yyyy-MM-dd"} as :string {format: "yyyy-MM-dd"} when insured.dob != null otherwise null): '' when insured.dob != null otherwise null,
				attribute @(name: 'AGE', value: caseData.quote.issueAge when insured.dob != null otherwise null): '' when insured.dob != null otherwise null,
				attribute @(name: 'SMOKER_STATUS', value: (filterRef(refdata, "TobaccoPremiumBasis", additional.tobaccoUsed).TranslationInput)): '' when additional.tobaccoUsed != null otherwise null,
				attribute @(name: 'UNDERWRITING_METHOD', value: 'FUW'): '',
				attribute @(name: 'PURPOSE_OF_INSURANCE', value: ((filterRef(refdata, "Purpose", additional.purposeOfInsurance[0]).TranslationInput) splitBy "+")[0] default "OLI_HOLDPURP_RETIREMENT"): '',
				attribute @(name: 'ADDITIONAL_INFO', value: 'false'): '',				
				attribute @(name: 'STP_RISK_CLASS', value: (filterRef(refdata, "RiskClass", caseData.underwriting.underwritingRiskClass).TranslationInput)): '' when caseData.underwriting.underwritingRiskClass != null otherwise null,
								
				(owners default [] map (owners, indexOfOwners) -> {
					attribute @(name: 'OWNER_' ++ indexOfOwners+1 ++ '_INSURABLE_INTEREST', value: (filterRef(refdata, "RelationRoleCode", owners.relationship).TranslationInput splitBy "+")[1]): '',
					attribute @(name: 'OWNER_' ++ indexOfOwners+1 ++ '_INSURABLE_INTEREST_PRESENT', value: 'true'): ''
				}),			
				([ownerStart[0] .. ownerEnd[0]] map {
					attribute @(name: 'OWNER_' ++ $ ++ '_INSURABLE_INTEREST_PRESENT', value: 'false'): ''
				} when (sizeOf (parties filter ($.role == 'Owner'))) < 5 otherwise {}),
				attribute @(name: 'ADDITIONAL_OWNERS', value: true when (parties != null and (sizeOf (parties filter ($.role == 'Owner'))) > 5) otherwise false): '',
				(primary default [] map (primary, indexOfPrimary) -> {
					attribute @(name: 'BENEFICIARY_' ++ indexOfPrimary+1 ++ '_INSURABLE_INTEREST', value: (filterRef(refdata, "RelationRoleCode", primary.relationship).TranslationInput splitBy "+")[1]): '',
					attribute @(name: 'BENEFICIARY_' ++ indexOfPrimary+1 ++ '_INSURABLE_INTEREST_PRESENT', value: 'true'): ''
				}),
				([primaryStart[0] .. primaryEnd[0]] map {
					attribute @(name: 'BENEFICIARY_' ++ $ ++ '_INSURABLE_INTEREST_PRESENT', value: 'false'): ''
				} when (sizeOf (parties filter ($.role == 'Primary Bene') or ($.role == 'Contingent Bene'))) < 6 otherwise {}) ,
				attribute @(name: 'ADDITIONAL_BENEFICIARIES', value: true when (parties != null and (sizeOf (parties filter ($.role == 'Primary Bene') or ($.role == 'Contingent Bene'))) > 6) otherwise false): '',
				attribute @(name: 'APPLICATION_STATE', value: ((filterRef(refdata, "Jurisdiction", coverage.state).TranslationInput) splitBy "+")[0]): '' when coverage.state != null otherwise null,
				attribute @(name: 'COUNTRY_OF_BIRTH', value: ((filterRef(refdata, "Country", insured.countryOfBirth).TranslationInput) splitBy "+")[0] when (not (mrasOtherCountryFields contains insured.countryOfBirth)) otherwise 'OLI_OTHER'): '' when insured.countryOfBirth != null otherwise null,
				attribute @(name: 'BIRTH_STATE', value: ((filterRef(refdata, "Jurisdiction", insured.stateOfBirth).TranslationInput) splitBy "+")[0] default "OLI_UNKNOWN"): '',
				attribute @(name: 'TOTAL_ANNUAL_EARNED_INCOME', value: 0): '',
				attribute @(name: 'TOTAL_ANNUAL_EARNED_INCOME_UNKNOWN', value: false): '',
				attribute @(name: 'TOTAL_ANNUAL_UNEARNED_INCOME', value: 0): '',
				attribute @(name: 'TOTAL_ANNUAL_UNEARNED_INCOME_UNKNOWN', value: false): '',
				attribute @(name: 'NET_WORTH', value: 0): '',
				attribute @(name: 'SSN', value: getNumber(insured.ss)): '' when insured.ss != null otherwise null,
				attribute @(name: 'SSN_TRUNCATED', value: (getNumber(insured.ss))[5..8]): '' when insured.ss != null otherwise null,
				attribute @(name: 'PRIMARY_PHONE_AREA_CODE', value: (getNumber(insured.phone))[0..2]): '' when insured.phone != null otherwise null,
				attribute @(name: 'PRIMARY_PHONE_NUMBER', value: (getNumber(insured.phone))[3..9]): '' when insured.phone != null otherwise null,
				attribute @(name: 'ALTERNATE_PHONE_AREA_CODE', value: insured.alternatePhone[0..2]): '' when insured.alternatePhone != null otherwise null,
				attribute @(name: 'ALTERNATE_PHONE_NUMBER', value: insured.alternatePhone[3..9]): '' when insured.alternatePhone != null otherwise null,
				attribute @(name: 'RESIDENCE_ADDRESS_1', value: (insured.addresses filter ($.type == 'Unknown'))[0].address): '' when insured.addresses != null and (insured.addresses filter ($.type == 'Unknown'))[0].address != null otherwise null,
				attribute @(name: 'RESIDENCE_CITY', value: (insured.addresses filter ($.type == 'Unknown'))[0].city): '' when insured.addresses != null and (insured.addresses filter ($.type == 'Unknown'))[0].city != null otherwise null,
				attribute @(name: 'RESIDENCE_STATE', value: ((filterRef(refdata, "Jurisdiction", (insured.addresses filter ($.type == 'Unknown'))[0].state).TranslationInput) splitBy "+")[0]): '' when insured.addresses != null and (insured.addresses filter ($.type == 'Unknown'))[0].state != null otherwise null,
				attribute @(name: 'ZIP', value: (insured.addresses filter ($.type == 'Unknown'))[0].zip): '' when insured.addresses != null and (insured.addresses filter ($.type == 'Unknown'))[0].state != null otherwise null,
				attribute @(name: 'COUNTRY_OF_RESIDENCE', value: ((filterRef(refdata, "Country", (insured.addresses filter ($.type == 'Unknown'))[0].country).TranslationInput) splitBy "+")[0]  default "OLI_NATION_USA"): '',
				attribute @(name: 'APPLICATION_TYPE', value: 'ZIPAPP'): '',
				attribute @(name: 'DISPLAY_FACE_AMOUNT', value: coverage.faceAmount): '' when coverage.faceAmount != null otherwise null,
				attribute @(name: 'FINANCIAL_AMOUNT_WITHIN_LIMITS', value: false): '',
				attribute @(name: 'IS_DEPENDENT_EXTERNAL_SUPPORT', value: false): '',
				(existingPolicies default [] map (existingPolicy, indexOfExistingPolicies) -> {
					attribute @(name: 'PRIOR_IN-FORCE_POLICY_NO_' ++ indexOfExistingPolicies + 1, value: existingPolicy.policyNumber): '' when existingPolicy.policyNumber != null otherwise null,
					attribute @(name: 'PRIOR_IN-FORCE_COMPANY_' ++ indexOfExistingPolicies + 1, value: existingPolicy.company): '' when existingPolicy.company != null otherwise null,
					attribute @(name: 'PRIOR_IN-FORCE_FACE_AMOUNT_' ++ indexOfExistingPolicies + 1, value: existingPolicy.benefitAmt): '' when existingPolicy.benefitAmt != null otherwise null,
					attribute @(name: 'PRIOR_IN-FORCE_ISSUE_YEAR_' ++ indexOfExistingPolicies + 1, value: existingPolicy.issueYear): '' when existingPolicy.issueYear != null otherwise null,
					attribute @(name: 'IS_PRIOR_IN-FORCE_REPLACED_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.isReplacement == "Yes" otherwise false): '',
					attribute @(name: 'IS_PRIOR_IN-FORCE_LIFE_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.lob == 'Life' otherwise false): '',
					attribute @(name: 'IS_PRIOR_IN-FORCE_ANN_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.lob == 'Annuity' otherwise false): '',
					attribute @(name: 'IS_PRIOR_IN-FORCE_INDIV_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.type == 'Individual' otherwise false): '',
					attribute @(name: 'IS_PRIOR_IN-FORCE_GRP_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.type == 'Group' otherwise false): '',
					attribute @(name: 'IS_PRIOR_IN-FORCE_BUS_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.purpose == 'Business' otherwise false): '',
					attribute @(name: 'IS_PRIOR_IN-FORCE_PERS_' ++ indexOfExistingPolicies + 1, value: true when existingPolicy.purpose == 'Personal' otherwise false): ''
				}),
				attribute @(name: 'ADDITIONAL_PRIOR_POLICIES', value: 'true' when (caseData.additional.existingPolicies != null and (sizeOf caseData.additional.existingPolicies) > 3) otherwise 'false'): '',
				(pendingOrPlannedPolicies default [] map (pendingOrPlannedPolicy, indexOfPendingOrPlannedPolicies) -> {
					attribute @(name: 'PENDING_POL_COMPANY_' ++ indexOfPendingOrPlannedPolicies + 1, value: pendingOrPlannedPolicy.company): '' when pendingOrPlannedPolicy.company != null otherwise null,
					attribute @(name: 'PENDING_POL_FACE_AMOUNT_' ++ indexOfPendingOrPlannedPolicies + 1, value: pendingOrPlannedPolicy.faceAmount): '' when pendingOrPlannedPolicy.faceAmount != null otherwise null,
					attribute @(name: 'PENDING_POL_PURPOSE_' ++ indexOfPendingOrPlannedPolicies + 1, value: pendingOrPlannedPolicy.purpose): '' when pendingOrPlannedPolicy.purpose != null otherwise null,
					attribute @(name: 'IS_PENDING_POL_IN_ADDITION_' ++ indexOfPendingOrPlannedPolicies + 1, value: true when pendingOrPlannedPolicy.isAdditional == 'Yes' otherwise false): ''
				}),
				attribute @(name: 'ADDITIONAL_PENDING_POLICIES', value: true when caseData.additional.pendingOrPlannedPolicies != null and (sizeOf caseData.additional.pendingOrPlannedPolicies) > 3 otherwise false): '',
				attribute @(name: 'DRIVERS_LICENSE_NUM', value: insured.driverNumber): '' when insured.driverNumber != null otherwise null,
				attribute @(name: 'DRIVERS_STATE', value: ((filterRef(refdata, "Jurisdiction", insured.driverState).TranslationInput) splitBy "+")[0]): '' when insured.driverState != null otherwise null,
				attribute @(name: 'DRIVERS_LICENSE_RECEIVED', value: true when insured.driverNumber != null otherwise false): '',
				attribute @(name: 'TYPE_OF_REINSURANCE_REQUESTED', value: 'AUTOMATIC'): '',
				attribute @(name: 'REQUESTED_RISK_CLASS', value: (filterRef(refdata, "RiskClass", quote.riskClass).TranslationInput)): '' when quote.riskClass != null otherwise null,
				attribute @(name: 'ELITE_INDICATOR', value: false): '',
				attribute @(name: 'COMBO_TYPE', value: 'NORMAL'): '',
				attribute @(name: 'ADDITIONAL_SECONDARY_POLICY_NOS', value: false): '',
				attribute @(name: 'PRODUCER_PROVIDED_EVIDENCE', value: false): '',
				attribute @(name: 'CASE_ROLE', value: 'PRIMARY'): '',
				aggregate @(type: 'RISK_BASED_VALUES', name: 'Lif'): {
					attribute @(name: 'FACE_AMOUNT', value: coverage.faceAmount): '' when coverage.faceAmount != null otherwise null,
					attribute @(name: 'ORIGINAL_FACE_AMOUNT', value: coverage.faceAmount): '' when coverage.faceAmount != null otherwise null,
					attribute @(name: 'TOTAL_FACE_AMOUNT', value: coverage.faceAmount): '' when coverage.faceAmount != null otherwise null,
					attribute @(name: 'PL_EXISTING_IN_FORCE', value: (sum (caseData.additional.existingPolicies filter ($.isInternal == "Yes" and $.lob != "Annuity" and $.type != "Group")).benefitAmt) default 0) : '',
				    attribute @(name: 'EXTERNAL_EXISTING_IN_FORCE', value: (sum (caseData.additional.existingPolicies filter ($.isInternal != "Yes" and $.lob != "Annuity" and $.type != "Group")).benefitAmt) default 0): '',
					attribute @(name: 'PENDING_TO_BE_PLACED_IN_FORCE', value: (sum (caseData.additional.pendingOrPlannedPolicies).faceAmount) default 0): '',
					attribute @(name: 'INITIAL_COVERAGE_AMOUNT', value: coverage.faceAmount): '' when coverage.faceAmount != null otherwise null
				} when coverage.faceAmount != null otherwise null,
				physicianRef  @(primary: ('true' when (additional.primaryPhysicianInd != null and additional.primaryPhysicianInd == "Yes") otherwise 'false'), id : "physician_" ++ (physicians.roleIndex default "")) : {					
					lastVisitMonth:(additional.primaryPhysicianLastVisitDate splitBy "-")[1] ,
					lastVisitYear:(additional.primaryPhysicianLastVisitDate splitBy "-")[0] ,
					reasonForLastVisit @(code: 'OTHER', tc: '6'): 'Other',
					otherReasonForLastVisit: additional.primaryPhysicianReasonForLastVisit ,
					LastVisitExplicitlyUnknown: additional.lastVisitExplicitlyUnknown 					
				} when additional.primaryPhysicianInd != null and  additional.primaryPhysicianInd == "Yes" otherwise null
			}
		},
		physicians: {
			physician @(id: "physician_" ++ (physicians.roleIndex default "")): {
				name: physicians.name,
				addressLine1: physicians.addresses[0].address,
				addressLine2: "",
				country: physicians.addresses[0].country,
				state: physicians.addresses[0].state,
				city: physicians.addresses[0].city,
				zip: physicians.addresses[0].zip,
				phone: physicians.phone,
				fax: physicians.fax,
				specialty: physicians.specialty
			}
		} when physicians != null otherwise null,
		attachments: {
			(documentURL default [] map (documentURL, indexOfDocumentURL) -> {
				attachment:{
						fileType: documentURL.fileType when documentURL.fileType != null otherwise null,
						docTypeCode: documentURL.docTypeCode when documentURL.docTypeCode != null otherwise null,
						location: "https://" ++ p('http.eim.host') ++ p('http.eim.path') ++ documentURL.url when documentURL.url != null otherwise null
					}	
			})
	} when documentURL != null otherwise null
}}