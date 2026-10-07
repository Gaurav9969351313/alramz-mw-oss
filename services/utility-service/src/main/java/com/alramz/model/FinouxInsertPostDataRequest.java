package com.alramz.model;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

public record FinouxInsertPostDataRequest(
        @JsonProperty("METHOD") String method,
        @JsonProperty("Version") String version,
        @JsonProperty("PARAM") List<FinouxParam> param) {
}
