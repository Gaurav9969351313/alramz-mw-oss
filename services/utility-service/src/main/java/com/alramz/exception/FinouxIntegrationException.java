package com.alramz.exception;

/**
 * Finoux responded but reported (or implied, via a non-2xx status) a business/backend
 * failure — covers spec.md §6 edge cases #7 (non-2xx HTTP) and #8 (2xx but isSuccess=false or
 * missing post_ID). Always maps to HTTP 500 in {@code GlobalExceptionHandler}.
 */
public class FinouxIntegrationException extends RuntimeException {

    private final String errorCode;

    public FinouxIntegrationException(String errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public String getErrorCode() {
        return errorCode;
    }
}
