package com.yuegang.zhihui.system.api;

public record InternalAiProviderConfig(
        String provider,
        String baseUrl,
        String chatModel,
        String embeddingModel,
        String apiKey,
        long version) {
    public boolean configured() {
        return apiKey != null && !apiKey.isBlank()
                && chatModel != null && !chatModel.isBlank()
                && embeddingModel != null && !embeddingModel.isBlank();
    }
}
