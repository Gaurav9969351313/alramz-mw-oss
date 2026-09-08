package com.alramz.service.impl;

import com.alramz.exception.ApplicationException;
import com.alramz.exception.ExternalSystemException;
import com.alramz.exception.TechnicalException;
import com.alramz.model.OnboardingRequest;
import com.alramz.model.OnboardingResponse;
import com.alramz.repository.DfmOnboardingRepository;
import com.alramz.service.DuplicateCheckService;
import com.alramz.service.OnboardingService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class OnboardingServiceImpl implements OnboardingService {

    private final DuplicateCheckService duplicateCheckService;
    private final DfmOnboardingRepository dfmOnboardingRepository;

    public OnboardingServiceImpl(DuplicateCheckService duplicateCheckService,
                                 DfmOnboardingRepository dfmOnboardingRepository) {
        this.duplicateCheckService = duplicateCheckService;
        this.dfmOnboardingRepository = dfmOnboardingRepository;
    }

    @Override
    public OnboardingResponse onboard(OnboardingRequest request) {
        String correlationId = java.util.UUID.randomUUID().toString();
        String memberReferenceNumber = correlationId;

        validateMandatoryFields(request);
        validateNationalityPresence(request);
        validateUsCitizen(request);

        String normalizedMobile = normalizeMobile(request.getCustMobile());
        request.setCustMobile(normalizedMobile);

        boolean[] duplicates = duplicateCheckService.checkDuplicates(
                request.getCustNin(),
                request.getEidNo(),
                request.getCustEmail(),
                request.getPpNo()
        );

        logDuplicates(duplicates);

        try {
            dfmOnboardingRepository.insert(request, memberReferenceNumber);
        } catch (Exception e) { // NOPMD AvoidCatchingGenericException
            log.error("Failed to persist onboarding request", e);
            throw new TechnicalException("Failed to persist onboarding request: " + e.getMessage());
        }

        OnboardingResponse response = new OnboardingResponse();
        response.setResponseCode("200");
        response.setResponseMessage("OK");
        response.setMemberReferenceNumber(java.util.UUID.fromString(memberReferenceNumber));
        response.setCorrelationId(java.util.UUID.fromString(correlationId));
        return response;
    }

    private void validateMandatoryFields(OnboardingRequest request) {
        if (request.getCustMobile() == null || request.getCustMobile().isBlank()) {
            throw new ApplicationException("cust_mobile", "Mobile Number (cust_mobile) is missing");
        }
        if (request.getCustEmail() == null || request.getCustEmail().isBlank()) {
            throw new ApplicationException("cust_email", "Email Address (cust_email) is missing");
        }
        if (request.getCustNin() == null || request.getCustNin().isBlank()) {
            throw new ApplicationException("cust_nin", "NIN Number (cust_nin) is missing");
        }
        if (request.getFatcaUscitizen() == null || request.getFatcaUscitizen().isBlank()) {
            throw new ApplicationException("fatca_uscitizen", "USCitizen (fatca_uscitizen) is missing");
        }
        if (request.getKycMatch() == null || request.getKycMatch().isBlank()) {
            throw new ApplicationException("kyc_match", "Background check (kyc_match) is missing");
        }
    }

    private void validateNationalityPresence(OnboardingRequest request) {
        boolean hasEidNationality = request.getEidNationality() != null && !request.getEidNationality().isBlank();
        boolean hasPassportNationality = request.getPpNationality() != null && !request.getPpNationality().isBlank();
        if (!hasEidNationality && !hasPassportNationality) {
            throw new ApplicationException("nationality", "Client nationality is missing");
        }
    }

    private void validateUsCitizen(OnboardingRequest request) {
        if (isUsCitizenFlag(request.getFatcaUscitizen())) {
            throw new ApplicationException("fatca_uscitizen", "Online onboarding is unavailable for US citizens");
        }
        if (isUsCitizen(request.getEidNationality())) {
            throw new ApplicationException("eid_nationality", "Online onboarding is unavailable for US citizens - eid_nationality");
        }
        if (isUsCitizen(request.getPpNationality())) {
            throw new ApplicationException("pp_nationality", "Online onboarding is unavailable for US citizens - pp_nationality");
        }
        if (isUsCitizen(request.getPinfCountry())) {
            throw new ApplicationException("pinf_country", "Online onboarding is unavailable for US citizens - pinf_country");
        }
    }

    private boolean isUsCitizenFlag(String value) {
        if (value == null || value.isBlank()) {
            return false;
        }
        return "Y".equals(value.trim().toUpperCase());
    }

    private boolean isUsCitizen(String value) {
        if (value == null || value.isBlank()) {
            return false;
        }
        return "USA".equals(value.trim().toUpperCase());
    }

    private String normalizeMobile(String mobile) {
        if (mobile != null && mobile.startsWith("971")) {
            return "00" + mobile.substring(3);
        }
        return mobile;
    }

    private void logDuplicates(boolean[] duplicates) {
        String[] labels = {"NIN", "EmiratesID", "Email", "Passport"};
        for (int i = 0; i < duplicates.length; i++) {
            if (duplicates[i]) {
                log.warn("Duplicate detected for field: {}", labels[i]);
            }
        }
    }
}
