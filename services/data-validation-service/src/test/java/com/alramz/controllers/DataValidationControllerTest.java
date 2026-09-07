package com.alramz.controllers;

import com.alramz.model.GenericResponse;
import com.alramz.model.IBANRequest;
import com.alramz.model.OnboardingRequest;
import com.alramz.model.OnboardingResponse;
import com.alramz.model.PhoneRequest;
import com.alramz.model.ValidationRequest;
import com.alramz.service.IBANValidationService;
import com.alramz.service.OnboardingService;
import com.alramz.service.PhoneValidationService;
import com.alramz.service.ValidationService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class DataValidationControllerTest {

    @Mock
    private IBANValidationService ibanValidationService;

    @Mock
    private PhoneValidationService phoneValidationService;

    @Mock
    private ValidationService validationService;

    @Mock
    private OnboardingService onboardingService;

    @Test
    void validateIBAN_shouldReturnOkResponse() {
        DataValidationController controller = new DataValidationController(ibanValidationService, phoneValidationService, validationService, onboardingService);

        IBANRequest ibanRequest = new IBANRequest();
        GenericResponse genericResponse = new GenericResponse();
        genericResponse.setResponseCode("200");
        genericResponse.setResponseMessage("OK");

        when(ibanValidationService.validate(any(IBANRequest.class))).thenReturn(genericResponse);

        ResponseEntity<GenericResponse> response = controller.validateIBAN(ibanRequest);

        assertThat(response).isNotNull();
        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(genericResponse);
        verify(ibanValidationService).validate(ibanRequest);
    }

    @Test
    void verifyPhone_shouldReturnOkResponse() {
        DataValidationController controller = new DataValidationController(ibanValidationService, phoneValidationService, validationService, onboardingService);

        PhoneRequest phoneRequest = new PhoneRequest();
        GenericResponse genericResponse = new GenericResponse();
        genericResponse.setResponseCode("200");
        genericResponse.setResponseMessage("OK");

        when(phoneValidationService.validate(any(PhoneRequest.class))).thenReturn(genericResponse);

        ResponseEntity<GenericResponse> response = controller.verifyPhone(phoneRequest);

        assertThat(response).isNotNull();
        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(genericResponse);
        verify(phoneValidationService).validate(phoneRequest);
    }

    @Test
    void validateExistingData_shouldReturnOkResponse() {
        DataValidationController controller = new DataValidationController(ibanValidationService, phoneValidationService, validationService, onboardingService);

        ValidationRequest validationRequest = new ValidationRequest();
        GenericResponse genericResponse = new GenericResponse();
        genericResponse.setResponseCode("200");
        genericResponse.setResponseMessage("OK");

        when(validationService.validate(any(ValidationRequest.class))).thenReturn(genericResponse);

        ResponseEntity<GenericResponse> response = controller.validateExistingData(validationRequest);

        assertThat(response).isNotNull();
        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(genericResponse);
        verify(validationService).validate(validationRequest);
    }

    @Test
    void onboard_shouldReturnOkResponse() {
        DataValidationController controller = new DataValidationController(ibanValidationService, phoneValidationService, validationService, onboardingService);

        OnboardingRequest onboardingRequest = new OnboardingRequest();
        OnboardingResponse onboardingResponse = new OnboardingResponse();
        onboardingResponse.setResponseCode("200");
        onboardingResponse.setResponseMessage("OK");

        when(onboardingService.onboard(any(OnboardingRequest.class))).thenReturn(onboardingResponse);

        ResponseEntity<OnboardingResponse> response = controller.onboard(onboardingRequest);

        assertThat(response).isNotNull();
        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(onboardingResponse);
        verify(onboardingService).onboard(onboardingRequest);
    }
}
