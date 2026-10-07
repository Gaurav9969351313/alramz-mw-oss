package com.alramz.exception;

import com.alramz.model.GenericResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void handleApplication_shouldReturn400WithExceptionsOwnErrorCode() {
        ApplicationException ex = new ApplicationException("postDesc", "too long", "FNX004");
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleApplication(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getErrorCode()).isEqualTo("FNX004");
        assertThat(response.getBody().getErrorMsg()).isEqualTo("too long");
        assertThat(response.getBody().getCorrelationId()).isNotNull();
    }

    @Test
    void handleValidation_shouldMapPostedUserIdToFNX001() {
        assertFieldMapsToCode("postedUserId", "FNX001");
    }

    @Test
    void handleValidation_shouldMapUsernameToFNX002() {
        assertFieldMapsToCode("username", "FNX002");
    }

    @Test
    void handleValidation_shouldMapPostedByToFNX003() {
        assertFieldMapsToCode("postedBy", "FNX003");
    }

    @Test
    void handleValidation_shouldMapPostDescToFNX004() {
        assertFieldMapsToCode("postDesc", "FNX004");
    }

    @Test
    void handleValidation_shouldMapTagSymbolToFNX005() {
        assertFieldMapsToCode("tagSymbol", "FNX005");
    }

    @Test
    void handleValidation_shouldFallBackToFNX090ForUnmappedField() {
        assertFieldMapsToCode("someUnknownField", "FNX090");
    }

    private void assertFieldMapsToCode(String field, String expectedCode) {
        MethodArgumentNotValidException ex = buildValidationException(field, "must not be blank");
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleValidation(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getErrorCode()).isEqualTo(expectedCode);
    }

    @Test
    void handleNotReadable_shouldReturn400WithFNX090() {
        HttpMessageNotReadableException ex = mock(HttpMessageNotReadableException.class);
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleNotReadable(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getErrorCode()).isEqualTo("FNX090");
        assertThat(response.getBody().getErrorMsg()).isEqualTo("Malformed JSON request");
    }

    @Test
    void handleFinouxIntegration_shouldReturn500WithExceptionsOwnErrorCode() {
        FinouxIntegrationException ex = new FinouxIntegrationException("FNX011", "isSuccess=false");
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleFinouxIntegration(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody().getErrorCode()).isEqualTo("FNX011");
        assertThat(response.getBody().getErrorMsg()).isEqualTo("isSuccess=false");
    }

    @Test
    void handleFinouxUnavailable_shouldReturn503WithFNX012() {
        FinouxUnavailableException ex = new FinouxUnavailableException("FNX012", "Finoux community service unavailable");
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleFinouxUnavailable(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getBody().getErrorCode()).isEqualTo("FNX012");
    }

    @Test
    void handleAccessDenied_shouldReturn403NotBeSwallowedByGenericHandler() {
        // Regression test (04_security): JwtSecuredAspect throws this exact exception type
        // when a valid JWT lacks ROLE_APP_UTILITY. Before this handler existed, it was caught
        // by handleGeneric (Exception.class is a supertype), silently turning a 403 into a 500.
        AccessDeniedException ex = new AccessDeniedException("Insufficient role. Required one of: [APP_UTILITY]");
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleAccessDenied(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody().getErrorMsg()).isEqualTo("Access denied");
        assertThat(response.getBody().getErrorMsg()).doesNotContain("APP_UTILITY");
        assertThat(response.getBody().getCorrelationId()).isNotNull();
    }

    @Test
    void handleGeneric_shouldReturn500WithFNX013AndNeverLeakExceptionMessage() {
        RuntimeException ex = new RuntimeException("leaked internal stack trace detail");
        HttpServletRequest request = requestWithNoCorrelationId();

        ResponseEntity<GenericResponse> response = handler.handleGeneric(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody().getErrorCode()).isEqualTo("FNX013");
        assertThat(response.getBody().getErrorMsg()).isEqualTo("Internal Server Error");
        assertThat(response.getBody().getErrorMsg()).doesNotContain("leaked internal stack trace detail");
    }

    @Test
    void handleApplication_shouldUseHeaderCorrelationIdWhenPresent() {
        ApplicationException ex = new ApplicationException("postDesc", "too long", "FNX004");
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader("X-Correlation-Id")).thenReturn("2afe4a42-44f7-4e12-aae7-df0e42d4d757");

        ResponseEntity<GenericResponse> response = handler.handleApplication(ex, request);

        assertThat(response.getBody().getCorrelationId().toString()).isEqualTo("2afe4a42-44f7-4e12-aae7-df0e42d4d757");
    }

    @Test
    void handleApplication_shouldGenerateRandomCorrelationIdWhenHeaderIsNotAValidUuid() {
        ApplicationException ex = new ApplicationException("postDesc", "too long", "FNX004");
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader("X-Correlation-Id")).thenReturn("not-a-uuid");

        ResponseEntity<GenericResponse> response = handler.handleApplication(ex, request);

        assertThat(response.getBody().getCorrelationId()).isNotNull();
    }

    private HttpServletRequest requestWithNoCorrelationId() {
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader("X-Correlation-Id")).thenReturn(null);
        when(request.getParameter("correlationId")).thenReturn(null);
        return request;
    }

    private MethodArgumentNotValidException buildValidationException(String field, String message) {
        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult(new Object(), "communityPostRequest");
        bindingResult.addError(new FieldError("communityPostRequest", field, message));
        Method method;
        try {
            method = GlobalExceptionHandlerTest.class.getDeclaredMethod("dummyTarget", String.class);
        } catch (NoSuchMethodException e) {
            throw new IllegalStateException(e);
        }
        MethodParameter parameter = new MethodParameter(method, 0);
        return new MethodArgumentNotValidException(parameter, bindingResult);
    }

    @SuppressWarnings("unused")
    private void dummyTarget(String arg) {
        // used only to build a MethodParameter for MethodArgumentNotValidException in tests
    }

    @Test
    void handleValidation_shouldJoinMultipleFieldErrorMessages() {
        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult(new Object(), "communityPostRequest");
        bindingResult.addError(new FieldError("communityPostRequest", "username", "must not be blank"));
        bindingResult.addError(new FieldError("communityPostRequest", "postedBy", "size must be between 1 and 45"));
        Method method;
        try {
            method = GlobalExceptionHandlerTest.class.getDeclaredMethod("dummyTarget", String.class);
        } catch (NoSuchMethodException e) {
            throw new IllegalStateException(e);
        }
        MethodArgumentNotValidException ex = new MethodArgumentNotValidException(new MethodParameter(method, 0), bindingResult);

        ResponseEntity<GenericResponse> response = handler.handleValidation(ex, requestWithNoCorrelationId());

        assertThat(response.getBody().getErrorMsg()).contains("username").contains("postedBy");
        assertThat(response.getBody().getErrorCode()).isEqualTo("FNX002");
    }
}
