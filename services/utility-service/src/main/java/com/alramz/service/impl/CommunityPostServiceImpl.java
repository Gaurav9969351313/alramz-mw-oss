package com.alramz.service.impl;

import com.alramz.audit.ApiAuditLog;
import com.alramz.audit.ApiAuditLogService;
import com.alramz.client.AbstractRestClient;
import com.alramz.config.FinouxProperties;
import com.alramz.exception.ApplicationException;
import com.alramz.exception.FinouxIntegrationException;
import com.alramz.exception.FinouxUnavailableException;
import com.alramz.exceptions.ApiCallFailedException;
import com.alramz.logging.aspect.Loggable;
import com.alramz.logging.util.MDCUtil;
import com.alramz.model.CommunityPost;
import com.alramz.model.CommunityPostRequest;
import com.alramz.model.FinouxData;
import com.alramz.model.FinouxInsertPostDataRequest;
import com.alramz.model.FinouxInsertPostDataResponse;
import com.alramz.model.FinouxParam;
import com.alramz.service.CommunityPostService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.timelimiter.TimeLimiter;
import org.owasp.html.PolicyFactory;
import org.owasp.html.Sanitizers;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class CommunityPostServiceImpl extends AbstractRestClient implements CommunityPostService {

    private static final int MAX_POST_DESC_LENGTH = 10000;
    private static final PolicyFactory SANITIZER =
            Sanitizers.FORMATTING.and(Sanitizers.LINKS).and(Sanitizers.BLOCKS);
    private static final String FINOUX_PATH = "/api/market";
    private static final String METHOD_NAME = "InsertPostData";
    private static final String VERSION = "2.0";
    private static final String HTTP_OK_BUSINESS_FAILURE_MARKER = "200";

    private final FinouxProperties finouxProperties;
    private final ObjectProvider<ApiAuditLogService> auditLogServiceProvider;
    private final Environment environment;

    public CommunityPostServiceImpl(
            @Qualifier("finouxService") WebClient webClient,
            @Qualifier("finouxCircuitBreaker") CircuitBreaker circuitBreaker,
            @Qualifier("finouxRetry") Retry retry,
            @Qualifier("finouxTimeLimiter") TimeLimiter timeLimiter,
            FinouxProperties finouxProperties,
            Environment environment,
            ObjectMapper objectMapper,
            ObjectProvider<ApiAuditLogService> auditLogServiceProvider) {
        super(webClient, circuitBreaker, retry, timeLimiter, environment, objectMapper);
        this.finouxProperties = finouxProperties;
        this.environment = environment;
        this.auditLogServiceProvider = auditLogServiceProvider;
    }

    @Override
    @Loggable
    public CommunityPost publish(CommunityPostRequest request) {
        String sanitizedDesc = sanitizeAndValidate(request.getPostDesc());
        FinouxInsertPostDataRequest finouxRequest = buildFinouxRequest(request, sanitizedDesc);
        FinouxResult result = dispatch(finouxRequest);
        return toCommunityPost(result);
    }

    /**
     * Package-private so the service test can exercise edge case #5 (postDesc empty/too-long
     * after sanitisation, and the &lt;script&gt;-stripping acceptance criterion) without mocking
     * the WebClient dispatch.
     */
    String sanitizeAndValidate(String rawPostDesc) {
        String sanitized = SANITIZER.sanitize(rawPostDesc);
        if (sanitized == null || sanitized.isBlank()) {
            throw new ApplicationException("postDesc", "postDesc must not be blank after sanitisation", "FNX004");
        }
        if (sanitized.length() > MAX_POST_DESC_LENGTH) {
            throw new ApplicationException("postDesc",
                    "postDesc must be at most " + MAX_POST_DESC_LENGTH + " characters after sanitisation", "FNX004");
        }
        return sanitized;
    }

    FinouxInsertPostDataRequest buildFinouxRequest(CommunityPostRequest request, String sanitizedDesc) {
        List<FinouxParam> params = new ArrayList<>();
        params.add(new FinouxParam("p_posted_user_id", String.valueOf(request.getPostedUserId())));
        params.add(new FinouxParam("p_user_name", request.getUsername()));
        params.add(new FinouxParam("p_posted_by", request.getPostedBy()));
        params.add(new FinouxParam("p_post_desc", sanitizedDesc));
        if (request.getTagSymbol() != null && !request.getTagSymbol().isBlank()) {
            params.add(new FinouxParam("p_tag_sc_comp_id", request.getTagSymbol()));
        }
        FinouxProperties.Post post = finouxProperties.getPost();
        params.add(new FinouxParam("p_posted_user_flag", post.getPostedUserFlag()));
        params.add(new FinouxParam("p_publish_flag", post.getPublishFlag()));
        params.add(new FinouxParam("p_post_type_id", post.getPostTypeId()));
        return new FinouxInsertPostDataRequest(METHOD_NAME, VERSION, params);
    }

    /** Not covered by a direct unit test — see technical_gaps (no repo precedent for mocking
     * the WebClient fluent chain). Kept deliberately thin: it only dispatches and translates the
     * outcome into a {@link FinouxResult}; the actual business mapping lives in
     * {@link #mapResponse} and {@link #toCommunityPost}, which are tested directly. */
    @Loggable
    FinouxResult dispatch(FinouxInsertPostDataRequest finouxRequest) {
        HttpHeaders headers = new HttpHeaders();
        if (finouxProperties.getApiKey() != null && !finouxProperties.getApiKey().isBlank()) {
            headers.set("X-API-Key", finouxProperties.getApiKey());
        }
        long startTime = System.currentTimeMillis();
        String status = "SUCCESS";
        Integer statusCode = null;
        String exceptionCause = null;
        String exceptionClass = null;
        Object responsePayload = null;
        try {
            FinouxInsertPostDataResponse response = call(
                    HttpMethod.POST,
                    FINOUX_PATH,
                    FinouxInsertPostDataRequest.class,
                    finouxRequest,
                    FinouxInsertPostDataResponse.class,
                    headers,
                    null
            ).block();
            responsePayload = response;
            return mapResponse(response);
        } catch (ApiCallFailedException e) {
            status = "FAILURE";
            statusCode = e.getResponseCode();
            exceptionCause = e.getResponseMessage();
            exceptionClass = e.getClass().getName();
            responsePayload = Map.of(
                    "statusCode", e.getResponseCode(),
                    "message", e.getResponseMessage()
            );
            return new FinouxResult.Rejected(e.getResponseCode(), e.getResponseMessage());
        } catch (RuntimeException e) { // NOPMD AvoidCatchingGenericException - timeout/connection/circuit-breaker-open
            status = "FAILURE";
            exceptionCause = e.getMessage();
            exceptionClass = e.getClass().getName();
            responsePayload = e.getMessage();
            return new FinouxResult.Unavailable(e);
        } finally {
            long durationMs = System.currentTimeMillis() - startTime;
            Map<String, Object> requestMap = new LinkedHashMap<>();
            requestMap.put("method", HttpMethod.POST.name());
            requestMap.put("uri", FINOUX_PATH);
            requestMap.put("body", finouxRequest);
            logOutboundApiCall(requestMap, responsePayload, status, statusCode, exceptionCause, exceptionClass, durationMs);
        }
    }

    private void logOutboundApiCall(Object requestPayload, Object responsePayload,
                                    String status, Integer statusCode, String exceptionCause,
                                    String exceptionClass, long durationMs) {
        ApiAuditLogService auditLogService = auditLogServiceProvider.getIfAvailable();
        if (auditLogService == null) {
            return;
        }
        String correlationId = MDCUtil.getCorrelationId();
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }
        auditLogService.log(new ApiAuditLog(
                UUID.fromString(correlationId),
                "OUTBOUND",
                environment.getProperty("spring.application.name", "unknown"),
                "CommunityPostServiceImpl.dispatch",
                FINOUX_PATH,
                HttpMethod.POST.name(),
                requestPayload,
                responsePayload,
                status,
                statusCode,
                exceptionCause,
                exceptionClass,
                durationMs,
                Instant.now()
        ));
    }

    FinouxResult mapResponse(FinouxInsertPostDataResponse response) {
        if (response == null || !Boolean.TRUE.equals(response.isSuccess())) {
            String message = response != null && response.message() != null
                    ? response.message()
                    : "Finoux did not confirm the post (isSuccess=false)";
            return new FinouxResult.Rejected(200, message);
        }

        Map<String, Object> row = firstRow(response.data());
        if (row == null || row.get("post_ID") == null) {
            return new FinouxResult.Rejected(200, "Finoux response is missing data.table[0].post_ID");
        }

        Long postId = asLong(row.get("post_ID"));
        Long postedUserId = asLong(row.get("posted_User_Id"));
        String postedBy = asString(row.get("posted_By"));
        String status = asString(row.get("status"));
        OffsetDateTime createdAt = asDateTime(row.get("created_Dtm"));
        OffsetDateTime publishedAt = asDateTime(row.get("publish_dtm"));
        String postType = asString(row.get("posttype"));

        return new FinouxResult.Posted(postId, postedUserId != null ? postedUserId : 0L,
                postedBy, status, createdAt, publishedAt, postType);
    }

    // Switch is exhaustive over FinouxResult's sealed permits (Posted/Rejected/Unavailable) with
    // no default branch needed — the compiler proves every case is handled.
    CommunityPost toCommunityPost(FinouxResult result) {
        return switch (result) {
            case FinouxResult.Posted posted -> buildCommunityPost(posted);
            case FinouxResult.Rejected rejected -> throw rejectionException(rejected);
            case FinouxResult.Unavailable unavailable ->
                    throw new FinouxUnavailableException("FNX012", "Finoux community service unavailable");
        };
    }

    private CommunityPost buildCommunityPost(FinouxResult.Posted posted) {
        CommunityPost post = new CommunityPost();
        post.setPostId(posted.postId());
        post.setPostedUserId(posted.postedUserId());
        post.setPostedBy(posted.postedBy());
        post.setStatus(posted.status() != null ? CommunityPost.StatusEnum.fromValue(mapStatus(posted.status())) : null);
        post.setCreatedAt(posted.createdAt());
        post.setPublishedAt(posted.publishedAt());
        post.setPostType(posted.postType());
        return post;
    }

    // Finoux's "status" column uses the same single-letter flag vocabulary as the outbound
    // p_publish_flag (see FinouxProperties.Post#publishFlag, default "A") rather than the
    // spec's spelled-out enum value, so the raw code is translated to the public contract here.
    private static String mapStatus(String finouxStatus) {
        return "A".equals(finouxStatus) ? "ACTIVE" : finouxStatus;
    }

    private FinouxIntegrationException rejectionException(FinouxResult.Rejected rejected) {
        boolean businessFailure = String.valueOf(rejected.httpStatus()).equals(HTTP_OK_BUSINESS_FAILURE_MARKER);
        String errorCode = businessFailure ? "FNX011" : "FNX010";
        return new FinouxIntegrationException(errorCode, rejected.finouxMessage());
    }

    private Map<String, Object> firstRow(FinouxData data) {
        if (data == null || data.table() == null || data.table().isEmpty()) {
            return null;
        }
        return data.table().get(0);
    }

    private static Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        return Long.parseLong(value.toString());
    }

    private static String asString(Object value) {
        return value != null ? value.toString() : null;
    }

    private static OffsetDateTime asDateTime(Object value) {
        return value != null ? OffsetDateTime.parse(value.toString()) : null;
    }
}
