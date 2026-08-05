package com.alramz.exception;

import com.alramz.model.ApiResponseIBAN;
import com.alramz.model.IBANValidationResponse;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

        @ExceptionHandler(MethodArgumentNotValidException.class)
        public ResponseEntity<ApiResponseIBAN> handleValidation(MethodArgumentNotValidException ex) {
                String message = ex.getBindingResult().getFieldErrors().stream()
                                .map(fe -> fe.getField() + ": "
                                                + (fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid"))
                                .collect(Collectors.joining("; "));

                IBANValidationResponse response = new IBANValidationResponse();
                response.getErrors().add(Map.of("code", "400", "message", message));

                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                                .body(new ApiResponseIBAN("400", "Invalid request", response));
        }

        @ExceptionHandler(ConstraintViolationException.class)
        public ResponseEntity<ApiResponseIBAN> handleConstraint(ConstraintViolationException ex) {
                String message = ex.getConstraintViolations().stream()
                                .map(ConstraintViolation::getMessage)
                                .collect(Collectors.joining("; "));

                IBANValidationResponse response = new IBANValidationResponse();
                response.getErrors().add(Map.of("code", "400", "message", message));

                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                                .body(new ApiResponseIBAN("400", "Invalid request", response));
        }

        @ExceptionHandler(HttpMessageNotReadableException.class)
        public ResponseEntity<ApiResponseIBAN> handleNotReadable(HttpMessageNotReadableException ex) {
                IBANValidationResponse response = new IBANValidationResponse();
                response.getErrors().add(Map.of("code", "400", "message", "Malformed JSON request"));

                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                                .body(new ApiResponseIBAN("400", "Invalid request", response));
        }

        @ExceptionHandler(IbanValidationException.class)
        public ResponseEntity<ApiResponseIBAN> handleIbanValidation(IbanValidationException ex) {
                IBANValidationResponse response = new IBANValidationResponse();
                response.getErrors().add(Map.of("code", ex.getCode(), "message", ex.getMessage()));

                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                                .body(new ApiResponseIBAN(ex.getCode(), ex.getMessage(), response));
        }

        @ExceptionHandler(Exception.class)
        public ResponseEntity<ApiResponseIBAN> handleGeneric(Exception ex) {
                IBANValidationResponse response = new IBANValidationResponse();
                response.getErrors().add(Map.of("code", "500", "message", "Internal server error"));

                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                .body(new ApiResponseIBAN("500", "Internal server error", response));
        }
}
