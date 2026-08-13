package com.alramz.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;

public record ETradeResponse(
    @JsonProperty("Error_code") String errorCode,
    @JsonProperty("IslamicMode") String islamicMode,
    @JsonProperty("Lang") String lang,
    @JsonProperty("Reference_No") String referenceNo,
    JsonNode resData
) {}
