package com.alramz;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

import com.alramz.referencedata.model.ReferenceData;
import com.alramz.referencedata.repository.ReferenceDataRepository;
import com.alramz.scheduler.EnableScheduler;
import com.alramz.service.impl.NinTradingNumberValidationService;

import java.util.List;

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

	@Bean
	ApplicationRunner referenceDataDemoRunner(ReferenceDataRepository refDataRepository) {
		return args -> {
			log.info("");
			log.info("╔════════════════════════════════════════════════════════════════════════════════╗");
			log.info("║                Reference Data Framework - LIVE DEMO                            ║");
			log.info("╚════════════════════════════════════════════════════════════════════════════════╝");
			log.info("");

			try {
				// Query 1: Fetch all countries
				log.info("📍 DEMO 1: Querying Countries (COUNTRY_* identifiers)");
				List<ReferenceData> countryUS = refDataRepository.find("COUNTRY_US", null, null);
				countryUS.forEach(d -> log.info("   ✓ {} → Type: {} | Value: {} | Status: {}",
					d.getIdentifier(), d.getIdentifierType(), d.getIdentifierText(), d.getStatus()));

				List<ReferenceData> countryGB = refDataRepository.find("COUNTRY_GB", null, null);
				countryGB.forEach(d -> log.info("   ✓ {} → Type: {} | Value: {} | Status: {}",
					d.getIdentifier(), d.getIdentifierType(), d.getIdentifierText(), d.getStatus()));

				List<ReferenceData> countryAE = refDataRepository.find("COUNTRY_AE", null, null);
				countryAE.forEach(d -> log.info("   ✓ {} → Type: {} | Value: {} | Status: {}",
					d.getIdentifier(), d.getIdentifierType(), d.getIdentifierText(), d.getStatus()));
				log.info("");

				// Query 2: Fetch currencies
				log.info("💱 DEMO 2: Querying Currencies (CURRENCY_* identifiers)");
				List<ReferenceData> currencyUSD = refDataRepository.find("CURRENCY_USD", null, null);
				currencyUSD.forEach(d -> log.info("   ✓ {} → Type: {} | Value: {} | Status: {}",
					d.getIdentifier(), d.getIdentifierType(), d.getIdentifierText(), d.getStatus()));

				List<ReferenceData> currencyAED = refDataRepository.find("CURRENCY_AED", null, null);
				currencyAED.forEach(d -> log.info("   ✓ {} → Type: {} | Value: {} | Status: {}",
					d.getIdentifier(), d.getIdentifierType(), d.getIdentifierText(), d.getStatus()));
				log.info("");

				// Query 3: Fetch as map
				log.info("🗺️  DEMO 3: Query As Map (findAsMap)");
				var mapData = refDataRepository.findAsMap("CURRENCY_USD");
				mapData.forEach((key, values) -> log.info("   ✓ Key: {} | Values: {}", key, values));
				log.info("");

				log.info("═══════════════════════════════════════════════════════════════════════════════════");
				log.info("✅ Reference Data Framework Successfully Demonstrated!");
				log.info("   - ReferenceData table created automatically via JPA");
				log.info("   - Sample data inserted via Liquibase migration");
				log.info("   - All queries executed successfully from middleware database");
				log.info("═══════════════════════════════════════════════════════════════════════════════════");
				log.info("");
			} catch (Exception e) {
				log.warn("❌ Demo unavailable: {}", e.getMessage());
			}
		};
	}

}
