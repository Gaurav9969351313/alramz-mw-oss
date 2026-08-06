package com.alramz.logging.config;

import com.alramz.logging.aspect.MethodExecutionLoggingAspect;
import com.alramz.logging.exception.LoggingExceptionHandler;
import com.alramz.logging.filter.CorrelationIdFilter;
import com.alramz.logging.filter.RequestLoggingFilter;
import com.alramz.logging.filter.ResponseLoggingFilter;
import com.alramz.logging.interceptor.RestTemplateLoggingInterceptor;
import com.alramz.logging.interceptor.WebClientLoggingFilter;
import com.alramz.logging.otel.OpenTelemetryTraceContextExtractor;
import com.alramz.logging.util.LogMaskingUtil;
import com.alramz.logging.util.LoggingHelper;
import jakarta.annotation.PostConstruct;
import jakarta.servlet.Filter;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.*;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;

/**
 * Auto-configuration entry point for the Al Ramz logging starter.
 * <p>
 * Registers the correlation id filter, request/response logging filters,
 * centralized exception handler, optional AOP aspect and outgoing HTTP
 * interceptors. Every bean is only registered when its feature is enabled
 * (via {@code company.logging.*} properties) and when the relevant Spring
 * component is on the classpath, so child applications can override or disable
 * any piece through configuration.
 */
@AutoConfiguration
@EnableConfigurationProperties(LoggingProperties.class)
@ConditionalOnProperty(name = "company.logging.enabled", havingValue = "true", matchIfMissing = true)
public class LoggingAutoConfiguration {

    private final LoggingProperties properties;

    public LoggingAutoConfiguration(LoggingProperties properties) {
        this.properties = properties;
    }

    @PostConstruct
    void configureMasking() {
        LogMaskingUtil.configure(
                properties.getMasking().isEnabled(),
                properties.getMasking().getMaskReplacement(),
                properties.getMasking().getSensitiveKeys(),
                properties.getMasking().getCustomPatterns());
    }

    @Bean
    @ConditionalOnClass(name = "io.opentelemetry.api.trace.Span")
    OpenTelemetryTraceContextExtractor openTelemetryTraceContextExtractor() {
        return new OpenTelemetryTraceContextExtractor();
    }

    @Bean
    LoggingHelper loggingHelper(Environment environment, LoggingProperties properties,
                                ObjectProvider<com.alramz.logging.otel.TraceContextExtractor> extractors) {
        List<com.alramz.logging.otel.TraceContextExtractor> all = extractors.orderedStream().toList();
        return new LoggingHelper(environment, properties, all);
    }

    // ---------------------------------------------------------------- filters

    @Bean
    @ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
    @ConditionalOnClass(Filter.class)
    CorrelationIdFilter alramzCorrelationIdFilter(LoggingProperties properties, LoggingHelper loggingHelper) {
        return new CorrelationIdFilter(properties, loggingHelper);
    }

    @Bean
    @ConditionalOnProperty(name = "company.logging.request.enabled", havingValue = "true", matchIfMissing = true)
    @ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
    RequestLoggingFilter alramzRequestLoggingFilter(LoggingProperties properties, LoggingHelper loggingHelper) {
        return new RequestLoggingFilter(properties, loggingHelper);
    }

    @Bean
    @ConditionalOnProperty(name = "company.logging.response.enabled", havingValue = "true", matchIfMissing = true)
    @ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
    ResponseLoggingFilter alramzResponseLoggingFilter(LoggingProperties properties, LoggingHelper loggingHelper) {
        return new ResponseLoggingFilter(properties, loggingHelper);
    }

    @Bean
    @ConditionalOnProperty(name = "company.logging.exception.enabled", havingValue = "true", matchIfMissing = true)
    @ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
    LoggingExceptionHandler alramzLoggingExceptionHandler() {
        return new LoggingExceptionHandler();
    }

    // ---------------------------------------------------------------- aspect

    @Bean
    @ConditionalOnProperty(name = "company.logging.aspect.enabled", havingValue = "true")
    @ConditionalOnClass(org.aspectj.lang.annotation.Aspect.class)
    MethodExecutionLoggingAspect alramzMethodExecutionLoggingAspect(LoggingProperties properties) {
        return new MethodExecutionLoggingAspect(properties);
    }

    // ----------------------------------------------------- outgoing http logs

    @Bean
    @ConditionalOnClass({RestTemplate.class, ClientHttpRequestInterceptor.class})
    RestTemplateLoggingInterceptor alramzRestTemplateLoggingInterceptor(LoggingProperties properties) {
        return new RestTemplateLoggingInterceptor(properties);
    }

    @Bean
    @ConditionalOnClass(WebClient.class)
    WebClientLoggingFilter alramzWebClientLoggingFilter(LoggingProperties properties) {
        return new WebClientLoggingFilter(properties);
    }

    /**
     * Reusable {@link ExchangeFilterFunction} that logs outgoing reactive HTTP
     * calls and propagates the correlation id. Child applications can wire it
     * into their {@link WebClient.Builder} directly, or rely on the companion
     * {@link WebClientLoggingFilter} bean.
     */
    @Bean
    @ConditionalOnClass(WebClient.class)
    ExchangeFilterFunction alramzWebClientLoggingFilterFunction(LoggingProperties properties) {
        return new WebClientLoggingFilter(properties).filterFunction();
    }
}
