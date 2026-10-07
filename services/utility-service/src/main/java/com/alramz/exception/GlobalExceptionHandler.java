package com.alramz.exception;

import com.alramz.model.GenericResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Single-envelope-family handler ({@code GenericResponse} only — utility-service has exactly
 * one response contract, unlike data-validation-service's two) modeled on
 * reference-data-service's (non-existent) handler per the exception-handling howto's Step 3
 * skeleton, extended with the errorCode/errorMsg fields this feature's contract requires.
 */
@RestControllerAdvice(basePackages = "com.alramz.controllers")
@Order(0)
public class GlobalExceptionHandler {

    @ExceptionHandler(ApplicationException.class)
    public ResponseEntity<GenericResponse> handleApplication(ApplicationException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.BAD_REQUEST, "Bad Request",
                ex.getServiceErrorResponseCode(), ex.getMessage(), request);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<GenericResponse> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + (fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid"))
                .collect(Collectors.joining("; "));
        String errorCode = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(fe -> mapFieldToErrorCode(fe.getField()))
                .orElse("FNX090");
        return buildResponse(HttpStatus.BAD_REQUEST, "Bad Request", errorCode, message, request);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<GenericResponse> handleNotReadable(HttpMessageNotReadableException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.BAD_REQUEST, "Bad Request", "FNX090", "Malformed JSON request", request);
    }

    @ExceptionHandler(FinouxIntegrationException.class)
    public ResponseEntity<GenericResponse> handleFinouxIntegration(FinouxIntegrationException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Internal Server Error",
                ex.getErrorCode(), ex.getMessage(), request);
    }

    @ExceptionHandler(FinouxUnavailableException.class)
    public ResponseEntity<GenericResponse> handleFinouxUnavailable(FinouxUnavailableException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.SERVICE_UNAVAILABLE, "Service Unavailable",
                ex.getErrorCode(), ex.getMessage(), request);
    }

    // Security fix (04_security): without this explicit handler, Spring's
    // ExceptionHandlerExceptionResolver resolves JwtSecuredAspect's AccessDeniedException
    // (thrown when a valid JWT lacks ROLE_APP_UTILITY) via the catch-all Exception.class
    // handler below BEFORE it can ever reach Spring Security's ExceptionTranslationFilter —
    // the generic Exception handler is checked first because MVC resolves @ExceptionHandler
    // methods inside DispatcherServlet, which runs before the exception could propagate back
    // out to the security filter chain. Without this, every 403 (edge case #12) was silently
    // downgraded to a 500/FNX013, masking authorization-denial visibility (OWASP A01/A09) and
    // failing spec.md §6 edge case #12's acceptance criterion.
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<GenericResponse> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.FORBIDDEN, "Forbidden", null, "Access denied", request);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<GenericResponse> handleGeneric(Exception ex, HttpServletRequest request) {
        // F-07: never leak ex.getMessage()/stack trace for an unexpected failure.
        return buildResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Internal Server Error",
                "FNX013", "Internal Server Error", request);
    }

    private ResponseEntity<GenericResponse> buildResponse(HttpStatus status, String responseMessage,
                                                           String errorCode, String errorMsg,
                                                           HttpServletRequest request) {
        GenericResponse body = new GenericResponse();
        body.setResponseCode(String.valueOf(status.value()));
        body.setResponseMessage(responseMessage);
        body.setErrorCode(errorCode);
        body.setErrorMsg(errorMsg);
        body.setCorrelationId(extractCorrelationId(request));
        return ResponseEntity.status(status).body(body);
    }

    private String mapFieldToErrorCode(String field) {
        if (field == null) {
            return "FNX090";
        }
        String normalized = field.contains(".") ? field.substring(field.lastIndexOf('.') + 1) : field;
        return switch (normalized) {
            case "postedUserId" -> "FNX001";
            case "username" -> "FNX002";
            case "postedBy" -> "FNX003";
            case "postDesc" -> "FNX004";
            case "tagSymbol" -> "FNX005";
            default -> "FNX090";
        };
    }

    private UUID extractCorrelationId(HttpServletRequest request) {
        String correlationId = request.getHeader("X-Correlation-Id");
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = request.getParameter("correlationId");
        }
        if (correlationId == null || correlationId.isBlank()) {
            return UUID.randomUUID();
        }
        try {
            return UUID.fromString(correlationId);
        } catch (IllegalArgumentException ex) {
            return UUID.randomUUID();
        }
    }
}
