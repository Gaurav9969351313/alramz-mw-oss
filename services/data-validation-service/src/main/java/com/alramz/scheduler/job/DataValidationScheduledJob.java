package com.alramz.scheduler.job;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.alramz.scheduler.model.ScheduleInfoBean;
import com.alramz.scheduler.service.Schedulable;

@Component("dataValidationJobRunner")
public class DataValidationScheduledJob implements Schedulable {

    private static final Logger log = LoggerFactory.getLogger(DataValidationScheduledJob.class);

    @Override
    public void run(ScheduleInfoBean scheduleInfoBean) {
        log.info("Executing scheduled data validation job: scheduleId={}, cronExpr={}, mode={}",
                scheduleInfoBean.getScheduleId(),
                scheduleInfoBean.getCronExpr(),
                scheduleInfoBean.getScheduleMode());
    }
}