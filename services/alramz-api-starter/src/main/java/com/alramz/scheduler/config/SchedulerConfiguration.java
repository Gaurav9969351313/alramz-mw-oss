package com.alramz.scheduler.config;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.BeanFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;

import com.alramz.scheduler.repository.ScheduleJobRepository;
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
                                              final SchedulerProperties properties,
                                              final org.springframework.core.env.Environment environment) {

        ScheduleJobRepository scheduleJobRepository = null;
        try {
            if (environment.getProperty("spring.datasource.url") != null
                    || environment.getProperty("spring.datasource.driver-class-name") != null) {
                scheduleJobRepository = beanFactory.getBean(ScheduleJobRepository.class);
            }
        } catch (Exception e) { // NOPMD AvoidCatchingGenericException
            logger.debug("ScheduleJobRepository not available, falling back to YAML properties for scheduler jobs");
        }

        return new JobScheduleManager(threadPoolTaskScheduler, beanFactory, properties, scheduleJobRepository);
    }

    @Bean
    public org.springframework.boot.ApplicationRunner schedulerStartupRunner(ISchedulerService schedulerService) {
        return args -> {
            String jobGroupName = System.getProperty("JobGroupName");
            if (jobGroupName != null) {
                schedulerService.schedule(jobGroupName);
                logger.info("Scheduler is started for the group: {}", jobGroupName);
            }
        };
    }
}