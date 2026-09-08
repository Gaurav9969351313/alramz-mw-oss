package com.alramz;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

import com.alramz.scheduler.EnableScheduler;
import com.alramz.service.impl.NinTradingNumberValidationService;

@SpringBootApplication
@EnableScheduler(jobGroupName = "dataValidation")
public class DataValidationServiceApplication {

	private static final Logger log = LoggerFactory.getLogger(DataValidationServiceApplication.class);

	// http://localhost:8080/api/v1/info
	public static void main(String[] args) {
		SpringApplication.run(DataValidationServiceApplication.class, args);
	}

	@Bean
	ApplicationRunner runner(Environment env) {
		return args -> {
			String port = env.getProperty("server.port", "8080");
			String host = env.getProperty("server.address", "localhost");
			String appName = env.getProperty("spring.application.name", "unknown");
			log.info("========================================");
			log.info("App:        {}", appName);
			log.info("Host:        {}", host);
			log.info("Port:        {}", port);
			log.info("========================================");
		};
	}

	@Bean
	ApplicationRunner ninTradingCheckRunner(org.springframework.context.ApplicationContext context) {
		return args -> {
			NinTradingNumberValidationService service = context.getBeanProvider(NinTradingNumberValidationService.class).getIfAvailable(); // NOPMD LawOfDemeter
			if (service == null) {
				log.info("NinTradingNumberValidationService is not enabled (company.datasource.brok.enabled=false)");
				return;
			}
			boolean existsNin = service.checkIfNinOrTradingNumberExists("DFM", "0006545043", null);
			log.info("NIN exists for DFM/0006545043: {}", existsNin);
			boolean existsTrading = service.checkIfNinOrTradingNumberExists("DFM", null, "0047938213");
			log.info("Trading number exists for DFM/0047938213: {}", existsTrading);
		};
	}

}
