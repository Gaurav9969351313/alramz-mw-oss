package com.alramz.exception;

import com.alramz.model.OnboardingResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import jakarta.servlet.http.HttpServletRequest;

@RestControllerAdvice(assignableTypes = com.alramz.controllers.DataValidationController.class)
@Order(1)
public class OnboardingExceptionHandler {

    @ExceptionHandler(ApplicationException.class)
    public ResponseEntity<OnboardingResponse> handleApplication(ApplicationException ex, HttpServletRequest request) {
        java.util.UUID correlationId = extractCorrelationId(request);

        OnboardingResponse response = new OnboardingResponse();
        response.setResponseCode("400");
        response.setResponseMessage(ex.getField() != null ? ex.getField() + ": " + ex.getMessage() : ex.getMessage());
        response.setMemberReferenceNumber(correlationId);
        response.setInternalErrorCode("ONB011");

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    @ExceptionHandler(org.springframework.web.bind.MethodArgumentNotValidException.class)
    public ResponseEntity<OnboardingResponse> handleValidation(org.springframework.web.bind.MethodArgumentNotValidException ex, HttpServletRequest request) {
        java.util.UUID correlationId = extractCorrelationId(request);

        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + (fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid"))
                .collect(java.util.stream.Collectors.joining("; "));

        OnboardingResponse response = new OnboardingResponse();
        response.setResponseCode("400");
        response.setResponseMessage(message);
        response.setMemberReferenceNumber(correlationId);
        response.setInternalErrorCode("ONB011");

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    @ExceptionHandler(ExternalSystemException.class)
    public ResponseEntity<OnboardingResponse> handleExternalSystem(ExternalSystemException ex, HttpServletRequest request) {
        java.util.UUID correlationId = extractCorrelationId(request);

        OnboardingResponse response = new OnboardingResponse();
        response.setResponseCode("503");
        response.setResponseMessage(ex.getMessage());
        response.setMemberReferenceNumber(correlationId);
        response.setInternalErrorCode("ONB011");

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(response);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<OnboardingResponse> handleGeneric(Exception ex, HttpServletRequest request) {
        java.util.UUID correlationId = extractCorrelationId(request);

        OnboardingResponse response = new OnboardingResponse();
        response.setResponseCode("500");
        response.setResponseMessage("Internal Server Error");
        response.setMemberReferenceNumber(correlationId);
        response.setInternalErrorCode("ONB011");

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }

    private java.util.UUID extractCorrelationId(HttpServletRequest request) {
        String correlationId = request.getHeader("X-Correlation-Id");
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = request.getParameter("correlationId");
        }
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = java.util.UUID.randomUUID().toString();
        }
        return java.util.UUID.fromString(correlationId);
    }
}
