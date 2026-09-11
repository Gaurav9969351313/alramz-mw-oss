package com.alramz.audit;

import com.alramz.logging.config.LoggingProperties;
import com.alramz.logging.util.MDCUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcOperations;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Slf4j
public class ApiAuditLogService {

    private static final String SQL = """
            INSERT INTO api_audit_log
            (correlation_id, direction, service_name, controller_name, api_endpoint, method,
             request, response, status, status_code, exception_cause, exception_class, duration_ms, created_at)
            VALUES (:correlationId, :direction, :serviceName, :controllerName, :apiEndpoint, :method,
                    CAST(:request AS JSON), CAST(:response AS JSON), :status, :statusCode, :exceptionCause, :exceptionClass, :durationMs, :createdAt)
            """;

    private static final String CLEANUP_SQL = "DELETE FROM api_audit_log WHERE created_at < NOW() - INTERVAL '%d days'";

    private final NamedParameterJdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final LoggingProperties properties;
    private final SensitiveDataMasker masker;

    public ApiAuditLogService(@Qualifier("middlewareNamedParameterJdbcTemplate") NamedParameterJdbcTemplate jdbcTemplate,
                              ObjectMapper objectMapper,
                              LoggingProperties properties) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper.copy()
                .registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule())
                .disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        this.properties = properties;
        this.masker = new SensitiveDataMasker(objectMapper, properties.getMasking().isEnabled()); // NOPMD LawOfDemeter
    }

    public void log(ApiAuditLog entry) {
        try {
            Map<String, Object> params = new HashMap<>();
            params.put("correlationId", entry.correlationId());
            params.put("direction", entry.direction());
            params.put("serviceName", entry.serviceName());
            params.put("controllerName", entry.controllerName());
            params.put("apiEndpoint", entry.apiEndpoint());
            params.put("method", entry.method());
            params.put("request", toJson(masker.mask(entry.request())));
            params.put("response", toJson(masker.mask(entry.response())));
            params.put("status", entry.status());
            params.put("statusCode", entry.statusCode());
            params.put("exceptionCause", entry.exceptionCause());
            params.put("exceptionClass", entry.exceptionClass());
            params.put("durationMs", entry.durationMs());
            params.put("createdAt", Timestamp.from(entry.createdAt()));

            jdbcTemplate.update(SQL, params);

            // Put audit params into MDC so SeqAppender captures them as structured fields
            MDCUtil.put("Direction", entry.direction());
            MDCUtil.put("Service", entry.serviceName());
            MDCUtil.put("Controller", entry.controllerName());
            MDCUtil.put("Endpoint", entry.apiEndpoint());
            MDCUtil.put("Method", entry.method());
            MDCUtil.put("Status", entry.status());
            MDCUtil.put("StatusCode", String.valueOf(entry.statusCode()));
            MDCUtil.put("DurationMs", String.valueOf(entry.durationMs()));
            MDCUtil.put("ExceptionCause", entry.exceptionCause());
            MDCUtil.put("ExceptionClass", entry.exceptionClass());
            String auditRequest = toJson(masker.mask(entry.request()));
            String auditResponse = toJson(masker.mask(entry.response()));
            MDCUtil.put("Request", auditRequest);
            MDCUtil.put("Response", auditResponse);

            try {
                log.info("API Audit: direction={} service={} controller={} endpoint={} method={} status={} statusCode={} durationMs={} correlationId={} exceptionCause={} exceptionClass={} request={} response={}",
                        entry.direction(),
                        entry.serviceName(),
                        entry.controllerName(),
                        entry.apiEndpoint(),
                        entry.method(),
                        entry.status(),
                        entry.statusCode(),
                        entry.durationMs(),
                        entry.correlationId(),
                        entry.exceptionCause(),
                        entry.exceptionClass(),
                        auditRequest,
                        auditResponse);
            } finally {
                MDCUtil.remove("Direction");
                MDCUtil.remove("Service");
                MDCUtil.remove("Controller");
                MDCUtil.remove("Endpoint");
                MDCUtil.remove("Method");
                MDCUtil.remove("Status");
                MDCUtil.remove("StatusCode");
                MDCUtil.remove("DurationMs");
                MDCUtil.remove("ExceptionCause");
                MDCUtil.remove("ExceptionClass");
                MDCUtil.remove("Request");
                MDCUtil.remove("Response");
            }
        } catch (Exception e) { // NOPMD AvoidCatchingGenericException
            log.error("Failed to insert api_audit_log", e);
        }
    }

    private String toJson(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) { // NOPMD AvoidCatchingGenericException
            log.warn("Failed to serialize audit payload to JSON", e);
            return null;
        }
    }

    @Scheduled(cron = "${company.logging.database-logging.cleanup-cron:0 0 2 * * *}")
    public void cleanupExpired() {
        try {
            LoggingProperties.DatabaseLoggingProperties databaseLogging = properties.getDatabaseLogging();
            int retentionDays = databaseLogging.getRetentionDays();
            String sql = String.format(CLEANUP_SQL, retentionDays);
            int deleted = jdbcTemplate.update(sql, Map.of());
            log.info("Cleaned up {} expired api_audit_log entries (retention={} days)", deleted, retentionDays);
        } catch (Exception e) { // NOPMD AvoidCatchingGenericException
            log.error("Failed to cleanup expired api_audit_log entries", e);
        }
    }

    public SensitiveDataMasker getMasker() {
        return masker;
    }
}
