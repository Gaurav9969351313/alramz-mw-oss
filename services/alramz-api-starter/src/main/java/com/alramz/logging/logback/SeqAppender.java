package com.alramz.logging.logback;

import com.alramz.logging.util.MDCUtil;
import ch.qos.logback.classic.spi.IThrowableProxy;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.AppenderBase;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;

public class SeqAppender extends AppenderBase<ILoggingEvent> {

    private static final Logger auditLogger = LoggerFactory.getLogger(SeqAppender.class);

    private static final String LEVEL_ERROR = "Error";
    private static final String LEVEL_WARNING = "Warning";
    private static final String LEVEL_INFORMATION = "Information";
    private static final String LEVEL_DEBUG = "Debug";
    private static final String LEVEL_VERBOSE = "Verbose";

    private static final String HEADER_API_KEY = "X-Seq-ApiKey";
    private static final String CONTENT_TYPE = "application/vnd.seq.clef; charset=utf-8";
    private static final String INGEST_PATH = "/ingest/clef";

    private static final long BASE_BACKOFF_MS = 1000L;
    private static final long MAX_BACKOFF_MS = 5000L;

    private String url = "http://localhost:5341";
    private String apiKey = "";
    private boolean enabled = false;
    private String serviceName = "application";

    private int batchSize = 50;
    private int flushIntervalMs = 1000;
    private int queueSize = 50000;
    private int connectTimeoutMs = 3000;
    private int requestTimeoutMs = 5000;
    private int maxRetries = 3;

    private boolean circuitBreakerEnabled = false;
    private int circuitBreakerFailureThreshold = 3;
    private long circuitBreakerCooldownMs = 10000L;

    private transient HttpClient httpClient;
    private transient ObjectMapper objectMapper;
    private transient java.util.concurrent.BlockingQueue<ILoggingEvent> queue;

    private enum CircuitState { CLOSED, OPEN, HALF_OPEN }

    private transient volatile CircuitState circuitState = CircuitState.CLOSED;
    private transient volatile int failureCount = 0;
    private transient volatile long lastFailureTime = 0L;

    private transient Thread flushThread;
    private transient volatile boolean running = false;

    @Override
    public void start() {
        if (!enabled) {
            return;
        }
        super.start();
        this.objectMapper = new ObjectMapper();
        this.queue = new java.util.concurrent.LinkedBlockingQueue<>(queueSize);
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(connectTimeoutMs))
                .version(HttpClient.Version.HTTP_1_1)
                .build();
        this.running = true;
        this.circuitState = CircuitState.CLOSED;
        this.failureCount = 0;
        this.lastFailureTime = 0L;
        this.flushThread = new Thread(this::flushLoop, "seq-flush-" + serviceName);
        this.flushThread.setDaemon(true);
        this.flushThread.start();
        auditLogger.info("SeqAppender started: url={}, batchSize={}, flushIntervalMs={}, queueSize={}", url, batchSize, flushIntervalMs, queueSize);
    }

    @Override
    public void stop() {
        if (!running) {
            super.stop();
            return;
        }
        running = false;
        if (flushThread != null) {
            flushThread.interrupt();
            try {
                flushThread.join(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        drainQueue();
        if (httpClient != null) {
            httpClient = null;
        }
        super.stop();
        auditLogger.info("SeqAppender stopped");
    }

    @Override
    public void append(ILoggingEvent event) {
        if (!isStarted() || !enabled) {
            return;
        }
        try {
            queue.put(event);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            auditLogger.warn("Interrupted while queueing log event for Seq", e);
        }
    }

    private void drainQueue() {
        java.util.List<ILoggingEvent> batch = new java.util.ArrayList<>(batchSize);
        queue.drainTo(batch, batchSize);
        if (!batch.isEmpty()) {
            flushBatch(batch, false);
        }
    }

    private void flushLoop() {
        while (running) {
            try {
                java.util.List<ILoggingEvent> batch = new java.util.ArrayList<>(batchSize);
                ILoggingEvent head = queue.poll(flushIntervalMs, java.util.concurrent.TimeUnit.MILLISECONDS);
                if (head != null) {
                    batch.add(head);
                    queue.drainTo(batch, batchSize - 1);
                }
                if (!batch.isEmpty()) {
                    flushBatch(batch, true);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                auditLogger.warn("Unexpected error in Seq flush loop", e);
            }
        }
    }

    private void flushBatch(java.util.List<ILoggingEvent> batch, boolean retryOnFailure) {
        if (!canSend()) {
            return;
        }
        StringBuilder payload = new StringBuilder();
        ObjectNode eventNode;
        for (ILoggingEvent event : batch) {
            eventNode = buildEventMap(event);
            try {
                payload.append(objectMapper.writeValueAsString(eventNode)).append('\n');
            } catch (JsonProcessingException e) {
                auditLogger.warn("Failed to serialize Seq log event", e);
            }
        }
        if (payload.isEmpty()) {
            return;
        }
        postWithRetry(payload.toString(), retryOnFailure);
    }

    private boolean canSend() {
        if (!circuitBreakerEnabled) {
            return true;
        }
        long now = System.currentTimeMillis();
        switch (circuitState) {
            case CLOSED:
                return true;
            case OPEN:
                if (now - lastFailureTime >= circuitBreakerCooldownMs) {
                    circuitState = CircuitState.HALF_OPEN;
                    return true;
                }
                return false;
            case HALF_OPEN:
                return true;
            default:
                return true;
        }
    }

    private void recordSuccess() {
        if (!circuitBreakerEnabled) {
            return;
        }
        switch (circuitState) {
            case HALF_OPEN:
            case OPEN:
                circuitState = CircuitState.CLOSED;
                failureCount = 0;
                lastFailureTime = 0L;
                break;
            case CLOSED:
            default:
                break;
        }
    }

    private void recordFailure() {
        if (!circuitBreakerEnabled) {
            return;
        }
        failureCount++;
        lastFailureTime = System.currentTimeMillis();
        if (failureCount >= circuitBreakerFailureThreshold) {
            circuitState = CircuitState.OPEN;
            auditLogger.warn("Seq circuit breaker opened after {} failures", failureCount);
        }
    }

    private void postWithRetry(String payload, boolean retryOnFailure) {
        int attempt = 0;
        long backoff = BASE_BACKOFF_MS;
        while (attempt <= maxRetries) {
            try {
                HttpRequest.Builder builder = HttpRequest.newBuilder()
                        .uri(URI.create(url + INGEST_PATH))
                        .timeout(Duration.ofMillis(requestTimeoutMs))
                        .header("Content-Type", CONTENT_TYPE);
                if (!apiKey.isBlank()) {
                    builder.header(HEADER_API_KEY, apiKey);
                }
                HttpRequest request = builder.POST(HttpRequest.BodyPublishers.ofString(payload)).build();
                HttpResponse<Void> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
                int status = response.statusCode();
                if (status >= 200 && status < 300) {
                    recordSuccess();
                    return;
                }
                auditLogger.warn("Seq ingestion returned status {} on attempt {}", status, attempt + 1);
            } catch (Exception e) {
                auditLogger.warn("Seq ingestion failed on attempt {}: {}", attempt + 1, e.getMessage());
            }
            attempt++;
            if (attempt > maxRetries || !retryOnFailure) {
                break;
            }
            try {
                Thread.sleep(backoff);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                break;
            }
            backoff = Math.min(backoff * 2, MAX_BACKOFF_MS);
        }
        recordFailure();
    }

    private ObjectNode buildEventMap(ILoggingEvent event) {
        ObjectNode node = objectMapper.createObjectNode();
        node.put("@t", Instant.ofEpochMilli(event.getTimeStamp()).toString());
        node.put("@mt", event.getFormattedMessage());
        node.put("@l", mapLevel(event.getLevel()));
        node.put("thread", event.getThreadName());
        node.put("logger", event.getLoggerName());

        Map<String, String> mdcContext = event.getMDCPropertyMap();
        if (mdcContext != null) {
            for (Map.Entry<String, String> entry : mdcContext.entrySet()) {
                String key = entry.getKey();
                String value = entry.getValue();
                if (value == null) {
                    continue;
                }
                switch (key) {
                    case "correlationId" -> node.put("correlationID", value);
                    case "traceId" -> node.put("traceId", value);
                    case "spanId" -> node.put("spanId", value);
                    case "responseStatus" -> node.put("responseCode", value);
                    default -> node.put(key, value);
                }
            }
        }

        IThrowableProxy throwableProxy = event.getThrowableProxy();
        if (throwableProxy != null) {
            node.put("exceptionType", throwableProxy.getClassName());
            String exceptionMessage = throwableProxy.getMessage();
            if (exceptionMessage != null) {
                node.put("exceptionMessage", exceptionMessage);
            }
            StringBuilder stackTrace = new StringBuilder();
            ch.qos.logback.classic.spi.StackTraceElementProxy[] proxies = throwableProxy.getStackTraceElementProxyArray();
            if (proxies != null) {
                for (ch.qos.logback.classic.spi.StackTraceElementProxy proxy : proxies) {
                    if (proxy != null && proxy.getStackTraceElement() != null) {
                        stackTrace.append("  at ").append(proxy.getStackTraceElement().toString()).append('\n');
                    }
                }
            }
            if (stackTrace.length() > 0) {
                node.put("exceptionStackTrace", stackTrace.toString().trim());
            }
        }

        return node;
    }

    private String mapLevel(ch.qos.logback.classic.Level level) {
        if (level == null) {
            return LEVEL_INFORMATION;
        }
        switch (level.toInt()) {
            case ch.qos.logback.classic.Level.ERROR_INT:
                return LEVEL_ERROR;
            case ch.qos.logback.classic.Level.WARN_INT:
                return LEVEL_WARNING;
            case ch.qos.logback.classic.Level.INFO_INT:
                return LEVEL_INFORMATION;
            case ch.qos.logback.classic.Level.DEBUG_INT:
                return LEVEL_DEBUG;
            case ch.qos.logback.classic.Level.TRACE_INT:
                return LEVEL_VERBOSE;
            default:
                return LEVEL_INFORMATION;
        }
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public void setServiceName(String serviceName) {
        this.serviceName = serviceName;
    }

    public void setBatchSize(int batchSize) {
        this.batchSize = Math.max(1, batchSize);
    }

    public void setFlushIntervalMs(int flushIntervalMs) {
        this.flushIntervalMs = Math.max(100, flushIntervalMs);
    }

    public void setQueueSize(int queueSize) {
        this.queueSize = Math.max(1, queueSize);
    }

    public void setConnectTimeoutMs(int connectTimeoutMs) {
        this.connectTimeoutMs = Math.max(100, connectTimeoutMs);
    }

    public void setRequestTimeoutMs(int requestTimeoutMs) {
        this.requestTimeoutMs = Math.max(100, requestTimeoutMs);
    }

    public void setMaxRetries(int maxRetries) {
        this.maxRetries = Math.max(0, maxRetries);
    }

    public void setCircuitBreakerEnabled(boolean circuitBreakerEnabled) {
        this.circuitBreakerEnabled = circuitBreakerEnabled;
    }

    public void setCircuitBreakerFailureThreshold(int circuitBreakerFailureThreshold) {
        this.circuitBreakerFailureThreshold = Math.max(1, circuitBreakerFailureThreshold);
    }

    public void setCircuitBreakerCooldownMs(long circuitBreakerCooldownMs) {
        this.circuitBreakerCooldownMs = Math.max(0, circuitBreakerCooldownMs);
    }
}
