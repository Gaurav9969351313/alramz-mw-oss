package com.alramz.service.impl;

import com.alramz.config.FinouxProperties;
import com.alramz.exception.ApplicationException;
import com.alramz.exception.FinouxIntegrationException;
import com.alramz.exception.FinouxUnavailableException;
import com.alramz.exceptions.ApiCallFailedException;
import com.alramz.model.CommunityPost;
import com.alramz.model.CommunityPostRequest;
import com.alramz.model.FinouxData;
import com.alramz.model.FinouxInsertPostDataRequest;
import com.alramz.model.FinouxInsertPostDataResponse;
import com.alramz.model.FinouxParam;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.timelimiter.TimeLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpMethod;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CommunityPostServiceImplTest {

    @Mock
    private WebClient webClient;
    @Mock
    private CircuitBreaker circuitBreaker;
    @Mock
    private Retry retry;
    @Mock
    private TimeLimiter timeLimiter;
    @Mock
    private Environment environment;
    @Mock
    private ObjectProvider<com.alramz.audit.ApiAuditLogService> auditLogServiceProvider;

    private FinouxProperties finouxProperties;
    private CommunityPostServiceImpl service;

    @BeforeEach
    void setUp() {
        finouxProperties = new FinouxProperties();
        finouxProperties.setBaseUrl("https://finoux.example.invalid");
        finouxProperties.setApiKey("test-api-key");
        finouxProperties.setRequestTimeoutSeconds(5);

        service = new CommunityPostServiceImpl(
                webClient, circuitBreaker, retry, timeLimiter,
                finouxProperties, environment, new ObjectMapper(), auditLogServiceProvider);
    }

    // --- sanitizeAndValidate (edge case #5 + <script>-stripping acceptance criterion) ---

    @Test
    void sanitizeAndValidate_shouldStripScriptTagButKeepFormattingMarkup() {
        String sanitized = service.sanitizeAndValidate("<p>Hello</p><script>alert('xss')</script>");

        assertThat(sanitized).contains("Hello");
        assertThat(sanitized).doesNotContain("<script>");
        assertThat(sanitized).doesNotContain("alert(");
    }

    @Test
    void sanitizeAndValidate_shouldThrowApplicationExceptionWhenBlankAfterSanitising() {
        // a pure script tag sanitises down to an empty string
        assertThatThrownBy(() -> service.sanitizeAndValidate("<script>alert('x')</script>"))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "postDesc")
                .hasFieldOrPropertyWithValue("serviceErrorResponseCode", "FNX004");
    }

    @Test
    void sanitizeAndValidate_shouldThrowApplicationExceptionWhenTooLongAfterSanitising() {
        String longText = "a".repeat(10_001);

        assertThatThrownBy(() -> service.sanitizeAndValidate(longText))
                .isInstanceOf(ApplicationException.class)
                .hasFieldOrPropertyWithValue("field", "postDesc")
                .hasFieldOrPropertyWithValue("serviceErrorResponseCode", "FNX004");
    }

    @Test
    void sanitizeAndValidate_shouldAllowDescriptionAtExactlyTheCapLength() {
        String exact = "a".repeat(10_000);

        String sanitized = service.sanitizeAndValidate(exact);

        assertThat(sanitized).hasSize(10_000);
    }

    // --- buildFinouxRequest ---

    @Test
    void buildFinouxRequest_shouldIncludeTagSymbolWhenPresent() {
        CommunityPostRequest request = new CommunityPostRequest(2L, "admin", "admin", "desc");
        request.setTagSymbol("1234");

        FinouxInsertPostDataRequest finouxRequest = service.buildFinouxRequest(request, "desc");

        assertThat(finouxRequest.method()).isEqualTo("InsertPostData");
        assertThat(finouxRequest.version()).isEqualTo("2.0");
        assertThat(finouxRequest.param()).extracting(FinouxParam::key)
                .contains("p_posted_user_id", "p_user_name", "p_posted_by", "p_post_desc",
                        "p_tag_sc_comp_id", "p_posted_user_flag", "p_publish_flag", "p_post_type_id");
    }

    @Test
    void buildFinouxRequest_shouldOmitTagSymbolWhenBlank() {
        CommunityPostRequest request = new CommunityPostRequest(2L, "admin", "admin", "desc");
        request.setTagSymbol(null);

        FinouxInsertPostDataRequest finouxRequest = service.buildFinouxRequest(request, "desc");

        assertThat(finouxRequest.param()).extracting(FinouxParam::key)
                .doesNotContain("p_tag_sc_comp_id");
    }

    // --- mapResponse + toCommunityPost (edge cases #7, #8, #9) ---

    @Test
    void mapResponse_shouldReturnPostedWhenSuccessfulWithPostId() {
        FinouxData data = new FinouxData(List.of(Map.of(
                "post_ID", 4747,
                "posted_User_Id", 2,
                "posted_By", "admin",
                "status", "A",
                "created_Dtm", "2025-07-24T16:40:42+00:00",
                "publish_dtm", "2025-07-24T16:40:42+00:00",
                "posttype", "2"
        )));
        FinouxInsertPostDataResponse response = new FinouxInsertPostDataResponse(true, "OK", data);

        FinouxResult result = service.mapResponse(response);

        assertThat(result).isInstanceOf(FinouxResult.Posted.class);
        FinouxResult.Posted posted = (FinouxResult.Posted) result;
        assertThat(posted.postId()).isEqualTo(4747L);
        assertThat(posted.postedBy()).isEqualTo("admin");

        CommunityPost post = service.toCommunityPost(result);
        assertThat(post.getPostId()).isEqualTo(4747L);
        assertThat(post.getStatus()).isEqualTo(CommunityPost.StatusEnum.ACTIVE);
    }

    @Test
    void mapResponse_shouldReturnRejectedWhenIsSuccessFalse() {
        FinouxInsertPostDataResponse response = new FinouxInsertPostDataResponse(false, "Business rule failed", null);

        FinouxResult result = service.mapResponse(response);

        assertThat(result).isInstanceOf(FinouxResult.Rejected.class);
        assertThat(((FinouxResult.Rejected) result).finouxMessage()).isEqualTo("Business rule failed");
    }

    @Test
    void mapResponse_shouldReturnRejectedWhenPostIdMissing() {
        FinouxData data = new FinouxData(List.of(Map.of("status", "ACTIVE")));
        FinouxInsertPostDataResponse response = new FinouxInsertPostDataResponse(true, "OK", data);

        FinouxResult result = service.mapResponse(response);

        assertThat(result).isInstanceOf(FinouxResult.Rejected.class);
    }

    @Test
    void mapResponse_shouldReturnRejectedWhenResponseIsNull() {
        FinouxResult result = service.mapResponse(null);

        assertThat(result).isInstanceOf(FinouxResult.Rejected.class);
    }

    @Test
    void toCommunityPost_shouldThrowFinouxIntegrationExceptionWithFNX010ForNon2xxRejection() {
        FinouxResult result = new FinouxResult.Rejected(500, "Finoux internal error");

        assertThatThrownBy(() -> service.toCommunityPost(result))
                .isInstanceOf(FinouxIntegrationException.class)
                .hasFieldOrPropertyWithValue("errorCode", "FNX010");
    }

    @Test
    void toCommunityPost_shouldThrowFinouxIntegrationExceptionWithFNX011ForBusinessFailureRejection() {
        FinouxResult result = new FinouxResult.Rejected(200, "isSuccess=false");

        assertThatThrownBy(() -> service.toCommunityPost(result))
                .isInstanceOf(FinouxIntegrationException.class)
                .hasFieldOrPropertyWithValue("errorCode", "FNX011");
    }

    @Test
    void toCommunityPost_shouldThrowFinouxUnavailableExceptionWithFNX012ForUnavailable() {
        FinouxResult result = new FinouxResult.Unavailable(new RuntimeException("connection refused"));

        assertThatThrownBy(() -> service.toCommunityPost(result))
                .isInstanceOf(FinouxUnavailableException.class)
                .hasFieldOrPropertyWithValue("errorCode", "FNX012");
    }

    @Test
    void mapResponse_shouldReturnRejectedWhenDataTableIsEmpty() {
        FinouxInsertPostDataResponse response = new FinouxInsertPostDataResponse(true, "OK", new FinouxData(List.of()));

        FinouxResult result = service.mapResponse(response);

        assertThat(result).isInstanceOf(FinouxResult.Rejected.class);
    }

    @Test
    void mapResponse_shouldParseStringPostId() {
        FinouxData data = new FinouxData(List.of(Map.of("post_ID", "4747", "posted_By", "admin")));
        FinouxInsertPostDataResponse response = new FinouxInsertPostDataResponse(true, "OK", data);

        FinouxResult result = service.mapResponse(response);

        assertThat(((FinouxResult.Posted) result).postId()).isEqualTo(4747L);
    }

    // --- publish() / dispatch() end-to-end (edge case #9: connection failure -> Unavailable) ---

    @Test
    void publish_shouldThrowFinouxUnavailableExceptionWhenWebClientDispatchFails() {
        CommunityPostRequest request = new CommunityPostRequest(2L, "admin", "admin", "<p>desc</p>");

        // webClient is an unstubbed Mockito mock: WebClient.method(...) returns null, so the
        // fluent chain NPEs inside AbstractRestClient.execute() — a RuntimeException, caught by
        // dispatch()'s generic catch and mapped to Unavailable/FNX012, exactly like a genuine
        // connection failure would be (same code path, no WebClient-mocking precedent needed).
        assertThatThrownBy(() -> service.publish(request))
                .isInstanceOf(FinouxUnavailableException.class)
                .hasFieldOrPropertyWithValue("errorCode", "FNX012");
    }

    @Test
    void dispatch_shouldReturnRejectedWhenApiCallFailedExceptionIsThrown() {
        when(webClient.method(any(HttpMethod.class)))
                .thenThrow(new ApiCallFailedException("/api/market", "POST", 500, "Finoux internal error"));

        FinouxResult result = service.dispatch(service.buildFinouxRequest(
                new CommunityPostRequest(2L, "admin", "admin", "desc"), "desc"));

        assertThat(result).isInstanceOf(FinouxResult.Rejected.class);
        assertThat(((FinouxResult.Rejected) result).httpStatus()).isEqualTo(500);
        assertThat(((FinouxResult.Rejected) result).finouxMessage()).isEqualTo("Finoux internal error");
    }
}
