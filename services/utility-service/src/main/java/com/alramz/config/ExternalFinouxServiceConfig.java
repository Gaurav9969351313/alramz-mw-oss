package com.alramz.config;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryConfig;
import io.github.resilience4j.retry.RetryRegistry;
import io.github.resilience4j.timelimiter.TimeLimiter;
import io.github.resilience4j.timelimiter.TimeLimiterConfig;
import io.github.resilience4j.timelimiter.TimeLimiterRegistry;
import lombok.AllArgsConstructor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Duration;

@Configuration
@EnableConfigurationProperties(FinouxProperties.class)
@Validated
@AllArgsConstructor
public class ExternalFinouxServiceConfig {

    private final FinouxProperties finouxProperties;

    private static final String RESILIENCE_ID = "finoux-community";

    @Bean(name = "finouxService")
    public WebClient finouxService() {
        return WebClient.builder()
                .baseUrl(finouxProperties.getBaseUrl())
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    @Bean(name = "finouxCircuitBreaker")
    public CircuitBreaker finouxCircuitBreaker(CircuitBreakerRegistry registry) {
        return registry.circuitBreaker(RESILIENCE_ID);
    }

    @Bean(name = "finouxRetry")
    public Retry finouxRetry(RetryRegistry registry) {
        // Deliberate divergence from ibanServiceRetry's implicit default (3 attempts): the
        // source migration doc requires the Finoux POST is never auto-retried (no
        // idempotency-key infra backs it) — see spec.md §5.
        RetryConfig config = RetryConfig.custom().maxAttempts(1).build();
        return registry.retry(RESILIENCE_ID, config);
    }

    @Bean(name = "finouxTimeLimiter")
    public TimeLimiter finouxTimeLimiter(TimeLimiterRegistry registry) {
        TimeLimiterConfig config = TimeLimiterConfig.custom()
                .timeoutDuration(Duration.ofSeconds(finouxProperties.getRequestTimeoutSeconds()))
                .build();
        return registry.timeLimiter(RESILIENCE_ID, config);
    }
}
