package com.alramz.exception;

public class EmailValidationException extends RuntimeException {

    private final String code;

    public EmailValidationException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
