package com.alramz.client;

import com.alramz.config.ETradeProperties;
import com.alramz.model.ETradeResponse;
import com.alramz.exception.ExternalSystemException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.timelimiter.TimeLimiter;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

@org.springframework.stereotype.Service
public class ETradeClient extends AbstractRestClient {

    private final ETradeProperties etradeProperties;

    public ETradeClient(
            @Qualifier("etradeValidationService") WebClient webClient,
            @Qualifier("etradeCircuitBreaker") CircuitBreaker circuitBreaker,
            @Qualifier("etradeRetry") Retry retry,
            @Qualifier("etradeTimeLimiter") TimeLimiter timeLimiter,
            ETradeProperties etradeProperties,
            Environment environment,
            com.fasterxml.jackson.databind.ObjectMapper objectMapper) {
        super(webClient, circuitBreaker, retry, timeLimiter, environment, objectMapper);
        this.etradeProperties = etradeProperties;
    }

    public ETradeResponse callETrade(String accessToken, String endpointPath, String method, Object body, Class<ETradeResponse> responseType) {
        HttpHeaders headers = new HttpHeaders();
        headers.add("access-token", accessToken);

        try {
            return call(
                    HttpMethod.valueOf(method),
                    endpointPath,
                    Object.class,
                    body,
                    responseType,
                    headers,
                    null
            ).block();
        } catch (WebClientResponseException e) {
            throw new ExternalSystemException("eTrade validation service unavailable: " + e.getMessage());
        } catch (Exception e) {
            throw new ExternalSystemException("eTrade validation service unavailable: " + e.getMessage());
        }
    }
}
