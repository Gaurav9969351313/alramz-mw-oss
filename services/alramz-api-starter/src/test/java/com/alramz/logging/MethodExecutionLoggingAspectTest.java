package com.alramz.logging;

import com.alramz.logging.aspect.MethodExecutionLoggingAspect;
import com.alramz.logging.config.LoggingProperties;
import com.alramz.logging.util.LogMaskingUtil;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.Signature;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;

import java.time.Duration;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class MethodExecutionLoggingAspectTest {

    private MethodExecutionLoggingAspect aspect;
    private ListAppender<ILoggingEvent> appender;

    @BeforeEach
    void setUp() {
        LogMaskingUtil.configure(true, "********", List.of(), List.of());
        LoggingProperties properties = new LoggingProperties();
        properties.getPerformance().setThreshold(Duration.ofMillis(0));
        aspect = new MethodExecutionLoggingAspect(properties);

        Logger logger = (Logger) LoggerFactory.getLogger(MethodExecutionLoggingAspect.class);
        appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
    }

    @AfterEach
    void tearDown() {
        appender.stop();
    }

    @Test
    void logsExecutionWhenThresholdIsZero() throws Throwable {
        ProceedingJoinPoint joinPoint = mock(ProceedingJoinPoint.class);
        Signature signature = mock(Signature.class);
        when(joinPoint.proceed()).thenReturn("ok");
        when(joinPoint.getTarget()).thenReturn(new Object());
        when(joinPoint.getSignature()).thenReturn(signature);
        when(signature.getName()).thenReturn("doWork");

        aspect.logExecutionTime(joinPoint);

        List<ILoggingEvent> events = appender.list;
        assertThat(events).isNotEmpty();
        assertThat(events.get(0).getFormattedMessage()).contains("doWork").contains("executed in");
    }

    @Test
    void doesNotLogWhenAboveThreshold() throws Throwable {
        LoggingProperties properties = new LoggingProperties();
        properties.getPerformance().setThreshold(Duration.ofMinutes(5));
        aspect = new MethodExecutionLoggingAspect(properties);

        ProceedingJoinPoint joinPoint = mock(ProceedingJoinPoint.class);
        when(joinPoint.proceed()).thenReturn("ok");

        aspect.logExecutionTime(joinPoint);

        assertThat(appender.list).isEmpty();
    }
}
