package com.yuegang.zhihui.ai.infrastructure;

import com.yuegang.zhihui.ai.domain.ModelGateway;
import com.yuegang.zhihui.system.api.InternalAiProviderConfig;

public final class DynamicModelGateway implements ModelGateway {
    private final SystemAiProviderConfigClient configs;
    private volatile Cached cached;

    public DynamicModelGateway(SystemAiProviderConfigClient configs) { this.configs = configs; }
    @Override public String answer(String systemPrompt, String userPrompt) { return delegate().answer(systemPrompt, userPrompt); }
    @Override public String modelName() { return delegate().modelName(); }
    @Override public boolean available() { return delegate().available(); }

    private ModelGateway delegate() {
        InternalAiProviderConfig current;
        try { current = configs.current(); }
        catch (RuntimeException unavailable) {
            Cached value = cached;
            return value == null ? new UnavailableModelGateway() : value.gateway();
        }
        Cached value = cached;
        if (value != null && value.version() == current.version()) return value.gateway();
        ModelGateway gateway = current.configured()
                ? new DoubaoModelGateway(current.baseUrl(), current.apiKey(), current.chatModel())
                : new UnavailableModelGateway();
        cached = new Cached(current.version(), gateway);
        return gateway;
    }
    private record Cached(long version, ModelGateway gateway) {}
}
