package com.alramz.scheduler.config;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.BeanFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;

import com.alramz.scheduler.service.ISchedulerService;
import com.alramz.scheduler.service.impl.JobScheduleManager;

@Configuration
@ConditionOnScheduler
public class SchedulerConfiguration {
    private static final Logger logger = LoggerFactory.getLogger(SchedulerConfiguration.class);

    @Bean(name = "threadPoolTaskScheduler")
    public ThreadPoolTaskScheduler threadPoolTaskScheduler(SchedulerProperties properties) {
        ThreadPoolTaskScheduler threadPoolTaskScheduler = new ThreadPoolTaskScheduler();

        threadPoolTaskScheduler.setPoolSize(properties.getPoolSize());
        threadPoolTaskScheduler.setThreadGroupName(properties.getThreadGroupName());
        threadPoolTaskScheduler.setThreadNamePrefix(properties.getThreadNamePrefix());
        logger.debug("@Bean=threadPoolTaskScheduler created");
        return threadPoolTaskScheduler;
    }


    @Bean
    public ISchedulerService schedulerService(final ThreadPoolTaskScheduler threadPoolTaskScheduler,
                                              final BeanFactory beanFactory,
                                              final SchedulerProperties properties) {

        ISchedulerService schedulerService = new JobScheduleManager(threadPoolTaskScheduler, beanFactory, properties);

        Optional.ofNullable(System.getProperty("JobGroupName")).ifPresent(jobGroupName -> {
            logger.debug("@Bean=schedulerService created");
            schedulerService.schedule(jobGroupName);
            logger.info("Scheduler is started for the group: {}", jobGroupName);
        });
        return schedulerService;
    }
}