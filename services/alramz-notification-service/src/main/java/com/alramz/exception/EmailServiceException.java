package com.alramz.exception;

public class EmailServiceException extends RuntimeException {

    private final int statusCode;

    public EmailServiceException(int statusCode, String message) {
        super(message);
        this.statusCode = statusCode;
    }

    public EmailServiceException(int statusCode, String message, Throwable cause) {
        super(message, cause);
        this.statusCode = statusCode;
    }

    public int getStatusCode() {
        return statusCode;
    }
}
