package com.alramz.exception;

import com.alramz.exception.ApplicationException;
import com.alramz.exception.ExternalSystemException;
import com.alramz.exception.IbanValidationException;
import com.alramz.exception.TechnicalException;
import com.alramz.exceptions.ApiCallFailedException;
import com.alramz.exceptions.InvalidHttpRequestException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.context.request.WebRequest;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;

import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void handleValidation_shouldReturnBadRequest() {
        MethodArgumentNotValidException ex = org.mockito.Mockito.mock(MethodArgumentNotValidException.class);
        org.springframework.validation.BindingResult bindingResult = org.mockito.Mockito.mock(org.springframework.validation.BindingResult.class);
        org.springframework.validation.FieldError fieldError = new org.springframework.validation.FieldError("field", "field", "default message");
        
        when(ex.getBindingResult()).thenReturn(bindingResult);
        when(bindingResult.getFieldErrors()).thenReturn(List.of(fieldError));
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleValidation(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void handleConstraint_shouldReturnBadRequest() {
        ConstraintViolationException ex = new ConstraintViolationException("constraint", Set.of());
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleConstraint(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void handleIbanValidation_shouldReturnBadRequest() {
        IbanValidationException ex = new IbanValidationException("1069", "validation error");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleIbanValidation(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getResponseCode()).isEqualTo("400");
    }

    @Test
    void handleExternalSystem_shouldReturnServiceUnavailable() {
        ExternalSystemException ex = new ExternalSystemException("external error");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleExternalSystem(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }

    @Test
    void handleTechnical_shouldReturnServiceUnavailable() {
        TechnicalException ex = new TechnicalException("technical error");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleTechnical(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }

    @Test
    void handleApplication_shouldReturnBadRequest() {
        ApplicationException ex = new ApplicationException("field", "test message");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleApplication(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getResponseCode()).isEqualTo("400");
    }

    @Test
    void handleApiCallFailed_shouldReturnServiceUnavailable() {
        ApiCallFailedException ex = new ApiCallFailedException("/path", "POST", 500, "error");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleApiCallFailed(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }

    @Test
    void handleInvalidHttpRequest_shouldReturnServiceUnavailable() {
        InvalidHttpRequestException ex = new InvalidHttpRequestException("invalid request");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleInvalidHttpRequest(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }

    @Test
    void handleGeneric_shouldReturnServiceUnavailable() {
        Exception ex = new Exception("generic error");
        
        ResponseEntity<com.alramz.model.GenericResponse> response = handler.handleGeneric(ex);
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }
}
