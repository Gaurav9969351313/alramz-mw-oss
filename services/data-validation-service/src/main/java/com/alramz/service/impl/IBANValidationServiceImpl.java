package com.alramz.service.impl;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.client.WebClient;

import com.alramz.client.AbstractRestClient;
import com.alramz.config.IbanServiceProperties;
import com.alramz.model.BankData;
import com.alramz.model.IBANRequest;
import com.alramz.model.IBANValidationResponse;
import com.alramz.model.SepaData;
import com.alramz.model.ValidationResult;
import com.alramz.model.Validations;
import com.alramz.service.IBANValidationService;
import com.fasterxml.jackson.databind.ObjectMapper;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.timelimiter.TimeLimiter;

import java.util.List;
import java.util.Map;

@Service
public class IBANValidationServiceImpl extends AbstractRestClient implements IBANValidationService {

    private final IbanServiceProperties ibanServiceProperties;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public IBANValidationServiceImpl(
            @Qualifier("ibanValidationService") WebClient webClient,
            @Qualifier("ibanCircuitBreaker") CircuitBreaker circuitBreaker,
            @Qualifier("ibanRetry") Retry retry,
            @Qualifier("ibanTimeLimiter") TimeLimiter timeLimiter,
            IbanServiceProperties ibanServiceProperties,
            Environment environment,
            ObjectMapper objectMapper
    ) {
        super(webClient, circuitBreaker, retry, timeLimiter, environment, objectMapper);

        this.ibanServiceProperties = ibanServiceProperties;
    }

    @Override
    public IBANValidationResponse validate(IBANRequest request) {
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("iban", request.getIBAN());
        params.add("format", "json");
        params.add("api_key", ibanServiceProperties.apiKey());

        IBANValidationResponse externalResponse = call(
                HttpMethod.GET,
                "/iban/",
                Void.class,
                null,
                IBANValidationResponse.class,
                null,
                params
        ).block();

        if (externalResponse == null) {
            return createErrorResponse("503", "Service unavailable");
        }

        return applyValidationRules(externalResponse);
    }

    private IBANValidationResponse applyValidationRules(IBANValidationResponse response) {
        Validations validations = response.getValidations();
        return createSuccessResponse(response.getBankData(), response.getSepaData(), response.getValidations());
    }

    private IBANValidationResponse createErrorResponse(String code, String message) {
        IBANValidationResponse error = new IBANValidationResponse();
        Map<String, String> errorDetail = Map.of(
                "errorCode", code,
                "errorMessage", message
        );
        error.addErrorsItem(errorDetail);
        return error;
    }

    private IBANValidationResponse createSuccessResponse(BankData bankData, SepaData sepaData, Validations validations) {
        IBANValidationResponse success = new IBANValidationResponse();
        success.setBankData(bankData);
        success.setSepaData(sepaData);
        success.setValidations(validations);
        return success;
    }
}