package com.alramz.service.impl;

import java.time.OffsetDateTime;

/**
 * Internal result of a Finoux {@code InsertPostData} call — adopted directly from the source
 * migration doc's own proposed design (spec.md §3.4), not invented here.
 */
public sealed interface FinouxResult permits FinouxResult.Posted, FinouxResult.Rejected, FinouxResult.Unavailable {

    record Posted(long postId, long postedUserId, String postedBy, String status,
                  OffsetDateTime createdAt, OffsetDateTime publishedAt, String postType) implements FinouxResult {
    }

    /** Non-2xx, or 2xx with isSuccess=false / missing post_ID. */
    record Rejected(int httpStatus, String finouxMessage) implements FinouxResult {
    }

    /** Timeout / connection failure / circuit breaker open. */
    record Unavailable(Throwable cause) implements FinouxResult {
    }
}
