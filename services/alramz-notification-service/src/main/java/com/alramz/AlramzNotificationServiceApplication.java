package com.alramz;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

import com.alramz.config.EmailProperties;

@SpringBootApplication
@EnableConfigurationProperties(EmailProperties.class)
public class AlramzNotificationServiceApplication {

	public static void main(String[] args) {
		SpringApplication.run(AlramzNotificationServiceApplication.class, args);
	}

}
