package com.alramz.exception;

/**
 * Finoux was unreachable, the connection was refused, or the call timed out — covers spec.md
 * §6 edge case #9. Always maps to HTTP 503 in {@code GlobalExceptionHandler}.
 */
public class FinouxUnavailableException extends RuntimeException {

    private final String errorCode;

    public FinouxUnavailableException(String errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public String getErrorCode() {
        return errorCode;
    }
}
