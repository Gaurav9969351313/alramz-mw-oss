package com.alramz.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public record FinouxInsertPostDataResponse(Boolean isSuccess, String message, FinouxData data) {
}
