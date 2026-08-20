package com.padeltms.platform.shared.web;

import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/public")
class PingController {

    @GetMapping("/ping")
    Map<String, Object> ping() {
        return Map.of("service", "padeltms-api", "time", Instant.now().toString());
    }
}