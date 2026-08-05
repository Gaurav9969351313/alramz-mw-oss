package com.alramz;

import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

@SpringBootApplication
public class DataValidationServiceApplication {

	// http://localhost:8080/api/v1/info
	public static void main(String[] args) {
		System.out.println("Gaurav Ta");
		SpringApplication.run(DataValidationServiceApplication.class, args);
	}

	@Bean
	ApplicationRunner runner(Environment env) {
		return args -> {
			String port = env.getProperty("server.port", "8080");
			String host = env.getProperty("server.address", "localhost");
			String appName = env.getProperty("spring.application.name", "unknown");
			System.out.println("========================================");
			System.out.println("Application: " + appName);
			System.out.println("Host:        " + host);
			System.out.println("Port:        " + port);
			System.out.println("========================================");
		};
	}

}
