package com.alramz;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DataValidationServiceApplication {

	// http://localhost:5001/api/v1/info
	public static void main(String[] args) {
		System.out.println("Gaurav Talele");
		SpringApplication.run(DataValidationServiceApplication.class, args);
	}

}
