package com.alramz.logging.interceptor;

import com.alramz.logging.config.LoggingProperties;
import com.alramz.logging.util.LogMaskingUtil;
import com.alramz.logging.util.MDCUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpMethod;
import org.springframework.web.reactive.function.client.ClientRequest;
import org.springframework.web.reactive.function.client.ClientResponse;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
import org.springframework.web.reactive.function.client.ExchangeFunction;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.time.Duration;

/**
 * Reactive counterpart of {@link RestTemplateLoggingInterceptor}. Produces an
 * {@link ExchangeFilterFunction} that logs outgoing
 * {@link org.springframework.web.reactive.function.client.WebClient} calls,
 * propagates the correlation id and enforces the performance threshold.
 */
public class WebClientLoggingFilter {

    private static final Logger logger = LoggerFactory.getLogger(WebClientLoggingFilter.class);

    private final LoggingProperties properties;

    public WebClientLoggingFilter(LoggingProperties properties) {
        this.properties = properties;
    }

    public ExchangeFilterFunction filterFunction() {
        return (clientRequest, next) -> {
            String headerName = properties.getCorrelationId().getHeader();
            String correlationId = MDCUtil.getCorrelationId();
            ClientRequest effectiveRequest = correlationId != null
                    && !clientRequest.headers().containsHeader(headerName)
                    ? ClientRequest.from(clientRequest)
                        .headers(headers -> headers.set(headerName, correlationId))
                        .build()
                    : clientRequest;

            long start = System.nanoTime();
            if (logger.isInfoEnabled()) {
                logger.info("Outgoing {} {} (correlationId={})",
                        effectiveRequest.method(), effectiveRequest.url(), correlationId);
            }
            return next.exchange(effectiveRequest)
                    .doOnSuccess(response -> {
                        long elapsedMs = (System.nanoTime() - start) / 1_000_000L;
                        int status = response.statusCode().value();
                        logger.info("Outgoing response {} {} in {}ms status={}",
                                effectiveRequest.method(), effectiveRequest.url(), elapsedMs, status);
                        warnIfSlow(elapsedMs, "outgoing call");
                    })
                    .doOnError(error -> {
                        long elapsedMs = (System.nanoTime() - start) / 1_000_000L;
                        if (logger.isErrorEnabled()) {
                            logger.error("Outgoing {} {} failed in {}ms (correlationId={})",
                                    effectiveRequest.method(), effectiveRequest.url(), elapsedMs, correlationId, error);
                        }
                    });
        };
    }

    public static ExchangeFilterFunction of(LoggingProperties properties) {
        return new WebClientLoggingFilter(properties).filterFunction();
    }

    private void warnIfSlow(long durationMs, String context) {
        Duration threshold = properties.getPerformance().getThreshold();
        if (threshold != null && durationMs > threshold.toMillis()) {
            logger.warn("Slow {} detected: {}ms (threshold {}ms)", context, durationMs, threshold.toMillis());
        }
    }
}
