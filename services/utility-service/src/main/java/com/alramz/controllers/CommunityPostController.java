package com.alramz.controllers;

import com.alramz.api.CommunityApi;
import com.alramz.jwt.annotation.JwtSecured;
import com.alramz.logging.aspect.Loggable;
import com.alramz.model.CommunityPost;
import com.alramz.model.CommunityPostRequest;
import com.alramz.model.CommunityPostResponse;
import com.alramz.model.GenericResponse;
import com.alramz.service.CommunityPostService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.net.URI;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CommunityPostController implements CommunityApi {

    private final CommunityPostService communityPostService;

    @Override
    @JwtSecured(roles = "APP_UTILITY")
    @Loggable
    public ResponseEntity<GenericResponse> createCommunityPost(CommunityPostRequest communityPostRequest) {
        CommunityPost post = communityPostService.publish(communityPostRequest);

        GenericResponse body = new GenericResponse();
        body.setResponseCode("201");
        body.setResponseMessage("Created");
        body.setResponse(new CommunityPostResponse().post(post));
        // Correction to spec.md §3.3's own code sketch, which never sets correlationId on the
        // success path even though the §3.2 example response body includes one.
        body.setCorrelationId(extractCorrelationId());

        return ResponseEntity.created(URI.create("/api/v1/community/posts/" + post.getPostId()))
                .body(body);
    }

    private UUID extractCorrelationId() {
        String correlationId = null;
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes servletAttributes) {
            HttpServletRequest request = servletAttributes.getRequest();
            correlationId = request.getHeader("X-Correlation-Id");
        }
        if (correlationId == null || correlationId.isBlank()) {
            return UUID.randomUUID();
        }
        try {
            return UUID.fromString(correlationId);
        } catch (IllegalArgumentException ex) {
            return UUID.randomUUID();
        }
    }
}
