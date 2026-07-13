package com.yuegang.zhihui.system.api;

import java.time.OffsetDateTime;

public record AiProviderConfigView(
        String provider,
        String baseUrl,
        String chatModel,
        String embeddingModel,
        boolean apiKeyConfigured,
        String apiKeyMasked,
        long version,
        OffsetDateTime updatedAt) {
}
