package com.alramz.exception;

import com.alramz.exceptions.ApiCallFailedException;
import com.alramz.exceptions.InvalidHttpRequestException;
import com.alramz.model.GenericResponse;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice(basePackages = "com.alramz.controllers")
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<GenericResponse> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + (fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid"))
                .collect(Collectors.joining("; "));

        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "400", "message", message))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("400");
        apiResponse.setResponseMessage("Invalid request");
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(apiResponse);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<GenericResponse> handleConstraint(ConstraintViolationException ex) {
        String message = ex.getConstraintViolations().stream()
                .map(ConstraintViolation::getMessage)
                .collect(Collectors.joining("; "));

        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "400", "message", message))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("400");
        apiResponse.setResponseMessage("Invalid request");
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(apiResponse);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<GenericResponse> handleNotReadable(HttpMessageNotReadableException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "400", "message", "Malformed JSON request"))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("400");
        apiResponse.setResponseMessage("Invalid request");
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(apiResponse);
    }

    @ExceptionHandler(IbanValidationException.class)
    public ResponseEntity<GenericResponse> handleIbanValidation(IbanValidationException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", ex.getCode(), "message", ex.getMessage()))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode(ex.getCode());
        apiResponse.setResponseMessage(ex.getMessage());
        apiResponse.setResponse(response);

        return ResponseEntity.ok(apiResponse);
    }

    @ExceptionHandler(ExternalSystemException.class)
    public ResponseEntity<GenericResponse> handleExternalSystem(ExternalSystemException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "503", "message", ex.getMessage()))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("503");
        apiResponse.setResponseMessage(ex.getMessage());
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(apiResponse);
    }

    @ExceptionHandler(TechnicalException.class)
    public ResponseEntity<GenericResponse> handleTechnical(TechnicalException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "503", "message", ex.getMessage()))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("503");
        apiResponse.setResponseMessage(ex.getMessage());
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(apiResponse);
    }

    @ExceptionHandler(ApplicationException.class)
    public ResponseEntity<GenericResponse> handleApplication(ApplicationException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "503", "message", ex.getMessage()))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("503");
        apiResponse.setResponseMessage(ex.getMessage());
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(apiResponse);
    }

    @ExceptionHandler(ApiCallFailedException.class)
    public ResponseEntity<GenericResponse> handleApiCallFailed(ApiCallFailedException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "503", "message", "IBAN validation service unavailable"))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("503");
        apiResponse.setResponseMessage("IBAN validation service unavailable");
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(apiResponse);
    }

    @ExceptionHandler(InvalidHttpRequestException.class)
    public ResponseEntity<GenericResponse> handleInvalidHttpRequest(InvalidHttpRequestException ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "503", "message", ex.getMessage()))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("503");
        apiResponse.setResponseMessage(ex.getMessage());
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(apiResponse);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<GenericResponse> handleGeneric(Exception ex) {
        Map<String, Object> response = Map.of(
                "errors", List.of(Map.of("code", "503", "message", "Internal server error"))
        );

        GenericResponse apiResponse = new GenericResponse();
        apiResponse.setResponseCode("503");
        apiResponse.setResponseMessage("Internal server error");
        apiResponse.setResponse(response);

        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(apiResponse);
    }
}
