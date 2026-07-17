package com.alramz.controllers;


import java.net.InetAddress;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ApplicationController {

    @Value("${spring.application.name}")
    private String applicationName;

    @GetMapping("/api/v1/info")
    public Map<String, Object> info() throws Exception {

        Map<String, Object> response = new HashMap<>();
        response.put("applicationName", applicationName);
        response.put("host", InetAddress.getLocalHost().getHostName());
        response.put("timestamp", Instant.now());

        return response;
    }
}