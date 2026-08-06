package com.alramz.logging.aspect;

import java.lang.annotation.*;

/**
 * Opt-in marker annotation. When {@code company.logging.aspect.enabled=true},
 * every method annotated with {@code @Loggable} is timed by
 * {@link MethodExecutionLoggingAspect} and logged if its execution exceeds the
 * configured performance threshold.
 * <p>
 * By default neither arguments nor return values are logged.
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Loggable {
}
