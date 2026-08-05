package com.alramz.service.impl;

import com.alramz.client.AbstractRestClient;
import com.alramz.config.IbanServiceProperties;
import com.alramz.exception.ApplicationException;
import com.alramz.exception.ExternalSystemException;
import com.alramz.exception.IbanValidationException;
import com.alramz.model.BankData;
import com.alramz.model.GenericResponse;
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
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;

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
    public GenericResponse validate(IBANRequest request) {
        String iban = request.getIBAN();
        if (iban == null || iban.trim().isEmpty()) {
            throw new IbanValidationException("1069", "Missing IBAN");
        }

        if (ibanServiceProperties.apiKey() == null || ibanServiceProperties.apiKey().isEmpty()
                || ibanServiceProperties.baseUrl() == null || ibanServiceProperties.baseUrl().isEmpty()) {
            throw new ExternalSystemException("Failed to retrieve IBAN base URL");
        }

        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("iban", iban);
        params.add("format", "json");
        params.add("api_key", ibanServiceProperties.apiKey());

        IBANValidationResponse externalResponse;
        try {
            externalResponse = call(
                    HttpMethod.GET,
                    "/iban/",
                    Void.class,
                    null,
                    IBANValidationResponse.class,
                    null,
                    params
            ).block();
        } catch (com.alramz.exceptions.ApiCallFailedException e) {
            throw new ExternalSystemException("IBAN validation service unavailable");
        } catch (org.springframework.web.reactive.function.client.WebClientResponseException e) {
            throw new ExternalSystemException("IBAN validation service unavailable");
        } catch (RuntimeException e) {
            throw new ApplicationException("Internal Server Error");
        }

        if (externalResponse == null) {
            throw new ExternalSystemException("IBAN validation service unavailable");
        }

        IBANValidationResponse result = applyValidationRules(externalResponse);
        return createSuccessResponse(result);
    }

    private IBANValidationResponse applyValidationRules(IBANValidationResponse response) {
        Validations validations = response.getValidations();

        if (validations == null) {
            return createSuccessResponse(response.getBankData(), response.getSepaData(), response.getValidations());
        }

        ValidationResult chars = validations.getChars();
        ValidationResult account = validations.getAccount();
        ValidationResult iban = validations.getIban();
        ValidationResult length = validations.getLength();
        ValidationResult countrySupport = validations.getCountrySupport();
        ValidationResult structure = validations.getStructure();

        String charsCode = chars != null ? chars.getCode() : null;
        String accountCode = account != null ? account.getCode() : null;
        String ibanCode = iban != null ? iban.getCode() : null;
        String lengthCode = length != null ? length.getCode() : null;
        String countrySupportCode = countrySupport != null ? countrySupport.getCode() : null;
        String structureCode = structure != null ? structure.getCode() : null;

        // if ("006".equals(charsCode)) {
        //     throw new IbanValidationException("1078", "IBAN contains illegal characters");
        // }

        // if (List.of("004", "002").contains(accountCode)) {
        //     if ("001".equals(ibanCode)) {
        //         throw new IbanValidationException("1075", "IBAN Check digit not correct");
        //     }
        //     if ("005".equals(lengthCode)) {
        //         throw new IbanValidationException("1076", "IBAN Length is not correct");
        //     }
        //     if ("003".equals(countrySupportCode)) {
        //         throw new IbanValidationException("1079", "Country does not support IBAN standard");
        //     }
        //     throw new IbanValidationException("1074", "Account Number check digit not correct");
        // }

        // if ("007".equals(structureCode)) {
        //     throw new IbanValidationException("1077", "IBAN Structure is not correct");
        // }

        return createSuccessResponse(response.getBankData(), response.getSepaData(), response.getValidations());
    }

    private IBANValidationResponse createSuccessResponse(BankData bankData, SepaData sepaData, Validations validations) {
        IBANValidationResponse success = new IBANValidationResponse();
        success.setBankData(bankData);
        success.setSepaData(sepaData);
        success.setValidations(validations);
        return success;
    }

    private GenericResponse createSuccessResponse(IBANValidationResponse validationResponse) {
        GenericResponse response = new GenericResponse();
        response.setResponse(validationResponse);
        response.setResponseMessage("OK");
        response.setResponseCode("200");
        return response;
    }
}