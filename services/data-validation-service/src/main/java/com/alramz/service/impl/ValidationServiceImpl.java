package com.alramz.service.impl;

import com.alramz.client.ETradeClient;
import com.alramz.config.ETradeProperties;
import com.alramz.config.ETradeTokenProvider;
import com.alramz.config.ValidationDefinition;
import com.alramz.config.ValidationDefinitionRegistry;
import com.alramz.exception.ApplicationException;
import com.alramz.exception.ExternalSystemException;
import com.alramz.exceptions.ApiCallFailedException;
import com.alramz.model.ETradeResponse;
import com.alramz.model.GenericResponse;
import com.alramz.model.ValidationRequest;
import com.alramz.model.ValidationRequest.ValidationTypeEnum;
import com.alramz.model.ValidationResponse;
import com.alramz.service.ValidationRequestMapper;
import com.alramz.service.ValidationResponseMapper;
import com.alramz.service.ValidationResponseMapperRegistry;
import com.alramz.service.ValidationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class ValidationServiceImpl implements ValidationService {

    private final ETradeTokenProvider etradeTokenProvider;
    private final ValidationDefinitionRegistry definitionRegistry;
    private final ValidationRequestMapper requestMapper;
    private final ValidationResponseMapperRegistry responseMapperRegistry;
    private final ETradeClient etradeClient;
    private final ETradeProperties etradeProperties;

    public ValidationServiceImpl(ETradeTokenProvider etradeTokenProvider,
                                 ValidationDefinitionRegistry definitionRegistry,
                                 ValidationRequestMapper requestMapper,
                                 ValidationResponseMapperRegistry responseMapperRegistry,
                                 ETradeClient etradeClient,
                                 ETradeProperties etradeProperties) {
        this.etradeTokenProvider = etradeTokenProvider;
        this.definitionRegistry = definitionRegistry;
        this.requestMapper = requestMapper;
        this.responseMapperRegistry = responseMapperRegistry;
        this.etradeClient = etradeClient;
        this.etradeProperties = etradeProperties;
    }

    @Override
    public GenericResponse validate(ValidationRequest request) {
        validateRequest(request);

        java.util.Optional<String> tokenOpt = etradeTokenProvider.getToken();
        if (tokenOpt.isEmpty()) {
            throw new ExternalSystemException("Failed to obtain eTrade access token");
        }
        String accessToken = tokenOpt.get();

        ValidationDefinition definition = definitionRegistry.get(request.getValidationType());

        ETradeResponse externalResponse = callExternalWithRetry(request, accessToken, definition);

        if (!"0".equals(externalResponse.errorCode())) {
            String errorMessage = externalResponse.resData() != null
                    ? externalResponse.resData().path("message").asText("External API error")
                    : "External API error";
            throw new ExternalSystemException("eTrade validation failed: " + errorMessage);
        }

        ValidationResponseMapper mapper = responseMapperRegistry.get(request.getValidationType());
        ValidationResponse validationResponse = mapper.map(externalResponse, request);

        GenericResponse response = new GenericResponse();
        response.setResponseCode("200");
        response.setResponseMessage("OK");
        response.setResponse(validationResponse);
        return response;
    }

    private ETradeResponse callExternalWithRetry(ValidationRequest request, String accessToken, ValidationDefinition definition) {
        try {
            return etradeClient.callETrade(
                    accessToken,
                    definition.endpoint(),
                    definition.method(),
                    requestMapper.map(request, definition),
                    ETradeResponse.class
            );
        } catch (ApiCallFailedException e) {
            if (e.getResponseCode() == 401) {
                log.warn("Received 401 from eTrade, invalidating token and retrying once");
                etradeTokenProvider.invalidate();
                String freshToken = etradeTokenProvider.getToken()
                        .orElseThrow(() -> new ExternalSystemException("Failed to obtain fresh eTrade access token after 401"));
                return etradeClient.callETrade(
                        freshToken,
                        definition.endpoint(),
                        definition.method(),
                        requestMapper.map(request, definition),
                        ETradeResponse.class
                );
            }
            throw new ExternalSystemException("eTrade validation service unavailable");
        }
    }

    private void validateRequest(ValidationRequest request) {
        ValidationTypeEnum type = request.getValidationType();
        if (type == ValidationTypeEnum.EMAIL_EXISTS) {
            if (request.getEmail() == null || request.getEmail().trim().isEmpty()) {
                throw new ApplicationException("email is required for EMAIL_EXISTS validation");
            }
        } else if (type == ValidationTypeEnum.PASSPORT_EXISTS) {
            if (request.getPassportNumber() == null || request.getPassportNumber().trim().isEmpty()) {
                throw new ApplicationException("passportNumber is required for PASSPORT_EXISTS validation");
            }
        } else if (type == ValidationTypeEnum.NIN_EXISTS) {
            if (request.getNin() == null || request.getNin().trim().isEmpty()) {
                throw new ApplicationException("nin is required for NIN_EXISTS validation");
            }
        } else {
            throw new ApplicationException("Unsupported validation type: " + type);
        }
    }
}
