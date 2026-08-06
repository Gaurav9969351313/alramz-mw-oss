package com.alramz.logging.aspect;

import com.alramz.logging.config.LoggingProperties;
import com.alramz.logging.constants.LoggingConstants;
import com.alramz.logging.util.MDCUtil;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

import java.time.Duration;

/**
 * AOP aspect that times methods annotated with {@link Loggable}.
 * <p>
 * To keep log pipelines lean, execution is only logged when it exceeds the
 * configured {@code company.logging.performance.threshold} (default 500ms). The
 * correlation id and other diagnostic context (already in the MDC) are
 * automatically attached to the emitted log line.
 */
@Slf4j
@Aspect
@ConditionalOnProperty(name = "company.logging.aspect.enabled", havingValue = "true")
public class MethodExecutionLoggingAspect {

    private static final Logger logger = LoggerFactory.getLogger(MethodExecutionLoggingAspect.class);

    private final LoggingProperties properties;

    public MethodExecutionLoggingAspect(LoggingProperties properties) {
        this.properties = properties;
    }

    @Around("@annotation(com.alramz.logging.aspect.Loggable)")
    public Object logExecutionTime(ProceedingJoinPoint joinPoint) throws Throwable {
        long start = System.nanoTime();
        try {
            return joinPoint.proceed();
        } finally {
            long elapsedMs = (System.nanoTime() - start) / 1_000_000L;
            Duration threshold = properties.getPerformance().getThreshold();
            if (threshold == null || threshold.isNegative() || elapsedMs >= threshold.toMillis()) {
                String targetClass = resolveTargetClass(joinPoint);
                String methodName = joinPoint.getSignature().getName();
                logger.info("{}#{} executed in {}ms (correlationId={})",
                        targetClass, methodName, elapsedMs, MDCUtil.getCorrelationId());
            }
        }
    }

    private String resolveTargetClass(ProceedingJoinPoint joinPoint) {
        Object target = joinPoint.getTarget();
        if (target != null) {
            Class<?> clazz = target.getClass();
            // For cglib proxies report the user-facing class if possible.
            String className = clazz.getName();
            if (className.contains("$$")) {
                className = className.substring(0, className.indexOf("$$"));
                int lastDot = className.lastIndexOf('.');
                return lastDot > 0 ? className.substring(lastDot + 1) : className;
            }
            return clazz.getSimpleName();
        }
        return joinPoint.getTarget() != null ? joinPoint.getTarget().getClass().getSimpleName() : "unknown";
    }
}
