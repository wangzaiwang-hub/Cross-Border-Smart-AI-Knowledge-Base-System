package com.yuegang.zhihui.auth.domain;

import java.time.Instant;
import java.util.Objects;

public record AccessToken(String value, Instant expiresAt) {
    public AccessToken {
        if (Objects.requireNonNull(value, "value must not be null").isBlank()) {
            throw new IllegalArgumentException("value must not be blank");
        }
        Objects.requireNonNull(expiresAt, "expiresAt must not be null");
    }

    @Override public String toString() {
        return "AccessToken[value=[REDACTED], expiresAt=" + expiresAt + "]";
    }
}
