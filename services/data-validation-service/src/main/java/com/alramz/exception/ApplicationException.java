package com.alramz.exception;

public class ApplicationException extends RuntimeException {

    private final String field;

    public ApplicationException(String field, String message) {
        super(message);
        this.field = field;
    }

    public ApplicationException(String message) {
        super(message);
        this.field = null;
    }

    public String getField() {
        return field;
    }
}
