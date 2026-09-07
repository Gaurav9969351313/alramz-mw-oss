package com.alramz.service.impl;

import com.alramz.exception.ApplicationException;
import com.alramz.exception.ExternalSystemException;
import com.alramz.exception.TechnicalException;
import com.alramz.model.OnboardingRequest;
import com.alramz.model.OnboardingResponse;
import com.alramz.repository.DfmOnboardingRepository;
import com.alramz.service.DuplicateCheckService;
import com.alramz.service.OnboardingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OnboardingServiceImplTest {

    @Mock
    private DuplicateCheckService duplicateCheckService;

    @Mock
    private DfmOnboardingRepository dfmOnboardingRepository;

    private OnboardingServiceImpl onboardingService;

    @BeforeEach
    void setUp() {
        onboardingService = new OnboardingServiceImpl(duplicateCheckService, dfmOnboardingRepository);
    }

    private OnboardingRequest buildValidRequest() {
        OnboardingRequest request = new OnboardingRequest();
        request.setSecuritykey("SK-123");
        request.setRequestId("REQ-001");
        request.setCustMobile("971502540238");
        request.setCustEmail("test@example.com");
        request.setCustNin("NIN123456");
        request.setFatcaUscitizen("N");
        request.setKycMatch("MATCH");
        request.setEidNationality("ARE");
        request.setPpNationality("ARE");
        request.setPinfCountry("ARE");
        return request;
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenMobileMissing() {
        OnboardingRequest request = buildValidRequest();
        request.setCustMobile(null);

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "cust_mobile");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenEmailMissing() {
        OnboardingRequest request = buildValidRequest();
        request.setCustEmail(null);

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "cust_email");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenNinMissing() {
        OnboardingRequest request = buildValidRequest();
        request.setCustNin(null);

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "cust_nin");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenFatcaMissing() {
        OnboardingRequest request = buildValidRequest();
        request.setFatcaUscitizen(null);

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "fatca_uscitizen");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenKycMissing() {
        OnboardingRequest request = buildValidRequest();
        request.setKycMatch(null);

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "kyc_match");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenNationalityMissing() {
        OnboardingRequest request = buildValidRequest();
        request.setEidNationality(null);
        request.setPpNationality(null);

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "nationality");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenUsCitizenByFatca() {
        OnboardingRequest request = buildValidRequest();
        request.setFatcaUscitizen("Y");

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "fatca_uscitizen")
                .hasMessageContaining("US citizens");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenUsCitizenByEidNationality() {
        OnboardingRequest request = buildValidRequest();
        request.setEidNationality("USA");

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "eid_nationality")
                .hasMessageContaining("US citizens");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenUsCitizenByPpNationality() {
        OnboardingRequest request = buildValidRequest();
        request.setPpNationality("usa");

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "pp_nationality")
                .hasMessageContaining("US citizens");
    }

    @Test
    void onboard_shouldThrowApplicationExceptionWhenUsCitizenByPinfCountry() {
        OnboardingRequest request = buildValidRequest();
        request.setPinfCountry("  UsA  ");

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "pinf_country")
                .hasMessageContaining("US citizens");
    }

    @Test
    void onboard_shouldNormalizeMobileNumber() {
        OnboardingRequest request = buildValidRequest();
        request.setCustMobile("971502540238");

        when(duplicateCheckService.checkDuplicates(any(), any(), any(), any()))
                .thenReturn(new boolean[]{false, false, false, false});

        OnboardingResponse response = onboardingService.onboard(request);

        assertThat(response).isNotNull();
        assertThat(response.getResponseCode()).isEqualTo("200");
        verify(dfmOnboardingRepository).insert(any(OnboardingRequest.class), anyString());
    }

    @Test
    void onboard_shouldCallDuplicateCheckAndNotReject() {
        OnboardingRequest request = buildValidRequest();

        when(duplicateCheckService.checkDuplicates(any(), any(), any(), any()))
                .thenReturn(new boolean[]{true, true, true, true});

        OnboardingResponse response = onboardingService.onboard(request);

        assertThat(response).isNotNull();
        assertThat(response.getResponseCode()).isEqualTo("200");
        verify(duplicateCheckService).checkDuplicates(request.getCustNin(), request.getEidNo(), request.getCustEmail(), request.getPpNo());
        verify(dfmOnboardingRepository).insert(any(OnboardingRequest.class), anyString());
    }

    @Test
    void onboard_shouldReturnSuccessResponse() {
        OnboardingRequest request = buildValidRequest();

        when(duplicateCheckService.checkDuplicates(any(), any(), any(), any()))
                .thenReturn(new boolean[]{false, false, false, false});

        OnboardingResponse response = onboardingService.onboard(request);

        assertThat(response).isNotNull();
        assertThat(response.getResponseCode()).isEqualTo("200");
        assertThat(response.getResponseMessage()).isEqualTo("OK");
        assertThat(response.getMemberReferenceNumber()).isNotNull();
        assertThat(response.getCorrelationId()).isNotNull();
        verify(dfmOnboardingRepository).insert(any(OnboardingRequest.class), anyString());
    }

    @Test
    void onboard_shouldThrowTechnicalExceptionOnPersistenceFailure() {
        OnboardingRequest request = buildValidRequest();

        when(duplicateCheckService.checkDuplicates(any(), any(), any(), any()))
                .thenReturn(new boolean[]{false, false, false, false});
        doThrow(new DataAccessException("DB error") {})
                .when(dfmOnboardingRepository).insert(any(OnboardingRequest.class), anyString());

        assertThatThrownBy(() -> onboardingService.onboard(request))
                .isInstanceOf(TechnicalException.class)
                .hasMessageContaining("Failed to persist onboarding request");
    }
}
